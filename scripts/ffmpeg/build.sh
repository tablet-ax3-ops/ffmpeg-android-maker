#!/usr/bin/env bash

# --- 1. OTTIMIZZAZIONI ARCHITETTURA (Focus su ARM NEON) ---
case $ANDROID_ABI in
  x86)
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --disable-asm"
    ;;
  x86_64)
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --x86asmexe=${NASM_EXECUTABLE}"
    ;;
  armeabi-v7a)
    # Forza NEON e ottimizzazioni per CPU a 32bit (VFPv3 è il minimo per performance decenti)
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-asm --enable-inline-asm --enable-neon"
    EXTRA_CFLAGS="-mfloat-abi=softfp -mfpu=neon"
    ;;
  arm64-v8a)
    # 64-bit: NEON è standard, ma abilitiamo l'ottimizzazione specifica per i registri estesi
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-asm --enable-inline-asm --enable-neon"
    ;;
esac

# --- 2. CONFIGURAZIONE DEI COMPONENTI (Massima Dieta) ---
# Disabilitiamo tutto e riaccendiamo solo il bisturi per GoPro
ADDITIONAL_COMPONENTS="--disable-everything \
  --enable-decoder=hevc \
  --enable-parser=hevc \
  --enable-demuxer=mov,mp4,hevc \
  --enable-protocol=file,pipe"

# --- 3. PARAMETRI DI COMPILAZIONE ---
DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib $FFMPEG_EXTRA_LD_FLAGS"
EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 $DEP_LD_FLAGS"

# Lancio della configurazione
./configure \
  --prefix=${BUILD_DIR_FFMPEG}/${ANDROID_ABI} \
  --enable-cross-compile \
  --target-os=android \
  --arch=${TARGET_TRIPLE_MACHINE_ARCH} \
  --sysroot=${SYSROOT_PATH} \
  --cc=${FAM_CC} \
  --cxx=${FAM_CXX} \
  --ld=${FAM_LD} \
  --ar=${FAM_AR} \
  --as=${FAM_CC} \
  --nm=${FAM_NM} \
  --ranlib=${FAM_RANLIB} \
  --strip=${FAM_STRIP} \
  \
  --extra-cflags="-O3 -fPIC -ffast-math -flto -funroll-loops $EXTRA_CFLAGS $DEP_CFLAGS" \
  --extra-ldflags="-O3 -flto $EXTRA_LDFLAGS" \
  \
  --enable-shared \
  --disable-static \
  --disable-debug \
  --disable-doc \
  --disable-programs \
  --disable-avdevice \
  --disable-postproc \
  --disable-avfilter \
  --disable-network \
  --disable-vulkan \
  \
  --enable-pthreads \
  --enable-optimizations \
  --enable-hardcoded-tables \
  --enable-runtime-cpudetect \
  \
  ${ADDITIONAL_COMPONENTS} \
  ${EXTRA_BUILD_CONFIGURATION_FLAGS} \
  --pkg-config=${PKG_CONFIG_EXECUTABLE} || exit 1

# Compilazione parallela sfruttando tutti i core della macchina (GitHub Actions ne ha solitamente 2 o 4)
${MAKE_EXECUTABLE} clean
${MAKE_EXECUTABLE} -j${HOST_NPROC}
${MAKE_EXECUTABLE} install
