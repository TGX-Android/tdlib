#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-$HOME/tdlib-symbols}

rm -rf build

./build-openssl.sh > build/build-openssl.log || { echo "OpenSSL build failed" >&2; exit 1; }
./build-tdlib.sh > build/build-tdlib.log || { echo "TDLib build failed" >&2; exit 1; }

rm -rf "${SYMBOLS_INSTALL_DIR:?}/*"
mkdir -p "${SYMBOLS_INSTALL_DIR:?}"
./install.sh "${SYMBOLS_INSTALL_DIR:?}"
