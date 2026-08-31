#!/bin/bash
set -e

pushd openssl || exit 1
git clean -ffd
git submodule foreach -q --recursive 'git clean -ffd'
git reset --hard HEAD
git submodule update --init
popd > /dev/null

pushd td || exit 1
git clean -ffd
git submodule foreach -q --recursive 'git clean -ffd'
git reset --hard HEAD
git submodule update --init
popd > /dev/null