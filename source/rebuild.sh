#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-$HOME/tdlib-symbols}

rm -rf build
mkdir build

# OpenSSL is built again only when its commit, its script or the NDKs change
source "$(pwd)/setup.sh" --light
OPENSSL_STAMP="$(git -C openssl rev-parse HEAD) $(git hash-object build-openssl.sh)"
OPENSSL_STAMP="$OPENSSL_STAMP $ANDROID_NDK_VERSION_PRIMARY $ANDROID_NDK_VERSION_LEGACY"
if [ -d ../openssl ] && [ "$(cat ../openssl/stamp.txt 2>/dev/null)" == "$OPENSSL_STAMP" ]; then
  echo "OpenSSL is up to date: $OPENSSL_STAMP"
  cp -R ../openssl build/openssl
else
  ./build-openssl.sh > build/build-openssl.log 2>&1 || { echo "OpenSSL build failed" >&2; exit 1; }
  echo "$OPENSSL_STAMP" > build/openssl/stamp.txt
fi
./build-tdlib.sh > build/build-tdlib.log 2>&1 || { echo "TDLib build failed" >&2; exit 1; }

./install.sh "${SYMBOLS_INSTALL_DIR:?}" || { echo "Installation failed" >&2; exit 1; }
