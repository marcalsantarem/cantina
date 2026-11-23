# M2: Turno (especificação T-014)

Decisões vigentes: 6 (turno ~3 min, calmaria e rush, sem derrota, 1–3 estrelas), 9 (cardápio que cresce), 19 (cozinha viva), 20 (mais receitas, pedidos com mais de 1 item).
Base: [m1_hamburguer.md](m1_hamburguer.md) (gestos, notas 1.0/0.7/0.4/0, carne, montagem e nota do hambúrguer continuam valendo, salvo o que estiver abaixo).
Problema: o M1 tem 1 receita, 1 fila de gestos, nada em jogo. O M2 cria **tensão** (relógio e rush), **malabarismo** (3 fontes de calor ao mesmo tempo) e **variedade** (2 receitas, pedidos combinados), sem derrota.

## 1. Turno

Duração: **180 s** de jogo (relógio pausa com o app em segundo plano ou na pausa).

| Fase | Tempo (s) | Intervalo entre chegadas | Máx. bilhetes abertos | Mistura de pedidos |
|---|---|---|---|---|
| Abertura (calmaria) | 0–45 | 22 s (1º bilhete aos 3 s) | 2 | só 1 item |
| Hora do rush | 45–135 | 16 s | 4 | 1 item 60%, 2 itens 40% |
| Fechamento | 135–165 | 25 s | 3 | só 1 item |
| Últimos pedidos | 165–180 | sem chegadas | — | — |

- Próxima chegada = chegada anterior + intervalo da fase em que ela cai. Se o trilho estiver no máximo da fase, a chegada espera a vaga + 4 s.
- Sequência esperada sem atraso: 3, 25, 47, 63, 79, 95, 111, 127, 143 → **9 bilhetes, ~12 itens**. Bom jogador atende ~10 itens; não é para dar conta de tudo.
- Trilho com 4 vagas (`Slot1`..`Slot4`).
- **Relógio visível na cena:** relógio de parede acima da janela de pedidos, indo de 11h00 a 14h00 (1 h de jogo = 60 s). Sem número na HUD. Reforços: sino na chegada de cada bilhete; aos 45 s placa "Hora do almoço!" e o sino fica mais vivo; aos 165 s placa "Últimos pedidos"; aos 180 s placa vira "FECHADO" com sino triplo.
- **Fim:** aos 180 s a cozinha congela (tudo para de cozinhar), itens em preparo somem; bilhetes abertos contam como não atendidos. Após 1,5 s abre a tela de fim de turno.

## 2. Estrelas

Por turno, 0–100:
`S = 0,60·Q + 0,25·A + 0,15·G`

| Termo | Cálculo |
|---|---|
| Q (qualidade) | média das notas dos bilhetes completos (0–100); 0 se nenhum |
| A (atendimento) | 100 × itens entregues / itens dos bilhetes que chegaram |
| G (agilidade) | 100 × média de `agilidade` dos bilhetes completos (§3) |

| Estrelas | Condição |
|---|---|
| ★ | sempre (abrir a cantina já vale; sem derrota) |
| ★★ | S ≥ 60 |
| ★★★ | S ≥ 80 |

Referência: Q 80, A 90, G 80 → 82,5 (★★★); Q 65, A 70, G 60 → 65,5 (★★); Q 60, A 40, G 40 → 52 (★).

**Tela de fim de turno** (UI do AG02): estrelas (uma a uma, com sino), "Pedidos atendidos 7/9", nota média, agilidade em palavra ("Ágil" ≥ 80, "No ritmo" ≥ 50, "Sem pressa" < 50), a melhor frase de bilhete-resposta do dia, botões "Jogar de novo" e "Próximo dia" (este só no M3).

## 3. Paciência sem derrota

O cliente **nunca vai embora** e a **nota do prato não cai** pela espera (a nota é do gesto, pilar 2). A espera pesa em **agilidade** (estrelas) e no **tom** do bilhete. Justificativa: punir o prato misturaria duas leituras e faria um prato perfeito parecer ruim.

Espera `w` = do bilhete chegar até o último item entregue. Tolerância `T` = 40 s (1 item) ou 60 s (2 itens).
`agilidade = 1,0` se w ≤ T; cai linear até 0,3 em w = T + 60 s; mínimo 0,3.

| Humor | Espera | Bilhete na cena |
|---|---|---|
| Contente | w ≤ T | normal |
| Impaciente | T < w ≤ T + 30 | balança de leve a cada 5 s; carimbo "…" |
| Faminto | w > T + 30 | papel amarelado; aparece linha extra ("Tô com fome, chef!") |

Resposta: se `agilidade < 0,7`, a frase ganha gancho de demora, que substitui o gancho de erro só quando a nota ≥ 80 ("Demorou, mas valeu cada minuto."); abaixo de 80 o erro do prato continua mandando.

## 4. Cozinha viva

Fogão `stove_multi` (4 bocas) no lugar do `stove_single`: **2 frigideiras** (`Stove_Pan` (1ª), `Stove_Pan2`, `pan_A`) + **1 panela** (`Stove_Pot`, `pot_A`). A 4ª boca fica livre para o M3. Tudo cozinha sozinho com o tempo, em paralelo; tirar da boca pausa (frigideira) ou não existe (panela é fixa).

### 4.1 Frigideiras
Mesma carne e mesma tabela do M1 §3, em cada frigideira de forma independente. Sinais de atenção, por frigideira: 7 s brilho + "tss" curto; 10 s fumaça cinza + aro laranja pulsando na boca; 13 s fumaça escura.

### 4.2 Ensopado (`food_stew`)
Ingredientes (caixotes novos): cenoura `crate_carrots`, batata `crate_potatoes`, cebola `crate_onions`. Picar na tábua (gesto M1 §2.2): cenoura 5 cortes → `food_ingredient_carrot_chopped`; batata 5 → `food_ingredient_potato_chopped`; cebola 6 → `food_ingredient_onion_chopped`. Mais de 9 cortes força `desajeitado`.
A panela aceita 1 de cada picado (repetido volta à tábua). Com os 3 dentro, começa a cozinhar. **Rende 2 porções.**

| Estado | Modelo | Duração / gatilho | Grude `g` (0–1) sem mexer | Sinal |
|---|---|---|---|---|
| Vazia | `pot_A` | aceita picados | — | dica "Solte os legumes picados" |
| Montando (1–2 itens) | `pot_A` + picados visíveis | espera o 3º | não sobe | — |
| Cozinhando | `pot_A_stew` | 0–18 s | +1/14 por s | vapor fino |
| Pronto | `pot_A_stew` | a partir de 18 s | +1/10 por s | vapor branco + "plim" |
| Grudando | — | g ≥ 0,6 | — | bolhas grossas, borbulhar alto, aro laranja |
| Quase queimando | — | g ≥ 0,85 | — | fumaça cinza |
| Queimado | `pot_A_stew` escurecido | g = 1 | trava em 1 | fumaça escura |

- **Mexer** (círculos na panela): cada volta completa reduz `g` em 0,35 (mín. 0). Sem mexer, queima aos 14 s, antes de ficar pronto: mexer é obrigatório.
- **Servir:** arrastar da panela leva uma tigela `food_stew` (tigela automática, sem estação de montagem); a 2ª porção esvazia a panela (`pot_A`). Antes de pronto pode, mas sai "mal cozido".
- **Panela queimada:** pode servir as porções (vira humor), ou **raspar** com 3 voltas de mexer, o que a esvazia sem custo.

**Gesto mexer** (começa dentro de `Stove_Pot`): ângulo acumulado em torno do centro da panela na tela; 1 volta = 360° com raio entre 0,03 e 0,15 u e duração 0,4–1,5 s; sentido livre (inverter zera a volta em curso). Nota da volta: `perfeito` se CV do tempo das últimas 3 voltas ≤ 0,20 e CV do raio ≤ 0,25; `bom` se ambos ≤ 0,40; senão `desajeitado`.

**Nota do ensopado** (0–100), por porção:
| Componente | Peso | Cálculo |
|---|---|---|
| Corte | 0,30 | média das 3 notas de corte |
| Cozimento | 0,45 | antes de pronto `desajeitado`; depois, pelo maior `g` do lote: ≤ 0,6 `perfeito`, ≤ 0,85 `bom`, < 1 `desajeitado`, 1 `queimado` (0) |
| Mexer | 0,25 | média das notas de volta do lote; sem volta = 0,4 |

Sem "sem cebola" no ensopado no M2 (a panela é compartilhada por 2 porções). Ganchos: `burnt` ("Tinha um crocante no fundo… era pra ter?"), `raw` ("A batata ainda tava pensando na vida."), `stir`.

## 5. Pedidos com 2 itens

- `TicketData` passa a ter `itens: Array` de `{receita, sem, entregue: bool, nota}`. O bilhete mostra as receitas lado a lado (decisão 16) e um ✓ em cada item entregue.
- **Servir item a item:** prato ou tigela arrastado à janela vai ao bilhete **mais antigo que ainda espera aquela receita** (ainda não entregue); se nenhum espera, volta à origem com a dica "Ninguém pediu isso agora".
- Bilhete completo quando todos os itens chegam. Nota do bilhete = média simples das notas dos itens. O bilhete-resposta sai só no fim, com o gancho do pior item (ou de demora, §3). O que volta pela janela segue a faixa da nota do bilhete (prato/tigela limpa, suja `plate_dirty`/`bowl_dirty`, intocada).
- Mistura no rush: 2 itens = hambúrguer + ensopado (75%) ou 2 hambúrgueres (25%). 1 item = hambúrguer 60%, ensopado 40%. `sem` do hambúrguer como no M1.

## 6. Conteúdo do M2 e o que fica para o M3

| Entra no M2 | Fica para o M3 |
|---|---|
| Hambúrguer (M1) | Hambúrguer vegetariano (`food_ingredient_vegetableburger_*`; sem modelo queimado: escurecer o material; sem caixote próprio: `crate` genérico com o disco em cima) |
| Ensopado (`pot_A`, `pot_A_stew`, `food_stew`, cenoura/batata/cebola) | Jantar `food_dinner`: presunto na frigideira (`food_ingredient_ham` → `_cooked` → `_trash`), batata na panela → purê (`food_ingredient_potato_mashed`), cenoura em pedaços (`_carrot_pieces`) |
| Combos de 2 itens | Forno (`oven`) e 4ª boca; pedidos de 3 itens |

## 7. Dificuldade

Dentro do turno: §1 (intervalo 22 → 16 → 25 s; máximo aberto 2 → 4 → 3; combos só no rush). Pressão extra vem da cozinha viva, não de punição.

Esboço dos dias para o M3 (cada dia libera algo, decisão 9):
| Dia | Libera | Turno |
|---|---|---|
| 1 | Hambúrguer, 1 frigideira | 150 s, rush 16 → 20 s, só 1 item |
| 2 | 2ª frigideira, combos de 2 hambúrgueres | 180 s |
| 3 | Ensopado (panela) e combo hambúrguer + ensopado (= M2 completo) | 180 s |
| 4 | Hambúrguer vegetariano; `sem` em mais itens | 180 s, rush 14 s |
| 5 | Jantar (presunto + purê + cenoura), 4ª boca | 200 s, pedidos de até 3 itens |

## 8. Perguntas ao dono

1. **Relógio:** relógio de parede na cena (11h → 14h) com placas "Hora do almoço!"/"Últimos pedidos", sem número na HUD? *Recomendo sim.*
2. **Desbloqueio (M3):** quantas estrelas liberam o próximo dia? *Recomendo 1 (sempre libera; 2–3 estrelas são orgulho e replay), coerente com "sem derrota".*
3. **Espera:** a demora pesa só na agilidade/estrelas e na frase, sem baixar a nota do prato? *Recomendo sim.*
4. **Servir 2 itens:** item a item na janela (cada prato/tigela vai ao bilhete que espera aquela receita), em vez de bandeja? *Recomendo item a item (sem estação nova, cabe na tela do celular).*

## 9. Tasks sugeridas

| Task | Agente | Tam. |
|---|---|---|
| `ShiftClock` (fases, chegadas, máximo aberto, fim aos 180 s) em lógica pura + testes | AG01 | M |
| Paciência/agilidade por bilhete + `ShiftScorer` (S e estrelas) + testes | AG01 | P |
| Bilhete multi-item (`TicketData.itens`, entrega item a item, nota combinada, 4 vagas) + testes | AG01 | M |
| 2 frigideiras independentes (controller com N `Patty`) | AG01 | M |
| `StewPot` (estados, grude, porções, raspar) + gesto mexer + receita `data/recipes/food_stew.json` + cortes de cenoura/batata/cebola + testes | AG01 | M |
| Cena: `stove_multi` com 2 frigideiras e panela, 3 caixotes novos, `Slot4`, relógio de parede, placas, efeitos (vapor, bolhas, aro de alerta) e sons | AG08 | M |
| HUD: bilhete com 2 itens e humor de espera; tela de fim de turno | AG02 | M |
| Balanceamento: jogar 3 turnos (celular e desktop), medir S e itens atendidos, propor ajuste de intervalos | AG03 | P |

## Esclarecimentos da implementação (BRF-013)

- **Nomes:** `TicketData.items[i]` = `{recipe, without, delivered, score, dominant}` (equivalem a `receita`, `sem`, `entregue`, `nota` do §5; identificadores em inglês, como o `recipe`/`without` do M1). `recipe`/`without` do bilhete espelham o 1º item.
- **Intervalo (§1):** "a fase em que ela cai" = fase da chegada anterior (é o que gera 3, 25, 47, 63…). O máximo aberto é o da fase no momento da chegada; a vaga é vista no início de cada tick (inclui a troca de máximo aos 45 s e 135 s). Chegada atrasada que cairia em ≥ 165 s não acontece.
- **Mexer (§4.2):** a 1ª volta de cada gesto vale `bom` (não há ritmo para medir); da 2ª em diante, CV sobre as voltas disponíveis (até 3). O histórico zera a cada toque. Volta fora de raio (média da volta) ou duração não conta e não tira grude. Inversão confirmada após 0,35 rad de recuo.
- **Ensopado:** queimado antes de pronto vale `queimado` (0), não `desajeitado`. Mexer a panela queimada conta como raspar (não tira grude). Mais de 9 cortes: mesmo picado, nota `desajeitado`. Ganchos: `stew_burnt`, `stew_raw`, `stew_stir` (separados dos do hambúrguer) e `late` (demora). Frases de faixa próprias do ensopado em `recipe_bands`; combo usa as genéricas.
- **Gancho de demora (§3):** com agilidade < 0,7 entra `late` se a nota do bilhete ≥ 80 ou se o pior item não tem erro; senão fica o gancho do pior item.
- **Tela de fim:** "melhor frase" = resposta do bilhete completo de maior nota (desempate: maior agilidade). Tigela volta como `bowl`/`bowl_dirty` (`DishScorer.return_model_for`).
