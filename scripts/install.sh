#!/bin/sh
# Install tun.ko + ZeroTier One + boot script on a WD My Book World Edition II.
# Run ON THE NAS as root (busybox sh), from a directory containing this repo's bin/ and scripts/:
#   sh scripts/install.sh
# It does NOT join any network; do that yourself afterwards.
set -e
HERE="$(cd "$(dirname "$0")/.." && pwd)"
KVER=2.6.24.4
MODDIR=/lib/modules/$KVER/kernel/drivers/net
ZT_DIR=/DataVolume/zerotier
STAMP=$(date +%Y%m%d%H%M%S)

[ "$(uname -r)" = "$KVER" ] || { echo "kernel is $(uname -r), expected $KVER - aborting"; exit 1; }
case "$(uname -m)" in armv5*) ;; *) echo "unexpected arch $(uname -m) - aborting"; exit 1;; esac
grep -q ' /DataVolume ' /proc/mounts || { echo "/DataVolume is not mounted - aborting"; exit 1; }

# Check vermagic of tun.ko and of an existing WD module before loading anything
# (busybox 1.1.1 has no strings/tr/grep -o, so match the exact string)
VERMAGIC="vermagic=2.6.24.4 mod_unload ARMv5"
grep -q "$VERMAGIC" "$HERE/bin/tun.ko" || { echo "tun.ko does not have '$VERMAGIC' - aborting"; exit 1; }
if [ -f "$MODDIR/mii.ko" ] && ! grep -q "$VERMAGIC" "$MODDIR/mii.ko"; then
	echo "this NAS's own modules are not '$VERMAGIC' - aborting"; exit 1
fi

echo "== tun.ko -> $MODDIR/tun.ko"
[ -f "$MODDIR/tun.ko" ] && cp -p "$MODDIR/tun.ko" "$MODDIR/tun.ko.bak-$STAMP"
cp "$HERE/bin/tun.ko" "$MODDIR/tun.ko"; chmod 644 "$MODDIR/tun.ko"

echo "== zerotier-one -> $ZT_DIR"
mkdir -p "$ZT_DIR/var"
if [ -f /etc/init.d/zerotier ]; then /etc/init.d/zerotier stop || true; fi
[ -f "$ZT_DIR/zerotier-one" ] && cp -p "$ZT_DIR/zerotier-one" "$ZT_DIR/zerotier-one.bak-$STAMP"
cp "$HERE/bin/zerotier-one" "$ZT_DIR/zerotier-one"; chmod 755 "$ZT_DIR/zerotier-one"
ln -sf zerotier-one "$ZT_DIR/zerotier-cli"
ln -sf zerotier-one "$ZT_DIR/zerotier-idtool"

echo "== /etc/init.d/zerotier + S99zerotier"
[ -f /etc/init.d/zerotier ] && cp -p /etc/init.d/zerotier "/etc/init.d/zerotier.bak-$STAMP"
cp "$HERE/scripts/init.d/zerotier" /etc/init.d/zerotier; chmod 755 /etc/init.d/zerotier
ln -sf zerotier /etc/init.d/S99zerotier
sync

/etc/init.d/zerotier start
sleep 5
/etc/init.d/zerotier status || true
echo
echo "Next: $ZT_DIR/zerotier-cli -D$ZT_DIR/var join <NETWORK_ID>"
echo "then authorize the node in ZeroTier Central (or your controller)."
