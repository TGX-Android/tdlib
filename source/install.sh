#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-build}
TDLIB_INSTALL_DIR=${2:-build/td}
OPENSSL_INSTALL_DIR=${3:-build/openssl}

if [ ! -d "$SYMBOLS_INSTALL_DIR" ] ; then
  echo "Error: directory \"$SYMBOLS_INSTALL_DIR\" doesn't exist. Specify existing directory for symbols"
  exit 1
fi

if [ ! -d "$OPENSSL_INSTALL_DIR" ] ; then
  echo "Error: directory \"$OPENSSL_INSTALL_DIR\" doesn't exist. Run ./build-openssl.sh"
  exit 1
fi

if [ ! -d "$TDLIB_INSTALL_DIR" ] ; then
  echo "Error: directory \"$TDLIB_INSTALL_DIR\" doesn't exist. Run ./build-tdlib.sh"
  exit 1
fi

SYMBOLS_INSTALL_DIR="$(cd "$(dirname -- "$SYMBOLS_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$SYMBOLS_INSTALL_DIR")"
TDLIB_INSTALL_DIR="$(cd "$(dirname -- "$TDLIB_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$TDLIB_INSTALL_DIR")"
OPENSSL_INSTALL_DIR="$(cd "$(dirname -- "$OPENSSL_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_INSTALL_DIR")"

# Delete System.loadLibrary("tdjni")
pushd "$TDLIB_INSTALL_DIR/tdlib/java/org/drinkless/tdlib" > /dev/null || exit 1
sed -i".bak" -E '/ {4}static \{/,+7d' TdApi.java || exit 1
sed -i".bak" "s/&#039;/'/g" TdApi.java || exit 1
sed -i".bak" -E '/ {4}static \{/,+7d' Client.java || exit 1
rm *.bak
popd > /dev/null

pushd "$TDLIB_INSTALL_DIR/tdlib" > /dev/null
rm -rf native-debug-symbols
rm -rf ../native-debug-symbols
unzip tdlib-debug.zip -d native-debug-symbols
cd native-debug-symbols
cp "$TDLIB_INSTALL_DIR/version.txt" .
mv tdlib/libs/* .
rm -rf tdlib
rm */*.so
for ABI in arm64-v8a armeabi-v7a x86_64 x86 ; do
  mv "$ABI/libtdjni.so.debug" "$ABI/libtdjni.so.dbg"
done
cd ..
rm -rf "$SYMBOLS_INSTALL_DIR/native-debug-symbols"
mv native-debug-symbols "$SYMBOLS_INSTALL_DIR/native-debug-symbols"

popd > /dev/null

pushd ../src/main > /dev/null
rm -rf libs
cp -R "$TDLIB_INSTALL_DIR/tdlib/libs" .
rm -rf java
cp -R "$TDLIB_INSTALL_DIR/tdlib/java" .
popd > /dev/null

pushd .. > /dev/null

rm -rf openssl
cp -R "$OPENSSL_INSTALL_DIR" ./openssl
rm -rf version.txt
cp "$TDLIB_INSTALL_DIR/version.txt" .

popd > /dev/null

echo "Done! OpenSSL: $(cat $OPENSSL_INSTALL_DIR/version.txt) TDLib: $(cat $TDLIB_INSTALL_DIR/version.txt)"
