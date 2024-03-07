#!/bin/sh
# Crontable schedules

_data_dir=crontab
mkdir -p "$_data_dir"

crontab -l >| "$_data_dir/${USER}.crontab"

git add "$_data_dir"

