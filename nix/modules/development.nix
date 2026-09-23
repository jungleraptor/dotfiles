{ pkgs, ... }:
{
  # Editor/runtime tools. Project compilers and environments stay project-owned.
  home.packages = with pkgs; [
    clang-tools
    llvm
    pyright
    rust-analyzer
    lua-language-server
  ];
  home.file.".vimrc".source = ../../vimrc;
  home.file.".vim".source = ../../vim;
}
