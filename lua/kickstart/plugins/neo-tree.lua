-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    sources = { 'filesystem', 'buffers', 'git_status' },
    source_selector = {
      winbar = true,
      statusline = false,
      content_layout = 'center',
      sources = {
        { source = 'filesystem', display_name = ' Files' },
        { source = 'buffers', display_name = ' Buffers' },
        { source = 'git_status', display_name = ' Git' },
      },
    },
    window = {
      mappings = {
        ['\\'] = 'close_window',
        t = 'open_tabnew',
        T = 'open_tab_drop',
        s = 'split_with_window_picker',
        v = 'vsplit_with_window_picker',
      },
    },
    filesystem = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = true,
        never_show = { '.DS_Store' },
        always_show = { '.obsidian' },
      },
    },
  },
}
