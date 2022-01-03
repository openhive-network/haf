#!/bin/sh

for file in "$@"
do
    cat ${file}
    echo "\n"
done


