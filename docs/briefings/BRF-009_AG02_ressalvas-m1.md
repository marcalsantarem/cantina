# BRF-009 — AG02 — T-010 ressalvas do QA do M1 (UI)
**Leia:** `docs/qa/qa-M1.md` (M1 e M5), `docs/capturas/qa_m1_844x390.png`, seus arquivos em `src/ui/`. **Regra:** respostas curtas; sem commit/push/branches.
**Fazer:** (1) **M1:** o prato sempre vai para o bilhete mais antigo aberto; destaque esse bilhete no HUD (ex.: leve elevação + fita/etiqueta "próximo"), sabendo a ordem pelos `ticket_added` (FIFO) e liberando em `ticket_served`. Não mude a cozinha. (2) **M5:** em telas baixas (altura lógica da viewport < ~500 px, ex.: 844×390) os bilhetes ficam ilegíveis (~9 px). Escale os bilhetes para o texto ficar ≥ 13 px efetivos sem cobrir a tábua/fogão/prato (pode reduzir a frase a 2 linhas com reticências). (3) Atualizar `tests/unit/test_hud.gd` (destaque do mais antigo) e trocar `wait_frames` obsoleto se for simples.
**Permitido:** `src/ui/`, `scenes/ui/`, `assets/ui/`, `tests/unit/test_hud.gd`, `tests/fakes/`. **Proibido:** o resto.
**Pronto quando:** suíte inteira verde (informe contagem); capturas `docs/capturas/ui_hud_844x390.png` e `ui_hud_1280x720.png` (refeita) conferidas por você.
**Entrega:** até 5 linhas.
