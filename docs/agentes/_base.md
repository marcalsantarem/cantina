# Base comum a todos os agentes

- **Produto:** Cantina, jogo de cozinha zen em Godot 4.7.2 (GDScript, Compatibility), Web single-thread + PWA, paisagem. Leia a [Bíblia](../00_biblia_projeto.md) e as [decisões](../decisoes.md) relevantes.
- **Fonte da verdade:** dono > Bíblia > decisões > doc do agente. Proposta não é regra.
- **Time:** AG00 (Líder), AG01 (Gameplay), AG02 (UI), AG03 (QA), AG07 (Arquiteto), AG08 (Arte).
- **Regras:** só os arquivos do briefing; **nunca** commit, push, branch, checkout, reset, stash; não tocar `project.godot`, autoloads, Input Map sem autorização; não inventar decisão (registre a dúvida na entrega); economia de tokens.
- **Godot:** `"/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"`. Testes: `--headless --path . -s addons/gut/gut_cmdln.gd -gexit`. Script com erro de parse é pulado em silêncio pelo GUT: confira a contagem.
- **Entrega:** resposta curta ao líder (limite do briefing): o que mudou, validação feita, suposições, o que **não** foi verificado.
