# QA M2: turno (T-021 / BRF-017)

**Data:** 2026-11-23 · **Agente:** AG03 · **Build:** Godot 4.7.2, export Web release local (`build/web`), commit `4ba6da3`

## Veredito: **passa com ressalvas graves**

O turno funciona de ponta a ponta no navegador: relógio de parede, placas "Hora do almoço!" / "Últimos pedidos" / "Fechado!", 4 vagas, combos item a item com ✓, humor (… e "Tô com fome, chef!"), 2 frigideiras em paralelo, ensopado do picar ao servir, "Ninguém pediu isso agora", congelamento aos 180 s, tela de estrelas e "Jogar de novo" (3 vezes, cozinha limpa a cada vez). Sem erro do jogo no console.
O M2 é **bem mais dinâmico que o M1**, mas há 2 graves que o dono vai sentir na primeira partida (G1: a tigela às vezes não sai da panela; G2: fumaça em quadrado) e 1 grave de balanceamento (G3: 2 estrelas com 1 pedido). Recomendo uma task de ressalvas antes da tag.

## Evidências

### Suíte
| Execução | Scripts | Testes | Passando | Pending | Asserts | Saída |
|---|---|---|---|---|---|---|
| 1 | 16 | 160 | 160 | 0 | 1314 | 0 |
| 2 | 16 | 160 | 160 | 0 | 1314 | 0 |
| 3 | 16 | 160 | 160 | 0 | 1314 | 0 |
| 4 (com o teste novo do QA) | 17 | 161 | 160 | 1 | 1317 | 0 |

16 scripts = 16 arquivos `test_*.gd`; sem "Parse error". Teste novo: `tests/integration/test_qa_m2_defects.gd` prova o G1. Enquanto o defeito existir ele fica **pending** com o motivo (não quebra a suíte); corrigido, vira regressão.

### Build web
| Arquivo | Bruto | gzip -9 |
|---|---|---|
| `index.wasm` | 39,5 MB (39 514 754 B) | 10,1 MB |
| `index.pck` | 5,51 MB (5 509 696 B) | 5,30 MB |
| `index.js` | 280 KB | — |

O `.pck` cresceu 68 KB desde o M1 (modelos novos). Ok.

### Turnos no navegador (servidor estático local, navegador embutido, 1280×720)
| Turno | ★ | Pedidos | Itens entregues/chegados | Nota média | Agilidade | Observação |
|---|---|---|---|---|---|---|
| 1 | ★★ | 3/6 | 5/8 | 72 | Sem pressa | Exploratório (comecei a jogar com o rush já cheio). Carne **queimada de propósito** ("Ops", "Queimou! Tire da panela"); bilhete ficou **faminto**; ensopado não saiu (G1). |
| 2 | ★★ | 4/7 | 6/10 | 83 | Ágil | 1ª panela queimou sem ninguém pedir ensopado e foi raspada; 2ª ficou pronta, mas a tigela não saiu (G1). Combo 2 hambúrgueres entregue item a item. |
| 3 | ★★★ | 8/9 | 9/10 | 81 | Ágil | Contornando o G1 (tocar no lado da panela virado para a janela). 9 bilhetes chegaram, como na sequência da spec. Combo hambúrguer + ensopado entregue item a item. |
| 4 (extra, ocioso) | ★★ | 1/5 | 1/6 | 87 | Ágil | Servi só 1 ensopado e não fiz mais nada: **2 estrelas** (G3). |

S estimado (§2): T1 ≈ 60–62; T2 ≈ 79; T3 ≈ 84; T4 ≈ 71.

**Como testei:** gestos por eventos sintéticos de ponteiro/mouse no canvas, com tempos reais (zigue-zague de 6 traços de ~160 ms, puxão de 120 ms, voltas de mexer de 650–800 ms, raio ~45 px). Os gestos tinham **precisão de robô e tempo de reação zero** (virar aos 8,3 s, tirar aos 16,8 s): o T3 é o teto, não o jogador médio. Para as capturas congelei o tempo do jogo (escala no `performance.now`, só no teste). O laço rodou com `setTimeout(16 ms)` no lugar do `requestAnimationFrame` (painel oculto), então **não mede desempenho**.

### Capturas (`docs/capturas/`)
- Rush com 4 bilhetes: `qa_m2_rush_1280x720.png`, `qa_m2_rush_844x390.png`, `qa_m2_rush_1024x768.png`
- Panela grudando (aro laranja + fumaça quadrada): `qa_m2_panela_grudando_1280x720.png` (com combo pendente), `qa_m2_panela_grudando_b_1280x720.png`, `qa_m2_panela_grudando_844x390.png`, `qa_m2_panela_grudando_1024x768.png`
- Fim de turno: `qa_m2_fim_1280x720.png`, `qa_m2_fim_844x390.png`, `qa_m2_fim_1024x768.png`; ocioso com 2 estrelas: `qa_m2_fim_1pedido_1280x720.png`

## Problemas

### Bloqueantes
Nenhum (há contorno para o G1).

### Graves
- **G1. A tigela não sai da panela quando o toque começa no lado oposto à janela.** `src/kitchen/kitchen_controller.gd:432`: a tigela só sai se `absf(stir.turn_angle) < PI * 0.5`. Quem toca o lado esquerdo/baixo da panela e arrasta para a janela (cima/direita) passa pelo centro, o ângulo em torno do centro gira ~180° e o gesto vira "mexer": não sai tigela, nada acontece e não há dica. Metade da área da panela falha. No navegador, todas as minhas tentativas a partir do centro visual falharam (T1 e T2); começando no lado direito funcionou sempre (T3). Prova: `tests/integration/test_qa_m2_defects.gd` (offsets −0,03/−0,02/−0,015 u à esquerda do centro → 0 entregas). Passos: ensopado pronto e um bilhete pedindo → tocar a metade esquerda da panela → arrastar até a janela → soltar. Sugestão: decidir "servir" pela distância do centro (sair do raio da panela) antes de checar o ângulo, ou ignorar o ângulo enquanto o raio ainda é menor que o mínimo da volta.
- **G2. Fumaça e vapor aparecem como quadrados (pretos no queimado), confirmado no navegador.** `src/kitchen/kitchen_controller.gd:1012-1019` (partícula `QuadMesh` sem textura) com as cores de `:73-76`. A fumaça escura (0,18/0,16/0,15, α 0,85) vira um quadrado preto sólido sobre a panela ou a frigideira; nas fases claras aparecem retângulos brancos translúcidos. Não é limitação do headless: está em `qa_m2_panela_grudando_844x390.png`. Fica no centro da tela, justamente no sinal de alerta. Sugestão: textura de fumaça redonda e suave (ou `SphereMesh`/gradiente radial) no material.
- **G3. Duas estrelas com um único pedido (balanceamento).** `src/kitchen/logic/shift_scorer.gd:107` (Q é a média **só dos bilhetes completos**) + `:62` (peso 0,60). Um bilhete perfeito e rápido dá Q 100 e G 100, ou seja, S ≥ 75 mesmo com A ≈ 0. Pior: ficar parado lota o trilho, segura as chegadas e encolhe o denominador de A (T4: só 5 bilhetes chegaram). No T4 servi 1 ensopado em 180 s e ganhei ★★. Isso esvazia a tensão que o M2 quer criar. Proposta abaixo.

### Menores
- **M1. Os glifos ↕ e ⟳ saem como caixinha** ("Pique em zigue-zague ▯", "Mexa em círculos ▯"): `src/kitchen/kitchen_controller.gd:62` e `:69`. A fonte não tem esses caracteres. Ver qualquer captura de panela grudando.
- **M2. No combo, a etiqueta "sem X" vale para o bilhete inteiro e não diz de qual item é.** `src/ui/ticket_card.gd:109-113` junta os `without` de todos os itens. Caso: Lu do Skate pediu 2 hambúrgueres, só o 2º "sem tomate"; a etiqueta embaixo dos dois me fez tirar o tomate dos dois, e a resposta reclamou ("Senti falta de alguém nesse hambúrguer"). Os ícones da 2ª linha estão certos, mas a etiqueta engana.
- **M3. Panela queimada mostra "Mexa em círculos"**, e mexer nela **raspa e joga fora** (3 voltas), sem aviso. `kitchen_controller.gd:1144-1146`. Quem mexe para "salvar" perde a porção sem entender. Sugestão: dica "Raspe a panela ⟲" no estado queimado.
- **M4. A pausa por perda de foco é silenciosa.** `kitchen_controller.gd:245-250`: no desktop, um clique fora da janela congela o relógio e a cozinha sem nenhum aviso na tela (aconteceu no T4; o jogo parecia travado). No celular está certo; no desktop falta um "Pausado — toque para voltar".
- **M5. Em 844×390, com 4 bilhetes**, eles cobrem o exaustor, o balão de dica cobre a etiqueta "próximo" do bilhete-alvo, e o texto do bilhete fica com ~9 px (`qa_m2_rush_844x390.png`). Conferir no celular (roteiro, passo 2).
- **M6. O alvo da entrega é só um.** A etiqueta "próximo" marca o bilhete mais antigo, mas no combo o ensopado pode ir para outro bilhete (o mais antigo que espera **ensopado**). Funciona como a spec, mas o jogador não vê para onde vai a tigela.
- **M7. Higiene:** `build/` continua sem `.gdignore` (6 `build/web/*.png.import`, M4 do M1). O import do Godot gerou `src/ui/end_screen.gd.uid`, `src/ui/phase_banner.gd.uid` e `tools/capture/capture_hud_m2.gd.uid` (não rastreados; o líder decide se commita).
- **M8. O service worker não registra no navegador embutido** (igual ao M1, M6). Conferir no Netlify.

### Pendências conhecidas (classificação)
| Pendência | Classificação |
|---|---|
| Sem áudio | **Backlog M4.** Sem o "tss", o "plim" e o borbulhar, os alertas dependem só do visual, e por isso o G2 pesa mais. |
| Fumaça como quadrado preto | **Confirmado no navegador → G2.** |
| Picados grandes na panela | **Menor/aceitável.** Em 1280×720 leem bem como "legumes na panela"; não atrapalham. |
| Toque real | **Não verificado** (roteiro do dono). |

## Balanceamento

**Leitura dos turnos.** Um "robô" com gesto perfeito faz 8/9 e ★★★ por pouco (S ≈ 84), então ★★★ é possível, mas exige jogar quase sem erro: bom para um humano. O problema está embaixo: ★ é praticamente impossível (qualquer prato bem feito já dá ★★), e o ensopado depois de pronto vira um imposto contínuo. Com +0,1 de grude por segundo, é preciso uma volta a cada ~3,5 s **para sempre**. Nos T2/T3, toda 2ª porção que ninguém pediu na hora queimou e foi raspada. O rush aperta de verdade: o trilho encheu com 4 bilhetes aos ~63 s parado e aos ~80 s jogando. O gargalo real é o **prato único de montagem** (~8–10 s por hambúrguer).

| # | Mudança | Onde | Justificativa |
|---|---|---|---|
| B1 | ★★ só com S ≥ 60 **e** A ≥ 50; ★★★ com S ≥ 80 **e** A ≥ 75 | `shift_scorer.gd` `stars_for` | Fecha o G3: 1 prato perfeito não vale ★★. T3 (A 90) segue ★★★; T4 (A 17) cai para ★. |
| B2 | Denominador de A = máx(itens chegados, itens das chegadas seguradas pelo trilho cheio) **ou** contar a chegada atrasada como "chegou" | `shift_clock.gd` / `shift_scorer.gd` | Ficar parado não pode encolher a régua. |
| B3 | Grude depois de pronto 1/10 → **1/18 por s** (`STICK_PER_S_READY`), com 6 s de "descanso" logo depois de pronto | `stew_pot.gd:12` | Mantém o mexer como malabarismo (~1 volta a cada 6 s), mas a 2ª porção sobrevive ~20 s à espera do próximo pedido. Hoje ela quase sempre vira lixo. |
| B4 | Tolerância 40 → **30 s** (1 item) e 60 → **50 s** (2 itens) | `shift_scorer.gd:9-10` | Nos T2/T3 deu "Ágil" fácil: G não diferencia. O hambúrguer mínimo é ~25 s (17 s de carne + montagem); 30 s ainda é justo para quem já tem carne no fogo. |
| B5 | Manter calmaria 22 s e rush 16 s; fechamento 25 → **20 s** | `shift_clock.gd:20` | O rush já aperta; o fechamento ficou morno (sobra tempo para limpar o trilho). Reavaliar com o celular, com toque humano (reação mais lenta). |

Com B1–B4: T1 → ★ ou ★★ no limite; T2 → ★★; T3 → ★★★; T4 → ★.

## Desempenho percebido
Carga local rápida, sem engasgo visível, mas o laço foi forçado por `setTimeout` (painel oculto): **não mede o celular**. Muitas partículas (2 frigideiras + panela, 10 partículas cada) são poucas para WebGL 2; o custo maior deve ser a sombra/overdraw dos bilhetes. Conferir no aparelho.

## Dinamismo (vs M1)
Melhorou muito. Há relógio visível, as placas marcam as fases, o trilho enche no rush, carne queimando numa boca enquanto se pica na tábua e a panela pede atenção: o malabarismo existe. Os bilhetes mudam de humor e as respostas comentam a demora. O que ainda achata: (a) sem som, os alertas competem só pelo olho; (b) G3, o resultado não reflete o esforço; (c) o ensopado é mais castigo que escolha (B3).

## Roteiro para o dono (celular, ~6 min)
1. Abra o link em paisagem, toque para começar. Veja o relógio de parede andar e o 1º bilhete chegar com 3 s.
2. Faça um hambúrguer completo. Leia os bilhetes com 4 abertos (lá pelo 1º minuto e meio): dá para ler? A dica cobre a etiqueta "próximo"?
3. Ensopado: arraste cenoura, batata e cebola para a tábua, pique cada uma (zigue-zague) e arraste à panela. Mexa em círculos com o dedo de tempos em tempos.
4. Quando um bilhete pedir ensopado, **toque o lado esquerdo da panela** e arraste à janela. Depois tente pelo lado direito. Anote se a tigela sai nos dois (esperado hoje: só no direito, G1).
5. Deixe uma carne queimar: a fumaça parece fumaça ou um quadrado preto (G2)?
6. Num combo, entregue um item e veja o ✓; entregue o outro e leia a resposta.
7. Jogue até o "Fechado!", veja as estrelas e toque "Jogar de novo". Outra rodada: sirva 1 pedido e fique parado até o fim. Quantas estrelas? (Hoje: 2, G3.)
8. Anote: toque que falhou, lentidão, tempo de carga, se o mexer com o dedo é confortável.

## Não verificado
Toque real e multitoque; desempenho em celular (Android, Safari iOS); PWA/offline; áudio (não existe); pausa por segundo plano no celular (só vi a perda de foco no desktop); raspar a panela de propósito com 3 voltas (só aconteceu por acidente, com o laço de mexer); prato devolvido sem tocar bloqueando algo; turnos com jogador humano (os números são de gestos automáticos).

## Cozinhar simples (T-026)

**Data:** 2026-11-23 · **Agente:** AG03 · **Build:** export Web release local, commit `b522307` (BRF-021) · **Briefing:** BRF-022

### Veredito: **passa com ressalvas**
Sem gestos ficou **simples de verdade**: tudo é arrastar e soltar, a tábua pica sozinha em 1,5 s e a panela cozinha sozinha. Nenhum texto pede movimento. Continua dinâmico no rush (2 frigideiras + panela + tábua única + prato único), mas **ficou fácil demais**: ★★★ nos 2 turnos, inclusive no turno com 2 carnes queimadas. Há 1 grave de layout no celular (G1) e proposta de aperto de tempos (B6–B10).

### Evidências
- **Suíte (1×):** 16 scripts, **144/144** passando, 1299 asserts, saída 0, sem "Parse error".
- **Build web:** `index.wasm` 39,5 MB (10,1 MB gzip); `index.pck` 5,50 MB (5,29 MB gzip), 11 KB menor que no M2.
- **Turnos** (navegador embutido, 1280×720; arrastes por eventos sintéticos de mouse; laço por `setTimeout` e tempo do jogo congelado nas capturas, só no teste):

| Turno | ★ | Pedidos | Nota média | Agilidade | O que fiz |
|---|---|---|---|---|---|
| 1 (ritmo de robô) | ★★★ | 8/9 | 87 | No ritmo | Hambúrgueres nas 2 frigideiras, ensopado, combos (hambúrguer+ensopado e 2 hambúrgueres) entregues item a item, 1 carne queimada, panela queimada esvaziada com 1 toque, 2ª porção servida "crocante" (gancho de queimado). |
| 2 (ritmo humano: ~0,7 s entre ações, 1,5 s de reação) | ★★★ | 7/10 | 84 | Ágil | 2 carnes **queimadas de propósito** e descartadas no caixote, 1 carne tirada passando do ponto ("Bom"), 2 ensopados de uma panela, 1 picado perdido. "Jogar de novo" 2× (cozinha limpa). |

**Capturas** (`docs/capturas/qa_simples_*`): `carne_no_ponto`, `carne_passando`, `carne_queimada`, `panela_queimada`, `fim_t1`, `fim_t2` (1280×720); `rush`, `fim`, `jogar_de_novo` (844×390).

### Mancha escura na carne (pendência)
**Não reproduz no navegador.** No ponto (10–14 s) a fumaça sai clara e translúcida (`qa_simples_carne_no_ponto`); de 14 a 20 s vira véu cinza com o aro (`carne_passando`). A mancha da captura headless tem o formato do quad redondo da fumaça, só que preto. A causa provável é a partícula desenhada **sem a cor por instância** na captura offscreen: o material usa `vertex_color_use_as_albedo` (`src/kitchen/kitchen_controller.gd:974`, em `_smoke_mesh` :956) e a cor vem de `smoke.color` em `_set_smoke` (:985), com os valores de `SMOKE_COLORS` (:73-76). Defeito do ambiente de captura, não do jogo. Não é sombra: a carne não projeta sombra ali.

### Problemas
**Bloqueantes:** nenhum.

**Graves**
- **G1. Em 844×390 o bilhete "próximo" expandido cobre os caixotes de cenoura e batata, metade do de cebola e o canto da tábua** (`qa_simples_rush_844x390`). O toque atravessa o bilhete (peguei a cenoura "às cegas" e funcionou), mas o jogador não vê os caixotes, e isso acontece justamente quando o próximo pedido é ensopado. No celular é a tela normal. Sugestão: bilhete expandido sem invadir a faixa dos caixotes (ancorar à direita) ou caixotes acima do bilhete.

**Menores**
- **M1. "Tire no ponto!" aparece aos 8 s** (`is_cooked`, `kitchen_controller.gd:1108`), mas o perfeito só começa aos 10 s. Quem obedece na hora ganha "Bom". A dica segue igual entre 14 e 20 s, quando já está passando. Sugestão: a dica só de 10 a 14 s, e "Tire já!" depois.
- **M2. A fumaça escura da carne queimada quase não aparece:** ela sobe para trás do balão "Queimou! Tire da frigideira", que fica logo acima da frigideira. O sinal que funciona é o carvão + aro. Aceitável; anotar para a arte.
- **M3. "Melhor frase do dia" saiu igual nos 2 turnos** ("Tá de parabéns! Voltei a acreditar no amor.").
- **M4. Restos de gesto só internos:** sinal `gesture_feedback` (`hud.gd:105`), comentário "feedback de gesto" (`feedback_word.gd:2`), classe/teste `GestureRecognizer`. Nenhum texto de jogador pede picar, puxar, mexer ou virar. Não há feedback de corte (só o "pop" + brilho ao terminar de picar).

### Balanceamento: ainda há tensão?
**Pouca.** Sem gesto, o tempo de espera virou ocioso: enquanto a carne cozinha (10 s), dá para picar a alface e montar o prato com folga, e a panela não pede nada durante 22 s depois de pronta. A janela de perfeito de 4 s é larga para quem só arrasta. O único aperto real é o **prato único** no rush. Mesmo errando de propósito (T2), deu ★★★ e "Ágil": a régua ficou baixa para o jogo novo.

| # | Mudança | Onde | Por quê |
|---|---|---|---|
| B6 | Perfeito 10–14 → **10–12,5 s**; queima 20 → **18 s** | `patty.gd:11-13` | Recoloca a decisão "tiro agora?" que o virar dava. |
| B7 | Rush: intervalo 16 → **13 s**; combo 0,4 → **0,5** | `shift_clock.gd:20,24` | Sem gesto, cada prato sai ~5 s mais rápido; mais pedidos devolvem o malabarismo. |
| B8 | ★★★ com S ≥ **85** (era 80) | `shift_scorer.gd:23` | T2, com 2 carnes queimadas, não deveria dar 3 estrelas. |
| B9 | Tolerância 30/50 → **25/45 s** | `shift_scorer.gd:9-10` | "Ágil" veio fácil mesmo em ritmo humano. |
| B10 | Panela queima 25 → **18 s** depois de pronta (37 → 30 s) | `stew_pot.gd` | A panela volta a disputar atenção sem gesto. A 2ª porção ainda espera ~10 s. |

Reavaliar no celular com o dedo antes de aplicar tudo: o toque humano é mais lento que o robô (B6 e B7 juntos podem pesar).

### Roteiro para o dono (celular, ~5 min)
1. Abra em paisagem e toque para começar. Arraste a carne às 2 frigideiras.
2. Arraste alface à tábua: ela pica sozinha? O "toc-toc-pop" dá prazer ou é espera chata?
3. Monte um hambúrguer (pão, carne, queijo, alface, tomate, tampa) e arraste à janela. Quando "Tire no ponto!" aparece, tire na hora: deu "Perfeito" ou "Bom"? (Hoje sai "Bom" se tirar antes de 10 s, M1.)
4. Quando o "próximo" for ensopado: você vê os caixotes de cenoura e batata ou o bilhete cobre (G1)?
5. Deixe uma carne queimar e uma panela queimar; toque na panela para esvaziar. Os sinais são claros?
6. Jogue até o "Fechado!", veja as estrelas e toque "Jogar de novo".
7. Diga: ficou **fácil** ou **parado** em algum momento? Em que fase (calmaria, rush, fechamento)?

### Não verificado
Toque real e multitoque; desempenho no celular (o laço foi forçado por `setTimeout`); som do "toc"/"pop" (o áudio não foi conferido); jogador humano de verdade (os números são de arrastes sintéticos); 1024×768; panela queimada servida (só a "crocante", OVERDONE/SCORCHING).
