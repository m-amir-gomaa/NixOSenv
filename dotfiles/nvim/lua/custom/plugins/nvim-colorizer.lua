return {
  {
    'norcalli/nvim-colorizer.lua',
    config = function()
      require('colorizer').setup({
        '*', -- Highlight ALL files (includes Lua by default)
        css = { rgb_fn = true },
        html = { names = false },
        '!vim', -- Only exclude vim help files
        '!comment',
        '!markdown',
      }, {
        mode = 'background', -- Background coloring
        RGB = true,
        RRGGBB = true,
        names = false,
        RRGGBBAA = true,
        rgb_fn = true,
        hsl_fn = true,
      })
    end,
  },
}
