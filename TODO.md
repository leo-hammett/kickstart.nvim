## Backlog

- [ ] Install Blink’s native fuzzy backend (`:BlinkCmpInstall fuzzy`) so completion stays fast.
- [ ] Remove the legacy packer directory at `~/.local/share/nvim/site/pack/packer`.
- [ ] Install Lua 5.1 (e.g. `brew install lua@5.1`) so luarocks/image.nvim can build dependencies.
- [ ] Install ImageMagick’s `magick` binary (already done) and optional Mermaid CLI (`npm i -g @mermaid-js/mermaid-cli`) for Snacks rendering.
- [ ] Decide whether to install missing toolchains (cargo, php/composer, java/javac, julia) for Mason. Skip if unused.
- [ ] Install `pynvim` (`pip3 install --user pynvim`) and `neovim` Ruby gem (`gem install neovim`) or disable those providers.
- [ ] Run `pip3 install marker-pdf` inside Python 3.11+ and set `vim.g.custom_pdf_marker_command` to the uv wrapper.
- [ ] Set a higher file-descriptor limit permanently (`ulimit -n 16384` in shell rc).
- [ ] Consider disabling Neo-tree git_status or enabling libuv watcher to reduce git spawning.
- [ ] Configure `image.nvim` for lazy rendering (`only_render_image_at_cursor = true`) to avoid loading every embed at once.
- [ ] Run `:SnacksImageRefresh` or `:ImageRefresh` when embeds look stale.
- [ ] Install `nvim-web-devicons` for consistent icon support.


