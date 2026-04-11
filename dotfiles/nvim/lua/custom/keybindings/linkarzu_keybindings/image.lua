-- ############################################################################
--                             Image section
-- ############################################################################

-- There's confusion with the pasting image keymaps. I have 2 keymaps:
-- One pastes the image in the same dir as the file, using the img-clip plugin settings
-- One pastes the image in the "assets" dir, useful for my blog or re-using images
-- lamw26wmal
--
-- HACK: View and paste images in Neovim like in Obsidian
-- https://youtu.be/0O3kqGwNzTI
--
-- Paste images
-- I tried using <C-v> but duh, that's used for visual block mode
vim.keymap.set({ 'n', 'i' }, '<M-a>', function()
  local pasted_image = require('img-clip').paste_image()
  if pasted_image then
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd 'silent! update'
    -- Get the current line
    local line = vim.api.nvim_get_current_line()
    -- Move cursor to end of line
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], #line })
    -- I reload the file, otherwise I cannot view the image after pasted
    vim.cmd 'edit!'
  end
end, { desc = '[P]Paste image from system clipboard' })
