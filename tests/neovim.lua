-- Runs with the real generated configuration and an empty, temporary HOME.
-- No activation, external services, credentials, or network are needed.
local ok, err = pcall(function()
  -- Some plugins intentionally use silent! commands that leave v:errmsg set.
  local messages = vim.api.nvim_exec2('messages', { output = true }).output
  assert(not messages:find('Error detected while processing', 1, true), messages)
  for _, name in ipairs({ 'cmp', 'luasnip', 'nvim-tree', 'diagflow', 'nvim-treesitter.configs' }) do
    assert(require(name), 'missing plugin: ' .. name)
  end
  assert(vim.g.colors_name == 'doom-one', 'colorscheme changed')
  assert(vim.fn.exists(':Files') == 2, 'fzf command missing')
  assert(vim.fn.exists(':Git') == 2, 'Fugitive command missing')
  assert(vim.fn.exists('*lightline#update') == 1 or vim.fn.exists('g:loaded_lightline') == 1,
    'Lightline missing')
  assert(vim.fn.maparg('<Space>f', 'n') == ':Files<CR>', 'file-search mapping changed')

  for _, language in ipairs({ 'c', 'cpp', 'fish', 'jsonnet', 'lua', 'starlark', 'rust', 'python', 'yaml' }) do
    vim.treesitter.language.add(language)
    assert(vim.treesitter.get_string_parser('', language):parse(), 'parser failed: ' .. language)
    assert(vim.treesitter.query.get(language, 'highlights'), 'highlight queries missing: ' .. language)
  end
  assert(vim.treesitter.query.get('cpp', 'textobjects'), 'textobject queries missing')

  local configs = require('lspconfig.configs')
  local expected = {
    clangd = 'clangd', pyright = 'pyright-langserver',
    rust_analyzer = 'rust-analyzer', lua_ls = 'lua-language-server',
  }
  for name, executable in pairs(expected) do
    local command = configs[name].manager.config.cmd[1]
    assert(vim.fn.fnamemodify(command, ':t') == executable, name .. ' launches the wrong server')
    assert(vim.fn.executable(command) == 1, name .. ' executable is missing')
  end
  local buffer = vim.api.nvim_create_buf(false, true)
  configs.pyright.manager.config.on_attach({
    supports_method = function(_, method)
      assert(method == 'textDocument/inlayHint', 'incorrect LSP capability call')
      return false
    end,
  }, buffer)
  local found_definition = false
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buffer, 'n')) do
    if mapping.lhs == 'gd' then found_definition = true end
  end
  assert(found_definition, 'LSP attachment did not install navigation mappings')
  vim.api.nvim_buf_delete(buffer, { force = true })
end)

if not ok then
  io.stderr:write(tostring(err) .. '\n')
  vim.cmd('cquit 1')
else
  print('Neovim plugins, parsers, mappings and language-server commands passed')
  vim.cmd('qa!')
end
