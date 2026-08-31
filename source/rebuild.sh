#!/bin/bash
set -e

rm -rf build

./build-openssl.sh || (echo "OpenSSL build failed" && exit 1)
./build-tdlib.sh || (echo "TDLib build failed" && exit 1)

rm -rf ~/tdlib-symbols
./install.sh ~/tdlib-symbols