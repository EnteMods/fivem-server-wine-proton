#!/bin/sh
# Runs only in the isolated Alpine Docker builder started by public-build.sh.
set -eu
export JOB_SLOTS=2

test -d /src/.git
test -d /work/verified-downloads
printf 'phase=builder-dependencies\n' > /work/status
apk update
apk add --no-cache curl git xz sudo rsync openssh-client binutils build-base pkgconfig \
    libarchive-dev talloc-dev uthash-dev linux-headers musl-dev \
    bsd-compat-headers dotnet6-sdk python3
apk info -vv > /work/base-apk-versions.txt
git config --global --add safe.directory /src
git config --global --add safe.directory /src/ext/native-doc-tooling
git config -f /src/.gitmodules --get-regexp 'submodule\..*\.path' |
    while read -r _key path; do git config --global --add safe.directory "/src/$path"; done
test "$(git -C /src rev-parse HEAD)" = 88a413835e9d7f56633f249880a13f42297153a2
printf '%s  %s\n' \
    bc08e3b4ab993063bf1c4be5c4591c0e0119f662d73938d0e62cec7e934f3075 \
    /src/code/tools/ci/build_server_docker_alpine_public.sh | sha256sum -c - >/dev/null
printf '%s  %s\n' \
    2b57165b4f91bb57d34d1278a33c20b9d28f4266a0e18d1445a9ccd2ed179cdd \
    /src/code/tools/ci/build_server_proot_alpine.sh | sha256sum -c - >/dev/null
printf '%s  %s\n' \
    e92a8365d8a2a3a78092661951320a3c7c1a9e3961672e8edb46d73868e7c978 \
    /src/code/tools/ci/docker-builder/proot_prepare.sh | sha256sum -c - >/dev/null
printf '%s  %s\n' \
    6c1a82a28f0ab12e69e3a5478e96ce47a2cae10cc9ebe5463560312c715694e1 \
    /src/code/tools/ci/wsl-build.sh | sha256sum -c - >/dev/null
(cd /work/verified-downloads && sha256sum -c /work/downloads.sha256 >/dev/null)

printf 'phase=submodules\n' > /work/status
git -C /src submodule sync --recursive
if ! git -C /src submodule update --init --recursive --depth=1 --filter=blob:none --jobs=2; then
    # Known shallow HDiffPatch Gitlink: recover only its public pinned tag.
    test -e /src/vendor/hdiffpatch/.git
    git -C /src/vendor/hdiffpatch fetch --depth=1 origin refs/tags/v4.5.2
    test "$(git -C /src/vendor/hdiffpatch rev-parse FETCH_HEAD^{commit})" = f62556a781f00cbe9212945bafed3ce01849c553
    git -C /src/vendor/hdiffpatch checkout --detach f62556a781f00cbe9212945bafed3ce01849c553
    git -C /src submodule update --init --recursive --depth=1 --filter=blob:none --jobs=2
fi
python3 /recipe/public-audit-submodules.py /src --repair-empty > /work/submodule-audit.txt

printf 'phase=verified-toolchain-inputs\n' > /work/status
mkdir -p /work/verified-downloads/sgerrand-keys
cp /work/verified-downloads/sgerrand.rsa.pub /work/verified-downloads/sgerrand-keys/sgerrand.rsa.pub
apk --keys-dir /work/verified-downloads/sgerrand-keys verify /work/verified-downloads/glibc-2.34-r0.apk
apk --keys-dir /work/verified-downloads/sgerrand-keys verify /work/verified-downloads/glibc-bin-2.34-r0.apk
apk verify /work/verified-downloads/git-2.36.6-r0.apk

mkdir -p /app/alpine /app/alpine/utils /builds
tar -xzf /work/verified-downloads/minirootfs.tar.gz -C /app/alpine
mkdir -p /app/proot
git -C /app/proot init -q
git -C /app/proot remote add origin https://github.com/proot-me/proot.git
git -C /app/proot fetch --depth=1 origin 25dc6a3134891f98a79f57ce1c2c1b23ff15cad1
git -C /app/proot checkout -q --detach 25dc6a3134891f98a79f57ce1c2c1b23ff15cad1
git -C /app/proot submodule update --init --recursive --depth=1 --jobs=2
test "$(git -C /app/proot rev-parse HEAD)" = 25dc6a3134891f98a79f57ce1c2c1b23ff15cad1
make -C /app/proot/src loader.elf loader-m32.elf build.h
make -C /app/proot/src proot care
cp /app/proot/src/proot /usr/local/bin/proot
printf '%s\n' 25dc6a3134891f98a79f57ce1c2c1b23ff15cad1 > /work/proot-commit.txt

cp /src/code/tools/ci/docker-builder/proot_prepare.sh /app/alpine/utils/proot_prepare.sh
cp /work/verified-downloads/sgerrand.rsa.pub /app/alpine/etc/apk/keys/sgerrand.rsa.pub
cp /work/verified-downloads/peachypies.rsa.pub /app/alpine/utils/peachypies.rsa.pub
cp /work/verified-downloads/hydrogen.rsa.pub /app/alpine/utils/hydrogen.rsa.pub
cp /work/verified-downloads/premake-5.0.0-beta1-src.zip /app/alpine/utils/premake.zip
cp /work/verified-downloads/git-2.36.6-r0.apk /app/alpine/utils/git-2.36.6-r0.apk
python3 - <<'PY'
from pathlib import Path
p=Path('/app/alpine/utils/proot_prepare.sh')
s=p.read_text()
replacements={
    'curl --http1.1 -sLo /etc/apk/keys/peachypies@protonmail.ch-5adb3818.rsa.pub https://runtime.fivem.net/client/alpine/peachypies@protonmail.ch-5adb3818.rsa.pub':
    'cp /utils/peachypies.rsa.pub /etc/apk/keys/peachypies@protonmail.ch-5adb3818.rsa.pub',
    'curl -sLo /etc/apk/keys/hydrogen@fivem.net-614370b9.rsa.pub https://content.cfx.re/mirrors/build/linux/hydrogen@fivem.net-614370b9.rsa.pub':
    'cp /utils/hydrogen.rsa.pub /etc/apk/keys/hydrogen@fivem.net-614370b9.rsa.pub',
    'curl --http1.1 -sLo /tmp/premake.zip https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-src.zip':
    'cp /utils/premake.zip /tmp/premake.zip',
    '--allow-untrusted ': ''
}
for old,new in replacements.items():
    if s.count(old)!=1: raise SystemExit('Unexpected upstream toolchain script form: '+old[:45])
    s=s.replace(old,new)
p.write_text(s)
PY

printf 'phase=upstream-toolchain\n' > /work/status
/usr/local/bin/proot --kill-on-exit -b /dev:/dev -b /sys:/sys -b /proc:/proc \
    -b /tmp:/tmp -b /root:/root -R /app/alpine \
    /bin/sh /utils/proot_prepare.sh
printf '%s  %s\n' \
    3ef4a8d71777b3ccdd540e18862d688e32aa1c7bc5a1c0170271a43d0e736486 \
    /app/alpine/tmp/glibc.apk | sha256sum -c - >/dev/null
printf '%s  %s\n' \
    cc631135f481644ce74b28f6e37ceea848de06389d669182a012a9ca1ac5a95a \
    /app/alpine/tmp/glibc-bin.apk | sha256sum -c - >/dev/null
printf '%s  %s\n' \
    9ea192a3cfa2c01ff6e1bd15ee06e764365f4df405b9c86eec4ea0f4c834cb98 \
    /app/alpine/etc/apk/keys/peachypies@protonmail.ch-5adb3818.rsa.pub | sha256sum -c - >/dev/null
printf '%s  %s\n' \
    1b6bda078d8763019f7561497306cd1dbaad4849b2d7bb64f99770657126990a \
    /app/alpine/etc/apk/keys/hydrogen@fivem.net-614370b9.rsa.pub | sha256sum -c - >/dev/null

# The edge Git helper requires curl_global_trace, absent from pinned Cfx curl.
# Replace only Git inside the isolated rootfs with signed Alpine 3.16 Git.
/usr/local/bin/proot --kill-on-exit -b /dev:/dev -b /sys:/sys -b /proc:/proc \
    -R /app/alpine /bin/sh -ec \
    'apk verify /utils/git-2.36.6-r0.apk; apk add --no-cache /utils/git-2.36.6-r0.apk; test "$(git --version)" = "git version 2.36.6"'
/usr/local/bin/proot --kill-on-exit -R /app/alpine /bin/sh -c 'apk info -vv' > /work/toolchain-apk-versions.txt
sha256sum /app/alpine/etc/apk/repositories > /work/toolchain-repositories.sha256

printf 'phase=original-public-ci\n' > /work/status
cd /src
/bin/sh code/tools/ci/build_server_docker_alpine_public.sh
test "$(git -C /src rev-parse HEAD)" = 88a413835e9d7f56633f249880a13f42297153a2
test "$(git -C /src/ext/native-doc-tooling rev-parse HEAD)" = 272dbe87ad0b24f63fe1458305ea99984c82d557
printf '%s  %s\n' \
    5c4ba646598c50750342836662f94826ef2aae74209f2059a17835b00046de42 \
    /src/ext/natives/inp/natives_global.lua | sha256sum -c - >/dev/null
test -s /src/alpine/opt/cfx-server/FXServer
(cd /src/alpine/opt/cfx-server && find . -type f -print0 | sort -z | xargs -0 sha256sum > /work/public-output.sha256)
printf 'phase=build-complete\n' > /work/status
