# Neovim Configuration Usage Guide

This comprehensive guide covers everything you need to know about using this custom Neovim configuration, optimized for Obsidian note-taking and Typst document creation.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Obsidian Workflow](#obsidian-workflow)
3. [Typst Workflow](#typst-workflow)
4. [General Neovim Features](#general-neovim-features)
5. [Keybindings Reference](#keybindings-reference)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites

Before using this configuration, ensure you have:

1. **Neovim** (latest stable or nightly)
2. **External Dependencies:**
   - `git`, `make`, `unzip`, C Compiler (`gcc`)
   - `ripgrep` and `fd-find` for search
   - Clipboard tool (see [Image Pasting Setup](#image-pasting-setup))

3. **For Obsidian:**
   - An Obsidian vault at `~/vaults/Lexicon/`
   - Clipboard tool for image pasting (see below)

4. **For Typst:**
   - Typst binary: `brew install typst` (macOS) or see [typst.app](https://typst.app/docs/getting-started/)
   - `typst-lsp` (install via `:Mason` in Neovim)

### First Launch

1. Open Neovim: `nvim`
2. Wait for plugins to install (Lazy will handle this automatically)
3. Run `:checkhealth` to verify everything is working
4. Install `typst-lsp` via `:Mason` if you plan to use Typst

---

## Obsidian Workflow

This configuration is optimized for working with Obsidian vaults, specifically the `~/vaults/Lexicon/` workspace.

### Image Pasting Setup

**Critical:** Image pasting requires platform-specific clipboard tools:

- **macOS:** `brew install pngpaste`
- **Linux (X11):** `sudo apt install xclip` or `xsel`
- **Linux (Wayland):** `sudo apt install wl-clipboard`
- **Windows:** Built-in support (no installation needed)

**Verify installation:**
```bash
# macOS
which pngpaste

# Linux (X11)
which xclip

# Linux (Wayland)
which wl-paste
```

### Daily Note Management

**Open Today's Note:**
- Press `<leader>ot` (Space + o + t)
- Creates today's daily note if it doesn't exist
- Format: `YYYY-MM-DD.md` in your vault

**Create New Notes:**
- `<leader>on` - Quick new note (uses current date/time)
- `<leader>od` - New note with title prompt (recommended)

**Insert Templates:**
- `<leader>oi` - Insert an Obsidian template
- Templates should be in your vault's template folder

### Navigation & Search

**Within Vault:**
- `<leader>os` - Search notes in vault (Obsidian search)
- `<leader>oq` - Quick switch between recent notes
- `<leader>of` - Telescope: find files in vault
- `<leader>og` - Telescope: live grep across vault content

**Open in Obsidian App:**
- `<leader>oo` - Opens current note in Obsidian desktop app
- Useful for viewing rendered markdown or using Obsidian plugins

### Image Management

**Paste Images (Two Methods):**

1. **Quick Paste** (`<leader>ip`):
   - Pastes to default `attachments/` folder
   - Uses timestamp filename: `img-YYYYMMDD-HHMMSS.png`
   - No prompts - fastest method

2. **Custom Paste** (`<leader>op`):
   - Prompts for attachment folder (defaults to `attachments/`)
   - Prompts for filename (defaults to timestamp)
   - More control over organization

**How It Works:**
- Images are saved relative to the current note
- If note is in `~/vaults/Lexicon/`, images go to `attachments/` in that directory
- Markdown link is automatically inserted: `![filename](attachments/filename.png)`
- Images can be previewed in Neovim using Snacks (if configured)

**Example Workflow:**
1. Take a screenshot (Cmd+Shift+4 on macOS)
2. Open your note in Neovim
3. Press `<leader>ip` for quick paste or `<leader>op` for custom
4. Image is saved and linked automatically

### PDF Parsing Workflow

Turn lecture slide PDFs into editable Markdown without leaving Neovim.

**Dependencies**
- Install `pdftotext` (Poppler): `brew install poppler` on macOS or use your package manager on Linux
- Optional: point `vim.g.custom_pdf_parser_command` to another CLI that outputs Markdown/text to stdout (e.g. `{ 'pdf2md' }`)

**Import new PDFs (`<leader>pa`):**
1. Open the markdown note where the content should land.
2. Press `<leader>pa` and pick any PDF on disk.
3. The file is copied into the note's `attachments/` folder and parsed.
4. A block is inserted at the cursor:
   - `## Notes from <filename>`
   - `[[attachments/<filename>.pdf]]` link for quick access
   - Extracted Markdown ready for editing.

**Parse existing attachments (`<leader>pp`):**
1. With a markdown note open, press `<leader>pp`.
2. Select one of the PDFs already living in `attachments/`.
3. The parsed Markdown is inserted at the cursor; the PDF stays untouched.

**Tips & verification**
- Run `which pdftotext` (or your custom parser) to confirm the binary is available before relying on the shortcut.
- Parsing uses the command synchronously—very large PDFs can take a few seconds.
- If the parser returns no text, the note gets `_No text extracted_` so you can spot problematic files quickly.

### Markdown Editing

**Toggle Conceal:**
- `<leader>oc` - Toggle conceal level (useful when editing raw Markdown)
- Conceal hides markdown syntax for cleaner viewing
- Toggle off to see raw syntax when needed

**Textobjects (Enhanced):**
- `vih` / `vah` - Select inside/around heading
- `vic` / `vac` - Select inside/around code block  
- `vil` / `val` - Select inside/around link
- `diw` - Delete inner word
- `ci"` - Change inside quotes

**Linking Notes:**
- Type `[[` to trigger Obsidian completion
- Autocompletion shows existing notes
- Press Enter to create link or new note

### Math & Equations

**Preview LaTeX:**
- `<leader>p` - Open Nabla popup to preview math equations
- Write LaTeX in your markdown: `$E = mc^2$`
- Press `<leader>p` to see rendered preview
- Great for checking complex equations

**Example:**
```markdown
The equation $E = mc^2$ shows...
```
Press `<leader>p` on the equation to see a rendered preview.

### Quality Control

**Check for Issues:**
- `:ObsidianLint` - Show Markdown diagnostics
- Displays broken links, syntax errors, etc.
- Opens quickfix list for navigation

---

## Typst Workflow

Typst is a modern markup-based typesetting system, perfect for academic papers, reports, and documents.

### Setup

1. **Install Typst:**
   ```bash
   # macOS
   brew install typst
   
   # Linux (see typst.app for instructions)
   # Windows: Download from typst.app
   ```

2. **Install LSP:**
   - Open Neovim
   - Run `:Mason`
   - Search for `typst-lsp` and install

3. **Verify:**
   - Create a `.typst` file
   - LSP should start automatically
   - Check `:LspInfo` to confirm

### Keymaps (Typst Files Only)

**Compilation:**
- `<leader>tc` - Compile current `.typst` file to PDF
- `<leader>tw` - Watch mode: auto-compile on save
- `<leader>to` - Open generated PDF (platform-aware)

**Insert Mode Shortcuts:**
- `<C-l>m` - Insert inline math: `#math.rad($0)`
- `<C-l>M` - Insert block: `#block($0)`

### Workflow Examples

**Quick Start:**
1. Create `document.typst`
2. Write your content
3. Press `<leader>tc` to compile
4. Press `<leader>to` to view PDF

**Live Editing:**
1. Open your `.typst` file
2. Press `<leader>tw` to enable watch mode
3. Edit your file - PDF updates automatically
4. Great for iterative design

**LSP Features:**
- Autocompletion for Typst syntax
- Go to definition for functions/variables
- Diagnostics for errors
- Hover documentation
- All standard LSP features work!

### Typst File Settings

Automatically configured for `.typst` files:
- 2-space indentation
- Word wrap enabled
- Line break on word boundaries
- Syntax highlighting

---

## General Neovim Features

### Search & Navigation

**File Search:**
- `<leader>sf` - Find files (Telescope)
- `<leader>sn` - Search Neovim config files
- `<leader><leader>` - Find existing buffers

**Content Search:**
- `<leader>sg` - Live grep (search file contents)
- `<leader>sw` - Search current word
- `<leader>s/` - Grep in open files only

**Help & Documentation:**
- `<leader>sh` - Search help documentation
- `<leader>sk` - Search keymaps
- `:help` - Open help system

**Resume Last Search:**
- `<leader>sr` - Resume last Telescope search

### Window Management

**Navigate Windows:**
- `<C-h>` - Move focus left
- `<C-j>` - Move focus down
- `<C-k>` - Move focus up
- `<C-l>` - Move focus right

**Splits:**
- `:vsplit` - Vertical split
- `:split` - Horizontal split
- Standard Vim window commands work

### Tabs & Buffers

**Opening Files in Tabs:**
- `:tabnew` - Create new empty tab
- `:tabedit <file>` - Open file in new tab
- `:tab drop <file>` - Open file in new tab (or switch if already open)
- `<leader>sf` then `<C-t>` - Open selected file in new tab (from Telescope)

**Tab Navigation:**
- `gt` or `:tabnext` - Go to next tab
- `gT` or `:tabprevious` - Go to previous tab
- `{count}gt` - Go to specific tab (e.g., `2gt` for tab 2)
- `:tablast` - Jump to last tab
- `:tabfirst` - Jump to first tab

**Tab Management:**
- `:tabclose` or `:tabc` - Close current tab
- `:tabonly` - Close all other tabs
- `:tabmove +1` - Move tab right
- `:tabmove -1` - Move tab left
- `:tabmove 0` - Move tab to first position

**Buffer Navigation:**
- `<leader><leader>` - List open buffers (Telescope)
- `:bnext` or `:bn` - Next buffer
- `:bprevious` or `:bp` - Previous buffer
- `:buffer <name>` - Switch to buffer by name
- `:bdelete` or `:bd` - Close current buffer

**Quick Workflow Examples:**

1. **Open multiple lecture notes in tabs:**
   ```vim
   :tabedit ~/vaults/Lexicon/Projects/Ursprung/lecture1.md
   :tabedit ~/vaults/Lexicon/Projects/Ursprung/lecture2.md
   :tabedit ~/vaults/Lexicon/Projects/Ursprung/lecture3.md
   ```
   Then use `gt` / `gT` to switch between them.

2. **Open files from Telescope in new tabs:**
   - Press `<leader>fl` (find lecture notes)
   - Navigate to desired file
   - Press `<C-t>` to open in new tab

3. **Split workflow within tabs:**
   - Open note in tab: `:tabedit note.md`
   - Split view: `:vsplit reference.md`
   - Now you have side-by-side editing in this tab

### Tmux Integration

**Opening Files in Tmux Windows:**

From terminal (outside Neovim):
```bash
# Open file in new tmux window
tmux new-window "nvim ~/vaults/Lexicon/lecture.md"

# Open file in new tmux window with name
tmux new-window -n "Lecture" "nvim ~/vaults/Lexicon/Projects/Ursprung/lecture.md"

# Split tmux pane and open file
tmux split-window "nvim ~/vaults/Lexicon/notes.md"
```

**Tmux Keybindings (default prefix: `C-b`):**
- `C-b c` - Create new window
- `C-b n` - Next window
- `C-b p` - Previous window
- `C-b 0-9` - Switch to window by number
- `C-b ,` - Rename window
- `C-b &` - Kill current window
- `C-b %` - Split pane vertically
- `C-b "` - Split pane horizontally
- `C-b o` - Switch between panes
- `C-b z` - Zoom/unzoom current pane

**Recommended Tmux Workflow for Note-Taking:**

1. **Create dedicated tmux session:**
   ```bash
   tmux new-session -s notes
   ```

2. **Open different note types in different windows:**
   ```bash
   # Window 0: Today's journal
   tmux rename-window "Journal"
   nvim ~/vaults/Lexicon/journal.md
   
   # Window 1: Lecture notes (in another window)
   tmux new-window -n "Lectures"
   nvim ~/vaults/Lexicon/Projects/Ursprung/
   
   # Window 2: General notes
   tmux new-window -n "Notes"
   nvim ~/vaults/Lexicon/
   ```

3. **Navigate between windows:**
   - Use `C-b 0`, `C-b 1`, `C-b 2` to jump directly
   - Or use `C-b n` / `C-b p` to cycle

**Quick Access Script (create `~/.local/bin/notes`):**
```bash
#!/bin/bash
# Quick access to lecture notes in tmux

# Create or attach to 'notes' session
if ! tmux has-session -t notes 2>/dev/null; then
    # Create new session with lecture notes
    tmux new-session -d -s notes -n "Lectures" "cd ~/vaults/Lexicon/Projects/Ursprung && nvim"
    tmux new-window -t notes -n "Journal" "cd ~/vaults/Lexicon && nvim journal.md"
    tmux new-window -t notes -n "Vault" "cd ~/vaults/Lexicon && nvim"
fi

# Attach to session
tmux attach-session -t notes
```

Make it executable:
```bash
chmod +x ~/.local/bin/notes
```

Now you can just run `notes` from terminal to jump into your note-taking environment!

**Neo-tree File Explorer:**
- Press `<C-n>` or `:Neotree` to toggle file explorer
- Navigate with `j`/`k`, open with `<Enter>`
- Press `t` to open file in new tab
- Press `s` to open in vertical split
- Press `S` to open in horizontal split

### Editing

**Formatting:**
- `<leader>f` - Format current buffer
- Auto-formats on save (for supported filetypes)
- Uses LSP formatter or Conform

**Text Objects:**
- `va)` - Select around parentheses
- `yi"` - Yank inside quotes
- `ci'` - Change inside single quotes
- `diw` - Delete inner word

**Surround:**
- `sa` - Add surround
- `sd` - Delete surround
- `sr` - Replace surround
- Example: `saiw)` - Surround inner word with parentheses

### LSP Features

**Navigation:**
- `grd` - Go to definition
- `grr` - Find references
- `gri` - Go to implementation
- `grn` - Rename symbol
- `gra` - Code actions

**Diagnostics:**
- `<leader>q` - Open diagnostic quickfix
- `<leader>sd` - Search diagnostics
- Errors shown inline with virtual text

**Inlay Hints:**
- `<leader>th` - Toggle inlay hints (if supported)

### Plugins

**Lazy Plugin Manager:**
- `:Lazy` - Open plugin manager
- View installed plugins
- Update plugins
- Configure plugin settings

**Mason (LSP/Tools Installer):**
- `:Mason` - Open Mason UI
- Install LSP servers
- Install formatters/linters
- Install debuggers

---

## Keybindings Reference

### Leader Key

The leader key is `<Space>`. All keybindings below assume `<leader>` means pressing Space first.

### Obsidian Keybindings

| Keybinding | Action |
|------------|--------|
| `<leader>ot` | Open today's daily note |
| `<leader>on` | Create new note |
| `<leader>od` | Create new note (with title prompt) |
| `<leader>oi` | Insert Obsidian template |
| `<leader>os` | Search notes in vault |
| `<leader>oq` | Quick switch between notes |
| `<leader>of` | Find files in vault (Telescope) |
| `<leader>og` | Grep in vault (Telescope) |
| `<leader>oo` | Open note in Obsidian app |
| `<leader>op` | Paste image (with prompts) |
| `<leader>ip` | Quick paste image (default location) |
| `<leader>oc` | Toggle conceal level |
| `<leader>p` | Preview LaTeX/math (Nabla) |

### Bookmark Keybindings

| Keybinding | Action |
|------------|--------|
| `<leader>bm` | Toggle bookmark at current line |
| `<leader>bi` | Add bookmark annotation |
| `<leader>bc` | Clean bookmarks in buffer |
| `<leader>bn` | Jump to next bookmark |
| `<leader>bp` | Jump to previous bookmark |
| `<leader>bl` | List all bookmarks (Telescope) |
| `<leader>fl` | Find files in lecture notes |
| `<leader>fv` | Find files in vault |
| `<leader>sl` | Search in lecture notes |
| `<leader>fr` | Recent vault files |

### Typst Keybindings

| Keybinding | Action |
|------------|--------|
| `<leader>tc` | Compile Typst to PDF |
| `<leader>tw` | Watch mode toggle (auto-compile in background) |
| `<leader>to` | Open generated PDF |
| `<leader>tp` | Compile and preview (compile + open) |
| `<leader>ta` | Toggle auto-compile on save |
| `<C-l>m` | Insert inline math (insert mode) |
| `<C-l>M` | Insert block (insert mode) |

### General Keybindings

| Keybinding | Action |
|------------|--------|
| `<leader>sf` | Find files |
| `<leader>sg` | Live grep |
| `<leader>sw` | Search current word |
| `<leader>sh` | Search help |
| `<leader>sk` | Search keymaps |
| `<leader>sr` | Resume last search |
| `<leader>sn` | Search Neovim config |
| `<leader>f` | Format buffer |
| `<leader>q` | Open diagnostic quickfix |
| `<leader>th` | Toggle inlay hints |
| `<C-h/j/k/l>` | Navigate windows |
| `<Esc>` | Clear search highlights |

### Text Objects

| Keybinding | Action |
|------------|--------|
| `vih` / `vah` | Select inside/around heading |
| `vic` / `vac` | Select inside/around code block |
| `vil` / `val` | Select inside/around link |
| `va)` | Select around parentheses |
| `yi"` | Yank inside quotes |
| `ci'` | Change inside single quotes |

---

## Troubleshooting

### Image Pasting Not Working

**Symptoms:** `<leader>op` or `<leader>ip` doesn't paste images

**Solutions:**
1. **Check clipboard tool:**
   ```bash
   # macOS
   which pngpaste
   # If not found: brew install pngpaste
   
   # Linux
   which xclip  # or wl-paste
   ```

2. **Verify clipboard has image:**
   - Take a screenshot first
   - Ensure image is in clipboard

3. **Check file is saved:**
   - Image pasting requires a saved file
   - Save with `:w` first

4. **Check Obsidian plugin:**
   - Run `:Lazy` and verify `obsidian.nvim` is installed
   - Check for errors with `:checkhealth`

### Obsidian Commands Not Found

**Symptoms:** `:ObsidianToday` or similar commands don't work

**Solutions:**
1. **Verify plugin loaded:**
   - Run `:Lazy` and check `obsidian.nvim` status
   - Should show as loaded

2. **Check filetype:**
   - Obsidian commands only work in markdown files
   - Verify with `:set filetype?` (should show `markdown`)

3. **Reload config:**
   - Run `:Lazy reload obsidian.nvim`
   - Or restart Neovim

### Typst Not Compiling

**Symptoms:** `<leader>tc` doesn't create PDF

**Solutions:**
1. **Check Typst installed:**
   ```bash
   typst --version
   ```

2. **Check file extension:**
   - File must be `.typst` extension
   - Not `.typ` or `.txt`

3. **Check for errors:**
   - Look at LSP diagnostics: `:LspInfo`
   - Check for compilation errors in messages

4. **Manual compile:**
   ```bash
   typst compile document.typst
   ```

### LSP Not Working

**Symptoms:** No autocompletion, no diagnostics

**Solutions:**
1. **Check Mason:**
   - Run `:Mason`
   - Verify LSP servers are installed
   - Install missing servers

2. **Check LSP status:**
   - Run `:LspInfo` to see active servers
   - Check for errors

3. **Restart LSP:**
   - `:LspRestart` to restart current LSP
   - Or restart Neovim

### Slow Performance

**Symptoms:** Neovim feels sluggish

**Solutions:**
1. **Check plugins:**
   - Run `:Lazy` and check for slow plugins
   - Disable unused plugins

2. **Check treesitter:**
   - Large files can slow down treesitter
   - Disable for very large files if needed

3. **Check LSP:**
   - Some LSPs can be slow
   - Check `:LspInfo` for issues

### Conceal Not Working

**Symptoms:** Markdown syntax still visible

**Solutions:**
1. **Check conceal level:**
   - Run `:set conceallevel?`
   - Should be 1 or 2 for markdown

2. **Toggle conceal:**
   - Use `<leader>oc` to toggle
   - Or manually: `:set conceallevel=2`

3. **Check filetype:**
   - Conceal only works for markdown
   - Verify with `:set filetype?`

---

## Advanced Tips

### Customizing Vault Path

To change the Obsidian vault path, edit `lua/custom/plugins/obsidian.lua`:

```lua
workspaces = {
  {
    name = 'lexicon',
    path = '~/vaults/Lexicon/',  -- Change this path
  },
},
```

Also update the vault path in `init.lua` for Telescope pickers.

### Adding More Workspaces

You can add multiple Obsidian workspaces:

```lua
workspaces = {
  {
    name = 'lexicon',
    path = '~/vaults/Lexicon/',
  },
  {
    name = 'work',
    path = '~/vaults/Work/',
  },
},
```

### Custom Keybindings

To add custom keybindings, create `lua/custom/keymaps.lua`:

```lua
vim.keymap.set('n', '<leader>xx', function()
  -- Your custom function
end, { desc = 'Custom action' })
```

Then require it in `init.lua` or your plugin config.

### Plugin Updates

Update all plugins:
```vim
:Lazy update
```

Update specific plugin:
```vim
:Lazy update <plugin-name>
```

### Configuration Files

- `init.lua` - Main configuration
- `lua/custom/plugins/*.lua` - Custom plugins
- `lua/kickstart/plugins/*.lua` - Kickstart plugins

---

## Getting Help

- **Neovim Help:** `:help` or `<leader>sh`
- **Plugin Help:** Check plugin READMEs
- **LSP Help:** `:help lsp`
- **Telescope Help:** Press `?` in Telescope
- **Lazy Help:** Press `?` in Lazy UI

---

## Quick Reference Card

Print this for quick reference:

```
OBSIDIAN:
  ot = Today's note    on = New note      od = New (prompt)
  oi = Template        os = Search        oq = Quick switch
  of = Find files      og = Grep          oo = Open in app
  op = Paste (custom) ip = Paste (quick) oc = Toggle conceal
  p  = Preview math

TYPST:
  tc = Compile         tw = Watch         to = Open PDF
  C-l m = Math         C-l M = Block

GENERAL:
  sf = Find files      sg = Grep          sw = Search word
  sh = Search help     sk = Keymaps       sr = Resume
  f  = Format          q  = Diagnostics  th = Inlay hints
  C-h/j/k/l = Windows
```

---

*Last updated: 2024*
*Configuration version: Based on kickstart.nvim with custom enhancements*

