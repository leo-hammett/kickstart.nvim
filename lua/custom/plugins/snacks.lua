-- lazy.nvim
return {
  'folke/snacks.nvim',
  ---@type snacks.Config
  opts = {
    image = {
      -- Enable image previews in Neovim buffers
      enabled = true,
      -- Style for image rendering: 'cover', 'contain', or 'fill'
      style = 'cover',
      -- Maximum width/height for images (0 = no limit)
      max_width = 0,
      max_height = 0,
    },
  },
}
