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

Adding clangd to the path requires some extra steps on macos:

`ln -s /usr/local/bin/ $(brew --prefix llvm)/bin/clangd`

For tree-sitter support run:

`:TSInstall <language_to_install>`
