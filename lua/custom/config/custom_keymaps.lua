local M = {}

local uv = vim.uv or vim.loop

-- Markdown helpers
-- * <leader>ip - Obsidian image paste (existing behaviour)
-- * <leader>pa - Import an external PDF, copy it into ./attachments, run the
--                configured parser (defaults to `pdftotext -layout -enc UTF-8`),
--                and insert the Markdown output into the current note.
-- * <leader>pp - Pick an already attached PDF and parse it into Markdown at the
--                cursor position.
-- Configure a different parser (e.g. `{'pdf2md'}`) with:
--   vim.g.custom_pdf_parser_command = { 'pdf2md' }
-- Dependencies: install `pdftotext` via `brew install poppler` (macOS) or any
-- other CLI that can emit Markdown/text to stdout.

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

      local function get_markdown_context()
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname == '' then
          return nil, 'No file open'
        end

        if vim.bo.filetype ~= 'markdown' then
          return nil, 'Current buffer is not markdown'
        end

        local note_dir = vim.fn.fnamemodify(bufname, ':h')
        local attachments_dir = note_dir .. '/attachments'
        vim.fn.mkdir(attachments_dir, 'p')

        return {
          note_path = bufname,
          note_dir = note_dir,
          attachments_dir = attachments_dir,
        }
      end

      local function system_capture(cmd)
        if vim.system then
          local result = vim.system(cmd, { text = true }):wait()
          if result.code ~= 0 then
            local stderr = vim.trim(result.stderr or '')
            return nil, stderr ~= '' and stderr or ('command failed: ' .. table.concat(cmd, ' '))
          end
          return result.stdout or '', nil
        end

        local output = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          return nil, output
        end
        return output, nil
      end

      local function parser_command()
        local cmd = vim.g.custom_pdf_parser_command or { 'pdftotext', '-layout', '-enc', 'UTF-8' }
        if type(cmd) == 'string' then
          cmd = vim.split(cmd, '%s+', { trimempty = true })
        end
        if type(cmd) ~= 'table' or #cmd == 0 then
          return nil, 'Invalid parser command configuration'
        end
        if vim.fn.executable(cmd[1]) == 0 then
          return nil, string.format("Parser executable '%s' not found", cmd[1])
        end
        return cmd, nil
      end

      local function normalize_markdown(text)
        text = (text or ''):gsub('\r\n', '\n')
        text = text:gsub('\f', '\n')
        text = text:gsub('•%s*', '- ')
        text = text:gsub('\n\n\n+', '\n\n')
        return vim.trim(text)
      end

      local function convert_pdf_to_markdown(pdf_path)
        local base_cmd, err = parser_command()
        if not base_cmd then
          return nil, err
        end

        local cmd = vim.deepcopy(base_cmd)
        table.insert(cmd, pdf_path)
        table.insert(cmd, '-')

        local output, run_err = system_capture(cmd)
        if not output then
          return nil, run_err
        end

        local markdown = normalize_markdown(output)
        if markdown == '' then
          markdown = '_No text extracted_'
        end

        return markdown, nil
      end

      local function make_unique_path(path)
        if not uv or not uv.fs_stat then
          return path
        end

        if not uv.fs_stat(path) then
          return path
        end

        local dir = vim.fn.fnamemodify(path, ':h')
        local stem = vim.fn.fnamemodify(path, ':t:r')
        local ext = vim.fn.fnamemodify(path, ':e')
        local i = 1
        local candidate
        repeat
          if ext == '' then
            candidate = string.format('%s/%s_%d', dir, stem, i)
          else
            candidate = string.format('%s/%s_%d.%s', dir, stem, i, ext)
          end
          i = i + 1
        until not uv.fs_stat(candidate)
        return candidate
      end

      local function copy_into_attachments(pdf_path, attachments_dir)
        local filename = vim.fn.fnamemodify(pdf_path, ':t')
        local target = string.format('%s/%s', attachments_dir, filename)
        if uv and uv.fs_stat and uv.fs_stat(target) then
          target = make_unique_path(target)
        end

        local ok, err
        if uv and uv.fs_copyfile then
          ok, err = uv.fs_copyfile(pdf_path, target)
        else
          ok = vim.fn.system({ 'cp', pdf_path, target })
          err = vim.v.shell_error ~= 0 and ok or nil
          ok = vim.v.shell_error == 0
        end

        if not ok then
          return nil, err or 'Failed to copy PDF'
        end

        return target, nil
      end

      local function insert_markdown_block(block)
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.split(block, '\n', { plain = true })
        vim.api.nvim_buf_set_lines(0, row, row, true, lines)
      end

      local function add_pdf_to_buffer(pdf_path, ctx)
        local markdown, err = convert_pdf_to_markdown(pdf_path)
        if not markdown then
          vim.notify('PDF parse failed: ' .. err, vim.log.levels.ERROR)
          return
        end

        local filename = vim.fn.fnamemodify(pdf_path, ':t')
        local heading = string.format('## Notes from %s', vim.fn.fnamemodify(filename, ':r'))
        local pdf_link = string.format('> Source: [[attachments/%s]]', filename)
        local block = table.concat({ heading, pdf_link, '', markdown, '' }, '\n')
        insert_markdown_block(block)
        vim.notify(string.format('Parsed %s into current note', filename), vim.log.levels.INFO)
      end

      local function prompt_for_pdf()
        local input = vim.fn.input('PDF path: ', '', 'file')
        if input == '' then
          return nil
        end
        local expanded = vim.fn.fnamemodify(vim.fn.expand(input), ':p')
        if vim.fn.filereadable(expanded) == 0 then
          vim.notify('PDF not found: ' .. expanded, vim.log.levels.WARN)
          return nil
        end
        return expanded
      end

      local function add_new_pdf()
        local ctx, ctx_err = get_markdown_context()
        if not ctx then
          vim.notify(ctx_err, vim.log.levels.WARN)
          return
        end

        local pdf_path = prompt_for_pdf()
        if not pdf_path then
          return
        end

        if vim.fn.fnamemodify(pdf_path, ':e'):lower() ~= 'pdf' then
          vim.notify('Selected file is not a PDF', vim.log.levels.WARN)
          return
        end

        local stored_pdf, err = copy_into_attachments(pdf_path, ctx.attachments_dir)
        if not stored_pdf then
          vim.notify('Failed to copy PDF: ' .. tostring(err), vim.log.levels.ERROR)
          return
        end

        add_pdf_to_buffer(stored_pdf, ctx)
      end

      local function parse_existing_pdf()
        local ctx, ctx_err = get_markdown_context()
        if not ctx then
          vim.notify(ctx_err, vim.log.levels.WARN)
          return
        end

        local pdfs = vim.fn.globpath(ctx.attachments_dir, '*.pdf', false, true)
        if vim.tbl_isempty(pdfs) then
          vim.notify('No PDF attachments found', vim.log.levels.INFO)
          return
        end

        vim.ui.select(pdfs, {
          prompt = 'PDF attachments',
          format_item = function(item)
            return vim.fn.fnamemodify(item, ':t')
          end,
        }, function(choice)
          if not choice then
            return
          end
          add_pdf_to_buffer(choice, ctx)
        end)
      end

      vim.keymap.set('n', '<leader>pa', add_new_pdf, { buffer = true, desc = 'Add & parse new PDF' })
      vim.keymap.set('n', '<leader>pp', parse_existing_pdf, { buffer = true, desc = 'Parse attached PDF' })
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

