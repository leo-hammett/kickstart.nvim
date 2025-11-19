-- lazy.nvim
return {
  'folke/snacks.nvim',
  ---@type snacks.Config
  opts = {
    image = {
      -- Disable Snacks image rendering so we don't double-render
      -- attachments (image.nvim already handles markdown embeds).
      enabled = false,
      -- Style for image rendering: 'cover', 'contain', or 'fill'
      style = 'cover',
      -- Maximum width/height for images (0 = no limit)
      max_width = 0,
      max_height = 0,
    },
  },
}
