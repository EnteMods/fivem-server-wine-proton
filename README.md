# Custom FXServer Linux x86-64 server build

**This repository is the native Linux x86-64 FXServer server build (ELF). It is not a macOS server build.** The tested client was a separate Apple Silicon Mac client running under Wine from [EnteMods/fivem-macos](https://github.com/EnteMods/fivem-macos); an M5 client join, resource load and basic game interaction were verified on 6 November 2026. Linux/Proton client support has not been tested. This is the project's **custom, pinned development build of the public FXServer source**, with controlled source build, compatibility packaging and isolated deployment setup. It still uses upstream's instance-wide `sv_lan true`; it is intended for an isolated, authorized test environment.

The `source-lan` branch is based on the tested upstream commit `88a413835e9d7f56633f249880a13f42297153a2`. The `master` branch is the upstream snapshot present when this fork was created; it is not the tested build. Do not merge or update a working deployment without the version and regression checks described below.

## What changed and what was tested

The original binary Recommended server in LAN mode supplied a `ci` resource URI that the source client could not mount. Building the matching public FXServer through upstream's public CI route resolved this mismatch. The existing Mac installation then completed resource download, protocol acknowledgement and game initialization; the owner confirmed movement, camera control and general interaction. No client URI rewriting or ci-provider imitation was added.

The public authentication and ticket source is unchanged. The separate public-development package omits only the unbuilt `svadhesive` metadata entry, following upstream `code/tools/ci/wsl-build.sh` at the pinned revision. Original component metadata is retained. No private security component is copied from the official binary distribution.

**This is not an OS-selective authentication exception.** LAN mode applies to Windows, macOS and Linux clients alike within this development instance. A client-reported OS is not platform attestation. Normal Cfx ticket issuance, regular anti-cheat integration and public-server compatibility remain unresolved. Native Linux/Proton-client gameplay has not been tested; the name describes the development target, not a completed compatibility matrix.

## Build, installation and release status

- [Pinned public build recipe](compatibility/PUBLIC_BUILD.md), including fixed inputs, isolated toolchain repairs, packaging and verification commands.
- [Installation and operating boundary](compatibility/INSTALL.md).
- [Test results and remaining checks](compatibility/TEST_RESULTS.md).
- [Known issues](compatibility/KNOWN_ISSUES.md).

The source tree and recipe are available. A finished binary download is **not yet published**: the new portable recipe still needs a clean second build, package startup test and complete corresponding-source/license inventory. There is no macOS server build or DMG, and no verified Wine-to-game fresh-install workflow is claimed. The linked client repository documents its current installation-specific bindings and open bootstrap work.

Do not expose this LAN development configuration as a public Internet service. The successful test used a dedicated network guard, explicit IPv4 game ports and access restricted to the authorized test device. A LAN convar is not network isolation.

## AI-assisted work and contributions

The compatibility build/packaging work and documentation were developed with substantial help from AI coding agents under the project owner's direction. Upstream CitizenFX code retains its authorship. Independent review, reproducible tests and ordinary platform/API compatibility contributions are welcome. A legitimate supported solution for the missing `cfxTicket2` remains sought in the client project. Do not post credentials, ticket values, private addresses, game data or proprietary DLL payloads.

## Licensing and upstream

The upstream [LICENSE](LICENSE), [LICENSES](LICENSES) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) remain unchanged and apply to their respective components. The preserved [upstream README](compatibility/UPSTREAM_README.md) describes the original project. This fork is not endorsed by Cfx.re, Rockstar Games or Take-Two.

Independent original additions under `compatibility/` have the separately stated [No Sale license](compatibility/LICENSE.original-tooling.txt), with explicit exceptions for upstream-derived and third-party material. That restriction does not replace upstream licenses or relicense the FiveM source. The overall work is source-available; it is not described as universally OSI open source.
