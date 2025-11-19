local M = {}

local function with_telescope(callback)
  local ok, builtin = pcall(require, 'telescope.builtin')
  if not ok then
    vim.notify('Telescope is not available', vim.log.levels.WARN)
    return
  end
  callback(builtin)
end

local function setup_obsidian_shortcuts()
  local vault = vim.fn.expand '~/vaults/Lexicon'

  with_telescope(function(builtin)
    vim.keymap.set('n', '<leader>of', function()
      builtin.find_files { cwd = vault }
    end, { desc = 'Obsidian [F]iles in vault' })

    vim.keymap.set('n', '<leader>og', function()
      builtin.live_grep { cwd = vault }
    end, { desc = 'Obsidian [G]rep in vault' })

    local bookmarks = {
      { name = 'Projects', path = vault .. '/Projects', key = '<leader>bp', desc = '[B]ookmark [P]rojects' },
      { name = 'Lecture Notes', path = vault .. '/Lecture Notes', key = '<leader>bl', desc = '[B]ookmark [L]ecture Notes' },
      {
        name = 'Daily Notes',
        path = vault .. '/Areas/Daily Notes',
        key = '<leader>bd',
        desc = '[B]ookmark [D]aily Notes',
      },
      { name = 'Templates', path = vault .. '/Templates', key = nil },
    }

    vim.keymap.set('n', '<leader>ob', function()
      builtin.find_files {
        prompt_title = 'Bookmarked Folders',
        search_dirs = vim.tbl_map(function(bookmark)
          return bookmark.path
        end, bookmarks),
      }
    end, { desc = 'Obsidian [B]ookmarks' })

    for _, bookmark in ipairs(bookmarks) do
      if bookmark.key then
        vim.keymap.set('n', bookmark.key, function()
          builtin.find_files { cwd = bookmark.path, prompt_title = bookmark.name }
        end, { desc = bookmark.desc })
      end
    end
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    group = vim.api.nvim_create_augroup('custom_obsidian_shortcuts', { clear = true }),
    callback = setup_obsidian_shortcuts,
    once = true,
  })
end

return M

