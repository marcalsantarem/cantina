# BRF-002 — AG01 — T-002 design do fluxo do hambúrguer
**Leia:** `docs/agentes/AG01_gameplay.md`, `docs/00_biblia_projeto.md` (seções Pilares, Gestos, Clientes). Lista de modelos: `ls KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf`. **Regra:** respostas curtas; sem commit/push/branches; **não escreva código**.
**Decisão do dono:** 3 (cena única de frente), 4 (gestos definem qualidade), 5 (clientes invisíveis), 6 (Zen: sem relógio nem derrota).
**Contrato:** ids de ingrediente/estado = nome base do modelo glTF (ex.: `food_ingredient_tomato_slice`), pois os ícones (AG08) e os modelos usam esses nomes.
**Fazer:** escrever `docs/design/m1_hamburguer.md`, curto e implementável (será a especificação do T-005 e T-007):
(1) receita do hambúrguer (pão de baixo, carne, queijo, alface, tomate, pão de cima) e a máquina de estados de cada ingrediente, ligando cada estado ao modelo glTF;
(2) cada gesto (pegar/arrastar, picar em zigue-zague, virar com puxão, montar, servir): entrada (pontos normalizados 0–1 e tempo), critério de reconhecimento e cálculo da qualidade (perfeito/bom/desajeitado) com números iniciais;
(3) cozimento sem relógio de pressão: como a carne passa de crua → no ponto → queimada (tempos) e por que isso não contradiz o Zen (sem derrota);
(4) bilhetes: formato do pedido (apelido, frase, variação simples), nota final do prato e 3 faixas de bilhete-resposta com exemplos de texto em pt-BR (tom caloroso e bem-humorado), e o que volta pela janela;
(5) estações da cena (nomes dos `Marker3D`/`Area3D` que a Arte vai criar): `Crate_<ingrediente>`, `CuttingBoard`, `Stove_Pan`, `Plate_Assembly`, `OrderWindow`, `TicketRail`;
(6) lista de dúvidas para o dono.
**Permitido:** `docs/design/`. **Proibido:** todo o resto.
**Pronto quando:** documento com as 6 seções, números concretos, ≤ 150 linhas.
**Entrega:** até 6 linhas: resumo e dúvidas para o dono.
