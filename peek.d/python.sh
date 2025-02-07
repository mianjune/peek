#!/bin/sh
# Python pypi modules freeze

DATA_DIR=python
mkdir -p "$DATA_DIR"

# Python Lib
pip3 freeze >| "$DATA_DIR"/python3-requirements.txt

git add "$DATA_DIR"

