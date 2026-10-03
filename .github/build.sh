#!/bin/bash
# Usage: .github/build.sh DEST
#
# Builds Image.gz-dtb from the commit checked out here and copies it into
# DEST. The kernel embeds the paths of its sources and of the compiler, so
# both go under a fixed directory first; the same commit then gives the
# same bytes on any x86-64 Linux host.
set -euo pipefail

toolchain_url=https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
toolchain_commit=d4d54ede13f6f76c77137c35a87fa5f0436eded2
mkdir -p "$1"
dest=$(cd "$1" && pwd)
repo=$(cd "$(dirname "$0")/.." && pwd)
root=/tmp/biscuit-kernel

if [ -n "$(git -C "$repo" status --porcelain)" ]; then
  echo "warning: uncommitted changes are not built" >&2
fi

if [ "$(git -C "$root/toolchain" rev-parse HEAD 2> /dev/null)" != "$toolchain_commit" ]; then
  rm -rf "$root/toolchain"
  git init -q "$root/toolchain"
  git -C "$root/toolchain" fetch -q --depth 1 "$toolchain_url" "$toolchain_commit"
  git -C "$root/toolchain" checkout -q FETCH_HEAD
fi

rm -rf "$root/src" "$root/out"
git clone -q --no-local "$repo" "$root/src"
cd "$root/src"
commit=$(git rev-parse HEAD)
export KBUILD_BUILD_TIMESTAMP
KBUILD_BUILD_TIMESTAMP=$(git log -1 --format=%cd --date=rfc2822)
export KBUILD_BUILD_USER=bboe
export KBUILD_BUILD_HOST=github
export KBUILD_BUILD_VERSION=1

args=(
  O="$root/out"
  ARCH=arm64
  CROSS_COMPILE="$root/toolchain/bin/aarch64-linux-android-"
  HOSTCFLAGS="-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89 -fcommon"
  LOCALVERSION="-bboe-g${commit:0:12}"
)
make "${args[@]}" biscuit_defconfig
make "${args[@]}" -j"$(nproc)"
cp "$root/out/arch/arm64/boot/Image.gz-dtb" "$dest/"
cd "$dest"
sha256sum Image.gz-dtb
