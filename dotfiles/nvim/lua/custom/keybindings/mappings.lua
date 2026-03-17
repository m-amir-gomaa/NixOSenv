-- add yours here
local map = vim.keymap.set

-- Basic & frequently used
map('n', ';', ':', { desc = 'CMD enter command mode' })
map({ 'n', 'v' }, ';', ':', { noremap = true })

map('i', 'jk', '<Esc>', { desc = 'Easy escape' })

-- yank/copy to end of line
map('n', 'Y', 'y$', { desc = '[P]Yank to end of line' })

-- Tab navigation
map('n', 'gt', ':tabnext<CR>', { silent = true })
map('n', 'gT', ':tabprev<CR>', { silent = true })
map('n', 't', ':tabnew<CR>', { silent = true })

-- Buffer navigation
map('n', 'bn', ':bn<CR>', { silent = true })
map('n', 'bp', ':bp<CR>', { silent = true })
map('n', 'b^', ':b#<CR>', { silent = true })
map('n', 'bk', ':bd<CR>', { silent = true })

-- Move lines up and down in visual mode
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = '[P]Move line down in visual mode' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = '[P]Move line up in visual mode' })

-- When you do joins with J it will keep your cursor at the beginning instead of at the end
map('n', 'J', 'mzJ`z')

-- When searching for stuff, search results show in the middle
map('n', 'n', 'nzzzv')
map('n', 'N', 'Nzzzv')

-- Clear search highlight
map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Marks keep coming back even after deleting them, this deletes them all
-- This deletes all marks in the current buffer, including lowercase, uppercase, and numbered marks
-- Fix should be applied on April 2024
-- https://github.com/chentoast/marks.nvim/issues/13
map('n', '<leader>mZ', function()
  -- Delete all marks in the current buffer
  vim.cmd 'delmarks!'
  print 'All marks deleted.'
end, { desc = '[P]Delete all marks' })

-- In visual mode, after going to the end of the line, come back 1 character
map('v', 'gl', '$h', { desc = '[P]Go to the end of the line' })

-- Window / split navigation
-- map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
-- map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Plugin toggles / utils
map('n', '<leader><leader>u', ':UndotreeToggle<CR>', { silent = true })
map('n', '<leader>vs', ':vsplit ~/.vim/hotkeys<CR>', { silent = true })

-- rustaceanvim keybindings (buffer-local)
local bufnr = vim.api.nvim_get_current_buf()

map('n', '<leader>cr', function() vim.cmd.RustLsp 'codeAction' end, { silent = true, buffer = bufnr, desc = 'Rust code action' })

map('n', 'K', function() vim.cmd.RustLsp { 'hover', 'actions' } end, { silent = true, buffer = bufnr, desc = 'Rust hover actions' })

-- Nvim DAP
map('n', '<Leader>dl', "<cmd>lua require'dap'.step_into()<CR>", { desc = 'Debugger step into' })
map('n', '<Leader>dj', "<cmd>lua require'dap'.step_over()<CR>", { desc = 'Debugger step over' })
map('n', '<Leader>dk', "<cmd>lua require'dap'.step_out()<CR>", { desc = 'Debugger step out' })
map('n', '<Leader>dc', "<cmd>lua require'dap'.continue()<CR>", { desc = 'Debugger continue' })
map('n', '<Leader>db', "<cmd>lua require'dap'.toggle_breakpoint()<CR>", { desc = 'Debugger toggle breakpoint' })
map('n', '<Leader>dd', "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", { desc = 'Debugger conditional breakpoint' })
map('n', '<Leader>de', "<cmd>lua require'dap'.terminate()<CR>", { desc = 'Debugger reset' })
map('n', '<Leader>dr', "<cmd>lua require'dap'.run_last()<CR>", { desc = 'Debugger run last' })

-- rustaceanvim testables
map('n', '<Leader>dt', "<cmd>lua vim.cmd('RustLsp testables')<CR>", { desc = 'Rust testables' })

-- -- Markdown preview settings
-- vim.g.mkdp_filetypes = { 'markdown' }
-- vim.g.mkdp_auto_start = 1
-- vim.g.mkdp_auto_close = 0
-- vim.g.mkdp_open_to_the_world = 0
-- vim.g.mkdp_browser = 'firefox'

vim.opt.updatetime = 50

vim.keymap.set('n', '<leader>x', function()
  local line = vim.api.nvim_get_current_line()
  -- Toggle between [ ] (unchecked) and [x] (checked) for task completion
  if line:match '%[ %]' then
    line = line:gsub('%[ %]', '[x]')
  elseif line:match '%[x%]' then
    line = line:gsub('%[x%]', '[ ]')
  else
    -- If no checkbox exists, add one at the start (with spaces preserved)
    local indent = line:match '^(%s*)'
    line = indent .. '- [x] ' .. line:gsub('^%s*', '')
  end
  vim.api.nvim_set_current_line(line)
end, { desc = 'Toggle markdown task completion' })
