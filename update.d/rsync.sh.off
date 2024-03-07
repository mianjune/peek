#!/bin/sh
# Sync custom directories, e.g. dotfiles

_data_dir=dotfiles
mkdir -p "$_data_dir"

rsync -aPh --delete-after \
    ~/.*rc \
    "$_data_dir"/

git add "$_data_dir"

