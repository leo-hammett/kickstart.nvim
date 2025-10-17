return {
  {
    'williamboman/mason.nvim',
    opts = { ensure_installed = { 'tree-sitter-cli' } },
  },

  {
    'jbyuki/nabla.nvim',
    dependencies = {
      'nvim-neo-tree/neo-tree.nvim',
      'williamboman/mason.nvim',
    },
    lazy = true,

    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'latex' },
        auto_install = true,
        sync_install = false,
      }
    end,

    keys = function()
      return {
        {
          '<leader>p',
          ':lua require("nabla").popup()<cr>',
          desc = 'NablaPopUp',
        },
      }
    end,
  },
}
