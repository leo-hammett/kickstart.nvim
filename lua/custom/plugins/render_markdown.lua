return {
  'MeanderingProgrammer/render-markdown.nvim',
  opts = {
    -- Enable enhanced rendering for sup/sub tags
    html = {
      enabled = true,
    },
  },
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' },
}

