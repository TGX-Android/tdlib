#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-build}
TDLIB_INSTALL_DIR=${2:-build/td}
OPENSSL_INSTALL_DIR=${3:-build/openssl}

if [ ! -d "$SYMBOLS_INSTALL_DIR" ] ; then
  echo "Error: directory \"$SYMBOLS_INSTALL_DIR\" doesn't exist. Specify existing directory for symbols"
  exit 1
fi

if [ ! -d "$TDLIB_INSTALL_DIR" ] ; then
  echo "Error: directory \"$TDLIB_INSTALL_DIR\" doesn't exist. Run ./build-tdlib.sh"
  exit 1
fi

SYMBOLS_INSTALL_DIR="$(cd "$(dirname -- "$SYMBOLS_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$SYMBOLS_INSTALL_DIR")"
TDLIB_INSTALL_DIR="$(cd "$(dirname -- "$TDLIB_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$TDLIB_INSTALL_DIR")"
if [ -e "$OPENSSL_INSTALL_DIR" ] ; then
  OPENSSL_INSTALL_DIR="$(cd "$(dirname -- "$OPENSSL_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_INSTALL_DIR")"
fi

NDK_VERSIONS="$ANDROID_NDK_VERSION_PRIMARY"
if [ "${ANDROID_NDK_VERSION_LEGACY}" != "${ANDROID_NDK_VERSION_PRIMARY}" ]; then
  NDK_VERSIONS="${NDK_VERSIONS} ${ANDROID_NDK_VERSION_LEGACY}"
fi

pushd ../src/main > /dev/null
rm -rf java
cp -R "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION_PRIMARY/tdlib/java" .
popd > /dev/null

for ANDROID_NDK_VERSION in $NDK_VERSIONS; do
  # Delete System.loadLibrary("tdjni")
  pushd "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION/tdlib/java/org/drinkless/tdlib" > /dev/null || exit 1
  sed -i".bak" -E '/ {4}static \{/,+7d' TdApi.java || exit 1
  sed -i".bak" "s/&#039;/'/g" TdApi.java || exit 1
  sed -i".bak" -E '/ {4}static \{/,+7d' Client.java || exit 1
  sed -i".bak" "s/Function /Function<?> /g" Client.java || exit 1
  rm ./*.bak
  popd > /dev/null

  pushd "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION" > /dev/null
  rm -rf native-debug-symbols
  unzip tdlib/tdlib-debug.zip -d native-debug-symbols

  cd native-debug-symbols
  cp "$TDLIB_INSTALL_DIR/version.txt" .
  mv tdlib/libs/* .
  rm -rf tdlib
  rm ./*/*.so
  for ABI in arm64-v8a armeabi-v7a x86_64 x86 ; do
    if [ -e "$ABI/libtdjni.so.debug" ] ; then
      mv "$ABI/libtdjni.so.debug" "$ABI/libtdjni.so.dbg"
    fi
  done
  cd ..

  rm -rf "${SYMBOLS_INSTALL_DIR:?}/${ANDROID_NDK_VERSION?:}"
  mkdir -p "$SYMBOLS_INSTALL_DIR/$ANDROID_NDK_VERSION"
  mv native-debug-symbols "$SYMBOLS_INSTALL_DIR/$ANDROID_NDK_VERSION/."
  popd > /dev/null

  pushd .. > /dev/null
  rm -rf libs/arm64-v8a libs/armeabi-v7a libs/x86 libs/x86_64 "libs/$ANDROID_NDK_VERSION}"
  cp -R "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION/tdlib/libs" "libs/$ANDROID_NDK_VERSION"
  popd > /dev/null
done

pushd .. > /dev/null

if [ -e "$OPENSSL_INSTALL_DIR" ] ; then
  rm -rf openssl
  cp -R "$OPENSSL_INSTALL_DIR" ./openssl
fi

rm -rf version.txt
cp "$TDLIB_INSTALL_DIR/version.txt" .

popd > /dev/null

echo "Done! OpenSSL: $(cat "$OPENSSL_INSTALL_DIR/version.txt") TDLib: $(cat "$TDLIB_INSTALL_DIR/version.txt")"
