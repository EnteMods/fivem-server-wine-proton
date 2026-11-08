#!/usr/bin/env bash
# Fresh, isolated Linux x86-64 Docker build of pinned public FXServer source.
set -euo pipefail
umask 077

source_sha=88a413835e9d7f56633f249880a13f42297153a2
data_sha=c6afa3909c763e3327ed76825e78453286c99f05
alpine_image='alpine@sha256:452e7292acee0ee16c332324d7de05fa2c99f9994ecc9f0779c602916a672ae4'

if [[ $# != 1 || "$1" != /* || "$1" == *:* || "$1" == *,* ]]; then
  echo 'Usage: public-build.sh /absolute/new/work-directory' >&2
  exit 2
fi
work=$1
[[ $EUID == 0 ]] || { echo 'Run as root on the dedicated Linux build host.' >&2; exit 2; }
[[ -d $(dirname "$work") ]] || { echo 'The work directory parent must exist.' >&2; exit 2; }
if [[ -e "$work" ]]; then
  echo 'Work directory already exists; use a new directory.' >&2
  exit 2
fi
[[ $(uname -m) == x86_64 ]] || { echo 'An x86-64 Linux host is required.' >&2; exit 2; }
[[ $(uname -s) == Linux ]] || { echo 'A Linux host is required.' >&2; exit 2; }
for command in docker git curl sha256sum df awk date python3; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 2; }
done
free_kib=$(df -Pk "$(dirname "$work")" | awk 'NR == 2 { print $4 }')
(( free_kib >= 26214400 )) || { echo 'At least 25 GiB free space is required before building.' >&2; exit 2; }
mkdir -m 700 -p "$work/verified-downloads"
recipe=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

fetch_pin() {
  local url=$1 hash=$2 path=$3
  curl --fail --location --silent --show-error --retry 3 --output "$path.part" "$url"
  printf '%s  %s\n' "$hash" "$path.part" | sha256sum -c - >/dev/null
  mv "$path.part" "$path"
}

fetch_pin 'https://dl-cdn.alpinelinux.org/alpine/v3.16/releases/x86_64/alpine-minirootfs-3.16.5-x86_64.tar.gz' \
  81ffb319cd733dab2397db5cdc305c77d7be2da420d438950b869d4ffb8d6237 "$work/verified-downloads/minirootfs.tar.gz"
fetch_pin 'https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub' \
  823b54589c93b02497f1ba4dc622eaef9c813e6b0f0ebbb2f771e32adf9f4ef2 "$work/verified-downloads/sgerrand.rsa.pub"
fetch_pin 'https://runtime.fivem.net/client/alpine/peachypies@protonmail.ch-5adb3818.rsa.pub' \
  9ea192a3cfa2c01ff6e1bd15ee06e764365f4df405b9c86eec4ea0f4c834cb98 "$work/verified-downloads/peachypies.rsa.pub"
fetch_pin 'https://content.cfx.re/mirrors/build/linux/hydrogen@fivem.net-614370b9.rsa.pub' \
  1b6bda078d8763019f7561497306cd1dbaad4849b2d7bb64f99770657126990a "$work/verified-downloads/hydrogen.rsa.pub"
fetch_pin 'https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.34-r0/glibc-2.34-r0.apk' \
  3ef4a8d71777b3ccdd540e18862d688e32aa1c7bc5a1c0170271a43d0e736486 "$work/verified-downloads/glibc-2.34-r0.apk"
fetch_pin 'https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.34-r0/glibc-bin-2.34-r0.apk' \
  cc631135f481644ce74b28f6e37ceea848de06389d669182a012a9ca1ac5a95a "$work/verified-downloads/glibc-bin-2.34-r0.apk"
fetch_pin 'https://dl-cdn.alpinelinux.org/alpine/v3.16/main/x86_64/git-2.36.6-r0.apk' \
  b841a64fe87e57323fa1f41e8f8902ea9ae27901ba5a23dff49b00895898dd8b "$work/verified-downloads/git-2.36.6-r0.apk"
fetch_pin 'https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-src.zip' \
  07b77cac3aacd4bcacd5ce0d1269332cb260363b78c2a8ae7718f4016bf2892f "$work/verified-downloads/premake-5.0.0-beta1-src.zip"
fetch_pin 'https://static.cfx.re/natives/natives.lua' \
  5c4ba646598c50750342836662f94826ef2aae74209f2059a17835b00046de42 "$work/verified-downloads/natives.lua"
(cd "$work/verified-downloads" && sha256sum * > "$work/downloads.sha256")

git init -q "$work/source"
git -C "$work/source" remote add origin https://github.com/citizenfx/fivem.git
git -C "$work/source" fetch --depth=1 --filter=blob:none origin "$source_sha"
git -C "$work/source" checkout -q --detach "$source_sha"
[[ $(git -C "$work/source" rev-parse HEAD) == "$source_sha" ]]
python3 "$recipe/public-source-overlay.py" apply "$recipe/SOURCE-SHA256SUMS.txt" "$work/source" \
  --overlay "$recipe/.." --receipt "$work/source-overlay-inventory.json"
git init -q "$work/server-data"
git -C "$work/server-data" remote add origin https://github.com/citizenfx/cfx-server-data.git
git -C "$work/server-data" fetch --depth=1 --filter=blob:none origin "$data_sha"
git -C "$work/server-data" checkout -q --detach "$data_sha"
[[ $(git -C "$work/server-data" rev-parse HEAD) == "$data_sha" ]]

container="fxserver-public-build-$(date -u +%Y%m%dT%H%M%SZ)-$$"
printf '%s\n' "$container" > "$work/build-container-name"
docker run -d --name "$container" --network bridge --cpus 2 --memory 6g --memory-swap 6g \
  --pids-limit 1024 --restart no \
  --mount "type=bind,src=$work,dst=/work" \
  --mount "type=bind,src=$work/source,dst=/src" \
  --mount "type=bind,src=$recipe,dst=/recipe,readonly" \
  "$alpine_image" /bin/sh /recipe/public-build-container.sh > "$work/build-container-id"
printf 'Build container: %s\n' "$container"
while [[ $(docker inspect --format '{{.State.Running}}' "$container") == true ]]; do
  free_kib=$(df -Pk "$work" | awk 'NR == 2 { print $4 }')
  if (( free_kib < 10485760 )); then
    echo 'Free space below 10 GiB; stopping only this build container.' >&2
    docker stop --time 30 "$container" >/dev/null
    exit 1
  fi
  sleep 30
done
exit_code=$(docker inspect --format '{{.State.ExitCode}}' "$container")
printf 'Build exit: %s; status: ' "$exit_code"
cat "$work/status" 2>/dev/null || echo unknown
if [[ $exit_code != 0 ]]; then
  echo "Inspect with: docker logs $container" >&2
  exit "$exit_code"
fi
echo "Public output: $work/source/alpine/opt/cfx-server"
echo "Package next: $recipe/public-package.sh $work"
