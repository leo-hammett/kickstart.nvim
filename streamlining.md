## Streamlining Neovim for Responsiveness & Battery

### Rendering & UI
- Prefer lazy image rendering: `image.nvim` → `only_render_image_at_cursor = true`, set `max_width/height`.
- Disable duplicate renderers (Snacks.image off, rely on one backend).
- Skip heavy UI modules (Snacks dashboards, scopes) unless needed; disable `obsidian.ui` for large files (`max_file_length`).
- Use a lighter colorscheme/statusline when on battery (fewer highlights reduces redraw cost).

### Filesystem & Git
- In Neo-tree, disable `git_status` or set `async = true` and `use_libuv_file_watcher = true` to avoid spawning many git jobs.
- Ignore large folders (attachments) via `filesystem.filtered_items` to cut scan time.
- Raise `ulimit -n` (already done) and avoid opening multiple watchers on the same vault (Snacks bigfile, LSP watchers, etc.).

### Plugins/Providers
- Remove or lazy-load plugins you rarely use (Snacks modules, obsidian extras).
- Disable unused providers (`vim.g.loaded_python3_provider = 0`, etc.) to avoid startup checks.
- Install Blink’s native fuzzy lib so completion doesn’t spike CPU in pure Lua.

### Marker & Parsing
- Restrict conversions to relevant pages (`--page_range`) or smaller PDFs; big runs block Neovim.
- Run `marker_single` via uv on an external terminal when possible, then open the generated markdown.
- For battery: perform heavy conversions while plugged in; review/edit later.

### Treesitter & Highlight
- Turn off Treesitter for buffers larger than 5k lines (`vim.treesitter.stop(bufnr)`), or set `highlight.enable = false` for markdown.
- Avoid simultaneous conceal + inline image preview on giant notes.

### System Tweaks
- Use a lower refresh rate (Ghostty/terminal setting) when on battery; less redraw.
- Enable macOS “Low Power Mode” so CPU turbo doesn’t kick in during long conversions.
- Close other apps using GPU/CPU cycles (Xcode, browsers) to keep Neovim’s latency low.


