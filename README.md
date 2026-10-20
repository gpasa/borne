<p align="center"><img src="scripts/icon/icon-1024.png" width="160" alt="Borne icon"></p>

# Borne

**A native macOS front end for [MAME](https://www.mamedev.org) and the classic id Software games, in the spirit of MAMEUI.**

Borne (French for *arcade cabinet*) puts your MAME collection in a familiar three-pane window:
folders on the left, the list of games in the middle, the artwork and details on the right.
Double-click a game and play.

![Borne](website/images/borne-window.png)

*Site (French): [borne.pasahome.org](https://borne.pasahome.org)*

## Features

- **MAMEUI-style folders**: available, favorites, parents and clones, working, vertical screens,
  manufacturer, year, driver, CPU…
- **Fast with the full catalogue**: 43 000+ machines, filtering and sorting never freeze the window.
- **Games on an external drive, read-only**: Borne never writes there. Settings, save states,
  NVRAM, high scores and snapshots go to `~/Library/Application Support/Borne/MAME`.
- **Install on this Mac**: copy a game (or all favorites) with its parent, BIOS, devices and
  samples, so it runs without the external drive. Local copies always come first.
- **ROM audit** in the background (`-verifyroms`), interruptible, results shown as they come.
- **Mac keyboard layout**: player 1 buttons on `Z X C V B N` instead of `Ctrl`
  (macOS keeps `Ctrl`+arrows for Mission Control), and a key reminder when a game starts.
- **MAME included**: version 0.289, native on Apple silicon and Intel, nothing else to install.
- **PC games**: point Borne at your game files and it finds them, add-ons grouped with their game:
  Doom, Doom II, Final Doom, Heretic, Hexen, Strife, Chex Quest, HacX and WAD mods; Quake, its mission
  packs and mods; Quake II, The Reckoning, Ground Zero and Capture The Flag; Quake III Arena and Team Arena; Return to Castle Wolfenstein (one entry per
  language); Wolfenstein 3D and Spear of Destiny; Doom 3 and Resurrection of Evil; Quake 4; Duke Nukem
  3D, Blood, Shadow Warrior, Redneck Rampage, Exhumed, NAM, WW2GI. New files are picked up as soon as
  they appear in the folder.
  Included engines: UZDoom (GZDoom on Intel and before macOS 26), vkQuake, Yamagi Quake II, Quake3e,
  iortcw, dhewm3, ECWolf. Downloaded on request, checksum verified: openQ4 (Quake 4, Apple silicon), Raze (Build
  games, built by Borne), the Quake III 1.32, Quake 4 1.4.2 and Doom 3 1.3.1 updates (after you
  accept id Software's licenses in Borne; original discs predate them) and
  [Freedoom](https://freedoom.github.io), a free Doom. **Settings → Data** downloads all of them at
  once. Saves and settings stay in the user folder, never next to your game files.
- **Vulkan on Metal**: KosmicKrisp (Mesa) on Apple silicon with macOS 26, MoltenVK elsewhere;
  switchable in Settings.

## Download

Signed and notarized builds, macOS 14 or later:

- **Apple silicon** (M1 and later): [Borne-AppleSilicon.zip](https://github.com/gpasa/borne/releases/latest/download/Borne-AppleSilicon.zip)
- **Intel**: [Borne-Intel.zip](https://github.com/gpasa/borne/releases/latest/download/Borne-Intel.zip)

Not sure? Apple menu → About This Mac: *Chip Apple M…* means Apple silicon, *Processor Intel* means Intel.
All versions are on the [Releases](https://github.com/gpasa/borne/releases) page.

Borne does **not** include any ROMs. Use only games you are entitled to.

## Build from source

Requirements: Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), the
[SDL3](https://github.com/libsdl-org/SDL/releases) framework in `/Library/Frameworks`.

```bash
# MAME, next to this repository
git clone --depth 1 --branch mame0289 https://github.com/mamedev/mame.git ../MAME
make -C ../MAME -j$(sysctl -n hw.ncpu)

# Optional, for the Intel version: MAME for x86_64, built under Rosetta
git clone --depth 1 --branch mame0289 https://github.com/mamedev/mame.git ../MAME-x64
arch -x86_64 make -C ../MAME-x64 -j$(sysctl -n hw.ncpu)

# Borne, with MAME bundled, installed in ~/Applications
scripts/deploy.sh
```

`scripts/release.sh` builds both versions, signs them with a Developer ID, notarizes and zips them.

## License

Borne is free software under the **GNU General Public License v3.0** (`LICENSE`).
Contributions follow the DCO (`CONTRIBUTING.md`).

The app bundles third-party software under their own licenses, included in
`Borne.app/Contents/Resources/Licenses`:

- **MAME** 0.289, © MAMEdev and contributors, GPL-2.0-or-later (with parts under BSD-3-Clause
  and other compatible licenses). The bundled binary is built, unmodified, from the
  [`mame0289` tag](https://github.com/mamedev/mame/tree/mame0289); the commands above rebuild it.
- **SDL3** 3.2.28, zlib license.
- **UZDoom** 5.0.3 (Apple silicon, macOS 26), GPL-3.0 and others, built here with a patch that
  clears its render targets (`engines/patches`; without it, the image turns green with recent
  MoltenVK). **GZDoom** 4.14.2 (Intel and older macOS), built here. License texts inside each engine.
  GZDoom and Raze are built with `engines/patches/zdoom-cocoa-cursor-warp.patch`: the official builds
  recenter the pointer with a synthetic event, for which macOS asks for Accessibility access in
  Borne's name (`scripts/build_zdoom_ports.sh`).
- **vkQuake** 1.37.0, GPL-2.0, built with a small patch (`engines/patches`) to go through the Vulkan
  loader; **Vulkan-Loader**, Apache-2.0; **MoltenVK** 1.4.2, Apache-2.0; **KosmicKrisp** from
  Mesa 26.2.5, MIT, with **SPIRV-Tools**, Apache-2.0 (Apple silicon only).
- **Quake3e**, official build, GPL-2.0. **iortcw**, built here, GPL-3.0 with additional terms.
- **ECWolf** 1.4.2, official build, GPL (see its `copyright` file).
- **Yamagi Quake II** 8.70 with the game code of The Reckoning (xatrix 2.17), Ground Zero (rogue
  2.16) and Capture The Flag (ctf 1.13), GPL-2.0, built here (`scripts/build_yquake2.sh`).
- **dhewm3** 1.5.5, GPL-3.0 with id's additional terms, built here (`scripts/build_dhewm3.sh`) with
  OpenAL Soft (LGPL) and a small patch to build its macOS port with SDL3 (`engines/patches`).
- Not bundled, downloaded on request: **openQ4** 0.13.2 (official release; GPL-3.0 and the Quake 4
  SDK license), **Raze** 1.11.0 (Borne's patched build, published as the
  [`raze-1.11.0-borne`](https://github.com/gpasa/borne/releases/tag/raze-1.11.0-borne) release;
  GPL-2.0 and the Build license), the **Quake III 1.32 patch**, the **Quake 4 1.4.2** and **Doom 3
  1.3.1 updates** (data files only, from id Software's official Linux patches; id Software licenses),
  **Freedoom** 0.13.0 (BSD-3-Clause). Copies of the redistributable ones (Freedoom, openQ4, Quake III
  patch with its license) are kept in the [`modules`](https://github.com/gpasa/borne/releases/tag/modules)
  release and used if the original source disappears; the Doom 3 and Quake 4 updates may not be
  redistributed, so they are not.

`scripts/prepare_engines.sh` downloads, builds and arranges all engines.

MAME is a registered trademark of Gregory Ember. Borne is an independent project, not
affiliated with or endorsed by the MAME team.
