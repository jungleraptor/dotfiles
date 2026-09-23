{ pkgs, editorPkgs, ... }:
let
  lspCommands = {
    clangd = "${pkgs.clang-tools}/bin/clangd";
    pyright = "${pkgs.pyright}/bin/pyright-langserver";
    rust_analyzer = "${pkgs.rust-analyzer}/bin/rust-analyzer";
    lua_ls = "${pkgs.lua-language-server}/bin/lua-language-server";
  };
in
{
  programs.neovim = {
    enable = true;
    package = editorPkgs.neovim-unwrapped;
    defaultEditor = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    extraPackages = with pkgs; [
      ripgrep
      fzf
    ];
    plugins = with editorPkgs.vimPlugins; [
      nvim-lspconfig
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      nvim-cmp
      luasnip
      cmp_luasnip
      friendly-snippets
      diagflow-nvim
      lspsaga-nvim
      (nvim-treesitter.withPlugins (
        grammars: with grammars; [
          c
          cpp
          fish
          jsonnet
          lua
          starlark
          rust
          python
          yaml
        ]
      ))
      nvim-treesitter-textobjects
      fzf-vim
      vim-qml
      vim-terraform
      doom-one-nvim
      nvim-web-devicons
      nvim-tree-lua
      vim-unimpaired
      vim-dispatch
      lightline-vim
      vim-fugitive
    ];
    extraConfig = ''
      lua << EOF
      vim.g.dotfiles_lsp_commands = vim.json.decode([==[${builtins.toJSON lspCommands}]==])
      EOF
    ''
    + builtins.readFile ../../vimrc
    + "\n"
    + builtins.readFile ../../nvim/init.vim;
  };
}
