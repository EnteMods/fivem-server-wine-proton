#!/usr/bin/env bash
# Package a completed pinned public build. No server is started or published.
set -euo pipefail
umask 077

source_sha=88a413835e9d7f56633f249880a13f42297153a2
data_sha=c6afa3909c763e3327ed76825e78453286c99f05
alpine_image='alpine@sha256:452e7292acee0ee16c332324d7de05fa2c99f9994ecc9f0779c602916a672ae4'
if [[ $# != 1 || "$1" != /* || "$1" == *:* || "$1" == *,* ]]; then
  echo 'Usage: public-package.sh /absolute/completed/build-work-directory' >&2
  exit 2
fi
work=$1
[[ $EUID == 0 ]] || { echo 'Run as root to read the isolated Alpine rootfs.' >&2; exit 2; }
recipe=$(cd "$(dirname "$0")" && pwd -P)
for command in docker git python3 sha256sum readelf tar xz; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 2; }
done
[[ -f "$work/status" && $(cat "$work/status") == phase=build-complete ]] || {
  echo 'The pinned public build has not completed.' >&2; exit 2;
}
[[ $(git -c safe.directory="$work/source" -C "$work/source" rev-parse HEAD) == "$source_sha" ]]
[[ -f "$work/source-overlay-inventory.json" ]]
python3 "$recipe/public-source-overlay.py" verify "$recipe/SOURCE-SHA256SUMS.txt" "$work/source"
[[ $(git -C "$work/server-data" rev-parse HEAD) == "$data_sha" ]]
[[ $(git --git-dir="$work/source/.git/modules/ext/native-doc-tooling" rev-parse HEAD) == 272dbe87ad0b24f63fe1458305ea99984c82d557 ]]
printf '%s  %s\n' bc08e3b4ab993063bf1c4be5c4591c0e0119f662d73938d0e62cec7e934f3075 \
  "$work/source/code/tools/ci/build_server_docker_alpine_public.sh" | sha256sum -c - >/dev/null
(cd "$work/source/alpine/opt/cfx-server" && sha256sum -c "$work/public-output.sha256" >/dev/null)
printf '%s  %s\n' ebf516aa5569aeeb0cfd31ca482810caae60d72d3227cf3eb1dd0c5ea138fcd2 \
  "$work/source/ext/system-resources/resources/chat/yarn.lock" | sha256sum -c - >/dev/null

[[ ! -e "$work/package" && ! -e "$work/chat-work" ]] || {
  echo 'Package/chat-work already exists; preserve it and use a fresh build directory.' >&2; exit 2;
}
cp -R "$work/source/ext/system-resources/resources/chat" "$work/chat-work"
docker run --rm --network bridge --cpus 2 --memory 2g --memory-swap 2g \
  --pids-limit 256 \
  --mount "type=bind,src=$work,dst=/work" -w /work/chat-work \
  "$alpine_image" /bin/sh -ec \
  'apk add --no-cache nodejs npm yarn >/dev/null; apk info -vv > /work/chat-apk-versions.txt; test "$(yarn --version)" = "1.22.19"; yarn install --frozen-lockfile --ignore-scripts --non-interactive; ./node_modules/.bin/webpack'
test -s "$work/chat-work/dist/chat.js"
test -s "$work/chat-work/dist/ui.html"
test -s "$work/chat-work/dist/index.css"

mkdir -p "$work/package"
cp -a "$work/source/alpine" "$work/package/alpine"
server="$work/package/alpine/opt/cfx-server"
# Only build-only directories are removed from this separate package copy.
rm -rf "$work/package/alpine/root" "$work/package/alpine/tmp" \
  "$work/package/alpine/src" "$work/package/alpine/fivem-private" \
  "$work/package/alpine/builds" "$work/package/alpine/utils" \
  "$work/package/alpine/var/cache/apk"
python3 - "$work/package/alpine/etc" <<'PY'
from pathlib import Path
import sys
etc=Path(sys.argv[1])
for prefix in ('shadow', 'gshadow', 'passwd', 'group'):
    for path in etc.glob(prefix+'*'):
        if prefix in ('passwd','group') and path.name==prefix:
            continue
        if path.is_file() or path.is_symlink():
            path.unlink()
PY
rm -rf "$server/cache"
mkdir -p "$server/resources" "$server/citizen/system_resources"
cp -a "$work/server-data/resources/." "$server/resources/"
chat="$server/citizen/system_resources/chat"
mkdir -p "$chat"
(cd "$work/chat-work" && tar --exclude='./node_modules' --exclude='./package.json' \
  --exclude='./yarn.lock' --exclude='./html' -cf - .) | (cd "$chat" && tar -xf -)
mkdir -p "$chat/html"
cp -a "$work/source/ext/system-resources/resources/chat/html/vendor" "$chat/html/vendor"
cp -a "$work/source/ext/system-resources/resources/yarn" "$server/citizen/system_resources/yarn"
cp -a "$work/source/ext/system-resources/resources/webpack" "$server/citizen/system_resources/webpack"
cp -a "$work/package/alpine/lib/ld-musl-x86_64.so.1" "$server/ld-musl-x86_64.so.1"
cp -a "$work/source/data/server_proot/run.sh" "$work/package/run.sh"
chmod +x "$work/package/run.sh"

python3 - "$server" <<'PY'
import json,sys
from pathlib import Path
server=Path(sys.argv[1])
p=server/'components.json'
original=p.read_bytes()
components=json.loads(original)
if len(components)!=26 or components.count('svadhesive')!=1:
    raise SystemExit('Unexpected upstream component manifest')
if (server/'libsvadhesive.so').exists():
    raise SystemExit('Do not remove a built component from metadata')
(server/'components.original.json').write_bytes(original)
components.remove('svadhesive')
p.write_text(json.dumps(components,indent=2)+'\n')
PY

cat > "$server/example-lan.cfg" <<'CFG'
sv_lan true
endpoint_add_tcp "127.0.0.1:30120"
endpoint_add_udp "127.0.0.1:30120"
sv_hostname "Source Development LAN"
sv_maxclients 4
sv_enforceGameBuild 3889
ensure mapmanager
ensure chat
ensure spawnmanager
ensure basic-gamemode
ensure fivem-map-hipster
CFG
chmod 0600 "$server/example-lan.cfg"
mkdir -p "$work/package/UPSTREAM-LICENSES"
cp -a "$work/source/LICENSE" "$work/package/UPSTREAM-LICENSES/CitizenFX-LICENSE"
cp -a "$work/source/LICENSES" "$work/package/UPSTREAM-LICENSES/CitizenFX-LICENSES"
cp "$recipe/SOURCE-SHA256SUMS.txt" "$work/package/SOURCE-OVERLAY-SHA256SUMS.txt"
cp "$work/source-overlay-inventory.json" "$work/package/SOURCE-OVERLAY-INVENTORY.json"
cat > "$work/package/SOURCE_PROVENANCE.txt" <<'TXT'
Public FXServer source development package
CitizenFX/FiveM base: 88a413835e9d7f56633f249880a13f42297153a2
V4/V5 source overlay: 23 files listed in SOURCE-OVERLAY-SHA256SUMS.txt.
The Git HEAD identifies the base, not the modified worktree.
Original public CI: code/tools/ci/build_server_docker_alpine_public.sh
Standard resource data: citizenfx/cfx-server-data c6afa3909c763e3327ed76825e78453286c99f05
System resources: source-built chat plus public yarn/webpack helpers; no Monitor artifact.
Only this package copy omits the unbuilt svadhesive component manifest entry,
as documented by public code/tools/ci/wsl-build.sh. components.original.json
preserves the original. No authentication, ticket or anti-cheat code is patched.
Example config binds loopback. Operators must supply their own private LAN guard.
The build does not assert public-client compatibility or bitwise reproducibility.
Review bundled third-party notices before redistribution.
TXT

(cd "$work/package" && find . -type l -printf '%p -> %l\n' | sort > SYMLINKS.txt)
(cd "$work/package" && find . -type f ! -name SHA256SUMS -print0 |
  sort -z | xargs -0 sha256sum > SHA256SUMS)
python3 "$recipe/public-verify-package.py" "$work/package"
bash "$recipe/public-smoke.sh" "$work/package"
archive="$work/fxserver-public-source-dev-88a4138-v5-overlay-linux-x64.tar.xz"
(tar -C "$work" --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
  -cf - package | xz -T2 -6 > "$archive")
xz -t "$archive"
tar -tf "$archive" >/dev/null
sha256sum "$archive" > "$archive.sha256"
echo "Verified package: $work/package"
echo "Archive: $archive"
