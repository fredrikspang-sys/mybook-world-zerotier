#!/bin/bash
# Build tun.ko (Universal TUN/TAP driver) for the WD My Book World Edition II
# (Oxsemi OX810, firmware 01.02.14, kernel 2.6.24.4, vermagic "2.6.24.4 mod_unload ARMv5").
#
# Usage: scripts/build_tun.sh            (run from the repo root, on an x86_64 Linux host)
#   WORKDIR=/some/dir scripts/build_tun.sh
# Output: $WORKDIR/tun.ko
set -euo pipefail
unset CFLAGS CXXFLAGS LDFLAGS CPPFLAGS   # host flags must not leak into the kernel build

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="${WORKDIR:-$REPO/work}"
JOBS="${JOBS:-$(nproc)}"

KERNEL_TAG="v2.6.24.4-WD-MyBookWorld-v1.02.14-GPL"
KERNEL_URL="https://github.com/superna9999/linux/archive/refs/tags/${KERNEL_TAG}.tar.gz"
KERNEL_DIR="$WORKDIR/linux-2.6.24.4-WD-MyBookWorld-v1.02.14-GPL"

TC_NAME="gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabi"
TC_URL="https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/arm-linux-gnueabi/${TC_NAME}.tar.xz"
TC_URL_MIRROR="https://dl.armbian.com/_toolchain/${TC_NAME}.tar.xz"

mkdir -p "$WORKDIR"; cd "$WORKDIR"

echo "### downloading WD GPL kernel source ($KERNEL_TAG)"
[ -f kernel.tar.gz ] || curl -L --fail -o kernel.tar.gz "$KERNEL_URL"
[ -d "$KERNEL_DIR" ] || tar xzf kernel.tar.gz

echo "### downloading Linaro GCC 4.9.4 arm-linux-gnueabi"
if [ ! -d "$TC_NAME" ]; then
	curl -L --fail -o toolchain.tar.xz "$TC_URL" || curl -L --fail -o toolchain.tar.xz "$TC_URL_MIRROR"
	tar xJf toolchain.tar.xz
fi
export PATH="$WORKDIR/$TC_NAME/bin:$PATH"

echo "### patching kernel Makefile for GNU make >= 3.82"
cd "$KERNEL_DIR"
if ! grep -q '^%config: scripts_basic' Makefile; then
	patch -p1 < "$REPO/patches/wd-kernel-2.6.24.4-make4.patch"
fi

MK="make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-"
echo "### configuring: WD production defconfig + CONFIG_TUN=m"
$MK oxnas_810_eabi_wd_prod_defconfig
sed -i -e 's/^# CONFIG_TUN is not set/CONFIG_TUN=m/' .config
yes '' | $MK oldconfig >/dev/null
grep -q '^CONFIG_TUN=m' .config
diff -q <(sed 1,5d .config) <(sed 1,5d "$REPO/patches/kernel.config") >/dev/null && echo "    .config identical to patches/kernel.config" \
	|| echo "    WARNING: .config differs from patches/kernel.config"

echo "### make modules_prepare + drivers/net/tun.ko"
$MK -j"$JOBS" modules_prepare
rm -f drivers/net/tun.o drivers/net/tun.ko drivers/net/tun.mod.*
$MK drivers/net/tun.ko
cp drivers/net/tun.ko "$WORKDIR/tun.ko"

echo "### result"
file "$WORKDIR/tun.ko"
strings "$WORKDIR/tun.ko" | grep '^vermagic='
