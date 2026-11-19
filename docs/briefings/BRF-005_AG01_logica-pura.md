# BRF-005 — AG01 — T-005 lógica pura do hambúrguer
**Leia:** `docs/agentes/AG01_gameplay.md`, `docs/design/m1_hamburguer.md` (é a especificação), decisões 11–15 em `docs/decisoes.md`. **Regra:** respostas curtas; sem commit/push/branches.
**Contrato (T-007 e T-008 vão usar):** classes `class_name` em `src/kitchen/logic/`, sem `Node` de cena (estenda `RefCounted`/`Resource`), tempo e RNG injetáveis para teste:
- `GestureRecognizer`: recebe amostras `(Vector2 0–1, ms)` + aspecto; reconhece `chop` (cortes, CV, cobertura → qualidade), `flip` (puxão) e `drag` (soltura + distância ao alvo → qualidade de alinhamento). Buffer fixo de 128.
- `Patty`: tempo por lado, `flip()`, `remove()`, estado visual (id do glTF) e notas `lado_a`/`lado_b`.
- `ChopTarget`: cortes acumulados, sessão, estado (id do glTF) e nota de corte.
- `PlateStack`: itens empilhados com notas; pão vira bun_bottom + bun_top automaticamente.
- `TicketQueue`: até 3 bilhetes, novo 6 s após vaga, variação `sem` (70/10/10/10), sem expirar.
- `DishScorer`: nota 0–100 pelos 5 pesos e faixa (≥80 / 50–79 / <50) + erro dominante.
- `ReplyPicker`: frase do bilhete-resposta por faixa e erro dominante.
- Qualidade como enum `Quality { CLUMSY, GOOD, PERFECT }` + rótulos "Ops", "Bom", "Perfeito!" (decisão 14).
Dados (apelidos, frases de pedido e de resposta em pt-BR, receita) em `data/` como `.tres` ou `.json` lido por código; ao menos 8 clientes e 4 frases por faixa.
**Fazer:** implementar e testar no GUT (`tests/unit/test_<classe>.gd`), cobrindo limites dos números do design.
**Permitido:** `src/kitchen/logic/`, `data/`, `tests/unit/test_*.gd` (exceto `test_smoke.gd`), `docs/design/` (só para corrigir/esclarecer). **Proibido:** `scenes/`, `src/ui/`, `project.godot`, `assets/`.
**Armadilha:** script com erro de parse é pulado em silêncio pelo GUT; confira a contagem de testes.
**Pronto quando:** suíte inteira verde, contagem informada, sem alocação por frame no reconhecedor.
**Entrega:** até 6 linhas: classes, nº de testes/asserts, desvios do design, o que não foi verificado.
