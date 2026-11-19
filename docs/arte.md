# Arte — guia curto (AG08)

## Paleta
- Base: textura única KayKit `restaurantbits_texture.png` (bancadas laranja, rodapé verde-água, parede pêssego, piso xadrez creme/grafite).
- Fundo/clear: creme `#F3E3C3`. Parede superior (BoxMesh nosso): `#F2DEC2`. Faixa/sanca terracota `#C76B45`. Caixote-degrau madeira `#9E5C3D`. Trilho de bilhetes cinza metal `#9EA8AD`.
- UI deve combinar: cantos arredondados, laranja/creme/verde-água, sem preto puro.

## Cena `scenes/kitchen/kitchen.tscn`
- Raiz `Kitchen`: `WorldEnvironment`, `Sun` (DirectionalLight3D, sem sombra), `MainCamera`, `Set` (piso, paredes, bancadas, fogão, exaustor), `Stations` (gameplay), `Decor`.
- Fluxo da esquerda p/ direita: caixotes (3 na frente, 2 atrás num degrau) → tábua → fogão/panela → prato → janela de pedidos (alto, centro-direita, com `TicketRail` no topo).
- Unidade KayKit: módulo de bancada = 2 m; topo da bancada y = 1; frente da parede z = -1.

## Câmera
- `MainCamera`: FOV 29° **horizontal** (`keep_aspect = KEEP_WIDTH`), 40° de cima, distância 25, mira em (-2.6, 2.2, 0).
- KEEP_WIDTH foi escolhido no lugar de `keep_height`: a cozinha é larga e baixa; a largura fica fixa em qualquer aspecto. 20:9 só corta céu/piso (sobra vertical); 4:3 mostra mais parede e piso.
- Faixa segura vertical: do topo da sanca (y≈4.2) à frente das bancadas; o piso embaixo fica livre para HUD.

## Regras
- Só KayKit CC0 ou formas nossas (BoxMesh). Nunca editar os `.gltf` originais.
- 1 luz direcional + ambiente quente; sem sombras (mobile/Web).
- Cena visual sem scripts. Estações: `Area3D` na camada 2, `CollisionShape3D` cobrindo a área tocável, `Marker3D` `Snap`; nomes fixos (ver `docs/design/m1_hamburguer.md` §5).
- Capturas: `godot --path . -s res://tools/capture/capture_kitchen.gd` (com janela) → `docs/capturas/` (pasta com `.gdignore`).
