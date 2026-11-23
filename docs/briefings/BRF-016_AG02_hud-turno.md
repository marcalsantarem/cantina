# BRF-016 — AG02 — T-020 HUD do M2
**Leia:** `docs/agentes/AG02_ui.md`, `docs/design/m2_turno.md` §1, §2, §3, §5 (e esclarecimentos), decisões 6, 16, 21, `src/ui/` (hud, ticket_card, main), `src/kitchen/logic/ticket_data.gd`, `shift_scorer.gd`, `shift_clock.gd` (só leitura). **Regra:** respostas curtas; sem commit/push/branches.
**Contrato de sinais do `KitchenController` (AG01 implementa em paralelo, BRF-015):**
- existentes: `ticket_added(slot, ticket)` — `ticket.items` é `Array` de `{recipe, without, delivered, score, dominant}`; `ticket_served(slot, ticket, score, band, reply)` (bilhete fechado); `gesture_feedback`; `action_hint`.
- novos: `ticket_item_delivered(slot: int, ticket: TicketData, item_index: int)`; `ticket_mood_changed(slot: int, mood: int)` (`ShiftScorer.Mood`: CONTENT, IMPATIENT, HUNGRY); `shift_phase_changed(phase: int)` (`ShiftClock.Phase`: OPENING, RUSH, CLOSING, LAST_ORDERS, CLOSED); `shift_ended(summary: Dictionary)` com chaves de `ShiftScorer.summarize`: `score, stars, quality, service, agility, served, arrived, items_delivered, items_total, avg_score, agility_word, best_reply`.
- `get_slot_screen_position(slot)` para 1..4. Conecte por nome com `has_signal` (como já faz).
**Fazer:**
1. **Bilhete multi-item:** 4 vagas; cada item mostra sua receita (ícones, como a decisão 16; ensopado = ícone `food_stew` + cenoura/batata/cebola picadas, ou só `food_stew` se ficar apertado) e recebe ✓ ao ser entregue. Cartões precisam caber 4 lado a lado em 16:9, 20:9 e 4:3 (ajuste escala), sem cobrir as bocas do fogão nem a janela.
2. **Humor:** impaciente = balanço leve a cada 5 s + carimbo "…"; faminto = papel amarelado + linha "Tô com fome, chef!".
3. **Placas do turno:** banner grande e breve: RUSH "Hora do almoço!", LAST_ORDERS "Últimos pedidos", CLOSED "Fechado!". Sem número de tempo na HUD (decisão 21).
4. **Tela de fim de turno:** estrelas uma a uma, "Pedidos atendidos X/Y", nota média, palavra de agilidade, melhor frase; botão "Jogar de novo" (recarrega jogo + HUD sem voltar à tela inicial; implemente em `main.gd`). "Próximo dia" fica para o M3 (não mostrar). Alvos ≥ 48 px, toque + mouse.
5. Testes: atualize `tests/unit/test_hud.gd` usando `tests/fakes/fake_kitchen_controller.gd` — o líder já acrescentou nele os 4 sinais novos (pode acrescentar métodos auxiliares de teste, sem mexer nos sinais). Suíte verde.
6. Capturas lidas e conferidas: `docs/capturas/hud_m2_*.png` (bilhetes com 2 itens e humor, placa, fim de turno) em 1280x720 e 1688x780.
**Permitido:** `src/ui/`, `scenes/ui/`, `scenes/main.tscn`, `assets/ui/`, `tests/unit/test_hud.gd`, `tests/fakes/fake_kitchen_controller.gd` (só posições de slot/auxiliares; sinais já prontos), `tools/capture/` (scripts seus), `docs/capturas/hud_m2_*.png`. **Proibido:** `src/kitchen/`, `scenes/kitchen/`, `data/`, `project.godot`.
**Pronto quando:** suíte verde (contagem informada; se falhar por arquivo do AG01 em andamento, diga e não conserte); capturas conferidas.
**Entrega:** até 8 linhas, incluindo o que não foi verificado.
