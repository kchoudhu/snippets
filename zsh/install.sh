#!/bin/sh

mkdir -p ~/.zsh_include
cp ./zsh_include/* ~/.zsh_include/
chmod 0700 ~/.zsh_include/*

cp ./zshrc ~/.zshrc

cp ./rootmake.mk ~/Makefile
