{ pkgs, editorPkgs, ... }:
{
  programs.neovim = {
    enable = true;
    package = editorPkgs.neovim-unwrapped;
    defaultEditor = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
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
    extraConfig = builtins.readFile ../../vimrc + "\n" + builtins.readFile ../../nvim/init.vim;
  };
}
