# BRF-001 — AG07 — T-001 projeto Godot + Web/PWA e T-006 CI/Netlify
**Leia:** `docs/agentes/AG07_arquiteto.md`, `CLAUDE.md`. Referência: `C:/Repos/projectanima` (`project.godot`, `export_presets.cfg`, `web/`, `.github/workflows/deploy-web.yml`, `netlify.toml`, `.gutconfig.json`, `addons/gut`). **Regra:** respostas curtas; sem commit/push/branches.
**Decisão do dono:** 1 (Godot web + PWA), 2 (paisagem), 7 (Netlify, link por tag), 8 (KayKit).
**Contrato:** modelos em `assets/models/kaykit/<nome>.gltf` (+ `.bin`) com a textura `assets/models/kaykit/restaurantbits_texture.png`, nomes iguais aos originais. A cena principal será `res://scenes/main.tscn` (crie um placeholder com uma `Camera3D` e um `Label` "Cantina").
**Fazer:**
(1) `project.godot` na raiz: nome "Cantina", versão `0.1.0` (`application/config/version`), renderer `gl_compatibility`, janela 1280×720, stretch `canvas_items`/`expand`, orientação landscape, cena principal acima.
(2) GUT (mesma versão do Anima) em `addons/gut`, `.gutconfig.json` (`tests/unit`, `tests/integration`), `tests/unit/test_smoke.gd` (confere versão 0.1.0).
(3) Copiar **só** `KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/*` para `assets/models/kaykit/` + `License.txt`. Criar `KayKit_Restaurant_Bits_1.0_FREE/.gdignore` e ignorar essa pasta no `.gitignore` (não apagar a pasta).
(4) `.gitignore` (base do Anima sem Firebase).
(5) `export_presets.cfg` preset "Web": thread_support desligado, PWA ligado com orientação **paisagem**, ícones e manifesto (adaptar `web/` do Anima: shell, splash e ícones placeholder com nome "Cantina", cores da paleta: creme `#F3E3C3`, verde-água `#2BB59A`, laranja `#E8713A`). Excluir de export o que não for do jogo (`tests/`, `addons/gut`, `docs/`, `modo_trabalho/`, `tools/`).
(6) `.github/workflows/deploy-web.yml` adaptado: testes GUT → export → deploy Netlify: push na `dev` → alias `dev`; push na `main` → produção; tag → alias da tag + GitHub Release com o zip. Se os segredos `NETLIFY_AUTH_TOKEN`/`NETLIFY_SITE_ID` não existirem, o job de deploy é **pulado** sem falhar. `netlify.toml` só com cabeçalhos de cache (sem funções).
(7) Import headless, rodar testes e export local para `build/web/`.
**Permitido:** raiz (`project.godot`, `export_presets.cfg`, `.gitignore`, `.gutconfig.json`, `netlify.toml`), `addons/`, `web/`, `.github/`, `src/core/`, `scenes/main.tscn`, `tests/unit/test_smoke.gd`, `assets/models/kaykit/`, `KayKit_Restaurant_Bits_1.0_FREE/.gdignore`. **Proibido:** `docs/`, `modo_trabalho/`, `src/kitchen/`, `src/ui/`, `assets/icons/`, `tools/`.
**Pronto quando:** import sem erro; GUT verde (contagem informada); `build/web/index.html` gerado com manifesto em paisagem; workflow YAML válido.
**Entrega:** até 8 linhas: arquivos criados, contagem de testes, tamanho de `build/web` (`.wasm`/`.pck`), o que não foi verificado (CI só roda no GitHub).
