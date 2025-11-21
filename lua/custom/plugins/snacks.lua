-- lazy.nvim
return {
  'folke/snacks.nvim',
  ---@type snacks.Config
  opts = {
    image = {
      enabled = true,
      style = 'cover',
      max_width = 1200,
      max_height = 800,
      lazy = true,
      max_images = 20,
      formats = {
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'webp',
        'tiff',
        'heic',
        'avif',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
      },
    },
  },
  config = function(_, opts)
    local snacks = require 'snacks'
    snacks.setup(opts)

    local ignored_exts = { ppt = true, pptx = true, pptm = true, doc = true, docx = true, xls = true, xlsx = true }
    local doc = require 'snacks.image.doc'
    if not doc._lexicon_filter then
      doc._lexicon_filter = true
      local orig = doc.find_visible
      doc.find_visible = function(buf, cb)
        orig(buf, function(matches)
          local filtered = {}
          for _, img in ipairs(matches) do
            local src = img.src or ''
            local ext = src:match '%.([^.]+)$'
            if not (ext and ignored_exts[ext:lower()]) then
              filtered[#filtered + 1] = img
            end
          end
          cb(filtered)
        end)
      end
    end
  end,
}
