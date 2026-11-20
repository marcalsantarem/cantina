# M1: fluxo do hambúrguer (especificação T-005 / T-007)

Decisões vigentes: 3 (cena única de frente), 4 (gesto define qualidade), 5 (clientes invisíveis), 6 (Zen: sem relógio, sem derrota).
Contrato: id de ingrediente/estado = nome base do glTF em `KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf`.
Notação de qualidade: `perfeito` = 1.0, `bom` = 0.7, `desajeitado` = 0.4, `ausente`/`queimado` = 0.

## 1. Receita e máquinas de estado

Receita `food_burger` (ícone = `food_burger`), ordem de baixo para cima:
`food_ingredient_bun_bottom` → `food_ingredient_burger_cooked` → `food_ingredient_cheese_slice` → `food_ingredient_lettuce_slice` → `food_ingredient_tomato_slice` → `food_ingredient_bun_top`.

| Ingrediente | Estado (id = modelo) | Transição | Para |
|---|---|---|---|
| Pão | `food_ingredient_bun` | soltar no prato vazio | `food_ingredient_bun_bottom` no prato + `food_ingredient_bun_top` estacionado em `Plate_Assembly/BunTopRest` |
| Carne | `food_ingredient_burger_uncooked` | cozinhar os 2 lados ≥ 5 s cada (ver §3) | `food_ingredient_burger_cooked` |
| | `food_ingredient_burger_cooked` | qualquer lado ≥ 13 s | `food_ingredient_burger_trash` (queimada, ainda utilizável) |
| Queijo | `food_ingredient_cheese_slice` | já sai fatiado do caixote (decisão 11) | — |
| Alface | `food_ingredient_lettuce` | picar 6 cortes | `food_ingredient_lettuce_slice` |
| | `food_ingredient_lettuce_slice` | passar de 10 cortes | `food_ingredient_lettuce_chopped` (corte vira `desajeitado`) |
| Tomate | `food_ingredient_tomato` | picar 6 cortes | `food_ingredient_tomato_slices` (pilha na tábua) |
| | `food_ingredient_tomato_slices` | arrastar da tábua | o dedo leva 1 `food_ingredient_tomato_slice` (a pilha some) |

Regras gerais: a tábua aceita 1 ingrediente por vez; a panela, 1 carne. Soltar fora de destino válido devolve o item à origem (tween de 0,25 s). Não há lixeira no M1; o item errado pode ser devolvido ao caixote de origem (some).
Cada item carrega `quality: Dictionary` com as notas de etapa já obtidas (ex.: `{"corte": 0.7}`).

## 2. Gestos

Entrada (todos): sequência de amostras `{p: Vector2 em 0–1 da viewport, t: ms}`, com y crescendo para baixo. Distâncias usam x corrigido pelo aspecto (`dx * largura/altura`), ou seja, "unidades de altura da tela" (u). Amostrar a cada evento de movimento; buffer fixo de 128 amostras (sem alocação por frame). O alvo sob o dedo vem de raycast nas `Area3D` das estações.

**2.1 Pegar/arrastar** (sem qualidade)
- Reconhece: toque em `Crate_*`, `CuttingBoard` (item pronto), `Stove_Pan` (carne) ou `Plate_Assembly` (prato) e deslocamento ≥ 0,02 u. Toque < 0,02 u e < 200 ms = toque simples (não faz nada no M1).
- Durante: item segue o dedo, 0,03 u acima da bancada. Solta: destino = `Area3D` sob o ponto final.

**2.2 Picar em zigue-zague** (tábua com ingrediente cru)
- Reconhece: gesto começa dentro de `CuttingBoard`. Divide-se em traços pela inversão do sentido em y. Traço válido: |Δy| ≥ 0,05 u e duração 80–600 ms. 1 traço válido = 1 corte. Pausa > 1,0 s encerra a sessão; o progresso fica, a próxima sessão continua.
- Cortes exigidos: alface 6, tomate 6.
- Ritmo: CV (desvio-padrão/média) das durações dos traços válidos.
- Cobertura: a largura do ingrediente na tela é dividida em 5 faixas em x; cobertura = faixas tocadas por algum ponto de virada / 5.
- Qualidade: `perfeito` se CV ≤ 0,25 e cobertura = 100%; `bom` se CV ≤ 0,50 e cobertura ≥ 60%; senão `desajeitado`. Alface com > 10 cortes: força `desajeitado`.

**2.3 Virar com puxão** (carne na panela)
- Reconhece: começa dentro de `Stove_Pan`; deslocamento para cima ≥ 0,12 u em ≤ 250 ms; |Δx| ≤ 0,5·|Δy|. Puxão fraco (0,05–0,12 u) só sacode a panela.
- Qualidade: vem do tempo do lado que estava para baixo (§3). Cada carne tem 2 notas: `lado_a` (no 1º puxão) e `lado_b` (ao tirar da panela).

**2.4 Montar** (soltar no `Plate_Assembly`)
- Reconhece: arrastar (2.1) com item de receita, soltando sobre o prato.
- Alinhamento: distância d entre o ponto de soltura e o centro do prato na tela. `perfeito` d ≤ 0,02 u; `bom` d ≤ 0,05 u; senão `desajeitado`. O visual fica sempre centralizado no `Snap`, sem giro, cada item sobre o topo (AABB) do anterior (decisão 17); `PlateStack` ainda guarda `offset`/`tilt_deg`, sem uso visual.
- Ordem: fora de ordem é aceito (empilha mesmo assim); conta como posição errada.
- O pão de cima, quando colocado, fecha o hambúrguer.

**2.5 Servir**
- Reconhece: arrastar o prato (toque no `Plate_Assembly` com pilha ≥ 1 item) e soltar em `OrderWindow`. Vai para o bilhete mais antigo do `TicketRail`. Sem qualidade de gesto.
- Prato incompleto pode ser servido (Zen); os itens ausentes valem 0. O prato vazio reaparece no `Plate_Assembly` em 1,5 s.

## 3. Cozimento sem relógio de pressão

Tempo t de cada lado só corre com a carne na panela e aquele lado para baixo (a panela está sempre quente; tirar a carne pausa tudo).

| t do lado (s) | Visual | Nota do lado se virar/tirar agora |
|---|---|---|
| 0–5 | `burger_uncooked`, chiado baixo | `desajeitado` (mal passado) |
| 5–7 | cooked, chiado médio | `bom` |
| 7–10 | cooked, chiado + leve brilho | `perfeito` |
| 10–13 | cooked, fumaça cinza | `bom` |
| ≥ 13 | `burger_trash`, fumaça escura | `queimado` (0) |

Modelo: `food_ingredient_burger_uncooked` até os dois lados terem t ≥ 5; `food_ingredient_burger_cooked` depois; `food_ingredient_burger_trash` se algum lado ≥ 13. Sem virar nunca, só o lado A cozinha e queima aos 13 s.
Por que é Zen: não há cronômetro na tela, nem prazo de pedido, nem falha. O tempo existe só dentro do ingrediente, começa quando o jogador decide pôr a carne e é lido pelo som/fumaça, como cozinhar de verdade. A janela `perfeito` tem 3 s e a de `bom` cobre 8 s. Carne queimada ainda pode ser servida (vira humor no bilhete), ou devolvida ao caixote para pegar outra, sem custo.

## 4. Bilhetes

Pedido (`Resource` `TicketData`): `{id, apelido: String, frase: String, receita: "food_burger", sem: Array[String] (ids de ingrediente), estado: aberto|servido}`.
- Variação simples no M1: `sem` vazio (70%) ou 1 item entre queijo, alface, tomate (10% cada). Ex.: `sem: ["food_ingredient_tomato_slice"]`.
- No máximo 3 bilhetes abertos; um novo chega 6 s depois que houver vaga. Bilhetes não expiram.
- Exemplos: "Zé do Bairro" — "O de sempre, caprichado que hoje é sexta!"; "Dona Cida" — "Sem tomate, por favor, é sério."; "Turma do 3º B" — "Queremos o mais bonito que você já fez."

Nota do prato (0–100) = round(100 × Σ peso·componente):
| Componente | Peso | Cálculo |
|---|---|---|
| Corte | 0,20 | média das notas de corte dos itens de corte pedidos |
| Cozimento | 0,35 | média de `lado_a` e `lado_b` |
| Alinhamento | 0,15 | média das notas de montagem dos itens pedidos |
| Ordem | 0,15 | posições corretas / itens pedidos |
| Pedido | 0,15 | 1 se respeitou o `sem` e não falta item; −0,5 por item proibido presente ou faltando (mín. 0) |

Item pedido ausente: entra como 0 nos componentes em que participaria.

Bilhete-resposta e o que volta pela janela (1,5 s após servir):
| Faixa | Volta | Exemplos (pt-BR) |
|---|---|---|
| ≥ 80 | `plate` limpo | "Lambi até o prato. Não conta pra ninguém." / "Chef, isso foi poesia com queijo." |
| 50–79 | `plate_dirty` | "Gostei! Comi metade e guardei o resto pro coração." / "Bom demais, só a alface tava meio rebelde." |
| < 50 | o prato como foi (intocado) | "Chef, acho que esse hambúrguer viu coisas... mas valeu o carinho." / "Vou levar pra casa pra estudar." |
Frases ganham gancho do erro dominante quando houver (queimado, item proibido, fora de ordem). Ex. queimado: "Gosto de bem passado, mas esse já passou da conta!". O prato devolvido some ao ser tocado.

## 5. Estações da cena (Arte cria; Gameplay procura por nome)

Cada estação = `Area3D` (toque/soltura) com filho `Marker3D` `Snap` (onde o item fica).
| Nó | Modelo sugerido | Função |
|---|---|---|
| `Crate_bun` | `crate_buns` | dá `food_ingredient_bun` |
| `Crate_burger` | `crate_steak` | dá `food_ingredient_burger_uncooked` |
| `Crate_cheese` | `crate_cheese` | dá `food_ingredient_cheese_slice` |
| `Crate_lettuce` | `crate_lettuce` | dá `food_ingredient_lettuce` |
| `Crate_tomato` | `crate_tomatoes` | dá `food_ingredient_tomato` |
| `CuttingBoard` | `cuttingboard` (+ `knife` decorativa) | picar |
| `Stove_Pan` | `stove_single` + `pan_A` | cozinhar e virar |
| `Plate_Assembly` | `plate`; filho extra `Marker3D` `BunTopRest` | montar |
| `OrderWindow` | (cenário) | servir; recebe o prato de volta em `Snap` |
| `TicketRail` | (cenário); filhos `Marker3D` `Slot1`..`Slot3` | bilhetes |

Sufixo de `Crate_<ingrediente>` = chave curta (`bun`, `burger`, `cheese`, `lettuce`, `tomato`); o mapeamento para ids glTF fica em `data/`.

## 6. Respostas

Decisões 11 a 15: queijo já fatiado; prato incompleto pode ser servido; sem moeda no M1; palavra + brilho ao fim de cada gesto ("Perfeito!", "Bom", "Ops"); carne de `crate_steak`; pão se divide sozinho no prato; sem lixeira.

## 7. Esclarecimentos da implementação (T-005)

- Picar: a nota de corte usa todos os cortes válidos do ingrediente, somando as sessões; pontos de virada = as duas pontas de cada traço válido; ponto fora da largura do ingrediente não conta faixa. Inversão em y só conta com recuo ≥ 0,01 u (filtra tremor).
- Puxão: medido a partir do toque inicial (≤ 250 ms). Enquanto o movimento parece puxão, o arrastar espera; passado o prazo, vira arrastar normal.
- Carne: a nota de um lado é gravada sempre que ele sai de baixo (virar ou tirar); com várias viradas vale a última. Ao tirar, lado sem nota recebe a nota do seu tempo (0 s = `desajeitado`). Queimado mostra "Ops".
- Ordem: posições corretas = maior subsequência comum entre as camadas pedidas e a pilha (extras e proibidos não tiram posição; ausente conta como errada).
- Erro dominante: componente com maior perda ponderada (desempate: cozimento, pedido, ordem, corte, alinhamento), traduzido em `burnt`, `raw`, `missing`, `forbidden`, `order`, `cut`, `alignment`, `cooking`. A frase de resposta = frase da faixa + gancho, quando o erro tem gancho nos dados.
- Bilhetes: com a fila vazia o primeiro também espera 6 s (a cena pode chamar `spawn()` para adiantar).
