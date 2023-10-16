#!/bin/bash
set -e

rm -rf build && ./build-openssl.sh && ./build-tdlib.sh && rm -rf ~/tdlib-symbols/native-debug-symbols/ && ./install.sh ~/tdlib-symbols/
