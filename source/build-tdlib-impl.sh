#!/usr/bin/env bash

set -e

ANDROID_SDK_ROOT=${1:-SDK}
ANDROID_NDK_VERSION=${2:-23.2.8568313}
OPENSSL_INSTALL_DIR=${3:-third-party/openssl}
ANDROID_STL=${4:-c++_static}
TDLIB_INTERFACE=${5:-Java}
ANDROID_SDK_PACKAGE=${6:-android-37.2}
ABIS=${7:-"arm64-v8a armeabi-v7a x86_64 x86"}
ANDROID_API=${8:-16}

if [ "$ANDROID_STL" != "c++_static" ] && [ "$ANDROID_STL" != "c++_shared" ] ; then
  echo 'Error: ANDROID_STL must be either "c++_static" or "c++_shared".'
  exit 1
fi

if [ "$TDLIB_INTERFACE" != "Java" ] && [ "$TDLIB_INTERFACE" != "JSON" ] && [ "$TDLIB_INTERFACE" != "JSONJava" ] ; then
  echo 'Error: TDLIB_INTERFACE must be either "Java", "JSON", or "JSONJava".'
  exit 1
fi

source ./check-environment.sh || exit 1

if [ ! -d "$ANDROID_SDK_ROOT" ] ; then
  echo "Error: directory \"$ANDROID_SDK_ROOT\" doesn't exist. Run ./fetch-sdk.sh first, or provide a valid path to Android SDK."
  exit 1
fi

if [ ! -d "$OPENSSL_INSTALL_DIR" ] ; then
  echo "Error: directory \"$OPENSSL_INSTALL_DIR\" doesn't exists. Run ./build-openssl.sh first."
  exit 1
fi

ANDROID_SDK_ROOT="$(cd "$(dirname -- "$ANDROID_SDK_ROOT")" >/dev/null; pwd -P)/$(basename -- "$ANDROID_SDK_ROOT")"
ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
OPENSSL_INSTALL_DIR="$(cd "$(dirname -- "$OPENSSL_INSTALL_DIR")" >/dev/null; pwd -P)/$(basename -- "$OPENSSL_INSTALL_DIR")"
PATH=$ANDROID_SDK_ROOT/cmake/3.22.1/bin:$PATH
TDLIB_INTERFACE_OPTION=$([ "$TDLIB_INTERFACE" == "JSON" ] && echo "-DTD_ANDROID_JSON=ON" || [ "$TDLIB_INTERFACE" == "JSONJava" ] && echo "-DTD_ANDROID_JSON_JAVA=ON" || echo "")

cd $(dirname $0)

echo "Generating TDLib source files..."
mkdir -p "build-native-$TDLIB_INTERFACE" || exit 1
cd "build-native-$TDLIB_INTERFACE" || exit 1
cmake "$TDLIB_INTERFACE_OPTION" -DTD_GENERATE_SOURCE_FILES=ON .. || exit 1
cmake --build . || exit 1
cd ..

rm -rf tdlib || exit 1

if [ "$TDLIB_INTERFACE" == "Java" ] ; then
  echo "Downloading annotation Java package..."
  rm -f android.jar annotation-1.4.0.jar || exit 1
  $WGET https://maven.google.com/androidx/annotation/annotation/1.4.0/annotation-1.4.0.jar || exit 1

  echo "Generating Java source files..."
  cmake --build build-native-$TDLIB_INTERFACE --target tl_generate_java || exit 1
  php AddIntDef.php org/drinkless/tdlib/TdApi.java || exit 1
  mkdir -p tdlib/java/org/drinkless/tdlib || exit 1
  cp -p {..,tdlib}/java/org/drinkless/tdlib/Client.java || exit 1
  mv {,tdlib/java/}org/drinkless/tdlib/TdApi.java || exit 1
  rm -rf org || exit 1

  echo "Generating Javadoc documentation..."
  cp "$ANDROID_SDK_ROOT/platforms/$ANDROID_SDK_PACKAGE/android.jar" . || exit 1
  JAVADOC_SEPARATOR=$([ "$OS_NAME" == "win" ] && echo ";" || echo ":")
  javadoc -d tdlib/javadoc -encoding UTF-8 -charset UTF-8 -classpath "android.jar${JAVADOC_SEPARATOR}annotation-1.4.0.jar" -quiet -sourcepath tdlib/java org.drinkless.tdlib || exit 1
  rm android.jar annotation-1.4.0.jar || exit 1
fi
if [ "$TDLIB_INTERFACE" == "JSONJava" ] ; then
  mkdir -p tdlib/java/org/drinkless/tdlib || exit 1
  cp -p {..,tdlib}/java/org/drinkless/tdlib/JsonClient.java || exit 1
fi

if [ "$ANDROID_API" -ge 23 ]; then
  EXTRA_LDFLAGS="-Wl,--pack-dyn-relocs=android";
else
  EXTRA_LDFLAGS="";
fi

for ABI in $ABIS ; do
  mkdir -p "tdlib/libs/$ABI/" || exit 1

  echo "Building TDLib... Android: $ANDROID_API, ABI: $ABI, ndk: $ANDROID_NDK_VERSION"

  mkdir -p "build-android-$ANDROID_API-$ABI-$TDLIB_INTERFACE" || exit 1
  cd "build-android-$ANDROID_API-$ABI-$TDLIB_INTERFACE" || exit 1
  LDFLAGS="$EXTRA_LDFLAGS" cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" -DOPENSSL_ROOT_DIR="$OPENSSL_INSTALL_DIR/$ANDROID_NDK_VERSION/android-$ANDROID_API/$ABI" -DCMAKE_BUILD_TYPE=RelWithDebInfo -GNinja -DANDROID_ABI="$ABI" -DANDROID_STL="$ANDROID_STL" -DANDROID_PLATFORM="android-$ANDROID_API" "$TDLIB_INTERFACE_OPTION" .. || exit 1
  if [ "$TDLIB_INTERFACE" == "Java" ] || [ "$TDLIB_INTERFACE" == "JSONJava" ] ; then
    cmake --build . --target tdjni || exit 1
    cp -p libtd*.so* "../tdlib/libs/$ABI/." || exit 1
  fi
  if [ "$TDLIB_INTERFACE" == "JSON" ] ; then
    cmake --build . --target tdjson || exit 1
    cp -p td/libtdjson.so "../tdlib/libs/$ABI/libtdjson.so.debug" || exit 1
    "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_ARCH/bin/llvm-strip" --strip-debug --strip-unneeded "../tdlib/libs/$ABI/libtdjson.so.debug" -o "../tdlib/libs/$ABI/libtdjson.so" || exit 1
  fi
  cd ..
done

echo "Compressing..."
rm -f tdlib.zip tdlib-debug.zip || exit 1
jar -cMf tdlib-debug.zip tdlib || exit 1
rm tdlib/libs/*/*.debug || exit 1
jar -cMf tdlib.zip tdlib || exit 1
mv tdlib.zip tdlib-debug.zip tdlib || exit 1

echo "Done."
