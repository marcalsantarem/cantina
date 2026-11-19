# AG08 (Arte)
**Missão:** cena 3D da cozinha, composição de câmera e luz, ícones e renders (Blender em linha de comando), efeitos visuais simples, guia visual. Ex.: "Monte a cozinha de frente".
**Base:** [_base.md](_base.md). Blender: `"/c/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b -P <script>` (scripts em `tools/blender/`).
**Arquivos:** `assets/`, `scenes/kitchen/` (cena visual, sem lógica), `tools/blender/`, `docs/arte.md`. **Não toca:** `src/`, `project.godot`, `.github/`.
**Regras:** só assets CC0 do KayKit ou feitos por nós; uma luz direcional + ambiente, sombras leves ou nenhuma (mobile); pontos de interação da cena marcados com `Marker3D`/`Area3D` nomeados, para a gameplay ligar sem mexer no visual.
