local M = {}

local uv = vim.uv or vim.loop

local function notify_status(message, opts)
  opts = opts or {}
  opts.title = opts.title or 'Obsidian PDF Parser'
  opts.timeout = opts.timeout or 0
  opts.render = opts.render or 'minimal'
  return vim.notify(message, opts.level or vim.log.levels.INFO, opts)
end

-- Markdown helpers
-- * <leader>ip - Obsidian image paste (existing behaviour)
-- * <leader>pa - Import an external PDF, copy it into ./attachments, run the
--                configured parser, and insert the Markdown output.
-- * <leader>pp - Pick an already attached PDF and parse it into Markdown at the
--                cursor position.
-- Parser selection:
--   vim.g.custom_pdf_parser = 'auto' | 'marker' | 'legacy'
--     * 'auto' (default) prefers `marker_single` when available for inline
--       images & tables, otherwise falls back to the legacy `pdftotext`.
--     * 'marker' enforces the Marker CLI (fail if missing).
--     * 'legacy' forces the original `pdftotext` + `pdfimages` pipeline.
-- Configure a different legacy parser (e.g. `{'pdf2md'}`) with:
--   vim.g.custom_pdf_parser_command = { 'pdf2md' }
-- Optional image extraction for the legacy path (enabled by default) requires
-- `pdfimages -png` from Poppler. Configure via:
--   vim.g.custom_pdf_embed_images = false
--   vim.g.custom_pdf_image_command = { 'pdfimages', '-png' }
-- Header/footer cleanup (legacy path) can be toggled with:
--   vim.g.custom_pdf_strip_headers = false
--   vim.g.custom_pdf_strip_footers = false
-- To enable inline placement install:
--   pip install marker-pdf
-- Dependencies: install `pdftotext`/`pdfimages` via `brew install poppler` or
-- rely on `marker_single` (Torch + Docling) for inline extraction. If you keep
-- Marker inside a tool such as `uv`, set `vim.g.custom_pdf_marker_command`
-- (string or list) to override the executable, e.g.
--   vim.g.custom_pdf_marker_command = { 'uv', 'run', 'marker_single' }

local function make_note_relative(path, note_dir)
  local prefix = note_dir .. '/'
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end
  return path
end

local function normalize_markdown(text)
  text = (text or ''):gsub('\r\n', '\n')
  text = text:gsub('\f', '\n')
  text = text:gsub('•%s*', '- ')
  text = text:gsub('\n\n\n+', '\n\n')
  return vim.trim(text)
end

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

      local function parser_mode()
        local mode = vim.g.custom_pdf_parser
        if type(mode) ~= 'string' then
          return 'auto'
        end
        mode = mode:lower()
        if mode ~= 'auto' and mode ~= 'legacy' and mode ~= 'marker' then
          return 'auto'
        end
        return mode
      end

      local function marker_available()
        local cmd = vim.g.custom_pdf_marker_command
        if cmd == nil then
          return vim.fn.executable('marker_single') == 1
        end
        if type(cmd) == 'string' then
          cmd = vim.split(cmd, '%s+', { trimempty = true })
        end
        if type(cmd) == 'table' and #cmd > 0 then
          local exe = cmd[1]
          if exe == 'uv' or exe == 'uvx' or exe:match('/') then
            return true
          end
          return vim.fn.executable(exe) == 1
        end
        return false
      end

      local function marker_command()
        local cmd = vim.g.custom_pdf_marker_command or { 'marker_single' }
        if type(cmd) == 'string' then
          cmd = vim.split(cmd, '%s+', { trimempty = true })
        end
        if type(cmd) ~= 'table' or #cmd == 0 then
          return nil, 'Invalid custom_pdf_marker_command'
        end
        return cmd, nil
      end

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

      local function rewrite_inline_embeds(markdown, base_dir)
        if markdown == nil or markdown == '' then
          return markdown
        end

        local function is_external(path)
          return path:match('^%a[%w+.-]*:') or path:match('^//')
        end

        return markdown:gsub('!%[(.-)%]%((.-)%)', function(label, path)
          if is_external(path) then
            return string.format('![%s](%s)', label, path)
          end
          if path:sub(1, 1) == '#' then
            return string.format('![%s](%s)', label, path)
          end

          local cleaned = path
            :gsub('^%./', '')
            :gsub('^attachments/', '')
            :gsub('^/', '')
            :gsub('\\%(', '(')
            :gsub('\\%)', ')')

          local target = string.format('%s/%s', base_dir, cleaned)
          target = target:gsub('//+', '/')

          if label ~= '' then
            return string.format('![[%s|%s]]', target, label)
          end
          return string.format('![[%s]]', target)
        end)
      end

      local function convert_with_marker(pdf_path, ctx)
        local base_cmd, cmd_err = marker_command()
        if not base_cmd then
          return nil, cmd_err
        end

        local stem = vim.fn.fnamemodify(pdf_path, ':t:r')
        local output_root = string.format('%s/%s_marker', ctx.attachments_dir, stem)
        if vim.fn.isdirectory(output_root) == 1 then
          vim.fn.delete(output_root, 'rf')
        end
        vim.fn.mkdir(output_root, 'p')

        local cmd = vim.deepcopy(base_cmd)
        vim.list_extend(cmd, {
          pdf_path,
          '--output_dir',
          output_root,
          '--output_format',
          'markdown',
        })

        local _, err = system_capture(cmd)
        if err then
          return nil, err
        end

        local leaf_dir = string.format('%s/%s', output_root, stem)
        if vim.fn.isdirectory(leaf_dir) == 0 then
          leaf_dir = output_root
        end

        local matches = vim.fn.globpath(leaf_dir, '**/*.md', false, true)
        if vim.tbl_isempty(matches) then
          return nil, 'Marker markdown output not found'
        end

        local markdown_path = matches[1]
        local content = table.concat(vim.fn.readfile(markdown_path), '\n')
        local markdown_dir = vim.fn.fnamemodify(markdown_path, ':h')
        local rel_root = make_note_relative(markdown_dir, ctx.note_dir)
        local rewritten = rewrite_inline_embeds(content, rel_root)

        return {
          text = normalize_markdown(rewritten),
          inline_images = true,
          source = 'marker',
        }, nil
      end

      local function image_extractor_command()
        local cmd = vim.g.custom_pdf_image_command or { 'pdfimages', '-png' }
        if type(cmd) == 'string' then
          cmd = vim.split(cmd, '%s+', { trimempty = true })
        end
        if type(cmd) ~= 'table' or #cmd == 0 then
          return nil, 'Invalid image extractor configuration'
        end
        if vim.fn.executable(cmd[1]) == 0 then
          return nil, string.format("Image extractor executable '%s' not found", cmd[1])
        end
        return cmd, nil
      end

      local function strip_repeating_lines(raw)
        local strip_headers = vim.g.custom_pdf_strip_headers ~= false
        local strip_footers = vim.g.custom_pdf_strip_footers ~= false
        if not strip_headers and not strip_footers then
          return raw
        end

        local pages = vim.split(raw, '\f', { plain = true })
        local function collect_line(lines, iter)
          for _, idx in iter(lines) do
            local line = vim.trim(lines[idx])
            if line ~= '' then
              return line
            end
          end
          return nil
        end

        local function forward_iter(lines)
          local items = {}
          for idx = 1, #lines do
            items[#items + 1] = idx
          end
          return ipairs(items)
        end

        local function backward_iter(lines)
          local items = {}
          for idx = #lines, 1, -1 do
            items[#items + 1] = idx
          end
          return ipairs(items)
        end

        local header_counts, footer_counts = {}, {}
        if strip_headers then
          for _, page in ipairs(pages) do
            local lines = vim.split(page, '\n', { plain = true })
            local line = collect_line(lines, forward_iter)
            if line then
              header_counts[line] = (header_counts[line] or 0) + 1
            end
          end
        end
        if strip_footers then
          for _, page in ipairs(pages) do
            local lines = vim.split(page, '\n', { plain = true })
            local line = collect_line(lines, backward_iter)
            if line then
              footer_counts[line] = (footer_counts[line] or 0) + 1
            end
          end
        end

        local function should_strip(line, counts)
          return line ~= '' and counts[line] and counts[line] >= 2
        end

        for page_idx, page in ipairs(pages) do
          local lines = vim.split(page, '\n', { plain = true })
          if strip_headers then
            while #lines > 0 do
              local candidate = vim.trim(lines[1])
              if should_strip(candidate, header_counts) then
                table.remove(lines, 1)
              else
                break
              end
            end
          end
          if strip_footers then
            while #lines > 0 do
              local candidate = vim.trim(lines[#lines])
              if should_strip(candidate, footer_counts) then
                table.remove(lines, #lines)
              else
                break
              end
            end
          end
          pages[page_idx] = table.concat(lines, '\n')
        end

        return table.concat(pages, '\f')
      end

      local function convert_with_legacy(pdf_path)
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

        local cleaned = strip_repeating_lines(output)
        local markdown = normalize_markdown(cleaned)
        if markdown == '' then
          markdown = '_No text extracted_'
        end

        return {
          text = markdown,
          inline_images = false,
          source = 'legacy',
        }, nil
      end

      local function convert_pdf_to_markdown(pdf_path, ctx)
        local mode = parser_mode()
        if mode ~= 'legacy' then
          if mode == 'marker' then
            local result, err = convert_with_marker(pdf_path, ctx)
            if result then
              return result, nil
            end
            return nil, err
          end

          if marker_available() then
            local result, err = convert_with_marker(pdf_path, ctx)
            if result then
              return result, nil
            end
            vim.notify('Marker parse failed, falling back to legacy parser: ' .. tostring(err), vim.log.levels.WARN)
          end
        end

        local result, err = convert_with_legacy(pdf_path)
        if not result then
          return nil, err
        end
        return result, nil
      end

      local function extract_pdf_images(pdf_path, ctx)
        if vim.g.custom_pdf_embed_images == false then
          return nil, 'disabled'
        end

        local base_cmd, err = image_extractor_command()
        if not base_cmd then
          return nil, err
        end

        local stem = vim.fn.fnamemodify(pdf_path, ':t:r')
        local images_dir = string.format('%s/%s_images', ctx.attachments_dir, stem)
        vim.fn.mkdir(images_dir, 'p')

        local existing = vim.fn.globpath(images_dir, '*.png', false, true)
        if #existing > 0 then
          return {
            dir = images_dir,
            files = existing,
          }, nil
        end

        local prefix = string.format('%s/%s', images_dir, stem)
        local cmd = vim.deepcopy(base_cmd)
        table.insert(cmd, pdf_path)
        table.insert(cmd, prefix)

        local _, run_err = system_capture(cmd)
        if run_err then
          return nil, run_err
        end

        local files = vim.fn.globpath(images_dir, '*.png', false, true)
        if #files == 0 then
          return nil, 'No images detected'
        end

        return {
          dir = images_dir,
          files = files,
        }, nil
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
        local filename = vim.fn.fnamemodify(pdf_path, ':t')
        local status = notify_status(('Parsing %s ...'):format(filename), { icon = '', timeout = 0 })

        local parsed, err = convert_pdf_to_markdown(pdf_path, ctx)
        if not parsed then
          notify_status(('Failed to parse %s'):format(filename), {
            replace = status,
            level = vim.log.levels.ERROR,
            timeout = 5000,
          })
          vim.notify('PDF parse failed: ' .. err, vim.log.levels.ERROR)
          return
        end

        local images
        if not parsed.inline_images then
          images, err = extract_pdf_images(pdf_path, ctx)
          if err and err ~= 'disabled' and err ~= 'No images detected' then
            vim.notify('PDF image extraction: ' .. err, vim.log.levels.WARN)
          end
        end

        local heading = string.format('## Notes from %s', vim.fn.fnamemodify(filename, ':r'))
        local pdf_link = string.format('> Source: [[attachments/%s]]', filename)
        local lines = { heading, pdf_link, '' }

        if images and images.files and #images.files > 0 then
          table.insert(lines, '> Extracted images')
          for idx, image_path in ipairs(images.files) do
            local rel = make_note_relative(image_path, ctx.note_dir)
            table.insert(lines, string.format('![[%s|PDF image %d]]', rel, idx))
          end
          table.insert(lines, '')
        end

        table.insert(lines, parsed.text)
        table.insert(lines, '')

        local block = table.concat(lines, '\n')
        insert_markdown_block(block)
        notify_status(('Parsed %s (%s)'):format(filename, parsed.source or 'legacy'), {
          replace = status,
          timeout = 3000,
          icon = '',
        })
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

