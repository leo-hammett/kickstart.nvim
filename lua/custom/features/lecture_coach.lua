local M = {}

local state = {
  busy = false,
}

local defaults = {
  provider = {
    endpoint = 'https://api.openai.com/v1/chat/completions',
    model = 'gpt-4o-mini',
    temperature = 0.3,
    timeout_ms = 20000,
    max_tokens = 480,
  },
  context = {
    before = 80,
    after = 4,
  },
  keymaps = {
    ask = '<leader>q',
    boost = '<leader>Q',
  },
  filetypes = { 'markdown', 'md', 'rmd', 'quarto' },
  prompts = {
    system = table.concat({
      'You are an expert study coach helping a student reason through challenging technical lectures.',
      'You only use the supplied excerpt (material they have already read) to craft a single reflective question.',
      'Respond using strict JSON with keys: question, feedback, reference_hint, expected_answer, difficulty.',
      'reference_hint must cite a concrete phrase, heading, or line from the provided excerpt so the student knows what to re-read.',
      'feedback nudges the student toward resolving the confusion without solving it outright.',
      'Never mention material that happens after the cursor or outside the excerpt.',
    }, ' '),
  },
  profiles = {
    question = {
      id = 'question',
      label = '🧠 Lecture Coach',
      difficulty = 'conceptual probe',
      expected_answer = '4-6 sentences explaining the mechanism in your own words.',
      focus = 'Surface the first gap in understanding before moving on.',
      context_before = 90,
      context_after = 4,
      temperature = 0.25,
      max_tokens = 520,
    },
    boost = {
      id = 'boost',
      label = '⚡ Focus Boost',
      difficulty = 'quick pulse-check',
      expected_answer = '2-3 sentences or bullets.',
      focus = 'Snap attention back to the most recent point.',
      context_before = 40,
      context_after = 2,
      temperature = 0.35,
      max_tokens = 360,
    },
  },
}

local config

local function log(msg, level)
  vim.notify(('Lecture Coach: %s'):format(msg), level or vim.log.levels.INFO)
end

local function merged_opts(user_opts)
  local global = vim.g.lecture_ai_coach or {}
  local opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), global, user_opts or {})
  opts.prompts = opts.prompts or {}
  if type(opts.prompts.system) ~= 'string' or opts.prompts.system == '' then
    opts.prompts.system = defaults.prompts.system
  end
  opts.filetypes = opts.filetypes or defaults.filetypes
  opts.keymaps = opts.keymaps or defaults.keymaps
  opts.context = vim.tbl_deep_extend('force', vim.deepcopy(defaults.context), opts.context or {})
  opts.provider = vim.tbl_deep_extend('force', vim.deepcopy(defaults.provider), opts.provider or {})
  opts.profiles = opts.profiles or {}
  if not opts.profiles.question then
    opts.profiles.question = vim.deepcopy(defaults.profiles.question)
  end
  if not opts.profiles.boost then
    opts.profiles.boost = vim.deepcopy(defaults.profiles.boost)
  end
  return opts
end

local function normalize_path(path)
  if not path or path == '' then
    return '[No Name]'
  end
  local rel = vim.fn.fnamemodify(path, ':.')
  if rel == '' then
    return path
  end
  return rel
end

local function find_heading(bufnr, line_nr)
  for line = line_nr, 1, -1 do
    local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
    local heading = text:match('^#+%s*(.-)%s*$')
    if heading and heading ~= '' then
      return heading, line
    end
  end
  return nil, nil
end

local function section_excerpt(bufnr, heading_line, cursor_line)
  local start_line = heading_line or 1
  if start_line < 1 then
    start_line = 1
  end
  local start_idx = start_line - 1
  local end_idx = math.max(cursor_line, start_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_idx, end_idx, false)
  return table.concat(lines, '\n')
end

local function build_excerpt(bufnr, cursor_line, profile)
  local before = profile.context_before or config.context.before
  local after = profile.context_after or config.context.after
  before = math.max(before or config.context.before, 0)
  after = math.max(after or config.context.after, 0)

  local total = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(cursor_line - before, 1)
  local end_line = math.min(cursor_line + after, total)

  local start_idx = start_line - 1
  local end_idx = end_line

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_idx, end_idx, false)
  local numbered = {}
  for idx, line in ipairs(lines) do
    local line_no = start_line + idx - 1
    numbered[#numbered + 1] = string.format('%4d │ %s', line_no, line)
  end

  return {
    plain = table.concat(lines, '\n'),
    numbered = table.concat(numbered, '\n'),
    start_line = start_line,
    end_line = end_line,
  }
end

local function ensure_supported(bufnr)
  local ft = vim.bo[bufnr].filetype
  for _, allowed in ipairs(config.filetypes) do
    if ft == allowed then
      return true
    end
  end
  return false
end

local function gather_context(profile)
  local bufnr = vim.api.nvim_get_current_buf()
  if not ensure_supported(bufnr) then
    return nil, nil, string.format(
      'Unsupported filetype "%s". Allowed: %s',
      vim.bo[bufnr].filetype,
      table.concat(config.filetypes, ', ')
    )
  end
  if vim.bo[bufnr].buftype ~= '' then
    return nil, nil, 'Lecture coach is disabled for special buffers.'
  end
  if not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
    return nil, nil, 'Current buffer is not writable.'
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local excerpt = build_excerpt(bufnr, cursor_line, profile)
  if excerpt.plain == '' then
    return nil, nil, 'No nearby text to analyze.'
  end

  local heading, heading_line = find_heading(bufnr, cursor_line)
  local meta = {
    bufnr = bufnr,
    cursor_line = cursor_line,
    cursor_col = cursor[2],
    total_lines = vim.api.nvim_buf_line_count(bufnr),
    heading = heading,
    heading_line = heading_line,
    section_excerpt = section_excerpt(bufnr, heading_line, cursor_line),
    file = vim.api.nvim_buf_get_name(bufnr),
  }
  meta.rel_path = normalize_path(meta.file)

  return excerpt, meta, nil
end

local function build_payload(profile, excerpt, meta)
  local prompt = table.concat({
    ('lecture_file: %s'):format(meta.rel_path),
    ('active_heading: %s'):format(meta.heading and string.format('%s (line %d)', meta.heading, meta.heading_line or meta.cursor_line) or 'none'),
    ('cursor_line: %d of %d'):format(meta.cursor_line, meta.total_lines),
    ('focus_goal: %s'):format(profile.focus or 'reinforce understanding'),
    ('difficulty_hint: %s'):format(profile.difficulty or 'baseline'),
    ('expected_answer: %s'):format(profile.expected_answer or 'short reflection'),
    ('excerpt_window: lines %d-%d (text already read)'):format(excerpt.start_line, excerpt.end_line),
    '',
    'Numbered excerpt:',
    excerpt.numbered,
    '',
    'Plain excerpt:',
    excerpt.plain,
    '',
    'Instructions:',
    '- Craft a single question that exposes missing understanding using only this excerpt.',
    '- The question must not rely on content beyond the cursor.',
    '- Provide reference_hint citing a phrase/heading from the excerpt.',
    '- Provide feedback that nudges the student and references what to revisit.',
    '- Respond with strict JSON. Do not wrap it in markdown fences.',
  }, '\n')

  return {
    model = profile.model or config.provider.model,
    temperature = profile.temperature or config.provider.temperature,
    max_tokens = profile.max_tokens or config.provider.max_tokens,
    messages = {
      { role = 'system', content = config.prompts.system },
      { role = 'user', content = prompt },
    },
  }
end

local function ensure_api_key()
  local key = config.provider.api_key or vim.env.OPENAI_API_KEY
  if key and key ~= '' then
    return key
  end
  return nil, 'Missing OPENAI_API_KEY (or set config.provider.api_key).'
end

local function request_completion(payload, callback)
  local api_key, key_err = ensure_api_key()
  if not api_key then
    callback(nil, key_err)
    return
  end
  local ok, body = pcall(vim.json.encode, payload)
  if not ok then
    callback(nil, 'Failed to encode payload: ' .. tostring(body))
    return
  end

  local cmd = {
    'curl',
    '--silent',
    '--show-error',
    '--fail-with-body',
    '--location',
    '-X',
    'POST',
    config.provider.endpoint,
    '-H',
    'Content-Type: application/json',
    '-H',
    'Authorization: Bearer ' .. api_key,
    '--data-binary',
    '@-',
  }

  local opts = {
    stdin = body,
    text = true,
    timeout = config.provider.timeout_ms,
  }

  if vim.system then
    vim.system(cmd, opts, function(result)
      if result.code ~= 0 then
        callback(nil, vim.trim(result.stderr ~= '' and result.stderr or result.stdout))
        return
      end
      local ok_decode, parsed = pcall(vim.json.decode, result.stdout)
      if not ok_decode then
        callback(nil, 'Failed to parse provider response: ' .. tostring(parsed))
        return
      end
      callback(parsed, nil)
    end)
    return
  end

  local output = vim.fn.system(cmd, body)
  if vim.v.shell_error ~= 0 then
    callback(nil, vim.trim(output))
    return
  end
  local ok_decode, parsed = pcall(vim.json.decode, output)
  if not ok_decode then
    callback(nil, 'Failed to parse provider response: ' .. tostring(parsed))
    return
  end
  callback(parsed, nil)
end

local function extract_choice(data)
  if type(data) ~= 'table' then
    return nil, 'Empty response from provider.'
  end
  local choices = data.choices
  if type(choices) ~= 'table' or not choices[1] then
    return nil, 'Provider returned no choices.'
  end
  local message = choices[1].message
  if not message or type(message.content) ~= 'string' then
    return nil, 'Provider response missing content.'
  end
  local content = vim.trim(message.content)
  content = content:gsub('^```json', ''):gsub('^```', '')
  content = content:gsub('```$', '')
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    return nil, 'Unable to decode coach reply as JSON.'
  end
  return decoded, nil
end

local function insert_block(result, profile, meta)
  if type(result) ~= 'table' then
    log('Empty question payload received.', vim.log.levels.WARN)
    return
  end
  local block = { '' }
  local header = string.format('> %s · %s', profile.label or 'Lecture Coach', result.difficulty or profile.difficulty or 'prompt')
  block[#block + 1] = header
  if result.question then
    block[#block + 1] = ('> Q: %s'):format(result.question)
  end
  local expected = result.expected_answer or profile.expected_answer
  if expected and expected ~= '' then
    block[#block + 1] = ('> Aim for: %s'):format(expected)
  end
  if result.reference_hint and result.reference_hint ~= '' then
    block[#block + 1] = ('> Hint: %s'):format(result.reference_hint)
  elseif meta.heading then
    block[#block + 1] = ('> Hint: revisit "%s"'):format(meta.heading)
  end
  if result.feedback and result.feedback ~= '' then
    block[#block + 1] = ('> Coach: %s'):format(result.feedback)
  end
  block[#block + 1] = ''
  block[#block + 1] = '- [ ] Answer:'
  local answer_index = #block
  block[#block + 1] = ''

  local insert_row = meta.cursor_line
  vim.api.nvim_buf_set_lines(meta.bufnr, insert_row, insert_row, true, block)
  vim.api.nvim_win_set_cursor(0, { insert_row + answer_index - 1, 12 })
end

function M.run(mode)
  if state.busy then
    log('Already generating a prompt. Please wait...', vim.log.levels.WARN)
    return
  end

  local profile = config.profiles[mode] or config.profiles.question
  local excerpt, meta, err = gather_context(profile)
  if not excerpt then
    log(err or 'Unable to collect lecture context.', vim.log.levels.WARN)
    return
  end

  state.busy = true
  log('Coach is reviewing the lecture context...')

  local payload = build_payload(profile, excerpt, meta)
  request_completion(payload, function(data, request_err)
    vim.schedule(function()
      state.busy = false
      if request_err then
        log(request_err, vim.log.levels.ERROR)
        return
      end
      local parsed, decode_err = extract_choice(data)
      if not parsed then
        log(decode_err or 'No response from coach.', vim.log.levels.ERROR)
        return
      end
      insert_block(parsed, profile, meta)
      log('Inserted a reflection prompt near line ' .. meta.cursor_line .. '.')
    end)
  end)
end

function M.setup(user_opts)
  if config then
    return
  end
  config = merged_opts(user_opts)

  -- Register simple global commands
  vim.api.nvim_create_user_command('LectureCoachAsk', function() M.run('question') end, { desc = 'Lecture Coach: Ask' })
  vim.api.nvim_create_user_command('LectureCoachBoost', function() M.run('boost') end, { desc = 'Lecture Coach: Boost' })

  -- Register keymaps globally, but check filetype inside execution
  -- This avoids "attach" complexity entirely
  if config.keymaps.ask and config.keymaps.ask ~= '' then
    vim.keymap.set('n', config.keymaps.ask, function()
      local ft = vim.bo.filetype
      if vim.tbl_contains(config.filetypes, ft) then
        M.run('question')
      else
        vim.notify('Lecture Coach only works in Markdown-like files', vim.log.levels.WARN)
      end
    end, { desc = 'Lecture coach question' })
  end

  if config.keymaps.boost and config.keymaps.boost ~= '' then
    vim.keymap.set('n', config.keymaps.boost, function()
      local ft = vim.bo.filetype
      if vim.tbl_contains(config.filetypes, ft) then
        M.run('boost')
      else
        vim.notify('Lecture Coach only works in Markdown-like files', vim.log.levels.WARN)
      end
    end, { desc = 'Lecture focus boost' })
  end
end

return M
