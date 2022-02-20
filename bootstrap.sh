#!/bin/bash

function bootstrap_linux() {
  echo "Hello Linux!"
  # xargs sudo apt-get -y install <packages.txt
}

function bootstrap_macos() {
  echo "Hello Macos!"
  # brew bundle
}

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  bootstrap_linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
  bootstrap_macos
fi
