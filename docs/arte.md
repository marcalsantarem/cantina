# Arte — guia curto (AG08)

## Paleta
- Base: textura única KayKit `restaurantbits_texture.png` (bancadas laranja, rodapé verde-água, parede pêssego, piso xadrez creme/grafite).
- Fundo/clear: creme `#F3E3C3`. Parede superior (BoxMesh nosso): `#F2DEC2`. Faixa/sanca terracota `#C76B45`. Caixote-degrau madeira `#9E5C3D`. Trilho de bilhetes cinza metal `#9EA8AD`.
- UI deve combinar: cantos arredondados, laranja/creme/verde-água, sem preto puro.

## Cena `scenes/kitchen/kitchen.tscn`
- Raiz `Kitchen`: `WorldEnvironment`, `Sun` (DirectionalLight3D, sem sombra), `MainCamera`, `Set` (piso, paredes, bancadas, fogão, exaustor), `Stations` (gameplay), `Decor`.
- Fluxo da esquerda p/ direita: caixotes (escala 0,55; frente: pão, carne, queijo, cebola; atrás num degrau: alface, tomate, cenoura, batata) → tábua → fogão `stove_multi` → prato → janela de pedidos (alto, centro-direita, com `TicketRail` no topo, `Slot1`..`Slot4`).
- Unidade KayKit: módulo de bancada = 2 m; topo da bancada y = 1; frente da parede z = -1.

## Fogão (M2)
- `stove_multi` em x = -1,5 (módulo de 2 m; bocas em ±0,5 x ±0,5). Exaustor subido 0,8 para a panela de trás aparecer.
- `Stove_Pan` (frente-esq.) e `Stove_Pan2` (frente-dir.): `pan_A` escala 0,9, cabos abertos para fora. `Stove_Pot` (trás-esq.): `pot_A` escala 0,75. A boca de trás-dir. fica livre (M3). Cada um tem `Snap` e `Model`.
- Efeitos (todos `visible = false`; a gameplay só liga/desliga): `Fx_Alert` (aro laranja, `TorusMesh` sem luz) nas 3 estações; `Fx_Steam` (8 esferas brancas translúcidas, `CPUParticles3D`) e `Fx_Bubbles` (6 bolhas, `CPUParticles3D`) na panela. As partículas já estão com `emitting = true`; basta `visible`. O material do aro é compartilhado: para pulsar, anime a escala do nó (ou duplique o material).

## Relógio de parede (`Set/WallClock`)
- Malhas nossas: aro terracota, mostrador creme, 4 marcas grafite, ponteiros `HandHour` e `HandMinute` (`Node3D` pivô no centro, malha filha apontando para +Y local).
- Giro: em torno do **eixo Z local** (normal do mostrador, aponta para a câmera). `rotation.z = 0` = ponteiro em **12h**. Sentido horário (visto de frente) = `rotation.z` **negativo**: `HandMinute.rotation.z = -TAU * minuto / 60`; `HandHour.rotation.z = -TAU * (hora % 12 + minuto / 60) / 12`. Na cena está em 11h00.
- Fica na parede à esquerda (acima dos caixotes), não acima da janela: os bilhetes da HUD cobrem a faixa acima da janela em todos os aspectos.

## Câmera
- `MainCamera`: FOV 29° **horizontal** (`keep_aspect = KEEP_WIDTH`), 40° de cima, distância 25, mira em (-2.6, 2.2, 0).
- KEEP_WIDTH foi escolhido no lugar de `keep_height`: a cozinha é larga e baixa; a largura fica fixa em qualquer aspecto. 20:9 só corta céu/piso (sobra vertical); 4:3 mostra mais parede e piso.
- Faixa segura vertical: do topo da sanca (y≈4.2) à frente das bancadas; o piso embaixo fica livre para HUD.

## Regras
- Só KayKit CC0 ou formas nossas (BoxMesh). Nunca editar os `.gltf` originais.
- 1 luz direcional + ambiente quente; sem sombras (mobile/Web).
- Cena visual sem scripts. Estações: `Area3D` na camada 2, `CollisionShape3D` cobrindo a área tocável, `Marker3D` `Snap`; nomes fixos (ver `docs/design/m1_hamburguer.md` §5).
- Capturas: `godot --path . -s res://tools/capture/capture_kitchen.gd` (com janela) → `docs/capturas/` (pasta com `.gdignore`). M2: `capture_kitchen_m2.gd` → `cozinha_m2_*.png` e `cozinha_m2_fx_1280x720.png` (efeitos ligados só na captura).
