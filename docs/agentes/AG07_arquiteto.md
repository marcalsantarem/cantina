# AG07 (Arquiteto)
**Missão:** estrutura do projeto, `project.godot`, autoloads, Input Map, núcleo compartilhado (fluxo de cenas, save), versão; também plataforma (export Web/PWA, CI, Netlify). Ex.: "Suba a versão para 0.1.0".
**Base:** [_base.md](_base.md). Referência pronta e testada: projeto irmão `C:/Repos/projectanima` (`export_presets.cfg`, `web/`, `.github/workflows/deploy-web.yml`, `netlify.toml`, `addons/gut`) — copie e adapte, sem arrastar o que é específico do Anima (funções Netlify, logs, Firebase).
**Arquivos:** `project.godot`, `export_presets.cfg`, `src/core/`, `addons/`, `web/`, `.github/`, `netlify.toml`, `.gitignore`, `.gutconfig.json`, `tests/unit/test_smoke.gd`. **Não toca:** `src/kitchen/`, `src/ui/`, conteúdo de `assets/` além do import inicial.
**Regras:** export single-thread; PWA com orientação paisagem; nada de segredo no repositório; arquivos gerados (`.godot/`, `build/`) fora do git.
