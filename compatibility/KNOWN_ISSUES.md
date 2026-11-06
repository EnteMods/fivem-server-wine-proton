# Known issues and hypotheses

## Shutdown exits with 139

The tested public-source server logs `Quitting` after SIGINT but exits 139 with OOM false. An isolated reproduction located a null access in `NodeParentEnvironment::Tick()` during `m_platform->DrainTasks()`, using matching ELF build IDs. No debugger or core was available for a complete stack.

The pinned public source signals termination through a plain cross-thread boolean and returns from the server entrypoint without visibly joining `svMain`. That loop can still run resource and Node tick callbacks. Overlap with destruction of the static Node environment is a source-supported hypothesis, not a proven exact object-destruction sequence. A proposed repair must stop and join the loop before server return, use proper synchronization and be tested against actual shutdown and client-session regressions. A null guard or forced exit code would not establish a correct fix. No shutdown repair is included here yet.

## Binary package and source closure

The existing candidate's development start and game session passed. The newly published portable scripts have not yet completed a clean second build or archive unpack/start test. Some upstream Alpine/Cfx repositories and Python dependencies remain time-varying; fixed inputs are checked and selected versions recorded, but bitwise reproducibility is not claimed.

The complete runtime also requires package-specific license texts and corresponding-source mapping, including Cfx Curl/V8, sgerrand glibc, Alpine libraries, FXServer dependencies and bundled JavaScript. Top-level FiveM license files alone do not complete this work. No binary asset is published until its actual contents and required source/notices are prepared. No private prefix, operator configuration, accounts, keys, game content or official client DLLs belong in the package.

## Compatibility limits

- Tested: existing Apple Silicon/Wine client, Legacy 3889, matching source-LAN server and the selected public resources.
- Not established: normal Cfx ticket issuance, public-server admission, OS-selective security policy or regular anti-cheat integration.
- Not tested: native Linux/Proton client, Windows-client compatibility matrix, multiple players, arbitrary resources, long-duration play, higher graphics settings and benchmarks.
- Pending: complete clean disconnect/reconnect evidence and independent external network-denial tests.
- Client installation/bootstrap, Retina behavior and normal Rockstar session reuse remain tracked in the [client issues](https://github.com/EnteMods/fivem-macos/issues).
