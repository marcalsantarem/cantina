# BRF-019 — AG02 — T-023 ressalvas do QA do M2 (UI)
**Leia:** `docs/qa/qa-M2.md` (M2, M4, M5, M6), `src/ui/`. **Regra:** respostas curtas; sem commit/push/branches.
**Fazer:**
1. **M2** "sem X" por item: no combo, a etiqueta fica junto da linha do item a que pertence (não junta os `without` de todos).
2. **M4** aviso de pausa: conectar `pause_changed(paused: bool)` (o AG01 implementa em paralelo; o fake já tem o sinal; conecte por nome com `has_signal`) e mostrar "Pausado — toque para voltar" por cima da cozinha enquanto `paused`.
3. **M5** telas baixas (844×390) com 4 bilhetes: o balão de dica não pode cobrir a etiqueta "próximo"; texto do bilhete legível (≥ ~11 px reais) — reduza o conteúdo do cartão se precisar (ex.: frase em 1 linha com reticências) em vez de encolher a fonte.
4. **M6** (leve): ao carregar uma tigela de ensopado, se a dica de destino ajudar, destaque o bilhete que vai recebê-la — só se der para fazer só com sinais existentes; senão, diga o que precisaria e não faça.
5. Testes em `tests/unit/test_hud.gd`; capturas `docs/capturas/hud_m2_*` atualizadas em 1280×720 e 844×390, lidas e conferidas.
**Permitido:** `src/ui/`, `scenes/ui/`, `assets/ui/`, `tests/unit/test_hud.gd`, `tests/fakes/fake_kitchen_controller.gd` (só auxiliares/posições), `tools/capture/` (seus scripts), `docs/capturas/hud_m2_*`. **Proibido:** `src/kitchen/`, `scenes/kitchen/`, `data/`, `project.godot`.
**Pronto quando:** suíte verde (contagem informada; se falhar por arquivo do AG01 em andamento, diga e não conserte).
**Entrega:** até 6 linhas, incluindo o que não foi verificado.
