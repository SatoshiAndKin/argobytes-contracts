#!/bin/sh
set -eux

isort .
black --line-length 120 argobytes bin setup.py tests

# TODO: fix this
# cd argobytes/argobytes_brownie_project
# yarn run prettier
