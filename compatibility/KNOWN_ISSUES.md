# Known issues and hypotheses

## Shutdown: original exit 139 and private V4 candidate

The tested public-source server logs `Quitting` after SIGINT but exits 139 with OOM false. An isolated reproduction located a null access in `NodeParentEnvironment::Tick()` during `m_platform->DrainTasks()`, using matching ELF build IDs. No debugger or core was available for a complete stack in that original 139 reproduction.

The original pinned baseline source signals termination through a plain cross-thread boolean and returns from the server entrypoint without visibly joining `svMain`. That loop can still run resource and Node tick callbacks. Overlap with destruction of the static Node environment is a source-supported hypothesis, not a proven exact object-destruction sequence. The private candidate stops and joins the loop before server return and uses synchronized shutdown. A null guard or forced exit code alone would not establish a correct fix. The exact original object-destruction sequence remains unproven.

A later V3 build reached its quit marker but hung. Debugger evidence showed `__stdio_exit` waiting on stdin while a detached non-TTY reader held the lock, after `svMain` had stopped. Private V4 adds a Linux non-TTY reader that can be woken and joined. Its real Linux build exited 0 without OOM, and five isolated non-TTY/TTY SIGINT and console-quit cycles exited naturally with the existing upstream return code 1. All five required candidate modules were confirmed mapped in each cycle. One TTY console harness attempt failed to deliver its command; a separate real-PTY retry passed. Details and limitations are in [test results](TEST_RESULTS.md).

The source update contains 16 V4 and seven V5 files; independent public review remains open. The private V5 live configuration uses four replacement modules over V4, and a subsequent real Mac/Wine client join reached the game world. Five earlier V4 shutdown tests and five separate V5 shutdown tests each exited naturally with code 1; neither establishes a zero exit code. The V5 tests checked the seven required modules and all 31 mapped ELF files. Fresh installed-package startup/shutdown checks also pass for both private V4 packages.

## Binary package and source closure

The existing candidate's development start and game session passed. The private Full V2 developer bundle and 74,514,616-byte Runtime V3 operator bundle passed fresh archive unpack, installation and isolated runtime acceptance. The latter externalizes only debug files and restores the original internal Git hardlinks; it does not alter shipped ELF bytes. There is no finished public binary download. The portable scripts apply the verified V4/V5 source overlay to the pinned 88a baseline. They have not completed a clean V5 build or archive unpack/start test. Some upstream Alpine/Cfx repositories and Python dependencies remain time-varying; fixed inputs are checked and selected versions recorded, but bitwise reproducibility is not claimed.

The complete runtime needs package-specific notices and a mapping of applicable license and corresponding-source obligations across Cfx Curl/V8, sgerrand glibc, Alpine libraries, FXServer dependencies and bundled JavaScript. Build-provenance gaps for permissively licensed components are separate from any actual source-disclosure duties. Top-level FiveM license files alone do not complete this work. No binary asset is published until its actual contents and required source/notices are prepared. No private prefix, operator configuration, accounts, keys, game content or official client DLLs belong in the package.

## Compatibility limits

- Tested: existing Apple Silicon/Wine client, Legacy 3889, matching source-LAN server and the selected public resources.
- Not established: normal Cfx ticket issuance, public-server admission, OS-selective security policy or regular anti-cheat integration.
- Not tested: native Linux/Proton client, Windows-client compatibility matrix, multiple players, arbitrary resources, long-duration play, higher graphics settings and benchmarks.
- A normal client quit left the server reporting zero players; a complete reconnect test and independent external network-denial tests remain pending.
- Client installation/bootstrap, Retina behavior and normal Rockstar session reuse remain tracked in the [client issues](https://github.com/EnteMods/fivem-macos/issues).
