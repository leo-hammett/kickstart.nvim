local M = {}

function M.setup()
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

        -- 1. Determine directories
        local note_dir = vim.fn.fnamemodify(note, ':h')
        local attachments_dir = note_dir .. '/attachments'
        vim.fn.mkdir(attachments_dir, 'p')

        -- 2. Ask for user input (Filename)
        local default_name = os.date 'img-%Y%m%d-%H%M%S'
        local input_name = vim.fn.input('Image name: ', default_name)
        if input_name == '' then return end
        
        if not input_name:match('%.%w+$') then
           input_name = input_name .. '.png'
        end

        local target_path = string.format('%s/%s', attachments_dir, input_name)

        -- 3. Save Image from Clipboard (Native implementation)
        local function save_image(path)
            -- macOS
            if vim.fn.has('mac') == 1 then
                local ret = vim.fn.system({'pngpaste', path})
                if vim.v.shell_error ~= 0 then
                    return false, "pngpaste failed (is it installed? brew install pngpaste): " .. ret
                end
                return true
            -- Linux (X11)
            elseif vim.fn.has('unix') == 1 and vim.env.WAYLAND_DISPLAY == nil then
                 local ret = vim.fn.system({'xclip', '-selection', 'clipboard', '-t', 'image/png', '-o', '>', path}) -- xclip syntax is tricky with redirection in vim.system
                 -- Easier to use shell redirection
                 local cmd = string.format("xclip -selection clipboard -t image/png -o > %s", vim.fn.shellescape(path))
                 local out = vim.fn.system(cmd)
                 if vim.v.shell_error ~= 0 then
                     return false, "xclip failed: " .. out
                 end
                 return true
            -- Linux (Wayland)
            elseif vim.env.WAYLAND_DISPLAY then
                 local cmd = string.format("wl-paste -t image/png > %s", vim.fn.shellescape(path))
                 local out = vim.fn.system(cmd)
                 if vim.v.shell_error ~= 0 then
                     return false, "wl-paste failed: " .. out
                 end
                 return true
            else
                return false, "Unsupported OS or clipboard tool missing"
            end
        end

        local saved, err = save_image(target_path)
        if not saved then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end

        -- 4. Insert Markdown Link
        local link = string.format('![[%s]]', input_name)
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_text(0, row-1, col, row-1, col, {link})
        
        vim.notify('Saved image to ' .. input_name, vim.log.levels.INFO)
        
      end, { buffer = true, desc = 'Paste image from clipboard' })
    end,
  })
end

return M
