#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-~/tdlib-symbols}

rm -rf build

./build-openssl.sh || (echo "OpenSSL build failed" && exit 1)
./build-tdlib.sh || (echo "TDLib build failed" && exit 1)

rm -rf "${SYMBOLS_INSTALL_DIR:?}/*"
mkdir -p "${SYMBOLS_INSTALL_DIR:?}"
./install.sh "${SYMBOLS_INSTALL_DIR:?}"
