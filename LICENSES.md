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

## bin/zerotier-one: ZeroTier One 1.10.6 (BSL 1.1 / Apache-2.0 after Change Date)

- **Source:** https://github.com/zerotier/ZeroTierOne, tag `1.10.6`, unmodified except for
  `patches/zt-1.10.6-make-linux-armv5te-softfloat.patch` and `patches/zt-1.10.6-noarp-fix.patch`.
- **License:** the 1.10.6 source tree's `LICENSE.txt` is reproduced verbatim in `licenses/ZeroTier-LICENSE.txt`.
  It is the Business Source License 1.1 with ZeroTier's Additional Use Grant.
  - The BSL grants the right to "copy, modify, create derivative works, redistribute, and make non-production use".
  - The Additional Use Grant allows production use, except for (1) operating or selling ZeroTier roots, controllers
    or key generation as a for-profit service, (2) closed-source commercial derivative products, (3) commercial
    rebranding, and (4) certain government uses.
  - That file names **Change Date: 2025-01-01** and **Change License: Apache-2.0**. The BSL converts on the Change
    Date or on the 4th anniversary of the version's first public release, whichever comes first.
  - The license header still names "Licensed Work: ... 1.4.4", a stale header in upstream's file. It is the license
    file shipped with the 1.10.6 tag.
- **Our reading:** personal and non-commercial use and redistribution of this binary (with the license text and
  source pointers, as here) is permitted. Under the stated Change Date, 1.10.6 should now also be available under
  Apache-2.0. This is not legal advice; check the license text yourself for commercial use.
- **"ZeroTier" trademark:** belongs to ZeroTier, Inc. This is an unofficial community build, not affiliated with
  or endorsed by ZeroTier, Inc.

Third-party code statically linked into `zerotier-one` (license files in `licenses/`):

| Component | License |
|-----------|---------|
| miniupnpc (bundled in ZeroTierOne `ext/`) | BSD-3-Clause |
| libnatpmp (bundled) | BSD-3-Clause |
| http-parser (bundled) | MIT |
| nlohmann/json (bundled, header-only) | MIT |
| musl libc (toolchain) | MIT |
| libstdc++ / libgcc (GCC 11.2.1, toolchain) | GPL-3.0 with the GCC Runtime Library Exception, which permits static linking into non-GPL programs |
