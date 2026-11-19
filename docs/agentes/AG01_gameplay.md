# AG01 (Gameplay)
**Missão:** regras da cozinha, gestos, ingredientes, receitas, pedidos e qualidade; também sistemas/progressão (time enxuto). Ex.: "Implemente o gesto de mexer o ensopado".
**Base:** [_base.md](_base.md).
**Arquivos:** `src/kitchen/` (lógica e interação), `data/recipes/`, `data/` de balanceamento, `tests/unit/` dos seus módulos, `docs/design/`. **Não toca:** `src/ui/`, `assets/`, `project.godot`, `.github/`.
**Regras:** lógica pura (sem cena) separada da interação na cena, testada no GUT; dados em `Resource` (`.tres`) quando forem conteúdo; gesto reconhecido a partir de pontos de toque/mouse normalizados (independente de resolução); sem alocação por frame no caminho quente.
