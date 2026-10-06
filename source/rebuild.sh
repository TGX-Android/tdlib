#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-$HOME/tdlib-symbols}

rm -rf build
mkdir build

./build-openssl.sh > build/build-openssl.log 2>&1 || { echo "OpenSSL build failed" >&2; exit 1; }
./build-tdlib.sh > build/build-tdlib.log 2>&1 || { echo "TDLib build failed" >&2; exit 1; }

rm -rf "${SYMBOLS_INSTALL_DIR:?}/*"
mkdir -p "${SYMBOLS_INSTALL_DIR:?}"
./install.sh "${SYMBOLS_INSTALL_DIR:?}"
