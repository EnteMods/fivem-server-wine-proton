# Public FXServer source development build (Linux x86-64)

For a public repository, copy **only** PUBLIC_BUILD.md, public-build.sh,
public-build-container.sh, public-audit-submodules.py, public-package.sh,
public-verify-package.py and public-smoke.sh from this working folder. The other local files
record a private host build/deployment and must stay private. Do not copy
the folder wholesale.

These scripts build CitizenFX/FiveM commit
88a413835e9d7f56633f249880a13f42297153a2 with its original public CI
script, then assemble a self-contained development package. The public CI
script and FiveM C++, authentication, ticket and anti-cheat source stay
unchanged. The scripts do not start a server, open ports, use operator keys or
publish an archive.

A fresh dedicated Linux x86-64 host needs Docker, Git, curl, Bash, Python 3, GNU
tar/coreutils, binutils (readelf), xz and at least 25 GiB free. The build
container is limited to two CPUs, 6 GiB RAM and 1024 PIDs. It uses bridge
networking, no published ports, no privileged mode, no host network and no
host Docker socket. It stops only its own container below 10 GiB free. Use a
new absolute directory for each run.

    sudo bash public-build.sh /absolute/path/to/new-fx-build
    sudo bash public-package.sh /absolute/path/to/new-fx-build

Root is required on that dedicated build host because the upstream public CI
creates a root-owned Alpine filesystem and changes source worktree ownership.

The wrapper prints and records the Docker container name and ID. After
completion it leaves the container and build files for audit. On failure,
inspect that container's logs and the work directory's status; do not restart
blindly. The package step creates package/, a SHA256SUMS and SYMLINKS.txt
inventory, plus fxserver-public-source-dev-88a4138-linux-x64.tar.xz and its
SHA-256 file. Packaging also runs a separate Docker loader/start smoke with
no network or published ports and open stdin. It checks the five resource
starts, stops its own container, and records any nonclean SIGINT exit without
calling it a successful shutdown. Repeat read-only file QA with:

    python3 public-verify-package.py /absolute/path/to/new-fx-build/package

## Fixed inputs and isolated repairs

- Source commit 88a4138; all 174 recursive Gitlinks must be pinned. Shallow
  HDiffPatch recovery is limited to public tag v4.5.2 resolving to
  f62556a781f00cbe9212945bafed3ce01849c553. Empty worktrees with a
  correct HEAD are restored only if they contain no indexed files. Other
  mismatches stop the build.
- Public server data is citizenfx/cfx-server-data commit
  c6afa3909c763e3327ed76825e78453286c99f05.
- The Docker base image is addressed by digest. Alpine 3.16.5 minirootfs,
  sgerrand glibc 2.34-r0 APKs, Alpine 3.16 Git 2.36.6-r0 APK, Premake
  5.0.0-beta1 source ZIP, Cfx repository signing keys and generated natives
  input are downloaded over HTTPS and SHA-256 checked before use. PRoot is
  fetched at commit 25dc6a3134891f98a79f57ce1c2c1b23ff15cad1.
- The original public CI script is SHA-256 checked and invoked unchanged.
  Its native-doc workaround selects commit
  272dbe87ad0b24f63fe1458305ea99984c82d557, verified after build.
  The toolchain preparation script is copied only into the isolated rootfs.
  That copy uses checked Cfx keys and Premake archive and drops the
  allow-untrusted flag for sgerrand APKs. Alpine apk verify checks both
  signatures against the checked sgerrand key. Signed Alpine 3.16 Git
  replaces an edge Git whose helper required curl_global_trace absent from
  pinned Cfx curl 7.72.0. Exact safe.directory entries cover only the
  container source and native-doc-tooling paths.
  The sgerrand key digest is pinned from its documented HTTPS endpoint;
  no independently published fingerprint was found for this key.
- Upstream ext/system-resources/build.sh mixes Chat compilation with a
  Monitor artifact download. Packaging compiles only Chat from pinned source
  using Alpine's signed Yarn 1.22.19, frozen lockfile and ignored install
  scripts. It copies public Yarn/Webpack helpers and omits Monitor.
- The public build does not produce libsvadhesive.so. In the package copy
  only, the one unbuilt svadhesive entry is removed from components.json,
  as documented by upstream code/tools/ci/wsl-build.sh lines 30-31. The
  original is kept as components.original.json. This is public source
  development metadata, with no authentication or ticket control-flow patch.
- Packaging copies the Alpine runtime, upstream data/server_proot/run.sh,
  public resources and compiled Chat. It strips build-only directories,
  APK cache and default shadow/backup account files from the package copy,
  then checks top-level ELF DT_NEEDED names against the upstream launcher's
  library directories and FXServer/component RPATHs. Nested libraries and
  dynamic loads require the separate isolated loader/start smoke. The example LAN config binds loopback
  and contains no key. Operators must supply a restricted LAN environment.

Download hashes and URLs are in public-build.sh. The new work directory
receives base-apk-versions.txt, toolchain-apk-versions.txt,
chat-apk-versions.txt, downloads.sha256, submodule-audit.txt and
public-output.sha256. Upstream Alpine edge/Cfx package repositories and
Python dependencies in proot_prepare.sh are time-varying. The scripts record
selected versions, check fixed inputs and fail on drift in those inputs;
they do not promise bit-identical builds or claim a new build was run.
A second clean build, archive unpack/start check and third-party license
inventory remain separate release checks.

The package includes CitizenFX's top-level LICENSE and LICENSES files and
source attribution. Those files do not by themselves clear every Alpine,
Mono, Node or Yarn dependency for redistribution. Apply the respective
upstream licenses, and review the server-data resource repository's license
status separately; any license chosen for independent original tooling does
not replace CitizenFX or third-party terms. The source development smoke
does not prove compatibility with public Cfx clients or server
authentication behavior. Observed source-server SIGINT shutdown exit 139
remains open.
