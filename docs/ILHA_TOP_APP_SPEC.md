# Ilha Top — spec técnica pro app do streamer (mduck_lives)

Tudo que a agência configura fica no Supabase compartilhado (mesmo banco do
admin `mduck_web_adm`). Este documento é o que o app do streamer precisa
consumir — nenhuma tela aqui, só schema + queries.

## 1. Modo teste (ativa/desativa no admin, aba "Pré-visualização")

Antes de tudo, toda consulta abaixo precisa checar se o modo teste está
ligado pra agência:

```sql
select value from app_settings
where agency_id = :agency_id and key = 'island_test_mode';
-- value = true (jsonb boolean) => modo teste ligado
```

Quando `island_test_mode = true`, a agência inteira entra em modo teste —
**ninguém é desbloqueado de verdade nesse modo**, é só pra pré-visualizar.
A configuração completa do teste fica na chave `island_test_config`
(jsonb) da mesma tabela:

```sql
select value from app_settings
where agency_id = :agency_id and key = 'island_test_config';
```

```json
{
  "diamond_threshold": 1000,
  "pinned_top1": "uuid-do-streamer|null",
  "pinned_top2": "uuid-do-streamer|null",
  "pinned_top3": "uuid-do-streamer|null",
  "rarity_locks": { "comum": false, "classico": false, "raro": false, "epico": true, "lendario": true }
}
```

Com `island_test_mode = true`, aplique **nessa ordem** em vez da regra
normal (80k fixo) em TODAS as queries de ranking da seção 4:

1. **`diamond_threshold`** substitui o mínimo de 80k — filtre por esse
   valor (pode ser 0, mostrando todo mundo).
2. **`pinned_top1`/`pinned_top2`/`pinned_top3`**: se preenchido, esse
   streamer ocupa exatamente aquela posição (`top_1`/`top_2`/`top_3`),
   **independente dos diamantes dele** (mesmo abaixo do `diamond_threshold`).
   Os streamers não fixados preenchem as posições restantes normalmente,
   ordenados por diamantes desc (as posições fixas "pulam a fila", o resto
   segue o ranking real entre si). Se um campo `pinned_topN` for `null`,
   essa posição é automática (por diamantes).
3. **`rarity_locks`**: ao montar a lista de avatares disponíveis pro
   streamer escolher (seção 7), se `rarity_locks[raridade do avatar] ==
   true`, esse avatar fica bloqueado nessa raridade **mesmo que o streamer
   já tivesse diamantes suficientes** (`min_diamonds`); se `false`, a
   raridade fica liberada **mesmo sem bater o `min_diamonds`** do avatar.
   Isso só vale com `island_test_mode = true`; fora do modo teste, ignore
   `island_test_config` inteiro e use as regras normais de cada avatar.

## 2. Fundo da ilha (vídeo/imagem, conforme horário)

```sql
select * from island_pick_background(p_agency_id := :agency_id);
```
Client: `supabase.rpc('island_pick_background', {'p_agency_id': agencyId})`.
Retorna a linha de `island_backgrounds` já escolhida pra hora atual
(resolve sozinho fixo vs. aleatório — não precisa reimplementar a lógica de
horário no app). Campos relevantes:

- `media_url` (vídeo ou imagem, ver `media_type`)
- `muted` (bool), `volume` (numeric 0–1), `loop_video` (bool)
- `crop_scale`, `crop_offset_x`, `crop_offset_y` — ver seção 5 (corte)

**Loop infinito não pode ser interrompido**: quando `loop_video = true`
nesse fundo (ou em qualquer vídeo abaixo), esse player precisa ser
independente/isolado dos outros players do app (ex: vídeo de aula do MAX).
Hoje o MAX pausa outros vídeos ao tocar — isso não pode acontecer com fundo
da ilha, avatar do pato nem mascote do Inventário.

## 3. Posições dos slots

```sql
select slot_key, label, pos_x, pos_y, scale, z_index,
       area_width, area_height, min_scale, is_enabled
from island_slots
where agency_id = :agency_id;
```

`slot_key`: `top_1` .. `top_10`, `top_11_plus` (área), `top_1_last_month`
(slot especial, ver seção 6). Ignore slots com `is_enabled = false`.

- `pos_x`/`pos_y`: % (0–100) do tamanho da imagem de fundo.
- `top_1`..`top_10`: ponto fixo — `left = pos_x/100 * largura`, `top =
  pos_y/100 * altura`, centralizado no `scale`.
- `top_11_plus`: uma ÁREA retangular (`area_width`/`area_height` em %) —
  distribua os avatares dentro dela (grid/wrap) sem sobrepor; use `scale`
  como tamanho normal e vá encolhendo até `min_scale` conforme a
  quantidade de streamers aumenta (poucos = `scale`, lotado = `min_scale`).
- `top_1_last_month`: ponto fixo, mas em vez do avatar escolhido, mostra
  **só a foto do streamer + nome + diamantes** (ver seção 6) — **sem
  nenhum texto tipo "Top 1 do mês passado"**, isso é só rótulo interno do
  admin, não é pra aparecer pro streamer.

## 4. Ranking (quem fica em cada slot)

```sql
-- diamantes do mes atual, streamers ativos da agencia
select p.id, p.display_name, p.avatar_url,
       ss.diamonds,
       si.avatar_id, ia.media_url as avatar_media_url,
       ia.crop_scale, ia.crop_offset_x, ia.crop_offset_y,
       ia.muted, ia.volume, ia.loop_video,
       ia.display_shape, ia.border_color, ia.size_mode, ia.size_percent
from profiles p
join streamer_stats ss on ss.streamer_id = p.id
left join streamer_islands si on si.streamer_id = p.id
left join island_avatars ia on ia.id = si.avatar_id
where p.is_active and p.agency_id = :agency_id
  and (:test_mode or ss.diamonds >= 80000)
order by ss.diamonds desc;
```

Ordene por diamantes desc; a posição na lista (1º, 2º, ...) define o
`slot_key`: `rank <= 10 ? 'top_' + rank : 'top_11_plus'`.

**Limite de quantidade (configurável no admin, aba "Posições da Ilha")**:
```sql
select value from app_settings
where agency_id = :agency_id and key = 'island_max_rank';
-- value = numero (jsonb) => so os top N por diamantes aparecem
-- value = null ou linha inexistente => sem limite, comportamento atual
```
Se tiver um valor, apliquem `limit :max_rank` na query acima (depois de
ordenar por diamantes) — os ranks além disso simplesmente não aparecem em
lugar nenhum da ilha (nem nos slots fixos, nem na área 11+).

**Atenção**: hoje o admin tem um botão "Desbloquear ilha" por streamer
(grava `streamer_islands.unlocked_at`). Decidam junto com a agência se o
app só deve mostrar quem tem `unlocked_at is not null` além de 80k+, ou se
todo 80k+ já aparece direto — isso muda o filtro da query acima.

**`avatar_id` pode vir `null`** (streamer nunca escolheu, ou o avatar que
ele tinha foi excluído) — nesse caso apliquem o fallback de avatar padrão
da seção 9.1 em vez de deixar o slot sem avatar.

## 5. Corte/enquadramento (zoom + posição)

Cada vídeo (fundo e avatar) tem `crop_scale` (1 = sem zoom), `crop_offset_x`
e `crop_offset_y` (% -50 a 50, deslocamento a partir do centro). Pra
reproduzir exatamente o que o admin configurou:

```dart
// pseudo-Flutter, mas a logica vale pra qualquer stack
ClipRect(
  child: Align(
    alignment: Alignment(cropOffsetX / 50, cropOffsetY / 50),
    child: SizedBox(
      width: frameWidth * cropScale,
      height: frameHeight * cropScale,
      child: VideoPlayer(..., fit: mediaFit),
    ),
  ),
)
```

**`mediaFit` muda conforme o que está sendo renderizado** — o editor do
admin usa o mesmo `fit` abaixo, então o que ele vê é o que precisa aparecer
no app:

- **Fundo da ilha**: `BoxFit.cover` — preenche a tela toda (full-bleed),
  cortando o excesso. `crop_scale = 1` já cobre o frame inteiro por padrão.
- **Avatar**: `BoxFit.contain` — mostra o arquivo **inteiro, sem cortar
  nada**, com `crop_scale = 1` (padrão). Só corta de propósito se o admin
  aumentar o `crop_scale` acima de 1 (zoom manual pra recortar uma parte
  específica). Isso importa principalmente pra GIF/imagem que não é
  quadrada — com `cover` ela apareceria cortada mesmo sem o admin querer;
  com `contain` aparece inteira, com faixas vazias nas bordas se a
  proporção não for quadrada.

## 6. Formatos de mídia e transparência

`media_url` (fundo e avatar) pode vir em qualquer um destes formatos —
todos aceitos no upload do admin: `mp4`, `mov`, `webm`, `m4v`, `gif`,
`webp`, `png`, `jpg`. Decida o player pela extensão (ou `Content-Type` da
resposta):

- **`mp4`/`mov`/`webm`/`m4v`** → vídeo de verdade, precisa de player de
  vídeo (`video_player` ou equivalente). **Nenhum desses formatos carrega
  transparência real no player** — mesmo que o arquivo original tenha sido
  exportado "com fundo transparente", ele chega como vídeo RGB opaco
  (geralmente com fundo preto ou verde sólido). Não tem correção possível
  no player padrão sem shader customizado — não implementem isso, é
  esperado que vídeo comum tenha fundo sólido.
- **`gif`/`webp`** → podem ser animados **com transparência real**. Dá pra
  tocar como imagem animada normal (ex: `Image.network(url)` no Flutter já
  decodifica GIF/WebP animado nativamente, sem precisar de video player) —
  é o formato recomendado pelo admin pra avatar com fundo transparente.
- **`png`/`jpg`** → imagem estática. PNG mantém transparência; JPG não.

Ou seja: se o avatar/fundo cadastrado for `gif` ou `webp`, tratem como
imagem animada (não como vídeo) pra transparência funcionar. Se for
`mp4`/`mov`/`webm`/`m4v`, é vídeo opaco normal — apliquem o corte da seção
5 e as opções da seção 7 do mesmo jeito, só sem esperar transparência.

## 7. Formato (recorte) e tamanho do avatar

Colunas novas em `island_avatars`, só pro slot do avatar escolhido pelo
streamer (fundo da ilha não usa isso):

- **`display_shape`** (text): `'circle_border'` (padrão), `'circle_plain'`
  ou `'square'`.
- **`border_color`** (text, hex tipo `#FFFFFF`): cor do anel, só relevante
  quando `display_shape = 'circle_border'`.
- **`size_mode`** (text): `'default'` (padrão) ou `'percent'`.
- **`size_percent`** (numeric, default 100): só relevante quando
  `size_mode = 'percent'`. 100 = tamanho real do arquivo; abaixo de 100
  diminui, acima aumenta.

Se qualquer uma dessas colunas vier `null` (avatar antigo, cadastrado antes
dessa feature), tratem como os defaults acima — mantém exatamente o visual
atual (círculo com borda, tamanho só pela escala do slot).

Ordem de aplicação, por cima do que já existe na seção 5 (corte) e da
`scale` do slot (seção 3):

```dart
// diametro final do avatar nesse slot
final baseDiameter = 44 * slot.scale; // 44 = tamanho base de referencia
final diameter = avatar.sizeMode == 'percent'
    ? baseDiameter * (avatar.sizePercent / 100)
    : baseDiameter; // 'default'

Widget mask({required Widget child}) {
  switch (avatar.displayShape) {
    case 'square':
      return ClipRRect(borderRadius: BorderRadius.circular(diameter * 0.12), child: child);
    case 'circle_plain':
      return ClipOval(child: child); // sem anel
    case 'circle_border':
    default:
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: hexToColor(avatar.borderColor), width: 1.5),
        ),
        child: ClipOval(child: child),
      );
  }
}
```

O corte/enquadramento (crop_scale/crop_offset_x/crop_offset_y, seção 5)
continua controlando o que aparece *dentro* do recorte — a máscara acima só
decide o formato da moldura e o tamanho final.

## 8. Top 1 do mês passado

```sql
-- pega o period_key mais recente que já foi fechado (importado)
select streamer_id, diamonds
from monthly_stats
where period_key = (select max(period_key) from monthly_stats)
order by diamonds desc
limit 1;
-- depois junta com profiles (display_name, avatar_url) pelo streamer_id,
-- filtrando so streamers ativos da agencia
```

Renderiza no slot `top_1_last_month`: **foto do streamer + nome + `💎 " +
diamonds`** — nada de texto de rótulo.

**Esse slot é sempre automático e incondicional**: não depende de 80k, de
"Desbloquear ilha" nem do modo teste/`island_test_config` — é só o
resultado dessa query. Assim que o mês vira e a agência importa a planilha
do mês fechado, o slot já atualiza sozinho pra mostrar quem foi o campeão,
sem nenhuma ação manual.

## 9. Avatares (patos) — banco e escolha do streamer

Lista de avatares disponíveis pro streamer escolher:

```sql
select id, label, media_url, gender, rarity, min_diamonds, category_ids,
       display_shape, border_color, size_mode, size_percent
from island_avatars
where agency_id = :agency_id and is_active = true
order by sort_order;
```

Filtre no app: `min_diamonds <= diamantes do streamer no mes` e
(`category_ids is null` ou `category_ids` contém a categoria do streamer
— `profiles` tem a categoria dele via `streamer_categories`). **Com modo
teste ligado, aplique antes o override de `rarity_locks` da seção 1** (pode
liberar uma raridade sem bater `min_diamonds`, ou bloquear mesmo batendo).

Gravar a escolha (RLS já libera o streamer atualizar só a própria linha):
```sql
update streamer_islands set avatar_id = :avatar_id
where streamer_id = :meu_profile_id;
```
Se a linha não existir ainda pra esse streamer, precisa de upsert com
`streamer_id`.

### 9.1 Avatar padrão (quando `avatar_id` é `null`)

`streamer_islands.avatar_id` pode ser `null` em dois casos: o streamer
nunca escolheu um avatar, ou o avatar que ele tinha escolhido foi excluído
pelo admin (a FK agora é `on delete set null` — excluir um avatar
desvincula automaticamente quem tinha escolhido ele, em vez de dar erro).

Nesses casos, resolvam um avatar padrão em vez de deixar o slot vazio,
nessa ordem de prioridade:

1. Avatar com `default_scope = 'category'` cujo `category_ids` contenha a
   categoria do streamer.
2. Se não achar nenhum, avatar com `default_scope = 'all'`.
3. Se nenhum dos dois existir, o slot fica vazio mesmo (sem avatar) — a
   agência ainda não configurou nenhum padrão.

```sql
select id, media_url, display_shape, border_color, size_mode, size_percent
from island_avatars
where agency_id = :agency_id and is_active = true
  and (
    (default_scope = 'category' and category_ids @> array[:categoria_do_streamer])
    or default_scope = 'all'
  )
order by (default_scope = 'category') desc -- categoria tem prioridade sobre "para todos"
limit 1;
```

**Coluna de compatibilidade**: `island_avatars.is_default` (boolean) também
existe, gerada automaticamente como `default_scope = 'all'`. Ela cobre só o
caso "padrão para todos" — se o código de vocês já checa
`is_default = true`, o caso "para todos" já passa a funcionar sozinho, sem
mudar nada. Mas ela **não sabe de categoria**: pra "padrão por categoria"
funcionar de verdade (e pra categoria ter prioridade sobre o "para todos",
como descrito acima), precisa trocar pra consultar `default_scope` +
`category_ids` direto, com a query completa acima.

Só pode existir um avatar `default_scope = 'all'` por agência e um por
categoria — o admin já garante isso ao salvar (desmarca o anterior
automaticamente), não precisa validar isso no app.

## 10. Áudio/volume/loop — em todo vídeo do app (não só a ilha)

As mesmas 3 colunas (`muted`, `volume`, `loop_video`) existem também em:
- `max_lessons` (aulas do MAX)
- chave `inventory_mascot_playback` em `app_settings` (jsonb:
  `{"muted": bool, "volume": number, "loop": bool}`) — pro vídeo do
  mascote do Inventário.

Regra do loop infinito (isolamento de player) vale igual pra esses dois.

## 11. Conta de teste (pra testar como um streamer de verdade)

Este repo (admin) não implementa login de streamer — isso é 100% do app.
Pra testar como um streamer real (ex: alguém pediu usar a conta
"gidreams_"): **não mexam no `auth_user_id` da conta real dele** (quebraria
o login de verdade). Caminhos seguros:
- Usar o **modo teste** (seção 1) + pedir pro próprio streamer (com login
  real dele) abrir o app e conferir — com modo teste ligado, ele aparece
  na ilha mesmo sem 80k.
- Ou criar um perfil de teste dedicado: um usuário novo no Supabase Auth +
  uma linha nova em `profiles` (não a do streamer real) vinculada a esse
  usuário via `auth_user_id`, só pra QA.
