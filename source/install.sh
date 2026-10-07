#!/bin/bash
set -e

SYMBOLS_INSTALL_DIR=${1:-build}
TDLIB_INSTALL_DIR=${2:-build/td}
OPENSSL_INSTALL_DIR=${3:-build/openssl}
TGX_FLAVORS=${4:-"latest marshmallow lollipop legacy"}

source "$(pwd)/setup.sh" --light

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

rm -rf ../src/main/libs
mkdir ../src/main/libs

rm -rf "${SYMBOLS_INSTALL_DIR:?}/*"
mkdir -p "$SYMBOLS_INSTALL_DIR"

for TGX_FLAVOR in $TGX_FLAVORS; do
  if [ "${TGX_FLAVOR}" != "legacy" ]; then
    ANDROID_NDK_VERSION="$ANDROID_NDK_VERSION_PRIMARY"
    ABIS="arm64-v8a armeabi-v7a x86_64 x86"
  else
    ANDROID_NDK_VERSION="$ANDROID_NDK_VERSION_LEGACY"
    ABIS="armeabi-v7a x86"
  fi

  case "${TGX_FLAVOR}" in
    latest)
      ANDROID_API=24
      ;;
    marshmallow)
      ANDROID_API=23
      ;;
    lollipop)
      ANDROID_API=21
      ;;
    legacy)
      ANDROID_API=16
      ;;
    *)
      echo -e "${STYLE_ERROR}Unsupported flavor: ${TGX_FLAVOR}.${STYLE_END}"
      exit 1
      ;;
  esac

  # Delete System.loadLibrary("tdjni")
  pushd "$TDLIB_INSTALL_DIR/${ANDROID_NDK_VERSION:?}/android-$ANDROID_API/tdlib/java/org/drinkless/tdlib" > /dev/null || exit 1
  sed -i".bak" -E '/ {4}static \{/,+7d' TdApi.java || exit 1
  sed -i".bak" "s/&#039;/'/g" TdApi.java || exit 1
  sed -i".bak" -E '/ {4}static \{/,+7d' Client.java || exit 1
  sed -i".bak" "s/Function /Function<?> /g" Client.java || exit 1
  rm ./*.bak
  popd > /dev/null

  pushd "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION/android-$ANDROID_API" > /dev/null
  rm -rf native-debug-symbols
  echo "Unzipping tdlib/tdlib-debug.zip to $TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION/android-$ANDROID_API"
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

  mkdir -p "$SYMBOLS_INSTALL_DIR/$ANDROID_NDK_VERSION/android-$ANDROID_API"
  mv native-debug-symbols "$SYMBOLS_INSTALL_DIR/$ANDROID_NDK_VERSION/android-$ANDROID_API/."
  popd > /dev/null

  pushd ../src/main > /dev/null
  cp -R "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION/android-$ANDROID_API/tdlib/libs" "./libs/$ANDROID_NDK_VERSION/android-$ANDROID_API"
  popd > /dev/null
done

pushd ../src/main > /dev/null
rm -rf java
cp -R "$TDLIB_INSTALL_DIR/$ANDROID_NDK_VERSION_PRIMARY/android-24/tdlib/java" .
popd > /dev/null

pushd .. > /dev/null
if [ -e "$OPENSSL_INSTALL_DIR" ] ; then
  rm -rf openssl
  cp -R "$OPENSSL_INSTALL_DIR" ./openssl
fi
rm -rf version.txt
cp "$TDLIB_INSTALL_DIR/version.txt" .
popd > /dev/null

echo "Done! OpenSSL: $(cat "$OPENSSL_INSTALL_DIR/version.txt") TDLib: $(cat "$TDLIB_INSTALL_DIR/version.txt")"
