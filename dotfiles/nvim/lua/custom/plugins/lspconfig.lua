return {
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Useful status updates for LSP.
    { 'j-hui/fidget.nvim', opts = {} },

    -- allows extra capabilities provided by blink.cmp
    'saghen/blink.cmp',
  },
  config = function()
    -- Brief aside: **What is LSP?**
    --
    -- LSP stands for Language Server Protocol. It's a protocol that helps editors
    -- and language tooling communicate in a standardized fashion.
    --
    -- In general, you have a "server" which is some tool built to understand a particular
    -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
    -- are standalone processes that communicate with Neovim.
    --
    -- LSP server binaries are now managed by Nix (via Home Manager) in `nvim.nix`.
    -- This configuration simply sets up the connection to those existing binaries.

    --  This function gets run when an LSP attaches to a particular buffer.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        local tel = require 'telescope.builtin'
        map('gd', tel.lsp_definitions, '[G]oto [D]efinition')
        map('gr', tel.lsp_references, '[G]oto [R]eferences')
        map('gI', tel.lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>D', tel.lsp_type_definitions, 'Type [D]efinition')
        map('<leader>ds', tel.lsp_document_symbols, '[D]ocument [S]ymbols')
        map('<leader>ws', tel.lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)

    -- Enable the following language servers
    -- Feel free to add/remove any LSPs that you want here.
    -- binaries must be installed via Nix/Home Manager!
    local servers = {
      yamlls = {},
      nil_ls = {}, -- Nix LSP
      gopls = {},
      bashls = {},
      html = {},
      ts_ls = {},
      pyright = {},
      rust_analyzer = {}, -- Usually managed via fenix in flake.nix, but good to have config here
      marksman = {},

      lua_ls = {
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            -- diagnostics = { disable = { 'missing-fields' } },
          },
        },
      },
    }

    -- Setup servers
    for server_name, server_config in pairs(servers) do
      server_config.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server_config.capabilities or {})

      -- Neovim 0.11+ deprecates the 'require("lspconfig")[name].setup()' framework.
      -- The new way is using vim.lsp.config and vim.lsp.enable.
      if vim.fn.has 'nvim-0.11' == 1 then
        vim.lsp.config(server_name, server_config)
        vim.lsp.enable(server_name)
      else
        require('lspconfig')[server_name].setup(server_config)
      end
    end
  end,
}
