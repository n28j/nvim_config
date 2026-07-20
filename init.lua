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
require('packer').startup({
  function(use)
    use {
        'wbthomason/packer.nvim',         -- Packer manages itself
        commit = "ea0cc3c"
    }

    -- LSP and completion plugins
    use {
        'neovim/nvim-lspconfig',          -- Configurations for built-in LSP client
        commit = "f0c6ccf"
    }
    use {
        'hrsh7th/nvim-cmp',               -- Completion plugin
        commit = "b5311ab"
    }
    use {
        'hrsh7th/cmp-nvim-lsp',           -- LSP source for nvim-cmp
        commit = "a8912b8"
    }
    use {
        'hrsh7th/cmp-buffer',             -- Buffer completions
        commit = "b74fab3" 
    }
    use {
        'hrsh7th/cmp-path',               -- Path completions
        commit = "c642487"
    }
    use {
        'L3MON4D3/LuaSnip',               -- Snippet engine
        commit = "de10d84"
    }
    use {
        'saadparwaiz1/cmp_luasnip',       -- Snippet completions
        commit = "98d9cb5"
    }

    if packer_bootstrap then
      require('packer').sync()
    end
  end,
})

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


-- struct_init_lsp.lua <vibe-coded with claude>
-- Generate struct-member initializer boilerplate by talking to clangd (or any
-- LSP server that implements documentSymbol) directly, instead of parsing
-- syntax with Treesitter. This is more robust than a hand-rolled Treesitter
-- query because clangd has already resolved typedefs, templates, macros, etc.
--
-- Setup: put this file at ~/.config/nvim/lua/struct_init_lsp.lua and add
-- `require("struct_init_lsp")` to your init.lua.
--
-- Usage: put the cursor on a struct/class type name in a declaration and run:
--   :Expand   -> inserts var.field = ; lines for each member, where
--                        `var` is auto-detected from the declaration itself
--                        (falls back to prompting if it can't be detected)
--   :ExpandDump -> debug helper, see below
--
-- Debugging tip: to see the raw shape of what clangd returns for the buffer
-- you're currently in, run:
--   :lua vim.print(vim.lsp.buf_request_sync(0, "textDocument/documentSymbol",
--     { textDocument = vim.lsp.util.make_text_document_params() }, 2000))

local M = {}

local SYMBOL_KIND = {
  Class = 5,
  Interface = 11,
  Struct = 23,
  Field = 8,
  Property = 7,
}

-- Send a request on a specific client and block until it resolves (or times out).
-- Avoids relying on vim.lsp.buf_request_sync's requirement that the client be
-- "attached" to the buffer in nvim's bookkeeping.
local function request_sync(client, method, params, bufnr, timeout_ms)
  local done, result, err = false, nil, nil
  local ok = client.request(method, params, function(e, res)
    err, result, done = e, res, true
  end, bufnr)
  if not ok then
    return nil, "failed to send request"
  end
  local waited = vim.wait(timeout_ms or 2000, function()
    return done
  end, 10)
  if not waited then
    return nil, "timed out waiting for " .. method
  end
  return result, err
end

-- Pick a client attached to `bufnr` that looks like it can do this (prefer clangd).
local function pick_client(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    return nil
  end
  for _, c in ipairs(clients) do
    if c.name == "clangd" then
      return c
    end
  end
  return clients[1]
end

-- Recursively search a documentSymbol tree for a symbol with the given name
-- that looks like a struct/class/interface.
local function find_type_symbol(symbols, name)
  for _, sym in ipairs(symbols or {}) do
    if
      sym.name == name
      and (sym.kind == SYMBOL_KIND.Struct or sym.kind == SYMBOL_KIND.Class or sym.kind == SYMBOL_KIND.Interface)
    then
      return sym
    end
    if sym.children then
      local found = find_type_symbol(sym.children, name)
      if found then
        return found
      end
    end
  end
  return nil
end

-- documentSymbol's optional `detail` field is where clangd puts the type
-- signature for a field/property (e.g. name="x", detail="int"). We return
-- {name=..., type=...} per field instead of a bare name.
local function fields_of_symbol(sym)
  local fields = {}
  for _, child in ipairs(sym.children or {}) do
    if child.kind == SYMBOL_KIND.Field or child.kind == SYMBOL_KIND.Property then
      table.insert(fields, { name = child.name, type = child.detail })
    end
  end
  return fields
end

-- Temporarily jump to `location` (same mechanism gd uses), run `fn(target_bufnr)`,
-- then restore the original window/buffer/cursor. Jumping for real (rather than
-- just loading the buffer in the background) means any LspAttach autocommands
-- fire exactly like they do for a manual gd, so the server is actually attached
-- and ready to answer documentSymbol.
local function with_temporary_jump(location, fn)
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_win_get_buf(origin_win)
  local origin_cursor = vim.api.nvim_win_get_cursor(origin_win)

  vim.lsp.util.jump_to_location(location, "utf-16", false)
  local target_bufnr = vim.api.nvim_get_current_buf()

  -- Give a freshly-opened buffer a moment for the LSP client to attach.
  vim.wait(500, function()
    return #vim.lsp.get_clients({ bufnr = target_bufnr }) > 0
  end, 20)

  local ok, result = pcall(fn, target_bufnr)

  vim.api.nvim_set_current_win(origin_win)
  vim.api.nvim_win_set_buf(origin_win, origin_buf)
  vim.api.nvim_win_set_cursor(origin_win, origin_cursor)

  if ok then
    return result
  end
  vim.notify("Expand: " .. tostring(result), vim.log.levels.ERROR)
  return nil
end

local function fields_via_document_symbol(bufnr, name)
  local client = pick_client(bufnr)
  if not client then
    return nil, "no LSP client attached to definition buffer"
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local result, err = request_sync(client, "textDocument/documentSymbol", params, bufnr, 2000)
  if err then
    return nil, "documentSymbol error: " .. vim.inspect(err)
  end
  if not result or #result == 0 then
    return nil, "documentSymbol returned nothing"
  end

  local sym = find_type_symbol(result, name)
  if not sym then
    return nil, "no struct/class symbol named '" .. name .. "' in documentSymbol results"
  end

  return fields_of_symbol(sym)
end

local function word_under_cursor()
  return vim.fn.expand("<cword>")
end

-- Literal leading whitespace of a given line (tabs and spaces preserved as-is).
local function line_indent(bufnr, lnum)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
  return line:match("^%s*") or ""
end

-- Tokens that can legally sit between the type name and the variable name
-- that we should skip over rather than mistake for the variable itself.
local QUALIFIER_WORDS = { ["const"] = true, ["volatile"] = true, ["restrict"] = true }

-- Given the full declaration line and the 0-indexed byte column the cursor is
-- on (anywhere inside the struct/class type name), find the variable being
-- declared: the first identifier after the type name that isn't a qualifier
-- keyword. Also reports whether a `*` appeared between the type and that
-- identifier, so the caller can tell stack values from pointers, e.g.
--   MyStruct foo;              -> "foo", false
--   MyStruct *foo;             -> "foo", true
--   MyStruct * const foo;      -> "foo", true
--   const MyStruct &foo;       -> "foo", false  (reference, not a pointer)
-- Limitations:
--   - a line declaring multiple variables (`MyStruct a, *b;`) only reports
--     the first ("a", false) -- a mixed pointer/non-pointer second declarator
--     is not detected
--   - a pointer hidden behind a typedef (`MyStructPtr foo;`) can't be
--     detected this way since there's no literal `*` in the text
--   - double pointers (`MyStruct **foo;`) are reported as a single pointer
local function var_name_after_cursor(line, col0)
  local idx = col0 + 1 -- shift to 1-indexed for Lua string ops
  -- walk to the end of whatever word the cursor is currently on
  while idx <= #line and line:sub(idx, idx):match("[%w_]") do
    idx = idx + 1
  end

  local search_pos = idx
  while true do
    local s, e, tok = line:find("([%a_][%w_]*)", search_pos)
    if not tok then
      return nil, false
    end
    if not QUALIFIER_WORDS[tok] then
      local between = line:sub(idx, s - 1)
      local is_pointer = between:find("%*") ~= nil
      return tok, is_pointer
    end
    search_pos = e + 1
  end
end

-- Debug helper: dump the raw documentSymbol response for the CURRENT buffer
-- into a scrollable scratch buffer, so you can see clangd's actual `kind`
-- values and nesting instead of guessing. Run this with the cursor already
-- inside the struct's home file (e.g. after `gd`), on/near the struct name.
-- If a symbol matching the word under the cursor is found, only that subtree
-- is shown; otherwise the whole file's symbol tree is dumped.
function M.dump()
  local name = word_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = pick_client(bufnr)
  if not client then
    vim.notify("Expand: no LSP client attached to this buffer", vim.log.levels.WARN)
    return
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local result, err = request_sync(client, "textDocument/documentSymbol", params, bufnr, 2000)
  if err then
    vim.notify("Expand: documentSymbol error: " .. vim.inspect(err), vim.log.levels.WARN)
    return
  end
  if not result then
    vim.notify("Expand: documentSymbol returned nothing", vim.log.levels.WARN)
    return
  end

  local sym = find_type_symbol(result, name)
  local to_show = sym or result

  vim.cmd("new")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "lua"
  local header = sym and ("-- matched symbol '" .. name .. "':")
    or ("-- no symbol named '" .. name .. "' found; showing full file symbol tree:")
  local lines = { header }
  vim.list_extend(lines, vim.split(vim.inspect(to_show), "\n"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.insert()
  local name = word_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()

  local client = pick_client(bufnr)
  if not client then
    vim.notify("Expand: no LSP client attached to current buffer", vim.log.levels.WARN)
    return
  end

  -- Capture everything about the declaration line before we jump anywhere.
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local decl_line = vim.api.nvim_get_current_line()
  local base_indent = line_indent(bufnr, row)

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local def_result, def_err = request_sync(client, "textDocument/definition", params, bufnr, 2000)
  if def_err or not def_result or vim.tbl_isempty(def_result) then
    vim.notify("Expand: definition request failed for '" .. name .. "'", vim.log.levels.WARN)
    return
  end

  -- definition can return a Location, Location[], or LocationLink[].
  local loc = def_result[1] or def_result
  if loc.targetUri then
    loc = {
      uri = loc.targetUri,
      range = loc.targetSelectionRange or loc.targetRange,
    }
  end

  local fields, err = with_temporary_jump(loc, function(target_bufnr)
    return fields_via_document_symbol(target_bufnr, name)
  end)

  if not fields or #fields == 0 then
    vim.notify("Expand: " .. (err or ("couldn't find fields for '" .. name .. "'")), vim.log.levels.WARN)
    return
  end

  local var, is_pointer = var_name_after_cursor(decl_line, col)
  if not var then
    var = vim.fn.input("Couldn't auto-detect variable name, enter one: ", "obj")
    if var == "" then
      return
    end
    is_pointer = vim.fn.confirm("Is '" .. var .. "' a pointer?", "&Yes\n&No", 2) == 1
  end

  local sep = is_pointer and "->" or "."
  local lines = {}
  for _, f in ipairs(fields) do
    local comment = f.type and (" // " .. f.type) or ""
    table.insert(lines, base_indent .. var .. sep .. f.name .. "; " .. comment)
  end

  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
end

vim.api.nvim_create_user_command("ExpandDump", function()
  M.dump()
end, {})

vim.api.nvim_create_user_command("Expand", function()
  M.insert()
end, {})

return M
