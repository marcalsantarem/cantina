# BRF-012 — AG01 — T-014 design do M2 "Turno"
**Leia:** `docs/agentes/AG01_gameplay.md`, Bíblia, decisões 6, 9, 19 e 20 (revistas hoje: o dono achou o jogo monótono e repetitivo), `docs/design/m1_hamburguer.md`, `src/kitchen/kitchen_controller.gd` (só para saber o que já existe). **Regra:** respostas curtas; sem commit/push/branches; só documento, sem código.
**Problema a resolver:** hoje é 1 receita, gestos sempre na mesma fila, 1 bilhete por vez, nada em jogo. Precisa de tensão, malabarismo e variedade, sem derrota.
**Fazer:** escrever `docs/design/m2_turno.md` (enxuto, tabelas, números concretos), cobrindo:
1. **Turno:** duração (~3 min), curva de chegada de bilhetes (calmaria → rush → fechamento), máximo de bilhetes abertos, o que acontece com o tempo (relógio visível? em que forma — ex.: sol/relógio de parede na cena), fim do turno.
2. **Estrelas:** fórmula de 1–3 estrelas (nota média + agilidade/pedidos atendidos), sem derrota; tela de fim de turno (o que mostra; a UI é do AG02).
3. **Paciência sem derrota:** se o bilhete esperar demais, o que acontece (ex.: nota cai aos poucos, frase-resposta muda), sem cliente ir embora — ou proponha alternativa justificada.
4. **Cozinha viva (decisão 19):** chapa com 2–3 vagas cozinhando em paralelo; panela de ensopado (`pot_A`/`stew_pot`, cenoura/batata/cebola picadas, gesto de **mexer** em círculo) que cozinha sozinha e gruda/queima se não for mexida; sinais visuais/sonoros de "precisa de atenção". Estados e tempos em tabela, como no §3 do M1.
5. **Pedidos com 2 itens (decisão 20):** ex.: hambúrguer + ensopado; como o prato/tigela vai à janela (servir item a item ou bandeja), como a nota junta os itens.
6. **Conteúdo do M2:** quais receitas entram no M2 e o que fica para o M3 (cardápio que cresce, decisão 9), usando só modelos de `KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf` (há `food_stew`, `stew_bowl`, `pot_A_stew`, `food_vegetableburger`, `food_dinner`, `crate_carrots/onions/potatoes/ham`, `stove_multi`, `oven`; **não** há batata frita nem bebida).
7. **Ritmo de dificuldade dentro do turno** e esboço dos dias 1–5 para o M3 (o que cada dia libera).
8. **Perguntas ao dono:** no máximo 4, objetivas, com sua recomendação.
9. Lista de tasks sugeridas para implementar o M2 (agente, tamanho P/M).
**Permitido:** `docs/design/m2_turno.md`. **Proibido:** todo o resto.
**Entrega:** até 6 linhas + as perguntas.
