# kickstart.nvim

## Introduction

A starting point for Neovim that is:

* Small
* Single-file
* Completely Documented

**NOT** a Neovim distribution, but instead a starting point for your configuration.

## Personal Customisations

- `lua/custom/plugins/obsidian.lua` wires in `epwalsh/obsidian.nvim` for the `~/vaults/Lexicon` workspace, adds daily-note/search/open keymaps under `<leader>o*`, enforces Markdown conceal settings, and provides a bespoke `<leader>op` paste helper that drops screenshots into an `attachments/` folder beside the current note. The global `<leader>ip` mapping in `init.lua` is the quick entry point for that workflow.
- `lua/custom/plugins/nabla.lua` installs `jbyuki/nabla.nvim`, ensures the LaTeX parser and `tree-sitter-cli` are available via Mason, and exposes `<leader>p` to render math blocks in-place.
- `lua/custom/plugins/snacks.lua` pulls in `folke/snacks.nvim` (with the image module enabled) so pasted images or attachments can be previewed directly inside Neovim buffers.
- `init.lua` adds quality-of-life tweaks beyond upstream Kickstart: automatic tab width detection via `NMAC427/guess-indent.nvim`, Markdown-focused LSP support by registering `marksman`, an explicit `PasteImage` keybind, and `tokyonight` styling changes (non-italic comments).
- `lua/custom/plugins/typst.lua` adds Typst support with syntax highlighting, LSP integration, and keymaps for compiling/watching PDFs.

## Neovim Workflow Guide

### Obsidian Note-Taking Workflow

This configuration is optimized for working with Obsidian vaults, specifically the `~/vaults/Lexicon` workspace.

#### Essential Keymaps

**Daily Note Management:**
- `<leader>ot` - Open today's daily note (creates if missing)
- `<leader>on` - Create a new note
- `<leader>od` - Create new note with title prompt
- `<leader>oi` - Insert Obsidian template

**Navigation & Search:**
- `<leader>os` - Search notes in vault
- `<leader>oq` - Quick switch between recent notes
- `<leader>of` - Telescope: find files in vault
- `<leader>og` - Telescope: live grep in vault
- `<leader>oo` - Open current note in Obsidian app

**Content Management:**
- `<leader>op` - Paste image to attachments folder (with prompts for folder/name)
- `<leader>ip` - Quick paste image (uses default location)
- `<leader>oc` - Toggle conceal level (useful when editing raw Markdown)
- `<leader>p` - Preview LaTeX/math equations with Nabla

**Quality Control:**
- `:ObsidianLint` - Show Markdown diagnostics (broken links, etc.)

#### Markdown Textobjects

Enhanced textobjects for efficient editing:
- `vih` / `vah` - Select inside/around heading
- `vic` / `vac` - Select inside/around code block
- `vil` / `val` - Select inside/around link

#### Workflow Tips

1. **Starting Your Day:**
   - Open Neovim in your vault directory
   - Press `<leader>ot` to jump to today's note
   - Use `<leader>oi` to insert a template if you have one

2. **Capturing Information:**
   - Take a screenshot and press `<leader>op`
   - Choose attachment folder (defaults to `attachments/` relative to note)
   - Name the file or use timestamp default
   - Image will be pasted and linked automatically

3. **Linking Notes:**
   - Type `[[` to trigger Obsidian completion
   - Use `<leader>oq` to quickly jump between related notes
   - Use `<leader>os` to search across all notes

4. **Editing Efficiency:**
   - Use `<leader>oc` to toggle conceal when you need to see raw Markdown
   - Use textobjects (`vih`, `vic`) to quickly select and edit sections
   - Use `<leader>og` to search for specific content across the vault

5. **Math & Equations:**
   - Write LaTeX in your notes
   - Press `<leader>p` to see a rendered preview popup
   - Great for checking complex equations before finalizing

### Typst Workflow

Typst is a modern markup-based typesetting system. This config provides full support.

#### Keymaps (Typst files only)

- `<leader>tc` - Compile current `.typst` file to PDF
- `<leader>tw` - Watch mode: auto-compile on save
- `<leader>to` - Open the generated PDF (platform-aware)

#### Insert Mode Shortcuts

- `<C-l>m` - Insert inline math: `#math.rad($0)`
- `<C-l>M` - Insert block: `#block($0)`

#### Setup Requirements

1. Install Typst: `brew install typst` (macOS) or see [typst.app](https://typst.app/docs/getting-started/)
2. Install `typst-lsp` via Mason (`:Mason` then search for `typst-lsp`)
3. Open a `.typst` file and start writing!

#### Workflow Tips

1. **Quick Start:**
   - Create a `.typst` file
   - Write your content
   - Press `<leader>tc` to compile
   - Press `<leader>to` to view the PDF

2. **Live Editing:**
   - Use `<leader>tw` to enable watch mode
   - Edit your file, PDF updates automatically
   - Great for iterative document design

3. **LSP Features:**
   - Autocompletion for Typst syntax
   - Go to definition for functions/variables
   - Diagnostics for errors
   - All standard LSP features work!

### General Neovim Tips

#### Search & Navigation
- `<leader>sf` - Find files
- `<leader>sg` - Live grep (search content)
- `<leader>sw` - Search current word
- `<leader>sh` - Search help documentation
- `<leader>sk` - Search keymaps

#### Window Management
- `<C-h/j/k/l>` - Navigate between windows
- `<leader>f` - Format current buffer

#### Getting Help
- `:help` - Open help
- `<leader>sh` - Search help topics
- `:Lazy` - View/manage plugins
- `:checkhealth` - Diagnose issues

## Installation

### Install Neovim

Kickstart.nvim targets *only* the latest
['stable'](https://github.com/neovim/neovim/releases/tag/stable) and latest
['nightly'](https://github.com/neovim/neovim/releases/tag/nightly) of Neovim.
If you are experiencing issues, please make sure you have the latest versions.

### Install External Dependencies

External Requirements:
- Basic utils: `git`, `make`, `unzip`, C Compiler (`gcc`)
- [ripgrep](https://github.com/BurntSushi/ripgrep#installation),
  [fd-find](https://github.com/sharkdp/fd#installation)
- Clipboard tool (xclip/xsel/win32yank or other depending on the platform)
- A [Nerd Font](https://www.nerdfonts.com/): optional, provides various icons
  - if you have it set `vim.g.have_nerd_font` in `init.lua` to true
- Emoji fonts (Ubuntu only, and only if you want emoji!) `sudo apt install fonts-noto-color-emoji`
- Language Setup:
  - If you want to write Typescript, you need `npm`
  - If you want to write Golang, you will need `go`
  - etc.

> [!NOTE]
> See [Install Recipes](#Install-Recipes) for additional Windows and Linux specific notes
> and quick install snippets

### Install Kickstart

> [!NOTE]
> [Backup](#FAQ) your previous configuration (if any exists)

Neovim's configurations are located under the following paths, depending on your OS:

| OS | PATH |
| :- | :--- |
| Linux, MacOS | `$XDG_CONFIG_HOME/nvim`, `~/.config/nvim` |
| Windows (cmd)| `%localappdata%\nvim\` |
| Windows (powershell)| `$env:LOCALAPPDATA\nvim\` |

#### Recommended Step

[Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) this repo
so that you have your own copy that you can modify, then install by cloning the
fork to your machine using one of the commands below, depending on your OS.

> [!NOTE]
> Your fork's URL will be something like this:
> `https://github.com/<your_github_username>/kickstart.nvim.git`

You likely want to remove `lazy-lock.json` from your fork's `.gitignore` file
too - it's ignored in the kickstart repo to make maintenance easier, but it's
[recommended to track it in version control](https://lazy.folke.io/usage/lockfile).

#### Clone kickstart.nvim

> [!NOTE]
> If following the recommended step above (i.e., forking the repo), replace
> `nvim-lua` with `<your_github_username>` in the commands below

<details><summary> Linux and Mac </summary>

```sh
git clone https://github.com/nvim-lua/kickstart.nvim.git "${XDG_CONFIG_HOME:-$HOME/.config}"/nvim
```

</details>

<details><summary> Windows </summary>

If you're using `cmd.exe`:

```
git clone https://github.com/nvim-lua/kickstart.nvim.git "%localappdata%\nvim"
```

If you're using `powershell.exe`

```
git clone https://github.com/nvim-lua/kickstart.nvim.git "${env:LOCALAPPDATA}\nvim"
```

</details>

### Post Installation

Start Neovim

```sh
nvim
```

That's it! Lazy will install all the plugins you have. Use `:Lazy` to view
the current plugin status. Hit `q` to close the window.

#### Read The Friendly Documentation

Read through the `init.lua` file in your configuration folder for more
information about extending and exploring Neovim. That also includes
examples of adding popularly requested plugins.

> [!NOTE]
> For more information about a particular plugin check its repository's documentation.


### Getting Started

[The Only Video You Need to Get Started with Neovim](https://youtu.be/m8C0Cq9Uv9o)

### FAQ

* What should I do if I already have a pre-existing Neovim configuration?
  * You should back it up and then delete all associated files.
  * This includes your existing init.lua and the Neovim files in `~/.local`
    which can be deleted with `rm -rf ~/.local/share/nvim/`
* Can I keep my existing configuration in parallel to kickstart?
  * Yes! You can use [NVIM_APPNAME](https://neovim.io/doc/user/starting.html#%24NVIM_APPNAME)`=nvim-NAME`
    to maintain multiple configurations. For example, you can install the kickstart
    configuration in `~/.config/nvim-kickstart` and create an alias:
    ```
    alias nvim-kickstart='NVIM_APPNAME="nvim-kickstart" nvim'
    ```
    When you run Neovim using `nvim-kickstart` alias it will use the alternative
    config directory and the matching local directory
    `~/.local/share/nvim-kickstart`. You can apply this approach to any Neovim
    distribution that you would like to try out.
* What if I want to "uninstall" this configuration:
  * See [lazy.nvim uninstall](https://lazy.folke.io/usage#-uninstalling) information
* Why is the kickstart `init.lua` a single file? Wouldn't it make sense to split it into multiple files?
  * The main purpose of kickstart is to serve as a teaching tool and a reference
    configuration that someone can easily use to `git clone` as a basis for their own.
    As you progress in learning Neovim and Lua, you might consider splitting `init.lua`
    into smaller parts. A fork of kickstart that does this while maintaining the
    same functionality is available here:
    * [kickstart-modular.nvim](https://github.com/dam9000/kickstart-modular.nvim)
  * Discussions on this topic can be found here:
    * [Restructure the configuration](https://github.com/nvim-lua/kickstart.nvim/issues/218)
    * [Reorganize init.lua into a multi-file setup](https://github.com/nvim-lua/kickstart.nvim/pull/473)

### Install Recipes

Below you can find OS specific install instructions for Neovim and dependencies.

After installing all the dependencies continue with the [Install Kickstart](#Install-Kickstart) step.

#### Windows Installation

<details><summary>Windows with Microsoft C++ Build Tools and CMake</summary>
Installation may require installing build tools and updating the run command for `telescope-fzf-native`

See `telescope-fzf-native` documentation for [more details](https://github.com/nvim-telescope/telescope-fzf-native.nvim#installation)

This requires:

- Install CMake and the Microsoft C++ Build Tools on Windows

```lua
{'nvim-telescope/telescope-fzf-native.nvim', build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build' }
```
</details>
<details><summary>Windows with gcc/make using chocolatey</summary>
Alternatively, one can install gcc and make which don't require changing the config,
the easiest way is to use choco:

1. install [chocolatey](https://chocolatey.org/install)
either follow the instructions on the page or use winget,
run in cmd as **admin**:
```
winget install --accept-source-agreements chocolatey.chocolatey
```

2. install all requirements using choco, exit the previous cmd and
open a new one so that choco path is set, and run in cmd as **admin**:
```
choco install -y neovim git ripgrep wget fd unzip gzip mingw make
```
</details>
<details><summary>WSL (Windows Subsystem for Linux)</summary>

```
wsl --install
wsl
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update
sudo apt install make gcc ripgrep unzip git xclip neovim
```
</details>

#### Linux Install
<details><summary>Ubuntu Install Steps</summary>

```
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update
sudo apt install make gcc ripgrep unzip git xclip neovim
```
</details>
<details><summary>Debian Install Steps</summary>

```
sudo apt update
sudo apt install make gcc ripgrep unzip git xclip curl

# Now we install nvim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo mkdir -p /opt/nvim-linux-x86_64
sudo chmod a+rX /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

# make it available in /usr/local/bin, distro installs to /usr/bin
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/
```
</details>
<details><summary>Fedora Install Steps</summary>

```
sudo dnf install -y gcc make git ripgrep fd-find unzip neovim
```
</details>

<details><summary>Arch Install Steps</summary>

```
sudo pacman -S --noconfirm --needed gcc make git ripgrep fd unzip neovim
```
</details>

