local M = {}

local function setup_markdown_paste()
  local augroup = vim.api.nvim_create_augroup('custom_markdown_paste', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    group = augroup,
    callback = function()
      vim.keymap.set('n', '<leader>ip', function()
        local note = vim.api.nvim_buf_get_name(0)
        if note == '' then
          vim.notify('No file open', vim.log.levels.WARN)
          return
        end

        local note_dir = vim.fn.fnamemodify(note, ':h')
        local attachments_dir = note_dir .. '/attachments'
        vim.fn.mkdir(attachments_dir, 'p')

        local basename = os.date 'Pasted image %Y%m%d%H%M%S'
        local target = string.format('%s/%s.png', attachments_dir, basename)

        local ok, err = pcall(vim.cmd, ('ObsidianPasteImg %s'):format(vim.fn.fnameescape(target)))
        if not ok then
          vim.notify('ObsidianPasteImg failed: ' .. tostring(err), vim.log.levels.ERROR)
        end
      end, { buffer = true, desc = 'Obsidian paste image' })
    end,
  })
end

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
    -- Vault-wide helpers
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
  setup_markdown_paste()

  vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    group = vim.api.nvim_create_augroup('custom_obsidian_shortcuts', { clear = true }),
    callback = setup_obsidian_shortcuts,
    once = true,
  })
end

return M

