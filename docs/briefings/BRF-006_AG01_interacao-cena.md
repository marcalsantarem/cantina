# BRF-006 — AG01 — T-007 interação na cena
**Leia:** `docs/agentes/AG01_gameplay.md`, `docs/design/m1_hamburguer.md`, `docs/arte.md`, `scenes/kitchen/kitchen.tscn` (nós em `Stations`), sua lógica em `src/kitchen/logic/`. **Regra:** respostas curtas; sem commit/push/branches.
**Decisão do dono:** 4, 11–15 (feedback "Perfeito!/Bom/Ops" + brilho).
**Contrato com AG02 (UI, em paralelo):** cena `res://scenes/game/game.tscn`, raiz `Node3D` "Game" com script `src/kitchen/kitchen_controller.gd` (`class_name KitchenController`), que instancia `kitchen.tscn`. A UI liga em você só por estes sinais e métodos (não mude os nomes):
- `signal ticket_added(slot: int, ticket: TicketData)`
- `signal ticket_served(slot: int, ticket: TicketData, score: int, band: int, reply: String)` (band: 0 = <50, 1 = 50–79, 2 = ≥80)
- `signal gesture_feedback(quality: int, label: String, screen_pos: Vector2)` (quality = `Kitchen.Quality`)
- `func get_slot_screen_position(slot: int) -> Vector2` (posição na tela do `TicketRail/SlotN`)
- `func start() -> void` (começa a fila de bilhetes; antes disso nada chega)
**Fazer:** (1) Entrada por eventos de mouse (o toque vira mouse pelo `emulate_mouse_from_touch` padrão; não mexa no `project.godot`), raycast na camada 2, amostras normalizadas para o `GestureRecognizer`. (2) Itens 3D (modelos de `assets/models/kaykit/`) seguindo o dedo, encaixando nos `Snap`, voltando com tween quando soltos fora. (3) Picar na tábua, carne na panela com troca de modelo cru/no ponto/queimado e fumaça simples (partículas leves ou malha), virar com puxão (pulinho da carne), montagem empilhando no prato, servir na janela, prato volta (limpo/sujo/intocado) e some ao tocar, prato novo em 1,5 s. (4) Brilho curto no item ao fim de cada gesto + emitir `gesture_feedback`. (5) Teste de integração em `tests/integration/test_kitchen_controller.gd` simulando um hambúrguer completo por chamadas/amostras (sem janela). (6) Uma cena de teste manual não é necessária: o AG02 liga tudo em `main.tscn`.
**Permitido:** `src/kitchen/`, `scenes/game/`, `data/`, `tests/unit/test_*.gd` (seus), `tests/integration/`. **Proibido:** `scenes/kitchen/` (só instancie; se precisar mudar algo nela, registre na entrega), `src/ui/`, `scenes/ui/`, `scenes/main.tscn`, `project.godot`, `assets/`.
**Pronto quando:** suíte inteira verde (informe contagem), import sem erro, hambúrguer completo servido no teste de integração.
**Entrega:** até 6 linhas: o que funciona, desvios, o que não foi verificado (toque real).
