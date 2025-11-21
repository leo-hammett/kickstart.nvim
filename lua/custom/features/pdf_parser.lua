local M = {}

local notify = vim.notify
local uv = vim.uv or vim.loop

local function notify_status(message, opts)
  opts = opts or {}
  opts.title = opts.title or 'Obsidian Document Parser'
  opts.timeout = opts.timeout or 0
  opts.render = opts.render or 'minimal'
  return notify(message, opts.level or vim.log.levels.INFO, opts)
end

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

local function system_capture(cmd, opts)
  opts = opts or {}
  if vim.system then
    local sys_opts = { text = true }
    if opts.cwd then
      sys_opts.cwd = opts.cwd
    end
    local result = vim.system(cmd, sys_opts):wait()
    if result.code ~= 0 then
      local stderr = vim.trim(result.stderr or '')
      return nil, stderr ~= '' and stderr or ('command failed: ' .. table.concat(cmd, ' '))
    end
    return result.stdout or '', nil
  end
  
  -- Fallback for older neovim
  local cmd_str = table.concat(cmd, ' ')
  if opts.cwd then
    cmd_str = string.format('cd %s && %s', vim.fn.shellescape(opts.cwd), cmd_str)
  end
  local output = vim.fn.system(cmd_str)
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

local function rewrite_inline_embeds(markdown, base_dir)
  if markdown == nil or markdown == '' then
    return markdown
  end

  local function is_external(path)
    return path:match('^%a[%w+.-]*:') or path:match('^//')
  end

  return markdown:gsub('!%[(.-)%]%((.-)%)', function(label, path)
    if is_external(path) or path:sub(1, 1) == '#' then
      return string.format('![%s](%s)', label, path)
    end

    local cleaned = path
      :gsub('^%./', '')
      :gsub('^attachments/', '')
      :gsub('^/', '')
      :gsub('\\%(', '(')
      :gsub('\\%)', ')')

    local target = string.format('%s/%s', base_dir, cleaned):gsub('//+', '/')
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

local function convert_with_native_pptx(pptx_path, ctx)
  if vim.fn.executable('unzip') == 0 then
    return nil, 'unzip executable not found'
  end

  local temp_dir = vim.fn.tempname() .. '_pptx'
  vim.fn.mkdir(temp_dir, 'p')

  local cmd = { 'unzip', '-q', pptx_path, '-d', temp_dir }
  local _, err = system_capture(cmd)
  if err then
    vim.fn.delete(temp_dir, 'rf')
    return nil, 'Failed to unzip PPTX: ' .. tostring(err)
  end

  local function read_content(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    return content
  end

  local slides_dir = temp_dir .. '/ppt/slides'
  local slides = vim.fn.globpath(slides_dir, 'slide*.xml', false, true)
  
  if type(slides) ~= 'table' then
    slides = {} 
  end
  
  table.sort(slides, function(a, b)
    local num_a = tonumber(a:match('slide(%d+)%.xml$') or 0)
    local num_b = tonumber(b:match('slide(%d+)%.xml$') or 0)
    return num_a < num_b
  end)

  local output_lines = {}
  local pptx_stem = vim.fn.fnamemodify(pptx_path, ':t:r')

  for _, slide_path in ipairs(slides) do
    local slide_filename = vim.fn.fnamemodify(slide_path, ':t')
    local slide_num = slide_filename:match('slide(%d+)%.xml')
    
    table.insert(output_lines, string.format('### Slide %s', slide_num))

    -- Parse Rels
    local rels_path = string.format('%s/_rels/%s.rels', slides_dir, slide_filename)
    local rels_content = read_content(rels_path) or ''
    local image_map = {}
    
    for id, target in rels_content:gmatch('Id="(.-)".-Target="(.-)"') do
      if target:match('image') or target:match('media') then
         image_map[id] = target
      end
    end

    local slide_content = read_content(slide_path) or ''
    
    -- Extract Images
    local seen_images = {}
    for embed_id in slide_content:gmatch('r:embed="(.-)"') do
       local target = image_map[embed_id]
       if target and not seen_images[target] then
          seen_images[target] = true
          
          local image_name = vim.fn.fnamemodify(target, ':t')
          local dest_dir = string.format('%s/%s_media', ctx.attachments_dir, pptx_stem)
          vim.fn.mkdir(dest_dir, 'p')
          
          local dest_path = string.format('%s/%s', dest_dir, image_name)
          
          local media_name = target:match('media[/\\](.+)')
          if not media_name then
            media_name = target:match('(.+)')
          end
          
          local real_source_path = temp_dir .. '/ppt/media/' .. media_name
          
          local ok_copy = false
          if uv.fs_stat and uv.fs_stat(real_source_path) then
             if uv.fs_copyfile then
               ok_copy = uv.fs_copyfile(real_source_path, dest_path)
             else
               vim.fn.system({'cp', real_source_path, dest_path})
               ok_copy = true
             end
          end
          
          if ok_copy then
             local rel_path = make_note_relative(dest_path, ctx.note_dir)
             table.insert(output_lines, string.format('![[%s]]', rel_path))
          end
       end
    end

    -- Extract Text - improved logic to avoid leaking XML tags
    local cursor = 1
    while true do
      -- Find paragraph start <a:p>
      local s, e = slide_content:find('<a:p>', cursor, true)
      if not s then 
        -- Try with attributes if simple tag not found
        s, e = slide_content:find('<a:p ', cursor, true)
      end
      if not s then break end
      
      -- Find paragraph end </a:p>
      local cs, ce = slide_content:find('</a:p>', e, true)
      if not cs then break end
      
      local p_content = slide_content:sub(e, cs-1)
      local p_text = ""
      
      -- Detect if this is a bullet point
      -- <a:pPr ... lvl="1"> indicates indentation level
      local bullet_level = 0
      local pr_s, pr_e = p_content:find('<a:pPr.-lvl="(%d+)"')
      if pr_s then
        bullet_level = tonumber(p_content:match('lvl="(%d+)"', pr_s)) or 0
      else
        -- Check if any pPr exists, might be level 0 bullet
        if p_content:find('<a:pPr') then
             -- Sometimes pPr exists but no lvl means level 0
        end
      end

      -- Extract text from run text elements: <a:t>...</a:t>
      for text in p_content:gmatch('<a:t[^>]*>(.-)</a:t>') do
         p_text = p_text .. text
      end
      
      -- Decode XML entities
      p_text = p_text:gsub('&lt;', '<')
        :gsub('&gt;', '>')
        :gsub('&amp;', '&')
        :gsub('&quot;', '"')
        :gsub('&apos;', "'")
      
      p_text = vim.trim(p_text)
      if p_text ~= "" then
         local prefix = ""
         if bullet_level > 0 then
            prefix = string.rep("  ", bullet_level) .. "- "
         elseif p_content:find('<a:bu') then 
            -- bullet defined explicitly
            prefix = "- "
         end
         
         table.insert(output_lines, prefix .. p_text)
      end
      
      cursor = ce + 1
    end
    
    table.insert(output_lines, "")
  end

  vim.fn.delete(temp_dir, 'rf')

  return {
    text = table.concat(output_lines, '\n'),
    inline_images = true,
    source = 'native_pptx',
  }, nil
end

local function parser_output(content)
  local cleaned = strip_repeating_lines(content)
  local markdown = normalize_markdown(cleaned)
  if markdown == '' then
    markdown = '_No text extracted_'
  end
  return markdown
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

  return {
    text = parser_output(output),
    inline_images = false,
    source = 'legacy',
  }, nil
end

local function convert_document_to_markdown(path, ctx)
  local ext = vim.fn.fnamemodify(path, ':e'):lower()
  
  if ext == 'pptx' then
    return convert_with_native_pptx(path, ctx)
  end
  
  -- Assume PDF
  local mode = parser_mode()
  if mode ~= 'legacy' then
    if mode == 'marker' then
      return convert_with_marker(path, ctx)
    end
    if marker_available() then
      local result, err = convert_with_marker(path, ctx)
      if result then
        return result, nil
      end
      notify('Marker parse failed, falling back to legacy parser: ' .. tostring(err), vim.log.levels.WARN)
    end
  end
  return convert_with_legacy(path)
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

local function copy_into_attachments(file_path, attachments_dir)
  local filename = vim.fn.fnamemodify(file_path, ':t')
  local target = string.format('%s/%s', attachments_dir, filename)
  if uv and uv.fs_stat and uv.fs_stat(target) then
    target = make_unique_path(target)
  end

  local ok, err
  if uv and uv.fs_copyfile then
    ok, err = uv.fs_copyfile(file_path, target)
  else
    ok = vim.fn.system({ 'cp', file_path, target })
    err = vim.v.shell_error ~= 0 and ok or nil
    ok = vim.v.shell_error == 0
  end

  if not ok then
    return nil, err or 'Failed to copy file'
  end
  return target, nil
end

local function image_dir_for(pdf_path, ctx)
  local stem = vim.fn.fnamemodify(pdf_path, ':t:r')
  return string.format('%s/%s_images', ctx.attachments_dir, stem)
end

local function extract_pdf_images(pdf_path, ctx)
  if vim.g.custom_pdf_embed_images == false then
    return nil, 'disabled'
  end

  local base_cmd, err = image_extractor_command()
  if not base_cmd then
    return nil, err
  end

  local images_dir = image_dir_for(pdf_path, ctx)
  vim.fn.mkdir(images_dir, 'p')

  local existing = vim.fn.globpath(images_dir, '*.png', false, true)
  if #existing > 0 then
    return { dir = images_dir, files = existing }, nil
  end

  local prefix = string.format('%s/%s', images_dir, vim.fn.fnamemodify(pdf_path, ':t:r'))
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
  return { dir = images_dir, files = files }, nil
end

local function insert_markdown_block(block)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.split(block, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(0, row, row, true, lines)
end

local function add_document_to_buffer(file_path, ctx)
  local filename = vim.fn.fnamemodify(file_path, ':t')
  local ext = vim.fn.fnamemodify(file_path, ':e'):lower()
  
  local status = notify_status(('Parsing %s ...'):format(filename), { icon = '', timeout = 0 })

  local parsed, err = convert_document_to_markdown(file_path, ctx)
  if not parsed then
    notify_status(('Failed to parse %s'):format(filename), {
      replace = status,
      level = vim.log.levels.ERROR,
      timeout = 5000,
    })
    notify('Parse failed: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local images
  if not parsed.inline_images and ext == 'pdf' then
    images, err = extract_pdf_images(file_path, ctx)
    if err and err ~= 'disabled' and err ~= 'No images detected' then
      notify('PDF image extraction: ' .. err, vim.log.levels.WARN)
    end
  end

  local heading = string.format('## Notes from %s', vim.fn.fnamemodify(filename, ':r'))
  local doc_link = string.format('> Source: [[attachments/%s]]', filename)
  local lines = { heading, doc_link, '' }

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

  insert_markdown_block(table.concat(lines, '\n'))
  notify_status(('Parsed %s (%s)'):format(filename, parsed.source or 'legacy'), {
    replace = status,
    timeout = 3000,
    icon = '',
  })
end

local function prompt_for_file()
  local input = vim.fn.input('Document path (pdf/pptx): ', '', 'file')
  if input == '' then
    return nil
  end
  local expanded = vim.fn.fnamemodify(vim.fn.expand(input), ':p')
  if vim.fn.filereadable(expanded) == 0 then
    notify('File not found: ' .. expanded, vim.log.levels.WARN)
    return nil
  end
  return expanded
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

local function add_new_document()
  local ctx, ctx_err = get_markdown_context()
  if not ctx then
    notify(ctx_err, vim.log.levels.WARN)
    return
  end
  local file_path = prompt_for_file()
  if not file_path then
    return
  end
  local ext = vim.fn.fnamemodify(file_path, ':e'):lower()
  if ext ~= 'pdf' and ext ~= 'pptx' then
    notify('Selected file is not a PDF or PPTX', vim.log.levels.WARN)
    return
  end
  
  local stored_file, err = copy_into_attachments(file_path, ctx.attachments_dir)
  if not stored_file then
    notify('Failed to copy file: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  add_document_to_buffer(stored_file, ctx)
end

local function parse_existing_document()
  local ctx, ctx_err = get_markdown_context()
  if not ctx then
    notify(ctx_err, vim.log.levels.WARN)
    return
  end
  
  local pdfs = vim.fn.globpath(ctx.attachments_dir, '*.pdf', false, true)
  local pptxs = vim.fn.globpath(ctx.attachments_dir, '*.pptx', false, true)
  local files = vim.list_extend(pdfs, pptxs)
  
  if vim.tbl_isempty(files) then
    notify('No PDF/PPTX attachments found', vim.log.levels.INFO)
    return
  end
  
  vim.ui.select(files, {
    prompt = 'Attachments',
    format_item = function(item)
      return vim.fn.fnamemodify(item, ':t')
    end,
  }, function(choice)
    if not choice then
      return
    end
    add_document_to_buffer(choice, ctx)
  end)
end

local function add_new_pdf()
  local ctx, ctx_err = get_markdown_context()
  if not ctx then
    notify(ctx_err, vim.log.levels.WARN)
    return
  end
  local input = vim.fn.input('PDF path: ', '', 'file')
  if input == '' then return end
  local expanded = vim.fn.fnamemodify(vim.fn.expand(input), ':p')
  if vim.fn.filereadable(expanded) == 0 then
    notify('PDF not found: ' .. expanded, vim.log.levels.WARN)
    return
  end
  local stored_pdf, err = copy_into_attachments(expanded, ctx.attachments_dir)
  if not stored_pdf then
    notify('Failed to copy PDF: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  add_document_to_buffer(stored_pdf, ctx)
end

local function parse_existing_pdf()
  local ctx, ctx_err = get_markdown_context()
  if not ctx then
    notify(ctx_err, vim.log.levels.WARN)
    return
  end
  local pdfs = vim.fn.globpath(ctx.attachments_dir, '*.pdf', false, true)
  if vim.tbl_isempty(pdfs) then
    notify('No PDF attachments found', vim.log.levels.INFO)
    return
  end
  vim.ui.select(pdfs, {
    prompt = 'PDF Attachments',
    format_item = function(item) return vim.fn.fnamemodify(item, ':t') end,
  }, function(choice)
    if choice then add_document_to_buffer(choice, ctx) end
  end)
end

function M.setup()
  local augroup = vim.api.nvim_create_augroup('custom_pdf_parser', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    group = augroup,
    callback = function()
      -- General document commands (PDF & PPTX)
      vim.keymap.set('n', '<leader>da', add_new_document, { buffer = true, desc = 'Add & parse Document (PDF/PPTX)' })
      vim.keymap.set('n', '<leader>dp', parse_existing_document, { buffer = true, desc = 'Parse attached Document (PDF/PPTX)' })
      
      -- Legacy/Specific PDF commands (Restored)
      vim.keymap.set('n', '<leader>pa', add_new_pdf, { buffer = true, desc = 'Add & parse PDF' })
      vim.keymap.set('n', '<leader>pp', parse_existing_pdf, { buffer = true, desc = 'Parse attached PDF' })
    end,
  })
end

return M
