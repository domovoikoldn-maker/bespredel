#!/usr/bin/env bash
# Сборка нативных ядер для Android и раскладка в jniLibs.
#   libxray.so               — Xray-core (готовый бинарник из релиза XTLS)
#   libbyedpi.so             — ByeDPI ciadpi (собирается NDK)
#   libhev-socks5-tunnel.so  — tun2socks (собирается ndk-build)
# Требуется переменная NDK (путь к Android NDK).
set -euo pipefail

: "${NDK:?Укажи путь к Android NDK в переменной NDK}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build-cores/android"
JNI="$ROOT/android/app/src/main/jniLibs"
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
API=24
rm -rf "$WORK"; mkdir -p "$WORK" "$JNI"

# abi : имя в релизе Xray : триплет clang
TARGETS=(
  "arm64-v8a:arm64-v8a:aarch64-linux-android"
  "x86_64:amd64:x86_64-linux-android"
)

echo "== Xray-core =="
for t in "${TARGETS[@]}"; do
  IFS=: read -r abi xa _ <<<"$t"
  mkdir -p "$JNI/$abi" "$WORK/xray-$abi"
  curl -fsSL -o "$WORK/xray-$abi.zip" \
    "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-android-$xa.zip"
  unzip -o -q "$WORK/xray-$abi.zip" -d "$WORK/xray-$abi"
  cp "$WORK/xray-$abi/xray" "$JNI/$abi/libxray.so"
done

echo "== ByeDPI =="
git clone --depth 1 https://github.com/hufrea/byedpi "$WORK/byedpi"
for t in "${TARGETS[@]}"; do
  IFS=: read -r abi _ tri <<<"$t"
  CC="$TC/${tri}${API}-clang"
  ( cd "$WORK/byedpi" && make clean >/dev/null 2>&1 || true
    if ! make CC="$CC" -j4; then
      echo "make не прошёл, собираю вручную"
      rm -f ciadpi
      "$CC" -O2 -D_GNU_SOURCE -o ciadpi $(ls *.c | grep -v -i win)
    fi )
  cp "$WORK/byedpi/ciadpi" "$JNI/$abi/libbyedpi.so"
done

echo "== hev-socks5-tunnel =="
mkdir -p "$WORK/hev"
git clone --depth 1 --recursive https://github.com/heiher/hev-socks5-tunnel "$WORK/hev/jni"
( cd "$WORK/hev" && "$NDK/ndk-build" \
    NDK_PROJECT_PATH=. \
    APP_BUILD_SCRIPT=jni/Android.mk \
    NDK_APPLICATION_MK=jni/Application.mk \
    "APP_CFLAGS=-O3 -DPKGNAME=com/domovoi4ik/bespredel -DCLSNAME=TProxyService" \
    "APP_ABI=arm64-v8a x86_64" \
    APP_PLATFORM=android-$API -j4 )
for t in "${TARGETS[@]}"; do
  IFS=: read -r abi _ _ <<<"$t"
  cp "$WORK/hev/libs/$abi/libhev-socks5-tunnel.so" "$JNI/$abi/"
done

chmod 755 "$JNI"/*/*.so
ls -la "$JNI"/*
