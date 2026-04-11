-- ~/.config/nvim/lua/plugins/harpoon.lua
return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2', -- Use latest
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'

    harpoon:setup {
      settings = {
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
          key = function() return vim.loop.cwd() end,
        },
      },
    }
    harpoon:extend {
      UI_CREATE = function(cx)
        vim.keymap.set('n', '<C-v>', function() harpoon.ui:select_menu_item { vsplit = true } end, { buffer = cx.bufnr })

        vim.keymap.set('n', '<C-x>', function() harpoon.ui:select_menu_item { split = true } end, { buffer = cx.bufnr })

        vim.keymap.set('n', '<C-t>', function() harpoon.ui:select_menu_item { tabedit = true } end, { buffer = cx.bufnr })
      end,
    }
    local harpoon_extensions = require 'harpoon.extensions'
    harpoon:extend(harpoon_extensions.builtins.highlight_current_file())
    -- -- basic telescope configuration
    -- local conf = require('telescope.config').values
    -- local function toggle_telescope(harpoon_files)
    --   local file_paths = {}
    --   for _, item in ipairs(harpoon_files.items) do
    --     table.insert(file_paths, item.value)
    --   end
    --
    --   require('telescope.pickers')
    --     .new({}, {
    --       prompt_title = 'Harpoon',
    --       finder = require('telescope.finders').new_table {
    --         results = file_paths,
    --       },
    --       previewer = conf.file_previewer {},
    --       sorter = conf.generic_sorter {},
    --     })
    --     :find()
    -- end
    --
    -- vim.keymap.set('n', '<C-e>', function() toggle_telescope(harpoon:list()) end, { desc = 'Open harpoon window' })
    -- Add/Remove files
    vim.keymap.set('n', '<leader>a', function() harpoon:list():add() end, { desc = 'Harpoon: Add file' })
    vim.keymap.set('n', '<leader>A', function() harpoon:list():remove() end, { desc = 'Harpoon: Remove file' })

    -- Toggle quick menu
    vim.keymap.set('n', '<C-e>', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = 'Harpoon: Toggle menu' })

    -- Navigate files (home row keys - easy reach!)
    vim.keymap.set('n', '<leader>1', function() harpoon:list():select(1) end, { desc = 'Harpoon: File 1' })
    vim.keymap.set('n', '<leader>2', function() harpoon:list():select(2) end, { desc = 'Harpoon: File 2' })
    vim.keymap.set('n', '<leader>3', function() harpoon:list():select(3) end, { desc = 'Harpoon: File 3' })
    vim.keymap.set('n', '<leader>4', function() harpoon:list():select(4) end, { desc = 'Harpoon: File 4' })

    vim.keymap.set('n', '<leader><C-q>', function() harpoon:list():replace_at(1) end, { desc = 'Harpoon: File 1' })
    vim.keymap.set('n', '<leader><C-w>', function() harpoon:list():replace_at(2) end, { desc = 'Harpoon: File 2' })
    vim.keymap.set('n', '<leader><C-e>', function() harpoon:list():replace_at(3) end, { desc = 'Harpoon: File 3' })
    vim.keymap.set('n', '<leader><C-r>', function() harpoon:list():replace_at(4) end, { desc = 'Harpoon: File 4' })

    -- Toggle previous & next buffers stored within Harpoon list
    vim.keymap.set('n', '<leader>p', function() harpoon:list():prev() end, { desc = 'Harpoon: Previous' })
    vim.keymap.set('n', '<leader>n', function() harpoon:list():next() end, { desc = 'Harpoon: Next' })
  end,
}
