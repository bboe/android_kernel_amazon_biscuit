#!/bin/bash
# Usage: reproduce.sh DIR
#
# Rebuilds this repository's history, up to the commit with our own
# changes, into DIR. DIR must be on a case-sensitive filesystem: the
# kernel has files whose names differ only in case.
set -euo pipefail

archive=Echo_Dot_src-5.5.5.4-20220824.tar.bz2
url=https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/$archive
sha256=dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd
aosp=https://android.googlesource.com/kernel/common
picks=(
  e471d38798061ba35a79ca4addaa304e848639cb
  69c791342876671439782a435df43c044ab6c31d
  5e8b2cba415453f47f9976d99cd766f42b0e4cc6
  b1b3844449d596e5f25f591d89611c7e57d32610
  05b7da58527ef14001fe2b6e8de6b01d895d4429
  ef632d47376aa04e9adb96193d9faa6628a03e72
  bd8d3dd3ae35f283f3b76e47b9762225c9f7d46c
  4443881a4a96c3e0822ee4818300ffbc70298c02
  527d350d5e91c2b3abc2d49789843601abb8a0eb
)
linux_3_18_19=3be2c604f5d257dbcd2dcf8c2688cc6a1f899542

export GIT_COMMITTER_NAME='Bryce Boe'
export GIT_COMMITTER_EMAIL=bbzbryce@gmail.com
export GIT_COMMITTER_DATE='2022-08-24T00:00:00+0000'
git() {
  command git -c core.autocrlf=false -c core.fileMode=true -c core.symlinks=true \
    -c core.ignorecase=false -c commit.gpgSign=false "$@"
}

mkdir -p "$1"
cd "$1"
curl -fsSLO "$url"
echo "$sha256  $archive" | sha256sum -c -
tar --no-same-owner -xjf "$archive" platform.tar
tar --no-same-owner -xf platform.tar kernel/mediatek/mt8163/3.18
mv kernel/mediatek/mt8163/3.18 repo
rm -r kernel platform.tar
cd repo

git init -q -b main
git add -Af .
GIT_AUTHOR_NAME="$GIT_COMMITTER_NAME" GIT_AUTHOR_EMAIL="$GIT_COMMITTER_EMAIL" \
  GIT_AUTHOR_DATE="$GIT_COMMITTER_DATE" git commit -q --cleanup=verbatim -F - <<EOF
Import the Echo Dot (2nd Gen) kernel from Fire OS 5.5.5.4

The tree is kernel/mediatek/mt8163/3.18 from platform.tar in
$archive, unchanged, from Amazon's source code
notices for Echo devices:

$url
sha256 $sha256
EOF

git remote add aosp "$aosp"
git config remote.aosp.promisor true
git config remote.aosp.partialclonefilter blob:none
git fetch -q --filter=blob:none --depth=2 aosp "${picks[@]}"

for c in "${picks[@]}"; do
  if ! git cherry-pick -n "$c" > /dev/null 2>&1; then
    git diff --name-only --diff-filter=U | while IFS= read -r f; do
      if git cat-file -e "HEAD:$f" 2> /dev/null; then
        echo "unexpected conflict in $f" >&2
        exit 1
      fi
      git rm -q -f -- "$f"
    done
  fi
  GIT_AUTHOR_NAME=$(git log -1 --format=%an "$c") \
    GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "$c") \
    GIT_AUTHOR_DATE=$(git log -1 --format=%ad --date=raw "$c") \
    git commit -q --cleanup=verbatim -F - <<EOF
$(git log -1 --format=%B "$c")
(cherry picked from commit $c)
EOF
done

git fetch -q --filter=blob:none --depth=1 aosp "$linux_3_18_19"
git checkout -q "$linux_3_18_19" -- lib/decompress_unlzma.c
GIT_AUTHOR_NAME="$GIT_COMMITTER_NAME" GIT_AUTHOR_EMAIL="$GIT_COMMITTER_EMAIL" \
  GIT_AUTHOR_DATE="$GIT_COMMITTER_DATE" git commit -q --cleanup=verbatim -F - <<EOF
Restore lib/decompress_unlzma.c from Linux 3.18.19

Amazon's tree leaves out files its config does not build, and
CONFIG_RD_LZMA builds this one. It is unchanged from Google's
android-3.18 commit that merged Linux 3.18.19:

$aosp/+/$linux_3_18_19
EOF
git remote remove aosp
git log --format='%H %s'
