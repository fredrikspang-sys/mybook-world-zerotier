# mybook-world-zerotier

ZeroTier One and a TUN/TAP kernel module for the **WD My Book World Edition II** ("white light") NAS.
It includes prebuilt binaries, the patches, and the scripts to rebuild everything yourself.

The stock firmware ships no `tun` driver, and its userland (glibc 2.3.4, kernel 2.6.24.4)
is far too old for any official ZeroTier build. This repo provides:

| File | What |
|------|------|
| `bin/tun.ko` | Universal TUN/TAP driver built from WD's own GPL kernel source, vermagic `2.6.24.4 mod_unload ARMv5` |
| `bin/zerotier-one` | ZeroTier One 1.10.6, fully static (musl), ARMv5TE soft-float EABI, with a NOARP fix for old kernels |
| `scripts/init.d/zerotier` | Boot script (start/stop/restart/status/save/cli) for the WD firmware's `/etc/init.d/S??*` mechanism; keeps ZeroTier's state in RAM so the disks can spin down |
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
/etc/init.d/zerotier cli join <NETWORK_ID>
/etc/init.d/zerotier save                 # keep the membership across reboots (see below)
/etc/init.d/zerotier cli info             # shows your node ID
/etc/init.d/zerotier cli listnetworks     # status becomes OK after authorization
```

`/etc/init.d/zerotier cli ...` runs `zerotier-cli` against the home directory the daemon is actually
using (RAM or disk), so you don't need to know which one it is.

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

### State in RAM (lets the disks spin down)

The NAS spins its disks down only after 10 minutes without any disk I/O (the firmware's
`/usr/bin/monitorio.sh` watches `/proc/diskstats` and then runs `hdparm -y`). ZeroTier
rewrites `networks.d/<NETWORK_ID>.conf` in its home directory about **every 60 seconds**
(each time it refreshes the network config from the controller), plus `peers.d/` now and then.
With the home on `/DataVolume`, those small writes alone keep the disks spinning forever.
`/`, `/var` and `/DataVolume` are all RAID partitions on the same disks, so there's no
"other" disk to move them to.

The init script therefore runs the daemon with its home in **`/mnt/ram/zerotier`**. That's the
firmware's own tmpfs (`/dev/ram0`, mounted by `S01auto_mountd`, which `rcS` runs long before `S99zerotier`).

- **`/DataVolume/zerotier/var` is the persistent seed.** On every start, if the RAM home has no
  identity yet (e.g. after a reboot), the script copies `identity.*`, `authtoken.secret`, `planet`,
  `networks.d/`, `moons.d/` and `peers.d/` from the seed into RAM. The node ID and the assigned
  IPs therefore stay the same across reboots.
- **The identity never leaves the NAS.** It's only copied between the NAS's own disk and RAM.
  On the very first start (empty seed), the identity ZeroTier generates in RAM is saved to the seed
  right away. `save` never overwrites an identity that already exists in the seed. If the two
  differ, it only prints a warning.
- **After joining (or leaving) a network, run `/etc/init.d/zerotier save`.** It copies `networks.d/*.conf`
  (and moons) from RAM back to the seed. `stop` and `restart` also save, but at shutdown the firmware
  may unmount `/DataVolume` before `S99zerotier stop` runs, so don't rely on that. Leaving a network
  is never mirrored automatically, as a safety measure. After `cli leave <NETWORK_ID>`, delete
  `/DataVolume/zerotier/var/networks.d/<NETWORK_ID>.conf` and `<NETWORK_ID>.local.conf` yourself.
- **Fallback:** if `/mnt/ram` isn't mounted, the daemon runs directly from the disk home, as before.
  Set `ZT_RAM_HOME=` at the top of the script to `auto` (default), `yes` (RAM only; refuse to start
  without `/mnt/ram`) or `no` (always the disk home).
- The RAM home uses well under 100 KB of the ~62 MB tmpfs.

Other things that can keep these NASes awake: the firmware's `syslogd` and `mini_httpd` log to
`/var/log`, which is a symlink to `/tmp` on the root RAID (`md0`), **not** tmpfs. One LAN device
probing the web UI every few minutes is enough to keep the disks spinning. Pointing those logs
to `/mnt/ram` too (`syslogd -O /mnt/ram/messages`, `mini_httpd -l /mnt/ram/mini_httpd.log`) fixes that.
`mini_httpd` is started by `rcS` before `/mnt/ram` is mounted, so it needs a guard or a restart later in boot.
You can check what is still writing with `echo 1 > /proc/sys/vm/block_dump; sleep 300; dmesg; echo 0 > /proc/sys/vm/block_dump`.

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

## See also

- [mybook-world-openssh](https://github.com/fredrikspang-sys/mybook-world-openssh): a static OpenSSH 10.6p1
  for the same NAS. It replaces the stock OpenSSH 3.9p1, so you no longer need the legacy client options,
  and the web GUI SSH toggle keeps working.

## Licenses

See [LICENSES.md](LICENSES.md). In short:

- the scripts and docs in this repo are MIT;
- `bin/tun.ko` is GPL-2.0 (Linux kernel);
- `bin/zerotier-one` is ZeroTier One 1.10.6 under the ZeroTier BSL 1.1 terms in
  `licenses/ZeroTier-LICENSE.txt`, plus bundled third-party code.
