#!/bin/sh
# Crontable schedules

DATA_DIR=crontab
mkdir -p "$DATA_DIR"

crontab -l >| "$DATA_DIR/${USER}.crontab"

git add "$DATA_DIR"

