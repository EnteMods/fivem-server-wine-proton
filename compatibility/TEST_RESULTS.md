# Verified development session

Date: 6 November 2026. Public server source: `88a413835e9d7f56633f249880a13f42297153a2`; public server-data: `c6afa3909c763e3327ed76825e78453286c99f05`; GTA V Legacy build: 3889.

The original public Alpine CI build completed with exit 0. Its built `FXServer` has SHA-256 `0a663b42514d48aba91571e2990f6903b0b7949dac22bf0b1f5f5cc3cdd3b855`. An isolated container without network access started the five selected public resources: mapmanager, spawnmanager, basic-gamemode, fivem-map-hipster and chat. This tested the existing candidate, not a fresh execution of the newly published portable scripts.

After a verified private backup, only the owner's isolated test instance was replaced. TCP info, valid UDP getinfo, service state, network guard and resource startup were checked. The test allowed four clients and used instance-wide LAN mode; no administration port was published. Independent blocked-source checks from outside the host remain untested.

The existing Apple Silicon/Wine client completed resource download, received the server protocol acknowledgement and finalized game loading. The server reported one player. The owner confirmed character movement, camera control and general interaction. A later separate client log also reached game-load finalization without a mounter failure. No performance benchmark, multiple-client test, long-duration session or complete clean disconnect/reconnect acceptance is claimed.

The earlier official Recommended binary with LAN mode failed with `Could not get resource mounter for resource mapmanager.` Its resource URI scheme was classified as `ci`. That error was absent in the successful matching-source attempt; no client URI patch or private provider replacement was used.

Private raw logs, screenshots, accounts, host identifiers and addresses are not published. The client repository's [fixed-field log reader](https://github.com/EnteMods/fivem-macos/blob/main/native/windows-client/source_join_progress.py) emits progress phases without URI payloads or ticket values.

The isolated SIGINT stop test logged `Quitting` but ended with code 139, without OOM. A separate network-none reproduction localized a null access in `NodeParentEnvironment::Tick()` during `m_platform->DrainTasks()` with a matching ELF build ID. The full stack and verified fix remain missing. See [known issues](KNOWN_ISSUES.md).
