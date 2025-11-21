-- lazy.nvim
return {
  'folke/snacks.nvim',
  ---@type snacks.Config
  opts = {
    image = {
      enabled = true,
      style = 'cover',
      -- Keep previews sane to avoid giant renders
      max_width = 1200,
      max_height = 800,
      lazy = true, -- render when cursor nears image
      max_images = 20, -- prevent loading hundreds at once
      -- Explicitly define supported formats to prevent errors with PDF/PPTX
      -- (Removing 'pdf' from the default list avoids the LibreOffice/Ghostscript errors)
      formats = {
        "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif",
        "mp4", "mov", "avi", "mkv", "webm"
      },
    },
  },
}
