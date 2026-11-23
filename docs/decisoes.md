# Registro de decisões

| # | Tema | Estado | Decisão | Origem e data |
|---|---|---|---|---|
| 1 | Engine e plataforma | Decidido | Godot (4.7.2, GDScript), exportado para Web e PWA. | Definido pelo dono do projeto em 2026-11-19 |
| 2 | Orientação | Decidido | No mobile o jogo roda só em paisagem. | Definido pelo dono do projeto em 2026-11-19 |
| 3 | Câmera | Decidido | Câmera fixa de frente para a cozinha, sem personagem visível, em cena única (toda a bancada visível de uma vez). | Definido pelo dono do projeto em 2026-11-19 |
| 4 | Gestos de cozinheiro | Decidido | Cada ação é um gesto (picar, virar, mexer…); a precisão define a qualidade do prato. | Definido pelo dono do projeto em 2026-11-19 |
| 5 | Clientes invisíveis | Decidido | Clientes não aparecem: existem nos bilhetes de pedido e no que volta pela janela. | Definido pelo dono do projeto em 2026-11-19 |
| 6 | Ritmo | Decidido | Substitui o Zen (achado monótono): cada dia é um turno curto (~3 min) com calmaria e hora do rush. Sem derrota; ao fim do turno, 1–3 estrelas por nota e agilidade. | Revisto pelo dono do projeto em 2026-11-23 (antes: Zen, 2026-11-19) |
| 7 | Deploy | Decidido | Netlify como no Anima: build no GitHub Actions; cada tag gera link de teste próprio. | Definido pelo dono do projeto em 2026-11-19 |
| 8 | Assets | Decidido | KayKit Restaurant Bits (CC0) como base visual; crédito a Kay Lousberg. | Pasta fornecida pelo dono em 2026-11-19 |
| 9 | Progressão | Decidido | Cardápio que cresce: cada dia novo traz receita ou estação nova; as estrelas desbloqueiam o próximo dia. | Definido pelo dono do projeto em 2026-11-23 |
| 10 | Idioma do jogo | Proposta | Interface em pt-BR, com textos em chaves para tradução futura. | Proposto pelo líder em 2026-11-19 |
| 11 | Queijo | Decidido | O queijo já sai fatiado do caixote (`food_ingredient_cheese_slice`); só alface e tomate passam pela tábua. | Definido pelo dono do projeto em 2026-11-19 |
| 12 | Prato incompleto | Decidido | Pode servir hambúrguer incompleto; a nota cai e o bilhete-resposta comenta. | Definido pelo dono do projeto em 2026-11-19 |
| 13 | Gorjeta no M1 | Decidido | Sem moeda no M1: a recompensa é só o bilhete-resposta. Moeda/progressão segue a decisão 9. | Definido pelo dono do projeto em 2026-11-19 |
| 14 | Feedback do gesto | Decidido | Ao terminar cada gesto, uma palavra pequena ("Perfeito!", "Bom", "Ops") sobe do ingrediente, com brilho. | Definido pelo dono do projeto em 2026-11-19 |
| 15 | Detalhes do M1 | Decidido | Carne vem de `crate_steak`; o pão se divide sozinho ao tocar o prato; sem lixeira (devolver ao caixote). | Definido pelo líder em 2026-11-19 (ajuste menor de design) |
| 16 | Receita no bilhete | Decidido | Cada bilhete mostra a receita esperada (ingredientes na ordem, com ícones), já sem os itens do "sem". | Definido pelo dono do projeto em 2026-11-19 |
| 17 | Prato alinhado | Decidido | Ingredientes montados ficam sempre centralizados e alinhados no prato (visual bonito). A precisão da soltura continua valendo só na nota de alinhamento, sem deslocar o visual. | Definido pelo dono do projeto em 2026-11-19 |
| 18 | Dica de ação | Decidido | O jogo mostra qual ação fazer com cada ingrediente/estação (ex.: "Pique em zigue-zague", "Puxe para virar", "Arraste ao prato"). | Definido pelo dono do projeto em 2026-11-19 |
| 19 | Cozinha viva | Decidido | Estações cozinham sozinhas com o tempo e queimam se esquecidas; o jogador faz malabarismo entre elas (picar enquanto a carne doura). | Definido pelo dono do projeto em 2026-11-23 |
| 20 | Variedade | Decidido | Mais receitas (ensopado, vegetariano, jantar…) e pedidos com mais de um item. Pedidos malucos, eventos e clientes recorrentes ficam de fora por ora. | Definido pelo dono do projeto em 2026-11-23 |
