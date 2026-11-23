# BRF-021 — AG01 — T-025 cozinhar simples
**Leia:** decisão 22 (o dono: "tire as ideias de movimentos, cortes; simplifique o cozinhar"), Bíblia §Interação, `docs/design/m2_turno.md`, `docs/design/m1_hamburguer.md`, `src/kitchen/`. **Regra:** respostas curtas; sem commit/push/branches.
**Regra nova:** a única interação é **tocar/arrastar/soltar**. Nenhum gesto de zigue-zague, puxão ou círculo; o reconhecedor desses gestos sai do caminho do jogo.
**Fazer:**
1. **Tábua:** soltar ingrediente cru → pica sozinho em ~1,5 s (anel/barra de progresso simples na cena ou só troca de modelo com um "pop"); depois arrastar o picado (tomate: o dedo leva 1 fatia, como hoje). Sem nota de corte.
2. **Frigideira:** carne cozinha sozinha, **sem virar** (os dois lados juntos): cru → no ponto → queimado, com a janela de "perfeito" e sinais visuais atuais (brilho, fumaça, `Fx_Alert`). Nota do ponto ao tirar. Tempos: ponto bom a partir de ~8 s, perfeito ~10–14 s, queima ~20 s (ajuste fino seu, registre na spec).
3. **Panela:** soltar os 3 picados → cozinha sozinha (~12 s) → pronta; **sem mexer**; depois de pronta queima se esquecida (~25 s) e então dá para servir queimado ou esvaziar arrastando para o caixote/ou tocando (escolha a mais simples e registre). Nota pelo ponto ao servir.
4. **Montar:** sem nota de alinhamento (prato já é alinhado). Nota do hambúrguer = ponto da carne + receita certa (itens e "sem") + ordem. Ensopado = ponto + receita. Rebalanceie pesos e registre.
5. **Feedback:** "Perfeito!/Bom/Ops" só ao tirar carne e servir tigela (ponto). Dicas atualizadas: sem "pique", "puxe", "mexa"; ex.: "Solte na tábua", "Tire no ponto!", "Arraste ao prato".
6. Remova código e dados mortos (picar/virar/mexer, `StirGesture`, notas de corte/alinhamento) e os testes deles; atualize testes de integração e unitários. Spec: reescreva o essencial em `docs/design/m2_turno.md` (seção "Cozinhar simples — decisão 22") e marque as partes de gesto do M1 como substituídas.
**Permitido:** `src/kitchen/`, `data/`, `tests/integration/`, `tests/unit/` (exceto `test_hud.gd`), `docs/design/`. **Proibido:** `src/ui/`, `scenes/`, `assets/`, `project.godot`, `tests/fakes/`. Se a UI precisar mudar (ex.: algo que mostra nota de corte), liste e não faça.
**Pronto quando:** suíte verde (contagem informada); captura de scratchpad lida mostrando tábua picando e carne na frigideira.
**Entrega:** até 8 linhas, incluindo o que não foi verificado e o que a UI precisaria mudar.
