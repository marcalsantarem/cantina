# QA M1: fluxo do hambúrguer (T-009 / BRF-008)

**Data:** 2026-11-19 · **Agente:** AG03 · **Build:** Godot 4.7.2, export Web release local (`build/web`), v0.1.0

## Veredito: **passa com ressalvas**

Sem bloqueantes nem graves. O ciclo completo (bilhete → pegar → picar → cozinhar/virar → montar → servir → bilhete-resposta → prato que volta → novo bilhete) funciona no navegador. As ressalvas são menores (UX de qual bilhete recebe o prato, textos de resposta, higiene de build) e o que só o aparelho real confirma (toque, desempenho, PWA).

## Evidências

### Suíte (3 execuções)
| Execução | Scripts | Testes | Passando | Asserts | Saída |
|---|---|---|---|---|---|
| 1 | 11 | 86 | 86 | 612 | 0 |
| 2 | 11 | 86 | 86 | 612 | 0 |
| 3 | 11 | 86 | 86 | 612 | 0 |

Contagem confere (86). 11 scripts = 11 arquivos `test_*.gd`, então nenhum foi pulado. Sem "Parse error". 4 avisos "Deprecated" (`wait_frames`, já conhecido).

### Build web
| Arquivo | Bruto | gzip -9 |
|---|---|---|
| `index.wasm` | 39,5 MB (39 514 754 B) | 10,1 MB |
| `index.pck` | 5,44 MB (5 441 384 B) | 5,24 MB |
| `index.js` | 280 KB | — |

O `.pck` quase não comprime (os assets já vêm comprimidos). O export anterior, das 13:59, tinha 5,22 MB; não investiguei a diferença de +0,2 MB.

### Partida no navegador (servidor estático local, navegador embutido)
| # | Bilhete | O que fiz | Resultado |
|---|---|---|---|
| 1 | Bia da Padaria (sem restrição) | carne queimada (virada tardia: "Ops"), alface Perfeito, **sem tomate** | faixa 50–79, volta `plate_dirty`; frase com o gancho de queimado ("…esse já passou da conta!") |
| 2 | Dona Cida (`sem alface`) | completo sem alface; corte, virada e montagem "Perfeito!" | ≥ 80, volta prato limpo ("Vou sonhar com esse hambúrguer hoje.") |
| 3 | Professor Otávio | completo, 6 camadas na ordem | ≥ 80, prato limpo ("Chef, isso foi poesia com queijo.") |
| 4 | Tio Jorge | só o pão (incompleto) | < 50, o prato volta intocado; gancho de item faltando |

Conferido: o pão se divide no prato e o de cima vai para o descanso; a palavra de feedback aparece ao fim de cada gesto; o bilhete vira bilhete-resposta com ícone e some aos poucos; o prato volta na janela e some ao ser tocado; um prato vazio novo aparece; chega bilhete novo quando há vaga (no máximo 3); a variação `sem alface` aparece.
Console: nenhum erro do jogo. Só apareceram (a) a falha ao registrar o service worker (ver M6) e (b) 2 avisos WebGL "Framebuffer is incomplete: zero size" na carga, quando o canvas ainda tinha tamanho 0 com o painel oculto. São inofensivos.

**Como testei:** o painel do navegador estava oculto, e com isso o `requestAnimationFrame` não roda e o jogo congela. Troquei o `requestAnimationFrame` por `setTimeout(16 ms)` pelo console (só no teste, sem mexer no build). Os arrastes foram feitos com o mouse. O zigue-zague e o puxão foram gerados com eventos sintéticos de ponteiro/mouse e tempo real (traços de ~200 ms; puxão de 120 ms). As capturas saíram do canvas em resolução nativa.

### Capturas
`docs/capturas/qa_m1_1280x720.png`, `qa_m1_844x390.png`, `qa_m1_1024x768.png`, `qa_m1_1688x780.png`, `qa_m1_retrato_390x844.png` (aviso "Gire o celular", com emulação móvel a DPR 2).

## Problemas

### Bloqueantes
Nenhum.

### Graves
Nenhum.

### Menores
- **M1. Não se vê qual bilhete vai receber o prato.** Um bilhete novo entra no primeiro slot livre (`src/kitchen/kitchen_controller.gd:508`), mas o prato vai para o bilhete mais antigo (`src/kitchen/kitchen_controller.gd:447`, `src/kitchen/logic/ticket_queue.gd:102`). Depois de algumas entregas, o mais antigo pode ser o da direita ou o do meio, sem nenhum destaque na tela, e o jogador pode servir o "sem alface" ao cliente errado. Passos: servir o bilhete do meio → chega um novo no meio → o próximo prato vai para o da direita (visto com Dona Cida → Marina → Professor Otávio). Sugestão: destacar o bilhete-alvo ou ordenar os slots por idade.
- **M2. A frase da faixa contradiz a jogada.** "Bom demais, só a alface tava meio rebelde." (`data/kitchen/replies.json:12`) saiu com a alface "Perfeito". A frase fixa cita um defeito que não houve.
- **M3. Repetição no texto:** "Obrigado pela intenção, chef. A intenção estava ótima." (`data/kitchen/replies.json:20`).
- **M4. `build/` sem `.gdignore`.** O editor importa os ícones exportados (6 arquivos `build/web/*.png.import`). Não infla o `.pck`, porque `exclude_filter` já tira `build/*`, mas suja o import e o diff. Passos: exportar, abrir o projeto e listar `build/web/*.import`.
- **M5. O texto dos bilhetes fica pequeno em 844×390** (~9 px CSS no corpo da frase; ver `qa_m1_844x390.png`). Conferir a leitura no celular (roteiro, passo 3).
- **M6. O service worker do PWA não registrou no navegador embutido** ("unknown error when fetching the script", embora `index.service.worker.js` responda 200 com `application/javascript`). Provavelmente é limitação do ambiente; conferir no Netlify ou no celular.

### Pendências conhecidas (classificação)
| Pendência | Classificação |
|---|---|
| Toque real não testado | **Não verificado.** Só mouse e eventos sintéticos; fica para o roteiro do dono. |
| Aviso de retrato só testado em SubViewport | **Resolvida no navegador** (390×844, emulação móvel). Falta girar um aparelho real. |
| Jogo em 1688×780 não conferido | **Resolvida.** Layout ok (`qa_m1_1688x780.png`); bilhetes encostam no exaustor, sem cobrir nada jogável. |
| Ingrediente cru na tábua só sai picado | **Menor, backlog.** Não trava a partida (dá para picar e usar), mas impede desfazer um engano. |
| `wait_frames` obsoleto | **Menor.** `tests/unit/test_hud.gd:27,39,62,85` (4 avisos "Deprecated"). |
| Textos sem `tr()` (decisão 10 é proposta) | **Backlog.** Não avaliado até a decisão do dono. |

## Desempenho percebido
Carga local rápida. A partida rodou fluida no Chromium do desktop com o laço a ~50 quadros/s, só que esse ritmo foi forçado pelo `setTimeout` (o painel estava oculto), então **não mede o celular**. O `.wasm` tem 10,1 MB gzip: no 4G deve haver alguns segundos de carga na primeira visita.

## Roteiro para o dono (celular, ~5 min)
1. Abra o link do Netlify no celular **em pé**: deve aparecer "Gire o celular". Gire: aparece a tela "Toque para começar". Toque.
2. Arraste a carne para a panela. Arraste o pão para o prato: ele se divide e o pão de cima fica ao lado.
3. Arraste uma alface para a tábua e faça zigue-zague (para cima e para baixo, de um lado ao outro) até ela virar fatias. Leia o texto dos bilhetes: dá para ler sem esforço?
4. Depois de ~8 s, dê um **puxão rápido para cima** na panela: deve aparecer "Perfeito!" ou "Bom". Espere mais ~8 s e arraste a carne para o prato.
5. Monte queijo, alface, tomate (pique antes) e o pão de cima, e arraste o prato para a janela. Leia o bilhete-resposta e toque no prato que voltou.
6. Faça um prato de propósito ruim (só pão, ou carne esquecida até ficar escura) e sirva.
7. Anote: algum toque que não respondeu? Travou ou ficou lento? Quanto tempo levou para carregar? No iPhone, "Adicionar à tela de início" funciona?

## Não verificado
Toque real e multitoque, desempenho em celular (Android/Safari iOS), PWA/offline e instalação, áudio (o M1 não tem sons conferidos aqui), devolver um item ao caixote, soltar em lugar inválido (o retorno com tween), uma segunda carne com a panela ocupada.
