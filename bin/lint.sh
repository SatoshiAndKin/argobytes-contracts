#!/bin/sh
set -eux

isort .
black --line-length 120 argobytes setup.py tests 

cd argobytes/argobytes_brownie_project

yarn run prettier
