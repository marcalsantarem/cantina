# BRF-020 — AG01 + AG02 — T-024 alvo da entrega
**Problema (QA M6 + AG02):** a fita "próximo" marca o bilhete mais antigo, mas o prato/tigela vai ao mais antigo que **espera aquela receita**. No combo, o jogador não vê para onde vai o item.
**Contrato:** `KitchenController` emite `delivery_target_changed(slot: int)` (0..3; `-1` = nenhum). Já está no fake.
**AG01:** emitir quando muda: carregando prato montado/tigela → vaga do bilhete que `TicketQueue.oldest_waiting(recipe)` daria (−1 se ninguém espera); sem carregar nada → vaga do bilhete mais antigo aberto (comportamento atual da fita). Teste de integração. **Permitido:** `src/kitchen/`, `tests/integration/`. **Proibido:** `src/ui/`, `tests/fakes/`.
**AG02:** a fita "próximo" segue `delivery_target_changed` quando o sinal existir (conecte por nome; sem ele, mantém o cálculo atual). Teste em `test_hud.gd`. **Permitido:** `src/ui/`, `scenes/ui/`, `tests/unit/test_hud.gd`. **Proibido:** `src/kitchen/`, `tests/fakes/`.
**Regra:** sem commit/push/branches; suíte verde (contagem). **Entrega:** até 4 linhas.
