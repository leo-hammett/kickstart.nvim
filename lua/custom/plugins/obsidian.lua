return {
  'epwalsh/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = 'markdown',
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
  --   "BufReadPre path/to/my-vault/**.md",
  --   "BufNewFile path/to/my-vault/**.md",
  -- },
  dependencies = {
    -- Required.
    'nvim-lua/plenary.nvim',

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = 'lexicon',
        path = '~/vaults/Lexicon/',
      },
    },

    -- Optional, completion of wiki links, local markdown links, and tags using nvim-cmp.
    completion = {
      -- Enables completion using blink.cmp
      blink = true,
      -- Trigger completion at 2 chars.
      min_chars = 2,
      -- Set to false to disable new note creation in the picker
      create_new = true,
    },
    -- Optional, configure additional syntax highlighting / extmarks.
    -- This requires you have `conceallevel` set to 1 or 2. See `:help conceallevel` for more details.
    ui = {
      enable = true, -- set to false to disable all additional syntax features
      ignore_conceal_warn = false, -- set to true to disable conceallevel specific warning
      update_debounce = 200, -- update delay after a text change (in milliseconds)
      max_file_length = 5000, -- disable UI features for files with more than this many lines
      -- Define how various check-boxes are displayed
      checkboxes = {
        -- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
        [' '] = { char = '󰄱', hl_group = 'ObsidianTodo' },
        ['x'] = { char = '', hl_group = 'ObsidianDone' },
        ['>'] = { char = '', hl_group = 'ObsidianRightArrow' },
        ['~'] = { char = '󰰱', hl_group = 'ObsidianTilde' },
        ['!'] = { char = '', hl_group = 'ObsidianImportant' },
        -- Replace the above with this if you don't have a patched font:
        -- [" "] = { char = "☐", hl_group = "ObsidianTodo" },
        -- ["x"] = { char = "✔", hl_group = "ObsidianDone" },

        -- You can also add more custom ones...
      },
      -- Use bullet marks for non-checkbox lists.
      bullets = { char = '•', hl_group = 'ObsidianBullet' },
      external_link_icon = { char = '', hl_group = 'ObsidianExtLinkIcon' },
      -- Replace the above with this if you don't have a patched font:
      -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
      reference_text = { hl_group = 'ObsidianRefText' },
      highlight_text = { hl_group = 'ObsidianHighlightText' },
      tags = { hl_group = 'ObsidianTag' },
      block_ids = { hl_group = 'ObsidianBlockID' },
      hl_groups = {
        -- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
        ObsidianTodo = { bold = true, fg = '#f78c6c' },
        ObsidianDone = { bold = true, fg = '#89ddff' },
        ObsidianRightArrow = { bold = true, fg = '#f78c6c' },
        ObsidianTilde = { bold = true, fg = '#ff5370' },
        ObsidianImportant = { bold = true, fg = '#d73128' },
        ObsidianBullet = { bold = true, fg = '#89ddff' },
        ObsidianRefText = { underline = true, fg = '#c792ea' },
        ObsidianExtLinkIcon = { fg = '#c792ea' },
        ObsidianTag = { italic = true, fg = '#89ddff' },
        ObsidianBlockID = { italic = true, fg = '#89ddff' },
        ObsidianHighlightText = { bg = '#75662e' },
      },
    },

    -- see below for full list of options
    -- Normal-mode mappings (leader assumed to be space)
    vim.keymap.set('n', '<leader>ot', '<cmd>ObsidianToday<CR>'),
    vim.keymap.set('n', '<leader>oo', '<cmd>ObsidianOpen<CR>'),
    vim.keymap.set('n', '<leader>oq', '<cmd>ObsidianQuickSwitch<CR>'),
    vim.keymap.set('n', '<leader>os', '<cmd>ObsidianSearch<CR>'),
    vim.keymap.set('n', '<leader>on', '<cmd>ObsidianNew<CR>'),
  },
  config = function(_, opts)
    require('obsidian').setup(opts)

    -- Conceal: apply to markdown buffers
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'markdown',
      callback = function()
        vim.opt_local.conceallevel = 1
        vim.opt_local.concealcursor = 'nc'
      end,
    })

    -- Keymaps
    vim.keymap.set('n', '<leader>ot', '<cmd>ObsidianToday<CR>', { desc = 'Obsidian Today' })
    vim.keymap.set('n', '<leader>oo', '<cmd>ObsidianOpen<CR>', { desc = 'Obsidian Open in app' })
    vim.keymap.set('n', '<leader>oq', '<cmd>ObsidianQuickSwitch<CR>', { desc = 'Obsidian Quick Switch' })
    vim.keymap.set('n', '<leader>os', '<cmd>ObsidianSearch<CR>', { desc = 'Obsidian Search' })
    vim.keymap.set('n', '<leader>on', '<cmd>ObsidianNew<CR>', { desc = 'Obsidian New note' })

    -- ---- Per-note attachments paste helper ----
    -- Requires: brew install pngpaste
    local function obsidian_paste_local()
      local vault = vim.fn.expand '~/vaults/Lexicon' -- your vault root
      local note = vim.api.nvim_buf_get_name(0) -- absolute path to current note
      if note == '' then
        return
      end

      if note:find(vault, 1, true) then
        -- If inside vault: use note’s directory
        local rel_dir = vim.fn.fnamemodify(note, ':h'):gsub('^' .. vim.pesc(vault) .. '/?', '')
        folder = (rel_dir ~= '' and (rel_dir .. '/attachments')) or 'attachments'
      else
        -- If outside vault: try to create a local attachments folder next to the file
        local note_dir = vim.fn.fnamemodify(note, ':h')
        local abs_dir = note_dir .. '/attachments'
        vim.fn.mkdir(abs_dir, 'p')
        folder = vim.fn.fnamemodify(abs_dir, ':.') -- make it relative to CWD
      end

      -- Get note dir relative to vault, then add "attachments"
      local rel_dir = vim.fn.fnamemodify(note, ':h')
      -- Strip vault prefix safely
      rel_dir = rel_dir:gsub('^' .. vim.pesc(vault) .. '/?', '')
      local folder = (rel_dir ~= '' and (rel_dir .. '/attachments')) or 'attachments'

      local name = os.date 'img-%Y%m%d-%H%M%S'
      -- Override target folder per paste (must be vault-relative)
      vim.cmd(('ObsidianPasteImg %s/%s'):format(vim.fn.fnameescape(folder), name))
    end

    vim.keymap.set('n', '<leader>op', obsidian_paste_local, { desc = 'Paste image to local attachments' })
  end,
}
