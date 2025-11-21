local markdown_paste = require 'custom.features.markdown_paste'
local pdf_parser = require 'custom.features.pdf_parser'
local obsidian_shortcuts = require 'custom.features.obsidian_shortcuts'
local lecture_coach = require 'custom.features.lecture_coach'

local M = {}

function M.setup()
  markdown_paste.setup()
  pdf_parser.setup()
  obsidian_shortcuts.setup()
  lecture_coach.setup()
end

return M
