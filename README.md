# dotfiles

personal dotfiles

vim plugins are managed using git subtrees

## Requirements

Install lsp clients for C++, Rust, and Python:

```sh
brew install neovim llvm rust_analyzer
npm i -g pyright
```
To get C++ LSP run cmake with:

`cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1`

For tree-sitter support run:

`:TSInstall <language_to_install>`
