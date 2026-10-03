# Echo Dot (2nd Gen) kernel for TWRP

A 64-bit Linux 3.18.19 kernel for the Echo Dot (2nd Gen), codename `biscuit`, built to boot a TWRP 3.7 (Android 9) recovery on a Dot unlocked with amonet v1.1.0.

## History

Every commit but the last is reproducible to the hash: anyone can rebuild them from Amazon's and Google's published sources and get the same SHAs. The last commit holds this repository's own changes.

1. `03b74ac765c8` imports Amazon's kernel from Fire OS 5.5.5.4, unchanged: `kernel/mediatek/mt8163/3.18` from `platform.tar` in [`Echo_Dot_src-5.5.5.4-20220824.tar.bz2`](https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2), listed under Echo Dot (2nd Generation) on Amazon's [Source Code Notice for Echo and Alexa Devices](https://www.amazon.com/gp/help/customer/display.html?nodeId=201626480).
2. Nine commits from Google's `deprecated/android-3.18` branch, with their original authors, dates and messages, each ending `(cherry picked from commit …)`:
   - Google's own revert of Android's early ioctl backport, which reads policy version 30 in a format Android 9's policy does not use, then its replacement, the upstream SELinux extended permissions for ioctls, with two follow-ups.
   - `/proc/sys/vm/mmap_rnd_bits`, which Android 9's `init` treats as fatal when missing.
3. `4c4ceeb28783` restores `lib/decompress_unlzma.c`, unchanged from Google's commit that merged Linux 3.18.19. Amazon's trimmed tree leaves it out, and an LZMA initramfs needs it.
4. This repository's changes, in one commit: `CONFIG_RD_LZMA`, which keeps TWRP inside the 16 MiB recovery partition, and the build script, the workflow and this file.

## Reproducing the history

`.github/reproduce.sh DIR` runs these commands. It needs `bash`, `git`, `curl`, `tar` with bzip2 and `sha256sum`, and DIR on a case-sensitive filesystem: the kernel has files whose names differ only in case. It has given the same SHAs on Ubuntu 24.04 (git 2.43, GNU tar) and macOS (git 2.39, bsdtar).

Every commit gets a fixed committer, and the commits of this repository's own making a fixed author:

```sh
export GIT_COMMITTER_NAME='Bryce Boe' GIT_COMMITTER_EMAIL=bbzbryce@gmail.com
export GIT_COMMITTER_DATE='2022-08-24T00:00:00+0000'
```

Unpack Amazon's archive and commit the kernel as it is:

```sh
curl -fsSLO https://fireos-audio-src.s3.amazonaws.com/fcDtMdy42ieZkba5oyC4H3KcwU/Echo_Dot_src-5.5.5.4-20220824.tar.bz2
echo 'dd92a7ddd7c0fb9b61455542b84132ad00a445c38ef4f910b1272ac04f6f83dd  Echo_Dot_src-5.5.5.4-20220824.tar.bz2' | sha256sum -c -
tar --no-same-owner -xjf Echo_Dot_src-5.5.5.4-20220824.tar.bz2 platform.tar
tar --no-same-owner -xf platform.tar kernel/mediatek/mt8163/3.18
mv kernel/mediatek/mt8163/3.18 repo && cd repo
git init -q -b main && git add -Af .
GIT_AUTHOR_NAME="$GIT_COMMITTER_NAME" GIT_AUTHOR_EMAIL="$GIT_COMMITTER_EMAIL" \
  GIT_AUTHOR_DATE="$GIT_COMMITTER_DATE" git commit -q --cleanup=verbatim -F MESSAGE
```

MESSAGE is the commit's message, which `reproduce.sh` writes out. Then fetch Google's nine commits, each with its parent but without file contents, and replay each one with its own author and message:

```sh
git remote add aosp https://android.googlesource.com/kernel/common
git config remote.aosp.promisor true
git config remote.aosp.partialclonefilter blob:none
git fetch -q --filter=blob:none --depth=2 aosp \
  e471d38798061ba35a79ca4addaa304e848639cb 69c791342876671439782a435df43c044ab6c31d \
  5e8b2cba415453f47f9976d99cd766f42b0e4cc6 b1b3844449d596e5f25f591d89611c7e57d32610 \
  05b7da58527ef14001fe2b6e8de6b01d895d4429 ef632d47376aa04e9adb96193d9faa6628a03e72 \
  bd8d3dd3ae35f283f3b76e47b9762225c9f7d46c 4443881a4a96c3e0822ee4818300ffbc70298c02 \
  527d350d5e91c2b3abc2d49789843601abb8a0eb
# for each, in that order:
git cherry-pick -n $c
GIT_AUTHOR_NAME="$(git log -1 --format=%an $c)" GIT_AUTHOR_EMAIL="$(git log -1 --format=%ae $c)" \
  GIT_AUTHOR_DATE="$(git log -1 --format=%ad --date=raw $c)" \
  git commit -q --cleanup=verbatim -F <(printf '%s\n(cherry picked from commit %s)\n' "$(git log -1 --format=%B $c)" $c)
```

One of them touches `Documentation/sysctl/vm.txt`, which Amazon's tree does not have. That conflict resolves with `git rm -f`. The script commits each one itself, not with `cherry-pick -x`, because git versions word a conflicted commit's message differently.

Last, take the one missing file from Google's 3.18.19 merge. Git downloads only that file:

```sh
git fetch -q --filter=blob:none --depth=1 aosp 3be2c604f5d257dbcd2dcf8c2688cc6a1f899542
git checkout -q 3be2c604f5d257dbcd2dcf8c2688cc6a1f899542 -- lib/decompress_unlzma.c
GIT_AUTHOR_NAME="$GIT_COMMITTER_NAME" GIT_AUTHOR_EMAIL="$GIT_COMMITTER_EMAIL" \
  GIT_AUTHOR_DATE="$GIT_COMMITTER_DATE" git commit -q --cleanup=verbatim -F MESSAGE
```

The result is `4c4ceeb28783d3b09fb85a0ea1bd4c64e3430e09`, and this repository's own commit sits on top of it.

## Building

The release build runs, on x86-64 Linux:

```sh
.github/build.sh dist
```

It fetches Google's `aarch64-linux-android-4.9` at commit `d4d54ede13f6` and clones the checked-out commit, both under `/tmp/biscuit-kernel`, and builds there. The kernel embeds the paths of its sources and of the compiler, so fixing both makes the same commit give the same `Image.gz-dtb` on any host. The build stamps come from the commit, and the release names it: `3.18.19-bboe-g` and 12 hex digits.

A build by other means needs `-fcommon` in `HOSTCFLAGS` with GCC 10 or later. The device-tree compiler's shipped lexer and parser both define `yylloc`, and from GCC 10 the two no longer merge, so the host tools fail to link. `build.sh` passes the Makefile's own host flags plus `-fcommon`.

## Verifying a release

```sh
gh attestation verify Image.gz-dtb --repo bboe/android_kernel_amazon_biscuit
```
