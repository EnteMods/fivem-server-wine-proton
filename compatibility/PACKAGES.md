# Package contents and validation

The Full V2 and Runtime V3 archives are private owner packages. Neither is a public download. Their tests establish the recorded package behavior, not public-server compatibility, authentication, or license clearance.

## Current deployment status

As of 8 November 2026, the private live V5 configuration overlays four modules on the validated V4 runtime. A real Apple Silicon/Wine client 1257409 with GTA V Legacy 3889 completed resource download, protocol acknowledgement and world entry. This does not establish public-server admission, voice chat, performance, or fresh-install acceptance.

The V5 build exited 0; 15 CitiTest cases passed with 2,812,163 assertions. Static review covered 35 ELF files including CitiTest. This deployment is not a public binary release.

## Package comparison

| Package | Archive size | Purpose | Recorded validation |
| --- | ---: | --- | --- |
| Full V2 | 555,324,540 bytes, about 530 MiB | Developer and symbol bundle. | Fresh install, two root-filesystem stop checks, and host-Bash checks passed. |
| Runtime V3 | 74,514,616 bytes, about 71 MiB | Smaller operator package built from the same V4 source binaries. | Fresh unpack and install, existing-destination refusal, file/mode/symlink checks, ELF closure, two root-filesystem shutdown paths, and an Ubuntu/Bash foreground-launcher stop passed. |

Runtime V3 externalizes only the debug files and restores the original 139 Git-alias hardlinks in the independent output. Shipped server ELF files, other runtime dependencies, and resources are byte-identical to Full V2. The 139 aliases retained one inode inside the tested installed tree and test containers.

Full V2 contains 34 `.dbg` files totaling 534,440,944 uncompressed bytes. `libnode22.so.dbg` accounts for 385,872,304 bytes. Expanded Git aliases add 401,932,176 bytes of duplicate logical file contents. These are file-size totals; they are not savings that can be subtracted directly from the compressed archive size.

## Package file reference

| File or group | Purpose |
| --- | --- |
| `install.sh` | Installs into a new destination while offline. It does not install or start a service. |
| `start-local.sh` | Foreground launcher that requires host Bash and uses the selected configuration. |
| `run.sh` | Starts the bundled musl loader used by the server executable. |
| `example-lan.cfg` | Example loopback TCP/UDP port 30120, GTA V Legacy build 3889, four-client limit, and five example resources. It contains no operator key. |
| `INSTALL-INVENTORY.json` | File hashes, modes, and symlink targets. The V3 verifier also checks shared inodes and link counts for Git aliases. |
| `SHA256SUMS` and archive `.sha256` | Package and archive integrity hashes. Compare the archive hash with a separately trusted receipt. |
| `BUILD-PROOF.json` | Build and compiler exit results. |
| `REBUILD-PROOF.json` | Matched ELF/debug build IDs and CRCs. |
| `BUILD-SHUTDOWN-RECEIPT.json` | Five private source shutdown cycles. It does not prove another client join. |
| `EXTERNAL-SYMBOLS.json` | In Runtime V3, identifies the exact 34 `.dbg` files retained in Full V2. |
| `FULL-V2-INVENTORY.json` | Provenance anchor for the Full V2 archive. |
| `SOURCE-AND-NOTICES.json`, `SOURCE-GAPS.txt` | Package filenames for factual source/license inventory and unresolved gaps. They are not links to files in this repository and are not legal clearance. |

## Integrity records

Package inventories and private proof receipts retain the file hashes, ELF build IDs, and CRCs used during review. They are not published here as downloadable artifacts or hash manifests.

## Distribution boundary

The packages contain no GTA/RPF data or private client DLLs. Full V2 and Runtime V3 passed their stated private checks, but they are not approved public binary distributions. Corresponding-source duties and notices for Cfx Curl/V8, sgerrand glibc, Alpine libraries, FXServer dependencies, bundled JavaScript, and server-data resources still need review. Top-level FiveM license files alone do not clear every dependency. Do not publish either archive until the package contents, required source, and applicable notices are ready.
