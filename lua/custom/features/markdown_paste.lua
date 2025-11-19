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
    end,
  })
end

return M
