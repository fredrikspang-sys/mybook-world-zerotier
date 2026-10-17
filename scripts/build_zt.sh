#!/bin/bash
# Build a fully static ZeroTier One 1.10.6 for ARMv5TE soft-float EABI (musl),
# for old kernels such as the WD My Book World Edition II (Linux 2.6.24.4, glibc 2.3.4).
#
# Usage: scripts/build_zt.sh             (run from the repo root, on an x86_64 Linux host)
#   WORKDIR=/some/dir scripts/build_zt.sh
# Output: $WORKDIR/zerotier-one (stripped)
set -euo pipefail
unset CFLAGS CXXFLAGS LDFLAGS CPPFLAGS

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="${WORKDIR:-$REPO/work}"
JOBS="${JOBS:-$(nproc)}"

ZT_VERSION="1.10.6"
ZT_URL="https://github.com/zerotier/ZeroTierOne/archive/refs/tags/${ZT_VERSION}.tar.gz"
ZT_DIR="$WORKDIR/ZeroTierOne-${ZT_VERSION}"

TC_NAME="armv5l-linux-musleabi-cross"
TC_URL="https://musl.cc/${TC_NAME}.tgz"
T=armv5l-linux-musleabi

mkdir -p "$WORKDIR"; cd "$WORKDIR"

echo "### downloading musl.cc $TC_NAME toolchain"
if [ ! -d "$TC_NAME" ]; then
	curl -L --fail -o "$TC_NAME.tgz" "$TC_URL"
	tar xzf "$TC_NAME.tgz"
fi
export PATH="$WORKDIR/$TC_NAME/bin:$PATH"

echo "### downloading ZeroTierOne $ZT_VERSION"
[ -f "zt-$ZT_VERSION.tar.gz" ] || curl -L --fail -o "zt-$ZT_VERSION.tar.gz" "$ZT_URL"
[ -d "$ZT_DIR" ] || tar xzf "zt-$ZT_VERSION.tar.gz"

cd "$ZT_DIR"
echo "### applying patches"
for p in zt-1.10.6-make-linux-armv5te-softfloat.patch zt-1.10.6-noarp-fix.patch; do
	if patch -p1 -R --dry-run -s < "$REPO/patches/$p" >/dev/null 2>&1; then
		echo "    $p already applied"
	else
		patch -p1 < "$REPO/patches/$p"
	fi
done

echo "### building (static, non-PIE, no SSO/Rust)"
make -f make-linux.mk clean >/dev/null
make -f make-linux.mk -j"$JOBS" one \
	CC=$T-gcc CXX=$T-g++ CC_MACH=arm ZT_SSO_SUPPORTED=0 ZT_STATIC=1 \
	CFLAGS="-O2 -fstack-protector" CXXFLAGS="-O2 -fstack-protector" LDFLAGS="-static -no-pie"
$T-strip -o "$WORKDIR/zerotier-one" zerotier-one

echo "### result"
ls -l "$WORKDIR/zerotier-one"
file "$WORKDIR/zerotier-one"
$T-readelf -A "$WORKDIR/zerotier-one" | grep -E 'Tag_CPU_arch:' || true
$T-readelf -l "$WORKDIR/zerotier-one" | grep -qi interp && echo "WARNING: not static" || echo "    static, no PT_INTERP"
# 64-bit atomics would need kuser cmpxchg64 (kernel >= 3.1); make sure none are used
if $T-nm zerotier-one | grep -qE '__kernel_cmpxchg64|__check_for_sync8_kernelhelper'; then
	echo "WARNING: binary uses 64-bit kernel atomic helpers (not available on 2.6.24)"
fi
