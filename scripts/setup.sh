#!/bin/bash -eux
# setup python and node environments

# make sure we are at the project root
[ -e requirements.in ]

if [ -d venv ]; then
  rm -rf venv
fi

python3 -m venv venv

. ./venv/bin/activate

pip install wheel
pip install -r requirements.txt

if [ -d node_modules ]; then
  rm -rf node_modules
fi

yarn install
