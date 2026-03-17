return {
  'HakonHarnes/img-clip.nvim',
  event = 'VeryLazy',
  opts = {
    -- add options here
    -- or leave it empty to use the default settings
  },
  keys = {
    -- suggested keymap
    { '<leader>p', '<cmd>PasteImage<cr>', desc = 'Paste image from system clipboard' },
  },
  -- In your keymaps.lua or plugins file
  vim.keymap.set('n', '<leader>si', function()
    Snacks.picker.files {
      ft = { 'jpg', 'jpeg', 'png', 'webp' },
      confirm = function(self, item, _)
        self:close()
        require('img-clip').paste_image({}, './' .. item.file)
      end,
    }
  end, { desc = 'Paste Image' }),
}
