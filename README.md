# FXServer source build for Linux x86-64

This repository contains a pinned public-source development build and
packaging recipe for the Linux x86-64 FXServer. It is not a macOS server, a
production binary download, or proof of compatibility with public FiveM
servers.

The client is a separate Apple Silicon Mac installation running under Wine.
Linux/Proton client gameplay has not been tested.

## Current status

Status snapshot: 8 November 2026.

| Track | Current evidence | Boundary |
| --- | --- | --- |
| Source | The public fork base uses upstream `88a413835e9d7f56633f249880a13f42297153a2`; the source update contains 16 V4 shutdown files and seven upstream hardening files. | Source covers the Linux server runtime changes reviewed through upstream `5c3065c`; it is not a full build of that commit. |
| Client session | Windows client 1257409 on Apple Silicon/Wine and GTA V Legacy 3889 joined the private live V5 server, completed resource download and protocol acknowledgement, and reached the game world. | One existing installation and one session. Normal public-server admission, full voice, performance, and fresh-install acceptance remain untested. |
| Live private server | A private V5 overlay replaced four modules over the validated V4 runtime; a real Mac client joined. | This is a single private deployment, not a public binary release. |
| V5 hardening | Build exited 0; 15 CitiTest cases passed with 2,812,163 assertions. Static review covered 35 ELF files including CitiTest. | The tested live configuration and loaded-module counts are detailed in [test results](compatibility/TEST_RESULTS.md). |
| Public recipe | Scripts pin source and selected build inputs, package the Linux runtime, and verify output files. | Clean second execution, full dependency notices, and public binary distribution remain open. |

## Authentication and network boundary

The server uses upstream's instance-wide `sv_lan true` mode. It does not
restrict admission by operating system, and a client-reported OS is not
platform attestation.

The build does not issue Cfx tickets or add an OS-selective authentication
exception. Normal ticket-authenticated public-server admission and regular
anti-cheat integration remain unresolved. No ticket solution or bypass is
claimed.

Do not expose this development configuration to the public Internet. A LAN
setting or firewall rule alone does not prove network isolation for another
host. Operators need an authorized test environment with restrictions verified
for its own network path.

## Documentation and packages

Use the [documentation index](compatibility/INDEX.md) to find the pinned
source-build recipe, operator guidance, evidence, package records, and known
issues. The [upstream README](compatibility/UPSTREAM_README.md) is preserved
for source context.

The private Full V2 and Runtime V3 owner packages passed their recorded
installation and runtime checks. Runtime V3 is the smaller operator package;
Full V2 retains debug symbols for development. Neither archive is a public
download.

See [package records](compatibility/PACKAGES.md) for contents, sizes, hashes,
and validation boundaries. These private packages are separate from the public source changes.

## Building and distribution

The public recipe checks out the pinned `88a` base, verifies and applies the 23 V4/V5 source files, then packages a Linux runtime. A clean public V5 build has not yet been run. It
does not start a service, open ports, or publish an archive. Read the
[installation boundary](compatibility/INSTALL.md) before building or running
a test instance.

A source build does not clear every dependency for binary redistribution.
Corresponding-source duties and component notices still need review. Do not
publish a package until its contents, source offer, and applicable notices are
ready.

## Licensing and contribution

CitizenFX source and third-party components retain their own terms. Original
tooling under `compatibility/` has a separate No Sale license with stated
exceptions; it does not relicense upstream code.

The [original tooling license](compatibility/LICENSE.original-tooling.txt)
is present. Root files `LICENSE`, `LICENSES/`, and `THIRD_PARTY_NOTICES.md` retain the upstream
source and notice information. `SOURCE-GAPS.txt`
is not included here. These records are not legal clearance.

Independent review and reproducible build or platform findings are welcome.
Do not post credentials, ticket values, private addresses, game data, or
proprietary DLL payloads. This project is not endorsed by Cfx.re, Rockstar
Games, or Take-Two.
