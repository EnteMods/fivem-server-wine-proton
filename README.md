# Custom FXServer Linux x86-64 server build

**This repository is the native Linux x86-64 FXServer server build (ELF). It is not a macOS server build.** The tested client was a separate Apple Silicon Mac client running under Wine from [EnteMods/fivem-macos](https://github.com/EnteMods/fivem-macos); an M5 client join, resource load and basic game interaction were verified on 6 November 2026. Linux/Proton client support has not been tested. This is the project's **custom, pinned development build of the public FXServer source**, with controlled source build, compatibility packaging and isolated deployment setup. It still uses upstream's instance-wide `sv_lan true`; it is intended for an isolated, authorized test environment.

The `source-lan` branch is based on the tested upstream commit `88a413835e9d7f56633f249880a13f42297153a2`. The `master` branch is the upstream snapshot present when this fork was created; it is not the tested build. Do not merge or update a working deployment without the version and regression checks described below.

## What changed and what was tested

The original binary Recommended server in LAN mode supplied a `ci` resource URI that the source client could not mount. Building the matching public FXServer through upstream's public CI route resolved this mismatch. The existing Mac installation then completed resource download, protocol acknowledgement and game initialization; the owner confirmed movement, camera control and general interaction. No client URI rewriting or ci-provider imitation was added.

The public authentication and ticket source is unchanged. The separate public-development package omits only the unbuilt `svadhesive` metadata entry, following upstream `code/tools/ci/wsl-build.sh` at the pinned revision. Original component metadata is retained. No private security component is copied from the official binary distribution.

**This is not an OS-selective authentication exception.** LAN mode applies to Windows, macOS and Linux clients alike within this development instance. A client-reported OS is not platform attestation. Normal Cfx ticket issuance, regular anti-cheat integration and public-server compatibility remain unresolved. Native Linux/Proton-client gameplay has not been tested; the name describes the development target, not a completed compatibility matrix.

## What the server build does

This repository contains the public source and build recipe for a Linux x86-64 FXServer based on `88a413835e9d7f56633f249880a13f42297153a2`. Matching that source build to the tested client resolved the Recommended server's resource-mounter/CI-scheme mismatch described above. The resulting server executable targets Linux; the tested Apple Silicon Mac ran a separate Wine client.

The build does not add an operating-system check or platform-specific ticket bypass. Its `sv_lan true` setting affects every client connecting to that instance. The M5 join, resource load, movement and camera interaction were observed, but this does not establish normal Cfx ticket behavior, anti-cheat operation, or compatibility with public servers.

Private shutdown work is separate from the public source build. A private V4 patch adds an atomic stop path, `svMain` ownership/join handling, an interruptible Linux non-TTY reader, and launcher-side thread joining. Its Linux build exited 0 without the reported OOM, and five shutdown cycles passed (three non-TTY and two TTY, with the upstream process exit code 1). That patch is **not in the public source branch**. Its privately verified Runtime V3 package is now deployed to the owner's single isolated Linux server. The deployed service passed a real SIGINT stop with natural exit 1 and a restart; five mapped module hashes, selected resources and TCP/UDP responses were verified. The earlier client gameplay session has not been repeated on V4.

## Package files and size

The package includes launch and installation helpers, configuration, and records that explain what was built and how its contents can be checked. They do not turn this into a macOS server package.

| File | Purpose |
| --- | --- |
| `install.sh` | Installs the package into a new destination while offline; it does not install or start services. |
| `start-local.sh` | Foreground launcher requiring host Bash, using the selected configuration. |
| `run.sh` | Starts the bundled musl loader used by the server executable. |
| `example-lan.cfg` | Loopback TCP/UDP port 30120, GTA V Legacy game build 3889, a four-client limit and five example resources. |
| `INSTALL-INVENTORY.json` | Records file hashes, modes and symlink targets. The V3 verifier additionally checks the Git aliases' shared inode and link count. |
| `SHA256SUMS`, `<archive>.sha256` | Integrity hashes for package files and the external archive. Compare the archive hash with a separately trusted receipt. |
| `BUILD-PROOF.json` | Records build and compiler exit results. |
| `REBUILD-PROOF.json` | Records matched ELF/debug build IDs and CRCs. |
| `BUILD-SHUTDOWN-RECEIPT.json` | Records the five private source shutdown cycles; it does not prove another client join. |
| `EXTERNAL-SYMBOLS.json` | In Runtime V3, identifies the exact 34 `.dbg` files retained in the optional Full V2 developer/symbol bundle. |
| `FULL-V2-INVENTORY.json` | Provenance anchor for the Full V2 archive. |
| `SOURCE-AND-NOTICES.json`, `SOURCE-GAPS.txt` | Factual source and license inventory plus unresolved gaps; these are not legal clearance. |

The Full V2 private archive is 555,324,540 bytes (about 530 MiB). Most of the removable bulk is debug-symbol data: 34 `.dbg` files account for 534,440,944 uncompressed bytes, including `libnode22.so.dbg` at 385,872,304 bytes. Expanded Git aliases add 401,932,176 bytes of duplicate file contents. These are raw file sizes, not separate contributions that can be subtracted directly from the compressed download size.

Runtime V3 is a packaging revision of the same V4 source binaries. Its measured archive is **74,514,616 bytes (about 71 MiB)**, compared with **555,324,540 bytes (about 530 MiB)** for Full V2. It removes only the 34 `.dbg` files, retaining their exact external-symbol references, and restores the original 139 Git-alias hardlinks in the independent output. All shipped server ELF files, other runtime dependencies and resources remain byte-identical. Fresh extraction, installation, both rootfs shutdown paths and the isolated Ubuntu/Bash foreground launcher passed; Git inode/link counts were checked inside the test containers. The private Full V2 remains the optional developer/symbol bundle. Neither archive is a public download.

The packages contain no GTA/RPF data or private client DLLs. Full V2 has passed fresh-install, two root-filesystem stop checks and host-Bash checks, but it is not approved for public binary distribution: the CPLA/corresponding-source and notices scope is still unresolved. The source publication and a binary release are separate decisions.

## Build, installation and release status

- [Pinned public build recipe](compatibility/PUBLIC_BUILD.md), including fixed inputs, isolated toolchain repairs, packaging and verification commands.
- [Installation and operating boundary](compatibility/INSTALL.md).
- [Test results and remaining checks](compatibility/TEST_RESULTS.md).
- [Known issues](compatibility/KNOWN_ISSUES.md).

The public source tree and recipe are available. Full V2 and the smaller Runtime V3 are completed, tested private owner packages; neither is a public binary download. Runtime V3 is the intended operator package, while Full V2 retains diagnostics for development. Corresponding-source and license/notices scope still needs resolution before public binary distribution. There is no macOS server build or DMG, and no verified Wine-to-game fresh-install workflow is claimed. The linked client repository documents its current installation-specific bindings and open bootstrap work.

Do not expose this LAN development configuration as a public Internet service. The successful test used a dedicated network guard, explicit IPv4 game ports and access restricted to the authorized test device. A LAN convar is not network isolation.

## AI-assisted work and contributions

The compatibility build/packaging work and documentation were developed with substantial help from AI coding agents under the project owner's direction. Upstream CitizenFX code retains its authorship. Independent review, reproducible tests and ordinary platform/API compatibility contributions are welcome. A legitimate supported solution for the missing `cfxTicket2` remains sought in the client project. Do not post credentials, ticket values, private addresses, game data or proprietary DLL payloads.

## Licensing and upstream

The upstream [LICENSE](LICENSE), [LICENSES](LICENSES) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) remain unchanged and apply to their respective components. The preserved [upstream README](compatibility/UPSTREAM_README.md) describes the original project. This fork is not endorsed by Cfx.re, Rockstar Games or Take-Two.

Independent original additions under `compatibility/` have the separately stated [No Sale license](compatibility/LICENSE.original-tooling.txt), with explicit exceptions for upstream-derived and third-party material. That restriction does not replace upstream licenses or relicense the FiveM source. The overall work is source-available; it is not described as universally OSI open source.
