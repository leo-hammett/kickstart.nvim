return {
  'nvim-telescope/telescope.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    -- Define your favorite projects/folders here
    local projects = {
      { name = 'Neovim Config', path = '~/.config/nvim' },
      { name = 'Lexicon',       path = '~/vaults/Lexicon' },
      { name = 'Lecture Notes', path = '~/vaults/Lexicon/Third Year/Lecture Notes' },
      -- Add more projects here as needed
    }

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    local function project_switcher()
      pickers.new({}, {
        prompt_title = 'Select Project Root',
        finder = finders.new_table {
          results = projects,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.name,
              ordinal = entry.name,
            }
          end,
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            local path = vim.fn.expand(selection.value.path)
            
            -- Change directory
            vim.cmd.cd(path)
            print('Changed directory to: ' .. path)

            -- Refresh Neo-tree if available
            if package.loaded['neo-tree'] then
              vim.cmd('Neotree dir=' .. path)
            end
          end)
          return true
        end,
      }):find()
    end

    -- Keymap to open the switcher
    vim.keymap.set('n', '<leader>fp', project_switcher, { desc = '[F]ind [P]roject root' })
  end,
}

