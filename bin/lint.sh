#!/bin/sh
set -eux

# if requirements.in and requirements.txt have changed, run pip-compile
# TODO: do this in a seperate lint script
sum_file=.requirements.shasum
if [ -e "$sum_file" ]; then
    if sha256sum --check "$sum_file"; then
        # shasum succeeded. no need to run pip-compile
        :
    else
        # shasum failed! this means one or more of the requirements files has changed
        pip-compile requirements.in
    fi
fi

# make sure shasums match the files that we expect
echo "# automatically generated file" > "$sum_file"
sha256sum requirements.in requirements.txt >> "$sum_file"

isort .
black --line-length 120 argobytes bin setup.py tests

# TODO: fix this
# cd argobytes/argobytes_brownie_project
# yarn run prettier
