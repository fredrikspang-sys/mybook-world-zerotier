# License notes

## Scripts, docs, patches written for this repo: MIT

See [LICENSE](LICENSE). This covers `scripts/`, `README.md`, and this file.
Patches to third-party code are additionally available under that code's own license.

## bin/tun.ko: GPL-2.0-only

`tun.ko` is the Linux kernel's Universal TUN/TAP driver (`drivers/net/tun.c`, (C) 1999-2004 Max Krasnyansky),
compiled from Western Digital's GPL release of the My Book World Edition kernel. The license text is in
`licenses/GPL-2.0.txt`.

Complete corresponding source (GPL-2.0 §3):

- **Kernel source:** WD-MyBookWorld-v1.02.14-GPL, kernel 2.6.24.4, mirrored at
  https://github.com/superna9999/linux, tag `v2.6.24.4-WD-MyBookWorld-v1.02.14-GPL`
  (https://github.com/superna9999/linux/archive/refs/tags/v2.6.24.4-WD-MyBookWorld-v1.02.14-GPL.tar.gz).
- **Build configuration:**
  - `patches/kernel.config` is the exact `.config` used;
  - `patches/kernel-defconfig-vs-config.diff` is its diff against WD's `arch/arm/configs/oxnas_810_eabi_wd_prod_defconfig`.
- **Source modification:** `patches/wd-kernel-2.6.24.4-make4.patch` (build system only).
- **Build script:** `scripts/build_tun.sh`.

If the mirror ever disappears, a copy of the source can be requested through this repo's issue tracker.

## bin/zerotier-one: ZeroTier One 1.16.2 (MPL-2.0)

- **Source:** https://github.com/zerotier/ZeroTierOne, tag `1.16.2`, unmodified except for
  `patches/zt-1.16.2-make-linux-armv5te-softfloat.patch`,
  `patches/zt-1.16.2-noarp-fix.patch`,
  `patches/zt-1.16.2-disable-recvmmsg.patch` and
  `patches/zt-1.16.2-httplib-so-reuseaddr.patch`.
- **License:** the 1.16.2 source tree's `LICENSE.txt` points at `LICENSE-MPL.txt` for `node/`, `osdep/`,
  `service/` and everywhere else except `ext/` and `nonfree/`. That MPL-2.0 text is reproduced verbatim in
  `licenses/ZeroTier-LICENSE-MPL.txt`. This build does not include the non-free controller
  (`ZT_NONFREE` is not set) and is built with `ZT_SSO_SUPPORTED=0`.
- **Our reading:** redistribution of this binary with the license text and source pointers, as here, is
  permitted under MPL-2.0. This is not legal advice; check the license text yourself for your use.
- **"ZeroTier" trademark:** belongs to ZeroTier, Inc. This is an unofficial community build, not affiliated with
  or endorsed by ZeroTier, Inc.

The previous prebuilt binary (ZeroTier One 1.10.6, [v1.2.0](https://github.com/fredrikspang-sys/mybook-world-zerotier/releases/tag/v1.2.0))
was under the Business Source License 1.1. That license text remains in `licenses/ZeroTier-LICENSE.txt`.

Third-party code statically linked into `zerotier-one` (license files in `licenses/`):

| Component | License |
|-----------|---------|
| miniupnpc (bundled in ZeroTierOne `ext/`) | BSD-3-Clause |
| libnatpmp (bundled) | BSD-3-Clause |
| http-parser (bundled) | MIT |
| nlohmann/json (bundled, header-only) | MIT |
| cpp-httplib (bundled, header-only) | MIT |
| inja (bundled, header-only) | MIT |
| prometheus-cpp-lite (bundled, header-only) | MIT |
| musl libc (toolchain) | MIT |
| libstdc++ / libgcc / libatomic (GCC 11.2.1, toolchain) | GPL-3.0 with the GCC Runtime Library Exception, which permits static linking into non-GPL programs |
