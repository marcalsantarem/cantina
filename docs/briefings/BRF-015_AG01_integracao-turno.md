# BRF-015 — AG01 — T-019 integração do M2 na cozinha
**Leia:** `docs/agentes/AG01_gameplay.md`, `docs/design/m2_turno.md` (incl. esclarecimentos), decisões 6, 19–21, `src/kitchen/kitchen_controller.gd`, as classes novas de `src/kitchen/logic/`, `docs/arte.md` (fogão e relógio), `scenes/kitchen/kitchen.tscn` (só leitura). **Regra:** respostas curtas; sem commit/push/branches.
**Fazer no `KitchenController`:**
1. **Turno:** `ShiftClock` dirige as chegadas (substitui o spawn do M1); 4 vagas (`Slot1..4`, `SLOT_COUNT = 4`); ponteiros do `Set/WallClock` pela `wall_clock()`; relógio pausa com o app em segundo plano (`NOTIFICATION_APPLICATION_FOCUS_OUT/PAUSED`); aos 180 s a cozinha congela, itens em preparo somem, e após `END_SCREEN_DELAY_S` emite o resumo.
2. **Cozinha viva:** `Stove_Pan` e `Stove_Pan2`, cada um com sua `Patty` independente (tremor da frigideira no filho `Model`, não mais `"Pan"`); `Stove_Pot` com `StewPot` + `StirGesture` (mexer começa dentro da panela), modelo `pot_A`/`pot_A_stew`, picados visíveis na panela; `Fx_Alert` (frigideira ≥ 10 s no lado ou panela `STICKING`+), `Fx_Steam` (cozinhando/pronto), `Fx_Bubbles` (grudando+). Caixotes `Crate_carrot/potato/onion` dão os crus; tábua pica com os cortes da spec.
3. **Servir item a item:** prato montado ou tigela (arrastar da panela pronta gera `food_stew` na mão) à `OrderWindow` → `TicketQueue.deliver`; se ninguém espera, volta à origem e dica "Ninguém pediu isso agora". O que volta pela janela usa `DishScorer.return_model_for`.
4. **Humor:** acompanhar `ShiftScorer.ticket_mood` por bilhete aberto e emitir quando mudar (sem alocação por frame).
5. **Dicas (decisão 18):** acrescentar "Solte os legumes na panela", "Mexa em círculos ⟳", "Arraste a tigela à janela", e as do M1 continuam.
**Contrato de sinais com AG02 (em paralelo, BRF-016) — mantenha exatamente:**
- existentes: `ticket_added(slot, ticket)` (agora com `ticket.items`), `ticket_served(slot, ticket, score, band, reply)` (só quando o bilhete fecha), `gesture_feedback`, `action_hint`.
- novos: `ticket_item_delivered(slot: int, ticket: TicketData, item_index: int)`; `ticket_mood_changed(slot: int, mood: int)` (`ShiftScorer.Mood`); `shift_phase_changed(phase: int)` (`ShiftClock.Phase`); `shift_ended(summary: Dictionary)` (`ShiftScorer.summarize`).
- `get_slot_screen_position(slot)` vale para 1..4. `start()` inicia o turno.
**Testes:** atualize/adicione em `tests/integration/test_kitchen_controller.gd` (turno acelerado com `advance`, duas frigideiras, ensopado do picar ao servir, entrega item a item, fim de turno com resumo). Suíte inteira verde.
**Permitido:** `src/kitchen/`, `data/`, `tests/integration/`, `tests/unit/test_*.gd` (exceto `test_hud.gd`), `tests/fakes/fake_kitchen_controller.gd` (o líder já acrescentou os 4 sinais novos; não edite), `docs/design/m2_turno.md` (esclarecimentos). **Proibido:** `src/ui/`, `scenes/`, `assets/`, `project.godot`.
**Pronto quando:** suíte verde (contagem informada); captura opcional de um turno em andamento em `docs/capturas/turno_m2.png` lida e conferida.
**Entrega:** até 8 linhas, incluindo o que não foi verificado.
