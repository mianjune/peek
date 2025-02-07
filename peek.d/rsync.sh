#!/bin/sh
# Sync custom directories, e.g. dotfiles

DATA_DIR=dotfiles
mkdir -p "$DATA_DIR"

rsync -aPh --delete-after \
    ~/.*rc \
    "$DATA_DIR"/

git add "$DATA_DIR"

