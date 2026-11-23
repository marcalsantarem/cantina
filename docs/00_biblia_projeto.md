# Cantina: Bíblia do projeto

## Pitch

**Cantina** é um jogo de cozinha **zen** para web/PWA, em paisagem. A câmera fica **fixa, olhando a cozinha de frente**, como um palco. Você **nunca vê o cozinheiro**: suas mãos são o seu dedo (ou o mouse). Cada ação é um **gesto de cozinheiro** e o capricho do gesto define a qualidade do prato. Os clientes também são **invisíveis**: existem só nos bilhetes que chegam pela janela de pedidos e no que volta dela.

## Pilares

1. **Turno com pico:** cada dia é um turno curto com calmaria e hora do rush, sem derrota; estrelas no fim (decisão 6). **Cozinha viva:** as estações cozinham e queimam sozinhas, o jogador faz malabarismo (decisão 19).
2. **Gesto é a mecânica** (decisão 4): o jogo se sente nas mãos.
3. **Clientes invisíveis com personalidade** (decisão 5): humor e calor pelos bilhetes.
4. **Um só quadro** (decisão 3): toda a cozinha visível de uma vez, sem navegar.

## Layout da tela (paisagem, cena única)

```
 ┌──────────────── janela de pedidos (bilhetes no trilho) ───────────────┐
 │ caixotes de      │  tábua de corte   │  fogão / panela  │ montagem    │
 │ ingredientes     │                   │                  │ (prato) →   │
 │ (esquerda)       │                   │                  │ janela      │
 └───────────────────────────────────────────────────────────────────────┘
```

Câmera 3D em perspectiva leve, de frente e um pouco acima da bancada.

## Gestos [Proposta, detalhar no M1]

| Ação | Gesto | Qualidade |
|---|---|---|
| Pegar ingrediente | tocar no caixote e arrastar | — |
| Picar (alface, tomate, cebola, cenoura, batata) | zigue-zague sobre a tábua | ritmo e cobertura |
| Virar hambúrguer / carne | puxão rápido para cima na panela | momento certo (cru → no ponto → queimado) |
| Mexer ensopado | círculos na panela | regularidade |
| Montar | arrastar ao prato, na ordem | ordem e alinhamento |
| Servir | arrastar o prato para a janela | — |

Qualidade: **perfeito / bom / desajeitado**. Queimar não é derrota: o prato sai, mas o bilhete de volta mostra a reação.

## Clientes invisíveis [Proposta]

- Chegam como **bilhete** no trilho: pedido, apelido e uma frase com personalidade ("sem cebola, por favor, é sério").
- Ao servir, volta um **bilhete-resposta** e o prato volta limpo, pela metade ou intocado.
- Clientes recorrentes ganham história ao longo dos dias [A definir].

## Receitas possíveis com os assets

Hambúrguer, hambúrguer vegetariano, ensopado (cenoura, batata, cebola), jantar (carne/presunto + purê + cenoura).

## Progressão

Cardápio que cresce: cada dia traz receita ou estação nova; as estrelas do turno desbloqueiam o próximo dia (decisão 9).

## Visual

KayKit Restaurant Bits (low poly, paleta única `restaurantbits_texture.png`): azulejo xadrez, parede creme e verde-água, bancadas laranja. UI arredondada e calorosa, combinando com essa paleta. Créditos a Kay Lousberg na tela de créditos.

## Time

Time enxuto de jogo pequeno ([Time_inicial.md](../modo_trabalho/Time_inicial.md)): AG00 (Líder), AG01 (Gameplay, inclui sistemas), AG02 (UI), AG03 (QA), AG07 (Arquiteto, inclui plataforma/CI), AG08 (Arte, inclui Blender e efeitos simples).
