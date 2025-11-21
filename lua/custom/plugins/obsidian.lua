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

    -- Image rendering for embedded images
    {
      '3rd/image.nvim',
      enabled = false,
    },
  },
  opts = {
    workspaces = {
      {
        name = 'lexicon',
        path = '~/vaults/Lexicon/',
      },
    },

    -- Daily notes configuration
    daily_notes = {
      -- Optional, if you keep daily notes in a separate directory.
      folder = 'Areas/Daily Notes',
      -- Optional, if you want to change the date format for the ID of daily notes.
      date_format = '%Y-%m-%d',
      -- Optional, if you want to change the date format of the default alias of daily notes.
      alias_format = '%B %-d, %Y',
      -- Optional, default tags to add to each new daily note created.
      default_tags = { 'daily-notes' },
      -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
      template = nil,
    },

    -- Attachments configuration
    attachments = {
      -- The directory to place images/attachments. Can be absolute or relative to the vault root.
      img_folder = 'attachments',
      -- A function that determines the text to insert when pasting an image
      img_text_func = function(client, path)
        path = client:vault_relative_path(path) or path
        return string.format('![[%s]]', path.filename)
      end,
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
      checkboxes = {}, -- Disabled to let render-markdown.nvim handle checkboxes

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

    -- Template insertion
    vim.keymap.set('n', '<leader>oi', '<cmd>ObsidianTemplate<CR>', { desc = 'Insert Obsidian template' })

    -- Prompted new note creation
    vim.keymap.set('n', '<leader>od', function()
      local title = vim.fn.input('Note title: ')
      if title ~= '' then
        vim.cmd('ObsidianNew ' .. title)
      end
    end, { desc = 'New note with prompt' })

    -- Toggle conceal for Markdown editing
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'markdown',
      callback = function()
        vim.keymap.set('n', '<leader>oc', function()
          local conceal = vim.wo.conceallevel
          vim.wo.conceallevel = conceal == 0 and 2 or 0
          vim.notify('Conceallevel: ' .. vim.wo.conceallevel)
        end, { buffer = 0, desc = 'Toggle conceal for Markdown' })
      end,
    })

    -- ---- Enhanced per-note attachments paste helper ----
    -- Platform-specific clipboard tools required:
    --   macOS: brew install pngpaste
    --   Linux (X11): xclip or xsel
    --   Linux (Wayland): wl-clipboard
    --   Windows: built-in (uses PowerShell)
    local function obsidian_paste_local()
      local vault = vim.fn.expand '~/vaults/Lexicon' -- your vault root
      local note = vim.api.nvim_buf_get_name(0) -- absolute path to current note
      if note == '' then
        vim.notify('No file open', vim.log.levels.WARN)
        return
      end

      -- Check if clipboard tool is available (basic check)
      local has_clipboard = false
      if vim.fn.has 'mac' == 1 then
        has_clipboard = vim.fn.executable 'pngpaste' == 1
      elseif vim.fn.has 'unix' == 1 then
        has_clipboard = (vim.fn.executable 'xclip' == 1) or (vim.fn.executable 'wl-paste' == 1)
      elseif vim.fn.has 'win32' == 1 then
        has_clipboard = true -- Windows has built-in clipboard support
      end

      if not has_clipboard then
        local platform_msg = vim.fn.has 'mac' == 1 and 'pngpaste' or (vim.fn.has 'unix' == 1 and 'xclip or wl-clipboard' or '')
        vim.notify('Clipboard tool not found. Install: ' .. platform_msg, vim.log.levels.WARN)
        -- Continue anyway, obsidian.nvim might handle it
      end

      local rel_dir = ''
      local default_folder = 'attachments'

      if note:find(vault, 1, true) then
        -- If inside vault: use note's directory
        rel_dir = vim.fn.fnamemodify(note, ':h'):gsub('^' .. vim.pesc(vault) .. '/?', '')
        default_folder = (rel_dir ~= '' and (rel_dir .. '/attachments')) or 'attachments'
      else
        -- If outside vault: try to create a local attachments folder next to the file
        local note_dir = vim.fn.fnamemodify(note, ':h')
        local abs_dir = note_dir .. '/attachments'
        vim.fn.mkdir(abs_dir, 'p')
        default_folder = vim.fn.fnamemodify(abs_dir, ':.') -- make it relative to CWD
      end

      -- Prompt for folder (with default)
      local target = vim.fn.input('Attachment folder: ', default_folder)
      if target == '' then
        target = default_folder
      end

      -- Prompt for filename (with timestamp default)
      local default_name = os.date 'img-%Y%m%d-%H%M%S'
      local name = vim.fn.input('File name (blank for timestamp): ', default_name)
      if name == '' then
        name = default_name
      end

      -- Paste the image using Obsidian's command
      vim.cmd(('ObsidianPasteImg %s/%s'):format(vim.fn.fnameescape(target), name))
    end

    vim.keymap.set('n', '<leader>op', obsidian_paste_local, { desc = 'Paste image to local attachments' })

    -- Markdown linting command
    vim.api.nvim_create_user_command('ObsidianLint', function()
      vim.diagnostic.setloclist { open = true }
    end, { desc = 'Show Markdown diagnostics for broken links' })
  end,
}
