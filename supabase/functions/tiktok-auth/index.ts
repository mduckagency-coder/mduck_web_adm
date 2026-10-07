// =============================================================================
// tiktok-auth -- Login/vinculo com TikTok (Login Kit, OAuth 2.0) para o app.
//
// Por que no servidor: o client_secret do TikTok e os tokens NUNCA vao pro app.
//
// Rotas (todas em https://<projeto>.supabase.co/functions/v1/tiktok-auth/...):
//   POST /start     body {mode:"login"|"link"}  -> {url}  (link exige o JWT do usuario)
//   GET  /callback  (o TikTok redireciona pra ca)  -> redireciona pro app:
//                   mduck://tiktok?status=...&token_hash=...
//   POST /unlink    (JWT do usuario) -> desvincula a conta TikTok
//
// Status devolvidos ao app: ok | linked | cancelled | not_found | already_linked
//                           | error (com &reason=...)
//
// ---------------------------------------------------------------------------
// CONFIGURACAO (credenciais NAO ficam no codigo). No terminal:
//   supabase secrets set TIKTOK_CLIENT_KEY=xxxx
//   supabase secrets set TIKTOK_CLIENT_SECRET=xxxx
//   supabase secrets set TIKTOK_REDIRECT_URI=https://<projeto>.supabase.co/functions/v1/tiktok-auth/callback
//   supabase secrets set APP_CALLBACK_URL=mduck://tiktok
//   supabase functions deploy tiktok-auth --no-verify-jwt
// (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY ja existem nas Edge Functions.)
//
// No TikTok for Developers (Login Kit):
//   - Redirect URI: exatamente o TIKTOK_REDIRECT_URI acima
//   - Scopes: user.info.basic (open_id, avatar, nome de exibicao)
//             user.info.profile (username = @). Sem o profile, o @ NAO vem.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const TIKTOK_AUTHORIZE = "https://www.tiktok.com/v2/auth/authorize/";
const TIKTOK_TOKEN = "https://open.tiktokapis.com/v2/oauth/token/";
const TIKTOK_USERINFO = "https://open.tiktokapis.com/v2/user/info/";
const SCOPES = "user.info.basic,user.info.profile";
const STATE_TTL_MS = 10 * 60 * 1000;

const env = (k: string) => Deno.env.get(k) ?? "";
const admin = () =>
  createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function appRedirect(params: Record<string, string>) {
  const base = env("APP_CALLBACK_URL") || "mduck://tiktok";
  const q = new URLSearchParams(params).toString();
  return new Response(null, { status: 302, headers: { Location: `${base}?${q}` } });
}

function configured() {
  return env("TIKTOK_CLIENT_KEY") && env("TIKTOK_CLIENT_SECRET") && env("TIKTOK_REDIRECT_URI");
}

/** Usuario logado (pelo JWT do app) ou null. */
async function userFromRequest(req: Request) {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data } = await admin().auth.getUser(token);
  return data.user ?? null;
}

function randomState() {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

// ----------------------------------------------------------------------------
async function start(req: Request) {
  if (!configured()) return json({ error: "tiktok_not_configured" }, 503);
  const body = await req.json().catch(() => ({}));
  const mode = body.mode === "link" ? "link" : "login";
  let userId: string | null = null;
  if (mode === "link") {
    const user = await userFromRequest(req);
    if (!user) return json({ error: "unauthorized" }, 401);
    userId = user.id;
  }
  const state = randomState();
  const db = admin();
  await db.from("tiktok_oauth_states").insert({ state, mode, user_id: userId });
  // limpeza de estados velhos
  await db.from("tiktok_oauth_states").delete().lt("created_at", new Date(Date.now() - STATE_TTL_MS).toISOString());

  const url = new URL(TIKTOK_AUTHORIZE);
  url.searchParams.set("client_key", env("TIKTOK_CLIENT_KEY"));
  url.searchParams.set("scope", SCOPES);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("redirect_uri", env("TIKTOK_REDIRECT_URI"));
  url.searchParams.set("state", state);
  return json({ url: url.toString() });
}

// ----------------------------------------------------------------------------
async function callback(req: Request) {
  const u = new URL(req.url);
  const code = u.searchParams.get("code");
  const state = u.searchParams.get("state") ?? "";
  const error = u.searchParams.get("error");
  if (error) return appRedirect({ status: error === "access_denied" ? "cancelled" : "error", reason: error });
  if (!code || !state) return appRedirect({ status: "error", reason: "missing_code" });

  const db = admin();
  const { data: st } = await db.from("tiktok_oauth_states").select("*").eq("state", state).maybeSingle();
  await db.from("tiktok_oauth_states").delete().eq("state", state); // uso unico
  if (!st || Date.now() - new Date(st.created_at).getTime() > STATE_TTL_MS) {
    return appRedirect({ status: "error", reason: "invalid_state" });
  }

  // 1) troca o code por tokens (com o client_secret, so aqui no servidor)
  const tokenRes = await fetch(TIKTOK_TOKEN, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_key: env("TIKTOK_CLIENT_KEY"),
      client_secret: env("TIKTOK_CLIENT_SECRET"),
      code,
      grant_type: "authorization_code",
      redirect_uri: env("TIKTOK_REDIRECT_URI"),
    }),
  });
  const tok = await tokenRes.json().catch(() => ({}));
  if (!tokenRes.ok || !tok.access_token || !tok.open_id) {
    console.error("tiktok token error", tok);
    return appRedirect({ status: "error", reason: "token_exchange" });
  }

  // 2) dados do usuario (o @/username exige o scope user.info.profile)
  const scopes = String(tok.scope ?? "");
  const fields = ["open_id", "union_id", "avatar_url", "avatar_large_url", "display_name"];
  if (scopes.includes("user.info.profile")) fields.push("username");
  const infoRes = await fetch(`${TIKTOK_USERINFO}?fields=${fields.join(",")}`, {
    headers: { Authorization: `Bearer ${tok.access_token}` },
  });
  const info = (await infoRes.json().catch(() => ({})))?.data?.user ?? {};
  const openId: string = info.open_id ?? tok.open_id;
  const username: string | null = info.username ?? null;

  // 3) quem e essa pessoa na MDuck?
  const { data: identity } = await db.from("tiktok_identities").select("*").eq("open_id", openId).maybeSingle();
  let profile: { id: string; auth_user_id: string | null; agency_id: string | null } | null = null;

  if (st.mode === "link") {
    const { data: p } = await db.from("profiles").select("id, auth_user_id, agency_id").eq("auth_user_id", st.user_id).maybeSingle();
    if (!p) return appRedirect({ status: "error", reason: "profile_not_found" });
    if (identity && identity.profile_id !== p.id) return appRedirect({ status: "already_linked" });
    profile = p;
  } else if (identity) {
    const { data: p } = await db.from("profiles").select("id, auth_user_id, agency_id").eq("id", identity.profile_id).maybeSingle();
    profile = p ?? null;
  } else if (username) {
    // primeiro login: procura o cadastro da agencia pelo @ (sem TikTok vinculado ainda)
    const { data: candidates } = await db.from("profiles").select("id, auth_user_id, agency_id").ilike("tiktok_username", username);
    for (const c of candidates ?? []) {
      const { data: taken } = await db.from("tiktok_identities").select("open_id").eq("profile_id", c.id).maybeSingle();
      if (!taken) {
        profile = c;
        break;
      }
    }
  }
  if (!profile) return appRedirect({ status: "not_found" });

  // 4) conta de login: usa a existente ou cria uma (e-mail tecnico) pro perfil
  let authUserId = profile.auth_user_id;
  if (!authUserId) {
    const email = `tiktok_${openId.replace(/[^a-zA-Z0-9]/g, "").slice(0, 40)}@users.mduck.app`;
    const { data: created, error: cErr } = await db.auth.admin.createUser({ email, email_confirm: true });
    if (cErr || !created.user) return appRedirect({ status: "error", reason: "create_user" });
    authUserId = created.user.id;
    await db.from("profiles").update({ auth_user_id: authUserId }).eq("id", profile.id);
  }

  // 5) foto oficial: copia o avatar pro storage (URLs do TikTok expiram)
  let avatarUrl: string | null = null;
  const remoteAvatar = info.avatar_large_url ?? info.avatar_url;
  if (remoteAvatar) {
    try {
      const img = await fetch(remoteAvatar);
      if (img.ok) {
        const bytes = new Uint8Array(await img.arrayBuffer());
        const path = `${profile.id}.jpg`;
        await db.storage.from("avatars").upload(path, bytes, { contentType: "image/jpeg", upsert: true });
        avatarUrl = `${db.storage.from("avatars").getPublicUrl(path).data.publicUrl}?v=${Date.now()}`;
      }
    } catch (e) {
      console.error("avatar copy failed", e);
    }
  }

  // 6) grava identidade + tokens (tokens so a service role le)
  const now = new Date();
  // um perfil tem no maximo 1 TikTok: troca de conta substitui o vinculo antigo
  await db.from("tiktok_identities").delete().eq("profile_id", profile.id).neq("open_id", openId);
  await db.from("tiktok_identities").upsert({
    open_id: openId,
    union_id: info.union_id ?? null,
    profile_id: profile.id,
    auth_user_id: authUserId,
    display_name: info.display_name ?? null,
    username,
    avatar_url: avatarUrl,
    scopes,
    updated_at: now.toISOString(),
  });
  await db.from("tiktok_tokens").upsert({
    open_id: openId,
    access_token: tok.access_token,
    refresh_token: tok.refresh_token ?? null,
    expires_at: tok.expires_in ? new Date(now.getTime() + tok.expires_in * 1000).toISOString() : null,
    refresh_expires_at: tok.refresh_expires_in ? new Date(now.getTime() + tok.refresh_expires_in * 1000).toISOString() : null,
    scope: scopes,
    updated_at: now.toISOString(),
  });
  const profileUpdate: Record<string, unknown> = {};
  if (avatarUrl) profileUpdate.avatar_url = avatarUrl; // foto do TikTok = foto oficial
  if (username) profileUpdate.tiktok_username = username;
  if (Object.keys(profileUpdate).length) await db.from("profiles").update(profileUpdate).eq("id", profile.id);

  if (st.mode === "link") return appRedirect({ status: "linked" });

  // 7) login: gera um token de uso unico; o app troca por sessao (verifyOtp)
  const { data: authUser } = await db.auth.admin.getUserById(authUserId);
  const email = authUser.user?.email;
  if (!email) return appRedirect({ status: "error", reason: "no_email" });
  const { data: link, error: lErr } = await db.auth.admin.generateLink({ type: "magiclink", email });
  if (lErr || !link.properties?.hashed_token) return appRedirect({ status: "error", reason: "session" });
  return appRedirect({ status: "ok", token_hash: link.properties.hashed_token, type: "magiclink" });
}

// ----------------------------------------------------------------------------
async function unlink(req: Request) {
  const user = await userFromRequest(req);
  if (!user) return json({ error: "unauthorized" }, 401);
  const db = admin();
  const { data: p } = await db.from("profiles").select("id").eq("auth_user_id", user.id).maybeSingle();
  if (!p) return json({ error: "profile_not_found" }, 404);
  await db.from("tiktok_identities").delete().eq("profile_id", p.id); // tokens caem em cascata
  return json({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const path = new URL(req.url).pathname.replace(/\/+$/, "");
  try {
    if (path.endsWith("/start") && req.method === "POST") return await start(req);
    if (path.endsWith("/callback")) return await callback(req);
    if (path.endsWith("/unlink") && req.method === "POST") return await unlink(req);
    return json({ error: "not_found" }, 404);
  } catch (e) {
    console.error(e);
    if (path.endsWith("/callback")) return appRedirect({ status: "error", reason: "internal" });
    return json({ error: "internal" }, 500);
  }
});
