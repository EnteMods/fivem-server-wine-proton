#!/usr/bin/env bash
# Isolated loader/start test for a packaged public source build.
set -euo pipefail
if [[ $# != 1 || "$1" != /* ]]; then
  echo 'Usage: public-smoke.sh /absolute/package-directory' >&2
  exit 2
fi
[[ $EUID == 0 ]] || { echo 'Run as root on the dedicated build host.' >&2; exit 2; }
package=$1
recipe=$(cd "$(dirname "$0")" && pwd -P)
python3 "$recipe/public-verify-package.py" "$package" >/dev/null
image="fxserver-public-smoke:$(date -u +%Y%m%dT%H%M%SZ)-$$"
container="fxserver-public-smoke-$(date -u +%Y%m%dT%H%M%SZ)-$$"
(tar -C "$package/alpine" -cf - . |
  docker import --change 'ENV LD_LIBRARY_PATH=/opt/cfx-server:/usr/lib/v8:/lib:/usr/lib' \
    --change 'WORKDIR /opt/cfx-server' --change 'STOPSIGNAL SIGINT' - "$image") >/dev/null
docker run -di --name "$container" --network none --cpus 1 --memory 2g \
  --memory-swap 2g --pids-limit 256 --cap-drop ALL \
  --security-opt no-new-privileges --stop-signal SIGINT --restart no \
  --tmpfs /tmp:rw,nosuid,nodev,size=64m \
  "$image" /opt/cfx-server/run.sh +set citizen_dir /opt/cfx-server/citizen/ \
  +exec example-lan.cfg >/dev/null
stop_if_running() {
  if [[ $(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null) == true ]]; then
    docker stop -t 20 "$container" >/dev/null || true
  fi
}
trap stop_if_running EXIT
echo "Smoke container: $container; image: $image"
ready=0
for _ in $(seq 1 20); do
  if [[ $(docker inspect -f '{{.State.Running}}' "$container") != true ]]; then
    break
  fi
  log=$(docker logs "$container" 2>&1)
  if grep -F 'Started resource fivem-map-hipster' <<< "$log" >/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
if [[ $ready != 1 ]]; then
  echo "Startup did not reach all resources; inspect: docker logs $container" >&2
  exit 1
fi
for name in mapmanager chat spawnmanager basic-gamemode fivem-map-hipster; do
  grep -F "Started resource $name" <<< "$log" >/dev/null || {
    echo "Missing start marker: $name" >&2; exit 1;
  }
done
grep -F 'Found 19 resources' <<< "$log" >/dev/null
if grep -Ei 'error|failed|could not' <<< "$log" >/dev/null; then
  echo "Error marker in startup log; inspect: docker logs $container" >&2
  exit 1
fi
echo 'Network-none loader/resource startup: pass (19 resources, 5 ensured)'
docker stop -t 20 "$container" >/dev/null
exit_code=$(docker inspect -f '{{.State.ExitCode}}' "$container")
oom=$(docker inspect -f '{{.State.OOMKilled}}' "$container")
printf 'StopSignal=SIGINT; shutdown_exit=%s; oom=%s\n' "$exit_code" "$oom"
if [[ $exit_code != 0 ]]; then
  echo 'Shutdown is not clean; classify it separately before release.'
fi
(cd "$package" && sha256sum -c SHA256SUMS >/dev/null)
echo 'Package hash inventory unchanged after smoke.'
