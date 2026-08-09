# Carregamento / Introdução — spec técnica pro app do streamer (mduck_lives)

Configurado no admin em "Configuração Animação APP" → "Carregamento" e
"Introdução". Mesmo banco compartilhado (Supabase) do admin `mduck_web_adm`.
Este documento é o que o app do streamer precisa consumir.

## O que é

Dois momentos, nessa ordem, ao abrir o app:

1. **Carregamento** (`kind = 'loading'`) — toca imediatamente ao abrir o
   app, como tela de splash/loading.
2. **Introdução** (`kind = 'intro'`) — toca logo em seguida, antes de
   entrar no app de verdade.

Cada um tem seu próprio banco de vídeos/imagens (pode ter vários
cadastrados), com janela de horário e modo fixo/aleatório — mesmo esquema
já usado nos fundos da Ilha Top.

## Buscar a mídia certa

```sql
select * from app_pick_splash_media(p_agency_id := :agency_id, p_kind := 'loading');
-- e depois, em seguida:
select * from app_pick_splash_media(p_agency_id := :agency_id, p_kind := 'intro');
```
Client: `supabase.rpc('app_pick_splash_media', {'p_agency_id': agencyId, 'p_kind': 'loading'})`.

A função já resolve a janela de horário sozinha (fixo vs. aleatório) — não
precisa reimplementar a lógica de horário no app. Pode retornar `null` (sem
linha) se a agência não tiver nada cadastrado/ativo pra aquele horário —
nesse caso pule direto pra próxima etapa (Carregamento sem linha → vai
direto pra Introdução; Introdução sem linha → vai direto pro app).

Campos relevantes de cada linha (`app_splash_media`):

- `media_url` (vídeo ou imagem, ver `media_type`)
- `media_type`: `'video'` ou `'image'`
- `muted` (bool), `volume` (numeric 0–1), `loop_video` (bool)

## Formatos de mídia

Mesmo critério da Ilha Top — só os formatos que o Flutter decodifica sem
plugin extra: `mp4`, `mov`, `webm`, `m4v` (vídeo), `gif`, `webp` (animados,
com transparência real), `png`, `jpg` (estáticos). Vídeo comum
(mp4/mov/webm/m4v) não carrega transparência de verdade — se algum desses
vier marcado como fundo transparente no admin, tratem como vídeo opaco
normal mesmo.

## Loop e áudio

Se `loop_video = true`, esse vídeo entra na mesma regra de player
isolado/loop infinito que já vale pro resto do app (fundo da Ilha Top,
avatar do pato, mascote do Inventário, aulas do MAX): não pode ser
pausado/interrompido por outro vídeo tocando em paralelo. Na prática, como
Carregamento e Introdução tocam em sequência e sozinhos (nada mais toca
junto), isso raramente é um problema real aqui — mas seguem as mesmas
colunas (`muted`/`volume`/`loop_video`) por consistência com o resto do
schema.

## Sem vídeo cadastrado

Se a agência não cadastrou nada em Carregamento e/ou Introdução (ou nada
está ativo pro horário atual), o app deve simplesmente pular essa etapa —
nunca travar ou mostrar tela em branco esperando uma mídia que não existe.
