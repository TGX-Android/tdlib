#!/bin/bash
set -e

TDLIB_INSTALL_DIR=${1:-build/td}
OPENSSL_INSTALL_DIR=${2:-build/openssl}

if [ ! -d "$OPENSSL_INSTALL_DIR" ] ; then
  echo "Error: directory \"$OPENSSL_INSTALL_DIR\" doesn't exist. Run ./build-openssl.sh"
  exit 1
fi

if [ ! -d "$TDLIB_INSTALL_DIR" ] ; then
  echo "Error: directory \"$TDLIB_INSTALL_DIR\" doesn't exist. Run ./build-tdlib.sh"
  exit 1
fi

TDLIB_INSTALL_DIR="$(cd "$(dirname -- "$TDLIB_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$TDLIB_INSTALL_DIR")"
OPENSSL_INSTALL_DIR="$(cd "$(dirname -- "$OPENSSL_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_INSTALL_DIR")"

# Delete System.loadLibrary("tdjni")
pushd "$TDLIB_INSTALL_DIR/tdlib/java/org/drinkless/tdlib" > /dev/null || exit 1
sed -i".bak" -E '/ {4}static \{/,+7d' TdApi.java || exit 1
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
mv native-debug-symbols ../.

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