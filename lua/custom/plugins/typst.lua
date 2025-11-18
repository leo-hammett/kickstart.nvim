return {
  -- Typst syntax highlighting
  {
    'kaarmu/typst.vim',
    ft = 'typst',
    config = function()
      -- Store watch job IDs per buffer
      local watch_jobs = {}

      -- Typst filetype settings
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'typst',
        callback = function()
          vim.opt_local.tabstop = 2
          vim.opt_local.shiftwidth = 2
          vim.opt_local.expandtab = true
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true

          local bufnr = vim.api.nvim_get_current_buf()

          -- Compile/export PDF keymaps
          vim.keymap.set('n', '<leader>tc', '<cmd>!typst compile %<CR>', { buffer = true, desc = 'Typst [C]ompile PDF' })

          -- Enhanced watch mode with background job
          vim.keymap.set('n', '<leader>tw', function()
            local file = vim.fn.expand '%'
            if watch_jobs[bufnr] then
              vim.fn.jobstop(watch_jobs[bufnr])
              watch_jobs[bufnr] = nil
              vim.notify('Stopped Typst watch mode', vim.log.levels.INFO)
            else
              watch_jobs[bufnr] = vim.fn.jobstart({ 'typst', 'watch', file }, {
                on_exit = function()
                  watch_jobs[bufnr] = nil
                end,
              })
              vim.notify('Started Typst watch mode', vim.log.levels.INFO)
            end
          end, { buffer = true, desc = 'Typst [W]atch toggle' })

          -- Open PDF viewer
          vim.keymap.set('n', '<leader>to', function()
            local pdf = vim.fn.expand '%:r' .. '.pdf'
            if vim.fn.filereadable(pdf) == 1 then
              if vim.fn.has 'mac' == 1 then
                vim.cmd('silent !open ' .. vim.fn.shellescape(pdf))
              elseif vim.fn.has 'unix' == 1 then
                vim.cmd('silent !xdg-open ' .. vim.fn.shellescape(pdf))
              elseif vim.fn.has 'win32' == 1 then
                vim.cmd('silent !start ' .. vim.fn.shellescape(pdf))
              end
              vim.notify('Opened PDF: ' .. pdf, vim.log.levels.INFO)
            else
              vim.notify('PDF not found. Run <leader>tc or <leader>tw first', vim.log.levels.WARN)
            end
          end, { buffer = true, desc = 'Typst [O]pen PDF' })

          -- Compile and open in one command
          vim.keymap.set('n', '<leader>tp', function()
            local file = vim.fn.expand '%'
            local pdf = vim.fn.expand '%:r' .. '.pdf'
            vim.fn.jobstart({ 'typst', 'compile', file }, {
              on_exit = function(_, exit_code)
                if exit_code == 0 then
                  if vim.fn.has 'mac' == 1 then
                    vim.cmd('silent !open ' .. vim.fn.shellescape(pdf))
                  elseif vim.fn.has 'unix' == 1 then
                    vim.cmd('silent !xdg-open ' .. vim.fn.shellescape(pdf))
                  elseif vim.fn.has 'win32' == 1 then
                    vim.cmd('silent !start ' .. vim.fn.shellescape(pdf))
                  end
                  vim.notify('Compiled and opened PDF', vim.log.levels.INFO)
                else
                  vim.notify('Typst compilation failed', vim.log.levels.ERROR)
                end
              end,
            })
          end, { buffer = true, desc = 'Typst compile and [P]review' })

          -- Auto-compile on save (optional, disabled by default)
          vim.keymap.set('n', '<leader>ta', function()
            local augroup = vim.api.nvim_create_augroup('TypstAutoCompile_' .. bufnr, { clear = true })
            if vim.b.typst_auto_compile then
              vim.api.nvim_clear_autocmds { group = augroup }
              vim.b.typst_auto_compile = false
              vim.notify('Disabled auto-compile on save', vim.log.levels.INFO)
            else
              vim.api.nvim_create_autocmd('BufWritePost', {
                group = augroup,
                buffer = bufnr,
                callback = function()
                  vim.fn.jobstart { 'typst', 'compile', vim.fn.expand '%' }
                end,
              })
              vim.b.typst_auto_compile = true
              vim.notify('Enabled auto-compile on save', vim.log.levels.INFO)
            end
          end, { buffer = true, desc = 'Typst toggle [A]uto-compile' })

          -- Math mode helpers (insert mode shortcuts)
          vim.keymap.set('i', '<C-l>m', '#math.rad($0)', { buffer = true, desc = 'Insert inline math' })
          vim.keymap.set('i', '<C-l>M', '#block($0)', { buffer = true, desc = 'Insert block' })
        end,
      })

      -- Clean up watch jobs when buffer is deleted
      vim.api.nvim_create_autocmd('BufDelete', {
        pattern = '*.typ',
        callback = function(ev)
          if watch_jobs[ev.buf] then
            vim.fn.jobstop(watch_jobs[ev.buf])
            watch_jobs[ev.buf] = nil
          end
        end,
      })
    end,
  },
}

