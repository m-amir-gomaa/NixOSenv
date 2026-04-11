return {
  'folke/snacks.nvim',
  priority = 1000, -- high priority
  lazy = false, -- NEVER lazy-load snacks if using image module
  ---@type snacks.Config
  opts = {
    image = {
      enabled = true,
      doc = {
        inline = false, -- keep this
        float = true, -- fallback popup on cursor if inline glitches
        max_width = 80,
        max_height = 40,
        only_render_image_at_cursor = true, -- if this exists in your version; try true/false
      },
      -- optional: force PNG conversion if formats cause issues
      formats = { 'png', 'jpg', 'jpeg', 'gif', 'webp' },
    },
    -- ... your other enabled modules
  },
  keys = {
    { '<leader>sm', function() Snacks.picker.marks() end, desc = 'Marks' },
  },
}
