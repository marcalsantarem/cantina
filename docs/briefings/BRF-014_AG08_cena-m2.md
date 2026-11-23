# BRF-014 — AG08 — T-018 cena do M2
**Leia:** `docs/agentes/AG08_arte.md`, `docs/design/m2_turno.md` §1 e §4, `docs/design/m1_hamburguer.md` §5 (contrato de estações), `scenes/kitchen/kitchen.tscn`. **Regra:** respostas curtas; sem commit/push/branches; cena sem scripts.
**Fazer em `scenes/kitchen/kitchen.tscn`:**
1. Trocar `stove_single` por `stove_multi` (ou `stove_multi_countertop`), com 3 estações `Area3D` (camada 2, cada uma com `Snap` e modelo filho `Model`): **`Stove_Pan`** (1ª frigideira, mantém o nome atual para não quebrar a suíte), `Stove_Pan2` (`pan_A`) e `Stove_Pot` (`pot_A`). Não edite testes; se algum quebrar, liste quais.
2. Caixotes novos `Crate_carrot` (`crate_carrots`), `Crate_potato` (`crate_potatoes`), `Crate_onion` (`crate_onions`), mesmo padrão dos atuais.
3. `TicketRail/Slot4`.
4. Relógio de parede acima da janela (`Set/WallClock`), feito com malhas simples na paleta KayKit: mostrador + ponteiros `WallClock/HandHour` e `WallClock/HandMinute` como `Node3D` pivô no centro (documente em `docs/arte.md` o eixo e o sentido de giro e o ângulo que marca 12h).
5. Nós de efeito, escondidos (`visible = false`), para a gameplay ligar: em `Stove_Pan`, `Stove_Pan2`, `Stove_Pot`: `Fx_Alert` (aro laranja na boca). Em `Stove_Pot`: `Fx_Steam` (vapor, partículas leves CPU ou malhas) e `Fx_Bubbles`. Nada pesado (mobile).
6. Tudo cabe na câmera fixa em 16:9 a 20:9 e 4:3 com espaço para os bilhetes; bancada legível. Captura `docs/capturas/cozinha_m2.png` (com os efeitos ligados temporariamente só para a captura, ou uma segunda captura) — confira lendo a imagem.
**Permitido:** `scenes/kitchen/`, `assets/` (copiar do KayKit o que faltar), `tools/blender/`, `tools/capture/`, `docs/arte.md`, `docs/capturas/cozinha_m2*.png`. **Proibido:** `src/`, `tests/`, `project.godot`, `scenes/ui/`, `scenes/main.tscn`.
**Em paralelo:** AG01 faz lógica pura (BRF-013), sem tocar na cena.
**Pronto quando:** import sem erro e suíte inteira verde (informe contagem); captura conferida; lista de nós novos na entrega.
**Entrega:** até 6 linhas.
