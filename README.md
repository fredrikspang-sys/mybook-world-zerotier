# mybook-world-zerotier

ZeroTier One and a TUN/TAP kernel module for the **WD My Book World Edition II** ("white light") NAS.
It includes prebuilt binaries, the patches, and the scripts to rebuild everything yourself.

The stock firmware ships no `tun` driver, and its userland (glibc 2.3.4, kernel 2.6.24.4)
is far too old for any official ZeroTier build. This repo provides:

| File | What |
|------|------|
| `bin/tun.ko` | Universal TUN/TAP driver built from WD's own GPL kernel source, vermagic `2.6.24.4 mod_unload ARMv5` |
| `bin/zerotier-one` | ZeroTier One 1.10.6, fully static (musl), ARMv5TE soft-float EABI, with a NOARP fix for old kernels |
| `scripts/init.d/zerotier` | Boot script (start/stop/restart/status) for the WD firmware's `/etc/init.d/S??*` mechanism |
| `scripts/install.sh` | Installer that runs on the NAS |
| `scripts/build_tun.sh`, `scripts/build_zt.sh` | Rebuild both binaries from source on an x86_64 Linux host |
| `patches/` | All source changes (kernel Makefile, ZeroTier makefile, NOARP fix) plus the exact kernel `.config` |

## Tested on

- WD My Book World Edition II (WDH2NC), Oxsemi OX810 (ARM926EJ-S, `armv5tejl`), 128 MB RAM
- WD firmware **01.02.14**, kernel `Linux 2.6.24.4 #1 Thu Apr 1 16:43:58 CST 2010 armv5tejl`
- Root shell over SSH (see the community "Hacking WD MyBook World Ed" wiki for how to enable it)

Other firmware versions with a different kernel build will most likely **not** accept `tun.ko`
(the vermagic and the kernel config must match). The installer checks the vermagic before installing.

## ⚠ Use at your own risk

This loads a kernel module and runs a network daemon as root on an old, unsupported NAS.
An incompatible kernel module can crash the kernel. Nothing here touches the firmware, flash,
or boot partitions, but there is **no warranty** of any kind. Back up your data first.

## Quick install (prebuilt binaries)

From your computer (use your NAS's address and SSH settings; the stock sshd may need legacy
algorithms, e.g. `-oKexAlgorithms=+diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa`):

```sh
sha256sum -c bin/SHA256SUMS
tar cf - bin scripts | ssh root@<NAS_IP> 'mkdir -p /DataVolume/zerotier-install && cd /DataVolume/zerotier-install && tar xf -'
ssh root@<NAS_IP> 'cd /DataVolume/zerotier-install && sh scripts/install.sh'
```

`install.sh`:

- checks the kernel version, the CPU architecture, that `/DataVolume` is mounted, and the vermagic;
- copies `tun.ko` to `/lib/modules/2.6.24.4/kernel/drivers/net/`;
- copies `zerotier-one` to `/DataVolume/zerotier/`, with the `zerotier-cli` and `zerotier-idtool` symlinks;
- installs `/etc/init.d/zerotier` and links it as `/etc/init.d/S99zerotier`.

It backs up any file it replaces (`*.bak-<timestamp>`), then starts the daemon.

Then join your network and authorize the node in ZeroTier Central:

```sh
cd /DataVolume/zerotier
./zerotier-cli -D/DataVolume/zerotier/var join <NETWORK_ID>
./zerotier-cli -D/DataVolume/zerotier/var info          # shows your node ID
./zerotier-cli -D/DataVolume/zerotier/var listnetworks  # status becomes OK after authorization
```

### Manual install

```sh
insmod /lib/modules/2.6.24.4/kernel/drivers/net/tun.ko
grep tun /proc/misc                         # -> "200 tun"
[ -c /dev/net/tun ] || { mkdir -p /dev/net; mknod /dev/net/tun c 10 200; }
mkdir -p /DataVolume/zerotier/var
/DataVolume/zerotier/zerotier-one -d /DataVolume/zerotier/var >/dev/null 2>&1 </dev/null
```

Redirect the output when starting the daemon over SSH. Otherwise the session stays open,
because the daemon inherits its file descriptors.

### Boot startup

The WD firmware boots via busybox `init` → `/etc/inittab` → `/etc/init.d/rcS`, which runs every
`/etc/init.d/S??*` with `start` in glob order. At shutdown, `rcH` runs them with `stop`.
The root filesystem (ext3 on `/dev/md0`) is persistent.

`S99zerotier` therefore runs after the network (`S40network`) and the shares. The script:

- loads `tun.ko` if needed and creates `/dev/net/tun` if it is missing;
- waits up to 60 s for `/DataVolume` (in the background, so boot is not delayed);
- starts the daemon.

It logs to syslog with the tag `zerotier`. To disable it: `rm /etc/init.d/S99zerotier`.

## Build it yourself

Requirements: an x86_64 Linux host with `gcc`, `make`, `curl`, `patch`, `xz` and `file`. No root is needed.

```sh
scripts/build_tun.sh    # -> work/tun.ko
scripts/build_zt.sh     # -> work/zerotier-one
```

(`WORKDIR=/path` changes the work directory; `JOBS=N` sets parallelism.)

### tun.ko

- **Source:** WD's GPL kernel for firmware 01.02.14, mirrored at
  [superna9999/linux, tag `v2.6.24.4-WD-MyBookWorld-v1.02.14-GPL`](https://github.com/superna9999/linux/releases/tag/v2.6.24.4-WD-MyBookWorld-v1.02.14-GPL).
- **Config:** WD's `oxnas_810_eabi_wd_prod_defconfig` with `CONFIG_TUN=m`. The resulting `.config` is in
  `patches/kernel.config`. The modules it builds are exactly the ones on the stock NAS, plus `tun`.
- **Toolchain:** Linaro GCC 4.9.4 `arm-linux-gnueabi` (2017.01). WD's original kernel was built with GCC 4.2.4.
  This kernel has no MODVERSIONS, so only the vermagic and the struct layouts (i.e. the config) have to match.
- **`patches/wd-kernel-2.6.24.4-make4.patch`:** fixes `mixed implicit and normal rules` errors with GNU make ≥ 3.82.
- **Host flags:** the scripts unset `CFLAGS`, `CXXFLAGS` and `LDFLAGS`. A host `LDFLAGS=-Wl,--as-needed`, for example,
  breaks the kernel's module link.

### zerotier-one

- **Source:** [ZeroTierOne tag `1.10.6`](https://github.com/zerotier/ZeroTierOne/tree/1.10.6).
- **Toolchain:** musl.cc `armv5l-linux-musleabi-cross` (GCC 11.2.1, musl). Linked fully static and **non-PIE**.
- **Build options:** `ZT_SSO_SUPPORTED=0` (no Rust/OIDC), `CC_MACH=arm`.
- **Kernel compatibility:** musl falls back to older syscalls where it needs to. ZeroTier itself uses no syscalls
  newer than 2.6.24, and it reads `/dev/urandom` instead of calling `getrandom`. The binary uses only 32-bit atomics
  (kernel helpers present since 2.6.12), not the 64-bit `kuser_cmpxchg64`, which needs kernel 3.1.
- **`patches/zt-1.10.6-make-linux-armv5te-softfloat.patch`:** `make-linux.mk` only picks soft-float flags when `dpkg`
  reports `armel`; otherwise it forces hard-float armv6. The patch always uses
  `-march=armv5te -mtune=arm926ej-s -mfloat-abi=soft -marm -mno-unaligned-access`.
- **`patches/zt-1.10.6-noarp-fix.patch`:** see below.

## The NOARP bug (and the fix)

On "old" kernels, which `isOldLinuxKernel()` detects (< 3.x), `LinuxEthernetTap.cpp` does the following:

1. `SIOCGIFFLAGS` (reads the flags into `struct ifreq`);
2. `SIOCSIFHWADDR` (writes the MAC into the same `ifreq` union);
3. `SIOCSIFMTU` (writes the MTU into the same union);
4. `ifr.ifr_flags |= IFF_UP | IFF_MULTICAST; SIOCSIFFLAGS`.

`ifr_flags`, `ifr_hwaddr` and `ifr_mtu` share one union, so step 4 uses the MTU (2800 = `0x0AF0`) as the flags.
That sets `IFF_NOARP`, `IFF_NOTRAILERS` and `IFF_ALLMULTI` on the `zt*` interface.

With NOARP the kernel never sends ARP requests and uses the interface's own MAC as the destination.
Everything looks fine (network `OK`, IP assigned) but **no traffic passes**: pings get 100% loss and
the `zt*` interface has no ARP entries.

The fix re-reads the flags right before setting `IFF_UP`:

```diff
+		ioctl(sock,SIOCGIFFLAGS,(void *)&ifr);
 		ifr.ifr_flags |= IFF_MULTICAST;
 		ifr.ifr_flags |= IFF_UP;
```

With an unpatched binary, the workaround is `ifconfig <zt-device> arp` after every start.

## Known limitations

- **No IPv6.** The stock kernel has no IPv6, so ZeroTier works over IPv4 only (on both the underlay and the virtual network).
- **ZeroTier 1.10.6, without SSO/OIDC.** No Rust or OpenSSL, and no web UI; manage it with `zerotier-cli`.
  Newer releases need Rust for the default build.
- **About 5–6 MB RSS** for the daemon, against 128 MB RAM.
- **Throughput** is limited by the 200 MHz-class ARM9 CPU, which does all the crypto in software.
- **Firmware specific.** `tun.ko` only fits firmware 01.02.14 / kernel `2.6.24.4 mod_unload ARMv5`.
- **No automatic updates.** Rebuild with a newer tag at your own risk.

## Licenses

See [LICENSES.md](LICENSES.md). In short:

- the scripts and docs in this repo are MIT;
- `bin/tun.ko` is GPL-2.0 (Linux kernel);
- `bin/zerotier-one` is ZeroTier One 1.10.6 under the ZeroTier BSL 1.1 terms in
  `licenses/ZeroTier-LICENSE.txt`, plus bundled third-party code.
