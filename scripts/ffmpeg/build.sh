#!/usr/bin/env bash
set -euo pipefail

# Build ottimizzata per playback locale HEVC Main10 software-only
# Target: Android ARM64
# Obiettivo: massimo throughput su CPU non molto potente

if [ "${ANDROID_ABI:-}" != "arm64-v8a" ]; then
  echo "This build is optimized only for arm64-v8a. Current ANDROID_ABI='${ANDROID_ABI:-unset}'"
  exit 1
fi

# --- 1. Ottimizzazioni architettura ---
EXTRA_BUILD_CONFIGURATION_FLAGS="${EXTRA_BUILD_CONFIGURATION_FLAGS:-} --enable-asm --enable-inline-asm --enable-neon"
EXTRA_CFLAGS="${EXTRA_CFLAGS:-}"

# --- 2. Build chirurgica: solo ciò che serve a HEVC locale ---
ADDITIONAL_COMPONENTS="--disable-everything \
  --enable-decoder=hevc \
  --enable-parser=hevc \
  --enable-demuxer=mov,mp4,hevc \
  --enable-protocol=file,pipe"

# --- 3. Dipendenze / linker ---
DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib ${FFMPEG_EXTRA_LD_FLAGS:-}"
EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 $DEP_LD_FLAGS"

# --- 4. Configure ---
./configure \
  --prefix="${BUILD_DIR_FFMPEG}/${ANDROID_ABI}" \
  --enable-cross-compile \
  --target-os=android \
  --arch="${TARGET_TRIPLE_MACHINE_ARCH}" \
  --sysroot="${SYSROOT_PATH}" \
  --cc="${FAM_CC}" \
  --cxx="${FAM_CXX}" \
  --ld="${FAM_LD}" \
  --ar="${FAM_AR}" \
  --as="${FAM_CC}" \
  --nm="${FAM_NM}" \
  --ranlib="${FAM_RANLIB}" \
  --strip="${FAM_STRIP}" \
  --extra-cflags="-O3 -fPIC -flto -fno-math-errno -fno-trapping-math -funroll-loops $EXTRA_CFLAGS $DEP_CFLAGS" \
  --extra-ldflags="-O3 -flto ${EXTRA_LDFLAGS}" \
  --enable-shared \
  --disable-static \
  --disable-debug \
  --disable-doc \
  --disable-programs \
  --enable-pthreads \
  --enable-optimizations \
  --enable-hardcoded-tables \
  ${ADDITIONAL_COMPONENTS} \
  ${EXTRA_BUILD_CONFIGURATION_FLAGS} \
  --pkg-config="${PKG_CONFIG_EXECUTABLE}"

# --- 5. Build ---
"${MAKE_EXECUTABLE}" clean
"${MAKE_EXECUTABLE}" -j"${HOST_NPROC}"
"${MAKE_EXECUTABLE}" install

