set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath

call plug#begin()

Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'rafamadriz/friendly-snippets'
Plug 'dgagn/diagflow.nvim'
Plug 'glepnir/lspsaga.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'peterhoeg/vim-qml'
Plug 'hashivim/vim-terraform'
" Plug 'Mofiqul/dracula.nvim'
Plug 'NTBBloodbath/doom-one.nvim'
Plug 'kyazdani42/nvim-web-devicons'
Plug 'kyazdani42/nvim-tree.lua'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-dispatch'
Plug 'github/copilot.vim'
Plug 'augmentcode/augment.vim'

call plug#end()

" Space as <leader> key
let g:mapleader = "\<Space>"

let g:augment_workspace_folders = ['~/enfabrica/internal/master']
let g:augment_disable_tab_mapping = v:true

nnoremap <silent> <leader>f :Files<CR>
nnoremap <silent> <leader>e :NvimTreeToggle<CR>
nnoremap <silent> <leader>s :ClangdSwitchSourceHeader<CR>
nnoremap <silent> <leader>p :echo expand('%:p')<CR>
inoremap <c-y> <cmd>call augment#Accept()<cr>

set grepprg=rg\ --vimgrep\ --smart-case\ --hidden
set grepformat=%f:%l:%c:%m

lua << EOF
require("nvim-tree").setup({
  view = {
    width = 40,
  },
})

EOF

lua << EOF

-- Set up nvim-cmp.
local cmp = require'cmp'
require('luasnip.loaders.from_vscode').lazy_load()

cmp.setup({
  -- preselect first item
  preselect = 'item',
  completion = {
    completeopt = 'menu,menuone,noinsert'
  },
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      -- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
      require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
      -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
      -- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)
    end,
  },
  window = {
--    completion = cmp.config.window.bordered(),
--    documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    -- Super tab
    ['<Tab>'] = cmp.mapping(function(fallback)
        local luasnip = require('luasnip')
        local col = vim.fn.col('.') - 1

        if cmp.visible() then
          cmp.select_next_item({behavior = 'select'}) -- Move to the next item
        elseif luasnip.expand_or_locally_jumpable() then
          luasnip.expand_or_jump()
        elseif col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
          fallback() -- Fallback behavior (e.g., insert a tab character)
        else
          cmp.complete()
        end
    end, { 'i', 's' }),
    -- Super shift tab
    ['<S-Tab>'] = cmp.mapping(function(fallback)
        local luasnip = require('luasnip')

        if cmp.visible() then
            cmp.select_prev_item({behavior = 'select'}) -- Move to the next item
        elseif luasnip.locally_jumpable(-1) then
            luasnip.jump(-1)
        else
            fallback() -- Fallback behavior (e.g., insert a tab character)
        end
    end, { 'i', 's' }),
      -- Jump to the next snippet placeholder
    ['<C-f>'] = cmp.mapping(function(fallback)
      local luasnip = require('luasnip')
      if luasnip.locally_jumpable(1) then
        luasnip.jump(1)
      else
        fallback()
      end
    end, {'i', 's'}),
    -- Jump to the previous snippet placeholder
    ['<C-b>'] = cmp.mapping(function(fallback)
      local luasnip = require('luasnip')
      if luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, {'i', 's'}),
--    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
--    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    -- { name = 'vsnip' }, -- For vsnip users.
    { name = 'luasnip' }, -- For luasnip users.
    -- { name = 'ultisnips' }, -- For ultisnips users.
    -- { name = 'snippy' }, -- For snippy users.
  }, {
    { name = 'buffer' },
  })
})

  -- To use git you need to install the plugin petertriho/cmp-git and uncomment lines below
  -- Set configuration for specific filetype.
  --[[ cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'git' },
    }, {
      { name = 'buffer' },
    })
 })
 require("cmp_git").setup() ]]-- 

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
--cmp.setup.cmdline(':', {
--  mapping = cmp.mapping.preset.cmdline(),
--  sources = cmp.config.sources({
--    { name = 'path' }
--  }, {
--    { name = 'cmdline' }
--  }),
--  matching = { disallow_symbol_nonprefix_matching = false }
--})

-- Set up lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local nvim_lsp = require('lspconfig')

-- Use on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }
 -- vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts) TODO: remap

  -- See `:help vim.lsp*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  -- gi seems to not work in rust
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  -- rarely works.
  buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<C-R>', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  -- Map <leader>f to format the current buffer
--  buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts) TODO: remap
  vim.lsp.inlay_hint.enable(true)

end

vim.keymap.set({'n', 'v'}, '<leader>w', function()
  vim.lsp.buf.format({ async = true })
end, { desc = 'Format buffer with LSP' })

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { 'pyright', 'rust_analyzer', 'clangd', 'lua_ls' }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    capabilities = capabilities,
    on_attach = on_attach,
    flags = {
      debounce_text_changes = 150,
    },
    settings = {
        ["rust-analyzer"] = {
            linkedProjects = {"./rust-project.json"}
            }

    },
    cmd = {
--        "/home/isaac/.local/bin/clangd_19.1.0/bin/clangd",
        "clangd",
        "--offset-encoding=utf-16",
        "--clang-tidy=false",
        "--header-insertion=never",
        "--query-driver=**",
--        "--remote-index-address=localhost:16000",
--        "--project-root=/home/isaac/enfabrica/internal-worktree/hermetic-gcc",
    },
  }
end

require('diagflow').setup({
    enable = true,
    max_width = 60,  -- The maximum width of the diagnostic messages
    max_height = 10, -- the maximum height per diagnostics
    severity_colors = {  -- The highlight groups to use for each diagnostic severity level
        error = "DiagnosticFloatingError",
        warning = "DiagnosticFloatingWarn",
        info = "DiagnosticFloatingInfo",
        hint = "DiagnosticFloatingHint",
    },
    format = function(diagnostic)
      return diagnostic.message
    end,
    gap_size = 1,
    scope = 'cursor', -- 'cursor', 'line' this changes the scope, so instead of showing errors under the cursor, it shows errors on the entire line.
    padding_top = 0,
    padding_right = 0,
    text_align = 'right', -- 'left', 'right'
    placement = 'top', -- 'top', 'inline'
    inline_padding_left = 0, -- the padding left when the placement is inline
    update_event = { 'DiagnosticChanged', 'BufReadPost' }, -- the event that updates the diagnostics cache
    toggle_event = { }, -- if InsertEnter, can toggle the diagnostics on inserts
    show_sign = false, -- set to true if you want to render the diagnostic sign before the diagnostic message
    render_event = { 'DiagnosticChanged', 'CursorMoved' },
    border_chars = {
      top_left = "┌",
      top_right = "┐",
      bottom_left = "└",
      bottom_right = "┘",
      horizontal = "─",
      vertical = "│"
    },
    show_borders = false,
})

-- loads diagnostics into locallist
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = function()
      vim.diagnostic.setloclist({ open = false }) -- Automatically updates the location list without opening it
  end,
})

require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },

  ensure_installed = { 
    "c",
    "cpp",
    "fish",
    "jsonnet",
    "lua",
    "starlark",
    "rust",
    "python",
    "yaml",
  },

  -- enables installing parsers from the cmdline but will
  -- still download async when nvim runs interactively:
  -- https://github.com/nvim-treesitter/nvim-treesitter/issues/3579
  sync_install = #vim.api.nvim_list_uis() == 0,

  textobjects = {
    select = {
      enable = true,
      lookahead = true,

      keymaps = {
        ['aa'] = '@parameter.outer',
        ['ia'] = '@parameter.inner',
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- Set jumps in the jumplist

      goto_next_start = {
        [']a'] = '@parameter.inner',
      },
      goto_next_end = {
        [']A'] = '@parameter.inner',
      },
      goto_previous_start = {
        ['[a'] = '@parameter.inner',
      },
      goto_previous_end = {
        ['[A'] = '@parameter.inner',
      },
    },
  },
--  textobjects = {
--    select = {
--      enable = true,
--      lookahead = true
--
--      keymaps = {
--        ['aa'] = '@parameter.outer',
--        ['ia'] = '@parameter.inner',
--      },
--    },
--    move = {
--      enable = true,
--      set_jumps = true, -- Set jumps in the jumplist
--      goto_next_start = {
--          [']a'] = '@parameter.outer',
--      },
--    }, 
--  },
}

EOF

set termguicolors

colorscheme doom-one

source ~/.vimrc
