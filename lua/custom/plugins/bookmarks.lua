return {
  {
    'tomasky/bookmarks.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    event = 'VimEnter',
    config = function()
      require('bookmarks').setup {
        save_file = vim.fn.expand '$HOME/.local/share/nvim/bookmarks', -- bookmarks save file path
        keywords = {
          ['@lecture'] = '📚 ', -- lecture notes
          ['@project'] = '📁 ', -- project files
          ['@todo'] = '✅ ', -- todo lists
          ['@important'] = '⭐ ', -- important notes
        },
      }

      -- Telescope integration
      require('telescope').load_extension 'bookmarks'

      -- Keybindings
      vim.keymap.set('n', '<leader>bm', "<cmd>lua require('bookmarks').bookmark_toggle()<CR>", { desc = '[B]ookmark toggle' })
      vim.keymap.set('n', '<leader>bi', "<cmd>lua require('bookmarks').bookmark_ann()<CR>", { desc = '[B]ookmark [I]nput annotation' })
      vim.keymap.set('n', '<leader>bc', "<cmd>lua require('bookmarks').bookmark_clean()<CR>", { desc = '[B]ookmark [C]lean in buffer' })
      vim.keymap.set('n', '<leader>bn', "<cmd>lua require('bookmarks').bookmark_next()<CR>", { desc = '[B]ookmark [N]ext' })
      vim.keymap.set('n', '<leader>bp', "<cmd>lua require('bookmarks').bookmark_prev()<CR>", { desc = '[B]ookmark [P]rev' })
      vim.keymap.set('n', '<leader>bl', '<cmd>Telescope bookmarks list<CR>', { desc = '[B]ookmark [L]ist' })
    end,
  },

  -- Additional quick-access commands for your Obsidian vault
  {
    'nvim-telescope/telescope.nvim',
    optional = true,
    keys = {
      -- Quick access to your lecture notes directory
      {
        '<leader>fl',
        function()
          require('telescope.builtin').find_files {
            prompt_title = '📚 Lecture Notes',
            cwd = vim.fn.expand '~/vaults/Lexicon/Projects/Ursprung',
            hidden = false,
          }
        end,
        desc = '[F]ind [L]ecture notes',
      },
      -- Quick access to entire Lexicon vault
      {
        '<leader>fv',
        function()
          require('telescope.builtin').find_files {
            prompt_title = '📖 Vault',
            cwd = vim.fn.expand '~/vaults/Lexicon',
            hidden = false,
          }
        end,
        desc = '[F]ind in [V]ault',
      },
      -- Search in lecture notes
      {
        '<leader>sl',
        function()
          require('telescope.builtin').live_grep {
            prompt_title = '🔍 Search Lecture Notes',
            cwd = vim.fn.expand '~/vaults/Lexicon/Projects/Ursprung',
          }
        end,
        desc = '[S]earch [L]ecture notes',
      },
      -- Recent files in vault
      {
        '<leader>fr',
        function()
          require('telescope.builtin').oldfiles {
            prompt_title = '📜 Recent Vault Files',
            cwd_only = true,
            cwd = vim.fn.expand '~/vaults/Lexicon',
          }
        end,
        desc = '[F]ind [R]ecent vault files',
      },
    },
  },
}

