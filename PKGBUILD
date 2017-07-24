#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de
# endregion
pkgname=arch-install
pkgver=1.0.11
pkgrel=17
pkgdesc='automate your installation process'
arch=('any')
url='http://torben.website/archInstall'
license=('CC-BY-3.0')
depends=('bash'
         'util-linux'
         'coreutils'
         'sed'
         'wget'
         'xz'
         'tar'
         'grep'
         'which')
optdepends=('pacman: if not provided a simple lite pacman version will be used to retrieve pacman first'
            'efibootmgr: to autoconfigure first efi based boot'
            'gptfdisk: for automatic partition creation'
            'btrfs-progs: to automatically format btrfs as filesystem'
            'dosfstools: for proper labeling boot partition'
            'arch-install-scripts: to avoid using own implementation of "arch-chroot"'
            'fakeroot: to support install into a folder without root access'
            'fakechroot: to support install into a folder without root access'
            'os-prober: for automatic boot option creation for other found distributions'
            'iproute2: for automatic network configuration')
provides=(arch-install)
source=('archInstall.sh')
md5sums=('SKIP')
copyToAUR=true

package() {
    install -D --mode 755 "${srcdir}/archInstall.sh" \
        "${pkgdir}/usr/bin/arch-install"
}
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
