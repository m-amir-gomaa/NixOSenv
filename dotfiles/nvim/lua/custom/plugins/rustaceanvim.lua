return {
  'mrcjkb/rustaceanvim',
  version = '^7', -- Recommended
  lazy = false, -- This plugin is already lazy
}
-- I'll add that one later when I learn more about Rust
-- {
--   'saecki/crates.nvim',
--   ft = { 'toml' },
--   config = function()
--     require('crates').setup {
--       completion = {
--         cmp = {
--           enabled = true,
--         },
--       },
--     }
--     require('cmp').setup.buffer {
--       sources = { { name = 'crates' } },
--     }
--   end,
-- },
