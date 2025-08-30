-- init.lua

vim.opt.number = true
vim.opt.scrolloff = 10
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.title = true
vim.opt.titlestring = "%f%m"
vim.opt.wrap = false

vim.g.mapleader = "\\"

vim.api.nvim_set_keymap('n', '<leader>e', '<cmd>lua vim.diagnostic.open_float(nil, {scope="cursor"})<CR>', { noremap=true, silent=true })

vim.api.nvim_create_augroup('remember_cursor_position', { clear = true })

vim.api.nvim_create_autocmd('BufReadPost', {
  group = 'remember_cursor_position',
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line = mark[1]
    local last_line = vim.api.nvim_buf_line_count(0)
    if line > 0 and line <= last_line then
      vim.api.nvim_win_set_cursor(0, { line, mark[2] })
    end
  end,
})

-- Bootstrap packer if not installed
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 
      'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Use packer to manage plugins
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'          -- Packer manages itself

  -- LSP and completion plugins
  use 'neovim/nvim-lspconfig'           -- Configurations for built-in LSP client
  use 'hrsh7th/nvim-cmp'                -- Completion plugin
  use 'hrsh7th/cmp-nvim-lsp'            -- LSP source for nvim-cmp
  use 'hrsh7th/cmp-buffer'              -- Buffer completions
  use 'hrsh7th/cmp-path'                -- Path completions
  use 'L3MON4D3/LuaSnip'                -- Snippet engine
  use 'saadparwaiz1/cmp_luasnip'        -- Snippet completions

  if packer_bootstrap then
    require('packer').sync()
  end
end)

-- Setup nvim-cmp
local cmp = require'cmp'

cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),     -- Trigger completion manually
    ['<CR>'] = cmp.mapping.confirm({ select = true }),  -- Confirm selection with Enter
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },    -- Language server completions
    { name = 'luasnip' },     -- Snippet completions
  }, {
    { name = 'buffer' },      -- Buffer completions
    { name = 'path' },        -- Path completions
  })
})

-- Setup LSP with clangd for C/C++
require('lspconfig').clangd.setup {
    cmd = {
        "clangd",
        "--header-insertion=false",
    },
}

local nvim_lsp = require('lspconfig')
local cmp = require('cmp')
local capabilities = require('cmp_nvim_lsp').default_capabilities()

nvim_lsp.pyright.setup{
    capabilities = capabilities
}

nvim_lsp.clangd.setup{
  on_attach = function(client, bufnr)
    local buf_map = function(mode, lhs, rhs)
      vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap=true, silent=true })
    end

    -- Jump to declaration
    buf_map('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>')

    -- Jump to definition
    buf_map('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>')

    -- List references
    buf_map('n', 'gr', '<Cmd>lua vim.lsp.buf.references()<CR>')

    -- Show hover info
    buf_map('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>')


  end
}


cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = { --cmp.mapping.preset.insert({
    ['<A-j>'] = cmp.mapping.select_next_item(),   -- Alt+j selects next completion item
    ['<A-k>'] = cmp.mapping.select_prev_item(),   -- Alt+k selects previous completion item
    --['<C-Space>'] = cmp.mapping.complete(),
    ['<Tab>'] = cmp.mapping.select_next_item(),
    ['<M-CR>'] = cmp.mapping.confirm({ select = true }),
    ['<CR>'] = cmp.mapping(function(fallback) fallback() end, {"i"}),
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer' },
  })
})

