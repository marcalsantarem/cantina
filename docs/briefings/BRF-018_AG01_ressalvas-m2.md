# BRF-018 — AG01 — T-022 ressalvas do QA do M2 (cozinha)
**Leia:** `docs/qa/qa-M2.md` (G1–G3, M1, M3, M4, B1–B5), `docs/design/m2_turno.md`, `src/kitchen/`. **Regra:** respostas curtas; sem commit/push/branches.
**Fazer:**
1. **G1** tigela x mexer: decidir "servir" ao sair do raio da panela antes de considerar o ângulo (ou ignorar ângulo enquanto o raio < mínimo da volta). O teste `tests/integration/test_qa_m2_defects.gd` deve passar (não mais pending; pode remover o pending).
2. **G2** fumaça/vapor: partícula redonda e suave (textura gerada em código com gradiente radial, ou malha esférica), sem quadrados; fumaça escura translúcida, não sólida. Confira com captura (scratchpad) lida por você.
3. **G3 + balanceamento:** aplicar B1, B2, B3, B4 e B5 do relatório como estão (o líder aceitou). Atualize a spec (§1–§4) e os testes.
4. **M1** glifos: troque ↕ e ⟳ por texto ou caracteres que a fonte Fredoka tenha (confira).
5. **M3** panela queimada: dica "Raspe a panela (3 voltas)" e não "Mexa em círculos".
6. **M4** pausa: novo sinal `pause_changed(paused: bool)` emitido ao pausar/retomar por foco (o AG02 mostra o aviso; o fake já tem o sinal). No desktop, retomar com o próximo toque/clique também vale.
**Permitido:** `src/kitchen/`, `data/`, `tests/integration/`, `tests/unit/test_*.gd` (exceto `test_hud.gd`), `docs/design/m2_turno.md`. **Proibido:** `src/ui/`, `scenes/`, `assets/`, `project.godot`, `tests/fakes/`.
**Em paralelo:** AG02 (BRF-019) em `src/ui/`.
**Pronto quando:** suíte verde (contagem informada).
**Entrega:** até 6 linhas, incluindo o que não foi verificado.
