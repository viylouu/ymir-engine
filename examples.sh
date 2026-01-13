#!/bin/bash

mkdir -p build

for dir in examples/*/ ; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    odin build "$dir" -out:"build/$name.game"
    "./build/$name.game"
done
