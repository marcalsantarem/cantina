# CLAUDE.md

> **Idioma:** documentação, commits, briefings e conversa em português (pt-BR). Identificadores de código em inglês.
> Itens **[Proposta]** não são regra e itens **[A definir]** estão em aberto: pergunte ao dono antes de agir com base neles.

## Método

O projeto segue o método de [modo_trabalho/](modo_trabalho/README.md). Resumo obrigatório:

- **Economia de tokens:** respostas curtas, leitura só do necessário, commits agrupados por etapa.
- **Git:** só a branch `dev` recebe commits (só do líder). A `main` é protegida e recebe PR `dev` → `main` aberto pelo dono. Sem outras branches. Versões por tag `vX.Y.Z` após o merge.
- **Fonte da verdade:** dono > [Bíblia](docs/00_biblia_projeto.md) > [decisões](docs/decisoes.md) > doc do agente.

## Papel do Claude

O Claude principal é o **AG00 (Líder)**: único interlocutor do dono, **gerencia e não implementa**. Quebra marcos em tasks ([docs/backlog.md](docs/backlog.md)), escreve briefings (`docs/briefings/`), dispara agentes especialistas ([docs/agentes/](docs/agentes/)), confere, faz commit e push na `dev` e relata no formato de [Listagem_tasks.md](modo_trabalho/Listagem_tasks.md).

**Se você é um agente especialista:** leia seu arquivo em `docs/agentes/` e o briefing; trabalhe só nos arquivos permitidos; **nunca** faça commit, push, branch, checkout, reset ou stash; não altere `project.godot`, autoloads ou Input Map sem autorização no briefing; ao terminar, reporte o que mudou e o que **não** foi verificado.

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [docs/00_biblia_projeto.md](docs/00_biblia_projeto.md) | Bíblia: pitch, regras do jogo, visual, time. **Leia primeiro.** |
| [docs/decisoes.md](docs/decisoes.md) | Decisões numeradas do dono |
| [docs/roadmap.md](docs/roadmap.md) | Marcos e versões |
| [docs/backlog.md](docs/backlog.md) | Tasks por marco |
| [docs/agentes/](docs/agentes/) | Um arquivo por agente |
| `docs/briefings/` | Pedidos do líder (`BRF-NNN_AGxx_<entrega>.md`) |

## Stack

- **Godot 4.7.2**, **GDScript**, renderer **Compatibility** (WebGL 2), 3D.
- Export **Web single-threaded** (sem SharedArrayBuffer/COOP/COEP) + **PWA**, orientação **paisagem** no mobile.
- Testes com **GUT**. CI no GitHub Actions; deploy no **Netlify** (link próprio por tag).
- Assets: **KayKit Restaurant Bits** (CC0, Kay Lousberg). O pacote original na raiz (`KayKit_Restaurant_Bits_1.0_FREE/`) fica fora do Godot (`.gdignore`) e fora do git; o que o jogo usa é copiado para `assets/`.
- Blender 5.3 instalado (`"/c/Program Files/Blender Foundation/Blender 5.3/blender.exe"`); usar em modo linha de comando (`-b -P script.py`) para gerar ícones/renders.

## Restrições web/mobile

- Alvo de desempenho: navegador de celular (inclui Safari no iPhone). Poucas luzes dinâmicas, sem sombras pesadas, sem alocação por frame, `.pck` enxuto.
- Áudio só depois da primeira interação: tela de "toque para começar".
- Toda interação funciona com **toque e mouse** (gestos), sem teclas fixas no código: use Input Actions.

## Comandos

`godot` = `"/c/Program Files/Godot/Godot_v4.7.2-stable_win64.exe"` (não está no PATH).

```bash
godot --headless --path . --import                                  # importar (clone limpo)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit         # testes
godot --headless --path . --export-release "Web" build/web/index.html  # export web
```
