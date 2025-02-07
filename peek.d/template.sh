#!/bin/sh
# This is a demo updater script

# Manage by directory, and make sure existed
DATA_DIR="$(basename "${0%.sh*}")"
mkdir -p "$DATA_DIR"

# Predefined function:
#   logging with format
#   > _log MESSAGE...
#   execute command with logging
#   > _exec COMMAND...

# TODO: update to >| "$DATA_DIR"


# Add to Git repository
git add "$DATA_DIR"

