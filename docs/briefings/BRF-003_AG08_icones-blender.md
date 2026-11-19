# BRF-003 — AG08 — T-003 ícones dos ingredientes no Blender
**Leia:** `docs/agentes/AG08_arte.md`. **Regra:** respostas curtas; sem commit/push/branches.
**Contrato:** um PNG por modelo, nome = nome base do glTF: `assets/icons/<nome>.png`, 256×256, fundo transparente, câmera ortográfica 3/4 de cima, enquadramento centrado com margem ~10%, luz suave, sem sombra no chão.
**Fazer:** (1) `tools/blender/render_icons.py` que importa cada glTF de `KayKit_Restaurant_Bits_1.0_FREE/Assets/gltf/`, enquadra e renderiza (EEVEE ou Workbench, o que for mais rápido e fiel às cores da textura), recebendo a lista de modelos por argumento. (2) Rodar para: todos os `food_*`, `plate`, `plate_small`, `bowl`, `pan_A`, `pot_A`, `cuttingboard`, `crate_*`, `ketchup`, `mustard`. (3) Gerar `assets/icons/_preview.png` (mosaico de todos) para conferência. Use o Blender em linha de comando (`-b`); não mexa na instância aberta pelo dono.
**Permitido:** `tools/blender/`, `assets/icons/`. **Proibido:** todo o resto (não crie `project.godot`).
**Pronto quando:** PNGs gerados com transparência e cores corretas (confira o mosaico).
**Entrega:** até 5 linhas: quantos ícones, tempo de render, problemas.
