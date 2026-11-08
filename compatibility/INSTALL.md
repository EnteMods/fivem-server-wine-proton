# Installation status and operating boundary

There is no published ready binary. Private owner packages have verified fresh-install and shutdown checks; the archives are not part of this public source recipe. The recipe applies the V4/V5 source overlay. This document gives the current source-build path and the operational requirements for an isolated development test. It must not be treated as a completed end-to-end Mac installation guide.

## Build the Linux server

Use a dedicated Linux x86-64 Docker build host with the prerequisites and free-space requirements in [PUBLIC_BUILD.md](PUBLIC_BUILD.md). Obtain and review this fork's `source-lan` branch, then run from its `compatibility` directory:

```sh
sudo bash public-build.sh /absolute/new/fxserver-work
sudo bash public-package.sh /absolute/new/fxserver-work
python3 public-verify-package.py /absolute/new/fxserver-work/package
```

The work directory must not already exist. The build uses the pinned upstream base and verified V4/V5 source overlay; it does not modify an existing server or start one. Keep the container, status, download hashes, package inventory and failure output for diagnosis. The scripts leave a failed run intact; investigate its actual error rather than blindly rerunning into the same directory. These portable scripts are still awaiting their own complete clean build/start validation.

## Use a separate data directory

The package's `run.sh` is the original upstream Linux launcher. Server resources and the neutral example configuration live under `package/alpine/opt/cfx-server/`. On a dedicated Linux x86-64 test machine or properly configured container, an isolated foreground startup uses that resource directory as the working directory:

```sh
cd /absolute/new/fxserver-work/package/alpine/opt/cfx-server
/absolute/new/fxserver-work/package/run.sh +exec example-lan.cfg
```

For an imported Alpine rootfs, provide a writable `/tmp`. The verified private container uses `--tmpfs /tmp:rw,nosuid,nodev,size=64m`; the Linux TCP dispatcher creates its internal Unix pipe there. A missing `/tmp` can leave a listening TCP socket whose HTTP connections are immediately reset. This is a runtime filesystem requirement, not an authentication fix.

The example binds TCP and UDP to `127.0.0.1:30120`, enables `sv_lan true`, selects Legacy 3889, allows four clients and starts only the documented public resources. It contains no operator key. Loopback cannot be reached from another Mac; do not replace it with a public listener before designing and verifying the restricted network path for your environment. The successful project test used a dedicated Docker bridge and host firewall guard, not this loopback example by itself.

No generic firewall command is supplied as proof of isolation. Container DNAT, IPv6, alternate host interfaces and administration listeners must be covered. Test both the allowed client path and denied access from an independent outside source. The development instance should be reachable only by authorized test devices.

Use the normal foreground interrupt to request stop, and record the real result: the current pinned build has the documented SIGINT exit-139 issue. Do not hide it with a forced success status or an automatic restart policy.

## Connect the existing client

Use your own legitimate GTA V Legacy installation and the separately configured [experimental Mac client](https://github.com/EnteMods/fivem-macos). Authenticate normally in Rockstar where required. In FiveM's console, `connect` targets only your own authorized, isolated server address. A client interface, Rockstar ownership or Cfx account link is not proof that a normal Cfx multiplayer ticket exists.

The client repository currently depends on an existing local installation and profile. A verified clean Mac route from Wine installation through Rockstar, GTA Legacy and a portable project app is unfinished; no DMG or universal one-command install is available. No game files, accounts or official client payloads are distributed by this fork.

## Updates and recovery

Keep each version in a new directory with its source pin, toolchain/download inventory, binary hashes, public resources and operator data recorded separately. Back up and verify the existing working deployment before exchanging it. Run a network-none resource smoke, then test the authorized client join, interaction, disconnect/reconnect and stop behavior before promoting an update. Retain the prior verified version for rollback, subject to applicable official update requirements. Do not merge a moving upstream branch into a working installation automatically.
