#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. See https://creativecommons.org/licenses/by/3.0/deed.de
# endregion
pkgname=arch-install
pkgver=1.0.19
pkgrel=25
pkgdesc='Automate your installation process.'
arch=(any)
url=https://torben.website/archinstall
license=(CC-BY-3.0)
devdepends=(shellcheck)
depends=(
    bash
    bashlink
    util-linux
    coreutils
    sed
    wget
    xz
    tar
    grep
    which
)
optdepends=(
    'arch-install-scripts: to avoid using own implementation of "arch-chroot"'
    'btrfs-progs: to automatically format btrfs as filesystem'
    'dosfstools: for proper labeling boot partition'
    'efibootmgr: to autoconfigure first efi based boot'
    'fakechroot: to support install into a folder without root access'
    'fakeroot: to support install into a folder without root access'
    'gptfdisk: for automatic partition creation'
    'iproute2: for automatic network configuration'
    'os-prober: for automatic boot option creation for other found distributions'
    'pacman: if not provided a simple lite pacman version will be used to retrieve pacman first'
)
provides=(arch-install pack-into-archiso)
source=(archinstall.sh pack-into-archiso.sh)
md5sums=(SKIP SKIP)
copy_to_aur=true

package() {
    install \
        -D \
        --mode 755 \
        "${srcdir}/archinstall.sh" \
        "${pkgdir}/usr/bin/arch-install"
    install \
        -D \
        --mode 755 \
        "${srcdir}/pack-into-archiso.sh" \
        "${pkgdir}/usr/bin/pack-into-archiso"
}
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
