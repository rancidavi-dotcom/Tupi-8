Canal do YouTube da Bitmap: https://www.youtube.com/@bitmap_exe
<div align="center">
  <img src="./logo.png" alt="Logo da Tupi Engine" width="180">

# Tupi-8

```text
████████╗██╗   ██╗██████╗ ██╗     █████╗ 
╚══██╔══╝██║   ██║██╔══██╗██║    ██╔══██╗
   ██║   ██║   ██║██████╔╝██║    ╚█████╔╝
   ██║   ██║   ██║██╔═══╝ ██║    ██╔══██╗
   ██║   ╚██████╔╝██║     ██║    ╚█████╔╝
   ╚═╝    ╚═════╝ ╚═╝     ╚═╝     ╚════╝ 
```

<p>
  <strong>Engine brasileira focada em performance, segurança e prototipação rápida.</strong>
</p>

<p>
  <img src="https://img.shields.io/badge/status-em%20desenvolvimento-22c55e?style=for-the-badge" alt="Status">
  <img src="https://img.shields.io/badge/plataformas-Linux%20%7C%20Windows-0f172a?style=for-the-badge" alt="Plataformas">
  <img src="https://img.shields.io/badge/build-Makefile-f59e0b?style=for-the-badge&logo=gnu" alt="Build">
</p>

<p>
  <img src="https://img.shields.io/badge/C-00599C?style=for-the-badge&logo=c&logoColor=white" alt="C">
  <img src="https://img.shields.io/badge/Rust-000000?style=for-the-badge&logo=rust&logoColor=white" alt="Rust">
  <img src="https://img.shields.io/badge/LuaJIT-2C2D72?style=for-the-badge&logo=lua&logoColor=white" alt="LuaJIT">
  <img src="https://img.shields.io/badge/SDL2-7A4EAB?style=for-the-badge&logo=sdl&logoColor=white" alt="SDL2">
  <img src="https://img.shields.io/badge/Vulkan-A41E22?style=for-the-badge&logo=vulkan&logoColor=white" alt="Vulkan">
</p>
</div>

---

## Visão geral

**Tupi-8** é uma engine brasileira inspirada em motores compactos, rápidos e fáceis de iterar. Ela combina a velocidade de **C + SDL2 + Vulkan**, a confiabilidade de **Rust** e a flexibilidade de scripts com **LuaJIT**.

### Foco da engine

- renderização eficiente com SDL2 + Vulkan
- validação e segurança na camada Rust
- scripts em LuaJIT para gameplay, testes e ferramentas
- empacotamento simples com `make`

## Stack

| Camada | Tecnologia | Função |
| --- | --- | --- |
| Core | C | Loop principal, integração de baixo nível e runtime |
| Render | SDL2 + Vulkan | Janela, contexto, renderização e pipeline gráfico |
| Segurança | Rust | Validações, consistência de dados e carregamento seguro |
| Script | LuaJIT | Gameplay, prototipação e iteração rápida |
| Build | Make + Cargo | Compilação, empacotamento e release |

## Como a Tupi-8 está organizada

### C + SDL2 + Vulkan

O núcleo em C cuida da execução em tempo real, do renderer, da janela e da integração com o restante da engine. Hoje essa base gera:

- `libtupi.so` para Linux
- `libtupi.dll` para Windows

### Rust

Rust entra como camada de segurança e suporte. Ele ajuda no carregamento seguro de imagens e assets, checagem de dados inválidos e partes sensíveis do pipeline que se beneficiam de validação mais rígida.

### LuaJIT

LuaJIT acelera a prototipação. O alvo `make rodar` executa `main.lua` diretamente, o que deixa o fluxo de teste de lógica e gameplay bem rápido.

## Fluxo principal de build

O fluxo principal de distribuição da engine agora é o `make bundle-linux`. Ele gera **um único executável Linux** com:

- scripts Lua embutidos
- bibliotecas `.so` necessárias
- assets do projeto
- assets obrigatórios da própria engine

Esse modelo é próximo do que engines como Godot e Love2D fazem no Linux: um executável que carrega tudo de forma centralizada, sem depender de uma pasta exportada separada.

## Comandos mais importantes

### Menu interativo

```bash
make
```

### Comandos diretos

```bash
make sdl2
make win
make bundle-linux
make rodar
make ci-linux
make release-linux VERSION=v0.3.0 GAME_NAME=MeuJogo
```

## O que cada alvo faz

- `make sdl2`: compila `libtupi.so` para Linux
- `make win`: compila `libtupi.dll` para Windows
- `make rodar`: executa `main.lua` no ambiente local
- `make bundle-linux`: gera o executável final para distribuição
- `make ci-linux`: gera o bundle e os arquivos auxiliares de CI
- `make release-linux`: gera o bundle final de release com manifest e checksum
- `make limpar`: remove artefatos temporários e de build

## CI/CD e releases Linux

O projeto possui CI/CD para gerar artefatos Linux em **Ubuntu 22.04**. Isso ajuda a evitar o cenário em que o binário funciona no Arch, mas falha no Ubuntu por diferenças de bibliotecas do sistema.

### O pipeline gera

- `bundle-linux`: um executável único
- `SHA256SUMS`: verificação de integridade
- `manifest`: informações básicas da build

### Workflows

- `.github/workflows/ci.yml`
  roda em `push`, `pull_request` e execução manual
- `.github/workflows/release.yml`
  publica os artefatos quando você cria uma tag como `v0.3.0`

## Assets obrigatórios no bundle

O bundle Linux exige alguns arquivos essenciais da engine durante o build:

- `assets/ascii.png`

Se ele estiver ausente, o `Makefile` falha cedo com uma mensagem clara. Isso evita gerar um executável que abre sem fonte padrão.

### Ícone no Linux

Se `main.lua` chamar `Tupi.janela(..., "caminho/do/icone.png")`, o `bundle-linux` reaproveita essa mesma imagem como ícone do app no Linux.

Se o sexto argumento não existir, ou se o arquivo não for encontrado, o bundle não força nenhum ícone e o sistema Linux usa o padrão dele.

Se você quiser sobrescrever isso manualmente no build:

```bash
make bundle-linux GAME_NAME=MeuJogo ENGINE_ICON_SRC=.engine/icon.png
```

## Dependências

O `Makefile` detecta automaticamente diferentes gerenciadores de pacotes no Linux e também oferece fluxo para Windows e cross-compile.

### Linux

Suporte atual para:

- `apt`
- `dnf`
- `pacman`
- `zypper`
- `apk`

Instalação:

```bash
make instalar-deps-linux
```

### Windows

Instalação da base do ambiente:

```bash
make instalar-deps-win
```

## Estrutura principal do projeto

### Fontes C usadas no build

- `src/Renderizador/Renderer.c`
- `src/Camera/Camera.c`
- `src/Colisores/Fisica.c`
- `src/Inputs/Inputs.c`
- `src/Colisores/ColisoesAABB.c`
- `src/Sprites/Sprites.c`
- `src/Mapas/Mapas.c`
- `main_bytecode_loader.c`

### Empacotamento do bundle

- `src/bin/tupi_pack.rs`
  monta o payload e anexa scripts, libs e assets ao executável final
- `main_bytecode_loader.c`
  lê o próprio binário e carrega o conteúdo embutido
- `scripts/collect_linux_deps.sh`
  coleta as bibliotecas dinâmicas necessárias para o bundle Linux

### Módulos Rust atuais

- `src/camera.rs`
- `src/colisores.rs`
- `src/fisica.rs`
- `src/lib.rs`
- `src/mapas.rs`
- `src/renderizador.rs`
- `src/sprites.rs`

## Por que a Tupi-8 é rápida

- batching de draw calls para reduzir custo de render
- validação antecipada na camada Rust
- shaders embutidos no build
- estrutura simples para compilar e iterar sem atrito

## Por que a Tupi-8 é boa para aprender

- separa bem o papel de cada linguagem
- aproxima o desenvolvimento de conceitos reais de engine
- permite prototipar rápido sem perder controle técnico
- mantém uma base pequena e relativamente fácil de estudar

## Identidade do projeto

A Tupi-8 é uma engine brasileira, feita com identidade própria e com foco em desenvolver tecnologia de jogos no nosso idioma, no nosso contexto e no nosso ecossistema.

---

<div align="center">
  <strong>Tupi Engine</strong><br>
  Performance de baixo nível com uma alma brasileira.
</div>
