#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# [Project page](https://tsickert.com/archinstall)

# Copyright Torben Sickert (info["~at~"]tsickert.com) 16.12.2012

# License
# -------

# This library written by Torben Sickert stands under a creative commons naming
# 4.0 international license.
# See https://creativecommons.org/licenses/by/4.0/deed.de
# endregion
# shellcheck disable=SC1004,SC2016,SC2034,SC2155
shopt -s expand_aliases
# region import
alias ai.download=ai_download
ai_download() {
    local -r __documentation__='
        Simply downloads missing modules.

        >>> ai.download --silent https://domain.tld/path/to/file.ext; echo $?
        6
    '
    command curl --insecure "$@"
    return $?
}

if [ -f "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh" ]; then
    # shellcheck disable=SC1090
    source "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh"
elif [ -f "/usr/lib/bashlink/module.sh" ]; then
    # shellcheck disable=SC1091
    source "/usr/lib/bashlink/module.sh"
else
    declare -g AI_CACHE_PATH="$(
        echo "$@" | \
            sed \
                --regexp-extended \
                's/(^| )(-o|--cache-path)(=| +)(.+[^ ])($| +-)/\4/'
    )"
    [ "$AI_CACHE_PATH" = "$*" ] && \
        AI_CACHE_PATH=archInstallCache
    AI_CACHE_PATH="${AI_CACHE_PATH%/}/"
    declare -gr BL_MODULE_REMOTE_MODULE_CACHE_PATH="${AI_CACHE_PATH}bashlink"
    mkdir --parents "$BL_MODULE_REMOTE_MODULE_CACHE_PATH"
    declare -gr BL_MODULE_RETRIEVE_REMOTE_MODULES=true
    if ! (
        [ -f "${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh" ] || \
        ai.download \
            https://raw.githubusercontent.com/thaibault/bashlink/main/module.sh \
                >"${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh"
    ); then
        echo Needed bashlink library could not be retrieved. 1>&2
        rm \
            --force \
            --recursive \
            "${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh"
fi
# NOTE: Shortens this module's scope to "ai_*" and "AI_*" names.
BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^archinstall$/ai/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^ARCHINSTALL$/AI/')
bl.module.import bashlink.changeroot
bl.module.import bashlink.dictionary
bl.module.import bashlink.exception
bl.module.import bashlink.logging
bl.module.import bashlink.number
bl.module.import bashlink.tools
# endregion
# region variables
declare -gr AI__DOCUMENTATION__='
    This module installs a linux from scratch by the arch way. You will end up
    in ligtweigth linux with pacman as packet manager. You can directly install
    into a given blockdevice, partition or any directory (see command line
    option "--target"). Note that every needed information which is not given
    via command line will be asked interactively on start. This script is as
    unnatted it could be, which means you can relax after providing all needed
    informations in the beginning till your new system is ready to boot.

    Start install progress command (Assuming internet is available):

    ```bash
        curl \
            https://raw.githubusercontent.com/thaibault/archinstall/main/archinstall.sh \
                >archinstall.sh && \
            chmod +x archinstall.sh
    ```

    Note that you only get very necessary output until you provide "--verbose"
    as commandline option.

    Examples:

    Start install progress command on first found blockdevice:

    ```bash
        arch-install --target /dev/sda
    ```

    Install directly into a given partition with verbose output:

    ```bash
        arch-install --target /dev/sda1 --verbose
    ```

    Install directly into a given directory with additional packages included:

    ```bash
        arch-install --target /dev/sda1 --verbose -f vim net-tools
    ```
'
declare -agr AI__DEPENDENCIES__=(
    bash
    cat
    chroot
    curl
    grep
    ln
    lsblk
    mktemp
    mount
    mountpoint
    rm
    sed
    sort
    sync
    touch
    tar
    uname
    which
    xz
    zstd
)
declare -agr AI__OPTIONAL_DEPENDENCIES__=(
    # Dependencies for blockdevice integration
    'blockdev: Call block device ioctls from the command line (part of util-linux).'
    'btrfs: Control a btrfs filesystem (part of btrfs-progs).'
    'cryptsetup: Userspace setup tool for transparent encryption of block devices using dm-crypt.'
    # Only needed for boot without boot loader.
    #'efibootmgr: Manipulate the EFI Boot Manager (part of efibootmgr).'
    'gdisk: Interactive GUID partition table (GPT) manipulator (part of gptfdisk).'
    # Native arch install script helper.
    'arch-chroot: Performs an arch chroot with api file system binding (part of package "arch-install-scripts").'
    # Needed for smart dos filesystem labeling, installing without root
    # permissions or automatic network configuration.
    'dosfslabel: Handle dos file systems (part of dosfstools).'
    'fakeroot: Run a command in an environment faking root privileges for file manipulation.'
    'fakechroot: Wraps some c-lib functions to enable programs like "chroot" running without root privileges.'
    'ip: Determines network adapter (part of iproute2).'
    'os-prober: Detects presence of other operating systems.'
    'pacstrap: Installs arch linux from an existing linux system (part of package "arch-install-scripts").'
)
declare -agr AI_BASIC_PACKAGES=(base iwd linux linux-firmware ntp which)
declare -agr AI_COMMON_ADDITIONAL_PACKAGES=(base-devel python sudo)

declare -ag AI_ADDITIONAL_PACKAGES=()
declare -g AI_ADD_COMMON_ADDITIONAL_PACKAGES=false
# After determining dependencies a list like this will be stored:
# "bash", "curl", "glibc", "openssl", "pacman", "readline", "xz", "tar" ...
declare -ag AI_NEEDED_PACKAGES=(filesystem pacman)

# Defines where to mount temporary new filesystem.
# NOTE: Path has to be end with a system specified delimiter.
declare -g AI_MOUNTPOINT_PATH=/mnt/

bl.dictionary.set AI_KNOWN_DEPENDENCY_ALIASES libncursesw.so ncurses

declare -ag AI_PACKAGE_SOURCE_URLS=(
    'https://www.archlinux.org/mirrorlist/?country=DE&protocol=http&ip_version=4&use_mirror_status=on'
)
declare -ag AI_PACKAGE_URLS=(
    https://mirrors.kernel.org/archlinux
)

declare -gi AI_NETWORK_TIMEOUT_IN_SECONDS=6

declare -ag AI_UNNEEDED_FILE_LOCATIONS=(.INSTALL .PKGINFO var/cache/pacman)
## region command line arguments
# NOTE: Already determined if bashlink had to be retrieved remotely.
declare -g AI_CACHE_PATH="${AI_CACHE_PATH:-archInstallCache/}"
declare -g AI_AUTO_PARTITIONING=false
declare -g AI_BOOT_ENTRY_LABEL=archLinux
declare -g AI_BOOT_PARTITION_LABEL=uefiBoot
# NOTE: A FAT32 partition has to be at least 2048 MB large.
declare -gi AI_BOOT_SPACE_IN_MEGA_BYTE=2048

declare -gi AI_NEEDED_SYSTEM_SPACE_IN_MEGA_BYTE=512
declare -g AI_SYSTEM_PARTITION_LABEL=system
declare -g AI_SYSTEM_PARTITION_INSTALLATION_ONLY=false

# NOTE: Each value which is present in "/etc/pacman.d/mirrorlist" is ok.
declare -g AI_COUNTRY_WITH_MIRRORS=Germany
# NOTE: This properties aren't needed in the future with supporting "localectl"
# program.
declare -g AI_LOCAL_TIME=Europe/Berlin

# NOTE: Possible constant values are "i686", "x86_64" "arm" or "any".
declare -g AI_CPU_ARCHITECTURE="$(uname -m)"

declare -g AI_HOST_NAME=''

declare -g AI_KEYBOARD_LAYOUT=de-latin1
declare -g AI_KEY_MAP_CONFIGURATION_FILE_CONTENT="KEYMAP=${AI_KEYBOARD_LAYOUT}"$'\nFONT=Lat2-Terminus16\nFONT_MAP='

declare -ag AI_NEEDED_SERVICES=(systemd-networkd systemd-resolved)

declare -g AI_TARGET=archInstall

declare -g AI_ENCRYPT=false
declare -g AI_PASSWORD=root
declare -ag AI_USER_NAMES=()

declare -g AI_PREVENT_USING_NATIVE_ARCH_CHANGEROOT=false
declare -g AI_PREVENT_USING_EXISTING_PACMAN=false
declare -g AI_AUTOMATIC_REBOOT=false
## endregion
BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^archinstall([._][a-zA-Z_-]+)?$/ai\1/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^ARCHINSTALL(_[a-zA-Z_-]+)?$/AI\1/')
# endregion
# region functions
## region command line interface
alias ai.get_commandline_option_description=ai_get_commandline_option_description
ai_get_commandline_option_description() {
    local -r __documentation__='
        Prints descriptions about each available command line option.
        NOTE: All letters are used for short options.
        NOTE: "-k" and "--key-map-configuration" is not needed in the future.

        >>> ai.get_commandline_option_description
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        -h --help Shows this help message.
        ...
    '
    cat << EOF
-h --help Shows this help message.

-v --verbose Tells you what is going on.

-d --debug Gives you any output from all tools which are used.


-u --user-names [USER_NAMES [USER_NAMES ...]], Defines user names for new system (default: "${AI_USER_NAMES[@]}").

-n --host-name HOST_NAME Defines name for new system (default: "$AI_HOST_NAME").


-c --cpu-architecture CPU_ARCHITECTURE Defines architecture (default: "$AI_CPU_ARCHITECTURE").

-t --target TARGET Defines where to install new operating system. You can provide a full disk or partition via blockdevice such as "/dev/sda" or "/dev/sda1". You can also provide a directory path such as "/tmp/filesystem" (default: "$AI_TARGET").


-l --local-time LOCAL_TIME Local time for you system (default: "$AI_LOCAL_TIME").

-i --keyboard-layout LAYOUT Defines needed keyboard layout (default: "$AI_KEYBOARD_LAYOUT").

-k --key-map-configuration FILE_CONTENT Keyboard map configuration (default: "$AI_KEY_MAP_CONFIGURATION_FILE_CONTENT").

-m --country-with-mirrors COUNTRY Country for enabling servers to get packages from (default: "$AI_COUNTRY_WITH_MIRRORS").


-r --reboot Reboot after finishing installation.

-p --prevent-using-existing-pacman Ignores presence of pacman to use it for install operating system (default: "$AI_PREVENT_USING_EXISTING_PACMAN").

-y --prevent-using-native-arch-chroot Ignores presence of "arch-chroot" to use it for chroot into newly created operating system (default: "$AI_PREVENT_USING_NATIVE_ARCH_CHANGEROOT").

-a --auto-partitioning Defines to do partitioning on founded block device automatic.


-b --boot-partition-label LABEL Partition label for uefi boot partition (default: "$AI_BOOT_PARTITION_LABEL").

-s --system-partition-label LABEL Partition label for system partition (default: "$AI_SYSTEM_PARTITION_LABEL").


-e --boot-entry-label LABEL Boot entry label (default: "$AI_BOOT_ENTRY_LABEL").


-w --boot-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your boot partition (default: "$AI_BOOT_SPACE_IN_MEGA_BYTE megabyte"). This partition is used for kernel and initramfs only.

-q --needed-system-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your system partition (default: "$AI_NEEDED_SYSTEM_SPACE_IN_MEGA_BYTE megabyte"). This partition is used for the whole operating system.


-z --add-common-additional-packages (default: "$AI_ADD_COMMON_ADDITIONAL_PACKAGES") If present the following packages will be installed: "${AI_COMMON_ADDITIONAL_PACKAGES[*]}".

-g --additional-packages [PACKAGES [PACKAGES ...]], You can give a list with additional available packages (default: "${AI_ADDITIONAL_PACKAGES[@]}").

-j --needed-services [SERVICES [SERVICES ...]], You can give a list with additional available services (default: "${AI_NEEDED_SERVICES[@]}").

-o --cache-path PATH Define where to load and save downloaded dependencies (default: "$AI_CACHE_PATH").


-S --system-partition-installation-only Interpret given input as single partition to use as target only (Will be determined automatically if not set explicitely).

-E --encrypt Encrypts system partition.

-P --password Password to use for root login (and encryption if corresponding flag is set).


-x --timeout NUMBER_OF_SECONDS Defines time to wait for requests (default: $AI_NETWORK_TIMEOUT_IN_SECONDS).

Presets:

-A TARGET Is the same as "--auto-partitioning --debug --host-name archlinux --target TARGET".
EOF
}
alias ai.get_help_message=ai_get_help_message
ai_get_help_message() {
    local -r __documentation__='
        Provides a help message for this module.

        >>> ai.get_help_message
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        ...
        Usage: arch-install [options]
        ...
    '
    echo -e $'\nUsage: arch-install [options]\n'
    echo -e "$AI__DOCUMENTATION__"
    echo -e $'\nOption descriptions:\n'
    ai.get_commandline_option_description "$@"
    echo
}
# NOTE: Depends on "ai.get_commandline_option_description" and
# "ai.get_help_message".
alias ai.commandline_interface=ai_commandline_interface
ai_commandline_interface() {
    local -r __documentation__='
        Provides the command line interface and interactive questions.

        >>> ai.commandline_interface --help
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        ...
        Usage: arch-install [options]
        ...

        >>> ai.commandline_interface --not-existing; echo $?
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        Given argument: "--not-existing" is not available.
        ...
        Usage: arch-install [options]
        ...
        1
    '
    bl.logging.set_command_level debug
    while true; do
        case "$1" in
            -h|--help)
                shift
                bl.logging.plain "$(ai.get_help_message "$0")"
                exit 0
                ;;
            -v|--verbose)
                shift
                if ! bl.logging.is_enabled info; then
                    bl.logging.set_level info
                fi
                ;;
            -d|--debug)
                shift
                bl.logging.set_level debug
                ;;

            -u|--user-names)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    AI_USER_NAMES+=("$1")
                    shift
                done
                ;;
            -n|--host-name)
                shift
                AI_HOST_NAME="$1"
                shift
                ;;

            -c|--cpu-architecture)
                shift
                AI_CPU_ARCHITECTURE="$1"
                shift
                ;;
            -t|--target)
                shift
                AI_TARGET="$1"
                shift
                ;;

            -l|--local-time)
                shift
                AI_LOCAL_TIME="$1"
                shift
                ;;
            -i|--keyboard-layout)
                shift
                AI_KEYBOARD_LAYOUT="$1"
                # NOTE: Keep the key map configuration in sync.
                AI_KEY_MAP_CONFIGURATION_FILE_CONTENT="$(
                    echo "$AI_KEY_MAP_CONFIGURATION_FILE_CONTENT" | \
                        command sed "s/^KEYMAP=.*$/KEYMAP=${1}/"
                )"
                shift
                ;;
            -k|--key-map-configuration)
                shift
                AI_KEY_MAP_CONFIGURATION_FILE_CONTENT="$1"
                shift
                ;;
            -m|--country-with-mirrors)
                shift
                AI_COUNTRY_WITH_MIRRORS="$1"
                shift
                ;;

            -r|--reboot)
                shift
                AI_AUTOMATIC_REBOOT=true
                ;;
            -a|--auto-partitioning)
                shift
                AI_AUTO_PARTITIONING=true
                ;;
            -p|--prevent-using-existing-pacman)
                shift
                AI_PREVENT_USING_EXISTING_PACMAN=true
                ;;
            -y|--prevent-using-native-arch-chroot)
                shift
                AI_PREVENT_USING_NATIVE_ARCH_CHANGEROOT=true
                ;;

            -b|--boot-partition-label)
                shift
                AI_BOOT_PARTITION_LABEL="$1"
                shift
                ;;
            -s|--system-partition-label)
                shift
                AI_SYSTEM_PARTITION_LABEL="$1"
                shift
                ;;

            -e|--boot-entry-label)
                shift
                AI_BOOT_ENTRY_LABEL="$1"
                shift
                ;;

            -w|--boot-space-in-mega-byte)
                shift
                AI_BOOT_SPACE_IN_MEGA_BYTE="$1"
                shift
                ;;
            -q|--needed-system-space-in-mega-byte)
                shift
                AI_NEEDED_SYSTEM_SPACE_IN_MEGA_BYTE="$1"
                shift
                ;;

            -z|--add-common-additional-packages)
                shift
                AI_ADD_COMMON_ADDITIONAL_PACKAGES=true
                ;;
            -g|--additional-packages)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    AI_ADDITIONAL_PACKAGES+=("$1")
                    shift
                done
                ;;
            -j|--needed-services)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    AI_NEEDED_SERVICES+=("$1")
                    shift
                done
                ;;
            -o|--cache-path)
                shift
                AI_CACHE_PATH="${1%/}/"
                shift
                ;;

            -S|--system-partition-installation-only)
                shift
                AI_SYSTEM_PARTITION_INSTALLATION_ONLY=true
                ;;

            -E|--encrypt)
                shift
                AI_ENCRYPT=true
                ;;
            -P|--password)
                shift
                AI_PASSWORD="$1"
                shift
                ;;

            -x|--timeout)
                shift
                AI_NETWORK_TIMEOUT_IN_SECONDS="$1"
                shift
                ;;

            -A)
                shift

                AI_AUTO_PARTITIONING=true
                AI_HOST_NAME=archlinux
                AI_TARGET="$1"

                bl.logging.set_level debug

                shift
                ;;

            '')
                shift || \
                    true
                break
                ;;
            *)
                bl.logging.error "Given argument: \"${1}\" is not available."
                bl.logging.plain "$(ai.get_help_message)"

                return 1
        esac
    done
    if \
        [[ "$UID" != 0 ]] && \
        ! {
            hash fakeroot 2>/dev/null && \
            hash fakechroot 2>/dev/null && \
            { [ -e "$AI_TARGET" ] && [ -d "$AI_TARGET" ]; }
        }
    then
        bl.logging.error_exception \
            "You have to run this script as \"root\" not as \"$USER\". You can alternatively install \"fakeroot\", \"fakechroot\" and install into a directory."
    fi
    if bl.tools.is_main; then
        if [ "$AI_HOST_NAME" = '' ]; then
            while true; do
                bl.logging.plain -n 'Please set hostname for new system: '
                read -r AI_HOST_NAME
                if [[ "$(
                    echo "$AI_HOST_NAME" | \
                        tr '[:upper:]' '[:lower:]'
                )" != '' ]]; then
                    break
                fi
            done
        fi
    fi
    # NOTE: We have to use `"$(which grep)"` instead of `command grep` because
    # the latter one's return value is not catched by the wrapping test, so
    # activated exceptions would throw on negative test here.
    # shellcheck disable=SC2230
    if \
        ! $AI_SYSTEM_PARTITION_INSTALLATION_ONLY && \
        ! $AI_AUTO_PARTITIONING && \
        echo "$AI_TARGET" | \
            "$(which grep)" --quiet --extended-regexp '[0-9]$'
    then
        AI_SYSTEM_PARTITION_INSTALLATION_ONLY=true
    fi
    return 0
}
## endregion
## region helper
### region change root functions
alias ai.changeroot=ai_changeroot
ai_changeroot() {
    local -r __documentation__='
        This function emulates the arch linux native "arch-chroot" function.
    '
    if ! $AI_PREVENT_USING_NATIVE_ARCH_CHANGEROOT && \
        hash arch-chroot 2>/dev/null
    then
        if [ "$1" = / ]; then
            shift
            "$@"
            return $?
        fi
        arch-chroot "$@"
        return $?
    fi
    bl.changeroot "$@"
    return $?
}
alias ai.changeroot_to_mountpoint=ai_changeroot_to_mountpoint
ai_changeroot_to_mountpoint() {
    local -r __documentation__='
        This function performs a changeroot to currently set mountpoint path.
    '
    ai.changeroot "$AI_MOUNTPOINT_PATH" "$@"
    return $?
}
### endregion
alias ai.add_boot_entries=ai_add_boot_entries
ai_add_boot_entries() {
    local -r __documentation__='
        Creates an uefi boot entry.
    '
    # NOTE: See boot without boot loader down here:
    #if ai.changeroot_to_mountpoint bash -c 'hash efibootmgr' \
    #    2>/dev/null
    #then
        bl.logging.info Configure efi boot manager.
        local root_boot_selector="root=PARTLABEL=${AI_SYSTEM_PARTITION_LABEL} rootflags=subvol=root"
        if $AI_ENCRYPT; then
            mkdir --parents "${AI_MOUNTPOINT_PATH}boot/keys"
            echo -n "$AI_PASSWORD" \
                >"${AI_MOUNTPOINT_PATH}boot/keys/boot.luks.password.txt"
            root_boot_selector="rd.luks.key=$(ai.determine_partition_uuid "$AI_SYSTEM_PARTITION_LABEL")=/keys/boot.luks.password.txt:UUID=$(ai.determine_partition_uuid "$AI_BOOT_PARTITION_LABEL") rd.luks.name=$(ai.determine_partition_uuid "$AI_SYSTEM_PARTITION_LABEL")=cryptroot rd.luks.options=timeout=36000 rd.luks.options=$(ai.determine_partition_uuid "$AI_SYSTEM_PARTITION_LABEL")=keyfile-timeout=2s root=/dev/mapper/cryptroot rw rootflags=subvol=root rootflags=x-systemd.device-timeout=36030"
        fi
        local -r kernel_command_line_options="${root_boot_selector} quiet loglevel=2"
        local -r kernel_command_line="initrd=\\initramfs-linux.img ${kernel_command_line_options}"
        # shellcheck disable=SC2028
        echo "\\vmlinuz-linux ${kernel_command_line}" \
            >"${AI_MOUNTPOINT_PATH}/boot/startup.nsh"

        # Version to skip boot loader and register linux kernel as boot entry
        # directly:
        # NOTE: Boot entry to boot on next reboot should be added at last.
        #ai.changeroot_to_mountpoint efibootmgr \
        #    --create \
        #    --disk "$AI_TARGET" \
        #    --label "$AI_BOOT_ENTRY_LABEL" \
        #    --loader '\vmlinuz-linux' \
        #    --part 1 \
        #    --unicode \
        #    "$kernel_command_line" || \
        #        bl.logging.warn \
        #            "Adding boot entry \"${AI_BOOT_ENTRY_LABEL}\" failed."

        # Add boot entry via systemds bootloader.
        ai.changeroot_to_mountpoint bootctl install
        # NOTE: "bootctl" can not determine the boot partition in a change
        # root, so we register the boot loader in the firmware from here.
        if \
            ! $AI_SYSTEM_PARTITION_INSTALLATION_ONLY && \
            hash efibootmgr 2>/dev/null && \
            [ -d /sys/firmware/efi/efivars ]
        then
            efibootmgr \
                --create \
                --disk "$AI_TARGET" \
                --label "$AI_BOOT_ENTRY_LABEL" \
                --loader '\EFI\systemd\systemd-bootx64.efi' \
                --part 1 \
                --unicode \
                    1>/dev/null || \
                        bl.logging.warn \
                            "Adding boot entry \"${AI_BOOT_ENTRY_LABEL}\" failed."
        else
            bl.logging.info \
                Boot via the firmware\'s fallback boot loader location.
        fi
        cat << EOF 1>>"${AI_MOUNTPOINT_PATH}boot/loader/loader.conf"
# Added during installation by "archinstall".

# Boot the default named boot configuration.
default default
# Do not show the boot selector.
editor  0
# Do not wait for user input.
timeout 0
EOF

        cat << EOF 1>>"${AI_MOUNTPOINT_PATH}boot/loader/entries/default.conf"
title   default
linux   /vmlinuz-linux
initrd  /initramfs-linux.img

options ${kernel_command_line_options}
EOF
    #else
    #    bl.logging.warn \
    #        \"efibootmgr\" doesn't seem to be installed. Creating a boot \
    #        entry failed.
    #fi
}
alias ai.append_temporary_install_mirrors=ai_append_temporary_install_mirrors
ai_append_temporary_install_mirrors() {
    local -r __documentation__='
        Appends temporary used mirrors to download missing packages during
        installation.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> mkdir --parents "${AI_MOUNTPOINT_PATH}etc/pacman.d"
        >>> ai.append_temporary_install_mirrors "https://a.tld https://b.tld"
        >>> cat "${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
        Server = https://a.tld/$repo/os/$arch
        Server = https://b.tld/$repo/os/$arch
    '
    local url
    for url in $1; do
        echo "Server = $url/\$repo/os/\$arch" \
            1>>"${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
    done
}
alias ai.cache=ai_cache
ai_cache() {
    local -r __documentation__='
        Cache previous downloaded packages and database.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> local AI_CACHE_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> mkdir --parents \
        >>>     "${AI_MOUNTPOINT_PATH}var/cache/pacman/pkg" \
        >>>     "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync"
        >>> touch "${AI_MOUNTPOINT_PATH}var/cache/pacman/pkg/"{a.pkg.tar.xz,b.pkg.tar.zst}
        >>> touch "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync/core.db"
        >>> ai.cache
        >>> ls "$AI_CACHE_PATH"
        a.pkg.tar.xz
        b.pkg.tar.zst
        core.db
    '
    bl.logging.info Cache loaded packages.
    cp \
        --force \
        --preserve \
        "${AI_MOUNTPOINT_PATH}var/cache/pacman/pkg/"*.pkg.tar.* \
        "$AI_CACHE_PATH"
    bl.logging.info Cache loaded databases.
    cp \
        --force \
        --preserve \
        "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync/"*.db \
        "$AI_CACHE_PATH"
    return $?
}
alias ai.enable_services=ai_enable_services
ai_enable_services() {
    local -r __documentation__='
        Enable all needed services.
    '
    local network_device_name
    for network_device_name in $(
        ip addr | \
            command grep --extended-regexp --only-matching '^[0-9]+: .+: ' | \
                command sed --regexp-extended 's/^[0-9]+: (.+): $/\1/g'
    ); do
        # NOTE: We have to use `"$(which grep)"` instead of `command grep`
        # because the latter one's return value is not catched by the wrapping
        # test, so activated exceptions would throw on negative test here.
        # shellcheck disable=SC2230
        if ! echo "$network_device_name" | "$(which grep)" \
            --extended-regexp '^(lo|loopback|localhost)$' --quiet
        then
            bl.logging.info "Found network device \"${network_device_name}\"."
            cat << EOF 1>"${AI_MOUNTPOINT_PATH}etc/systemd/network/20-ethernet.network"
[Match]
Name=en*
Name=eth*

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes

[DHCP]
RouteMetric=512
EOF
            cat << EOF 1>"${AI_MOUNTPOINT_PATH}etc/systemd/network/20-wireless.network"
[Match]
Name=wlp*
Name=wlan*

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes

[DHCP]
RouteMetric=1024
EOF
# NOTE: Legacy "netctl-auto" approach.
#            local service_name=dhcpcd
#            local connection=ethernet
#            local description='A basic dhcp connection'
#            local additional_properties=''
#            if [ "${network_device_name:0:1}" = e ]; then
#                bl.logging.info \
#                    "Enable dhcp service on wired network device \"$network_device_name\"."
#                service_name=netctl-ifplugd
#                connection=ethernet
#                description='A basic ethernet dhcp connection'
#            elif [ "${network_device_name:0:1}" = w ]; then
#                bl.logging.info \
#                    "Enable dhcp service on wireless network device \"$network_device_name\"."
#                service_name=netctl-auto
#                connection=wireless
#                description='A simple WPA encrypted wireless connection'
#                additional_properties=$'\nSecurity=wpa\nESSID='"'home'"$'\nKey='"'home'"
#            fi
#        cat << EOF 1>"${AI_MOUNTPOINT_PATH}etc/netctl/${network_device_name}-dhcp"
#Description='${description}'
#Interface=${network_device_name}
#Connection=${connection}
#IP=dhcp
### for DHCPv6
##IP6=dhcp
### for IPv6 autoconfiguration
##IP6=stateless${additional_properties}
#EOF
#            ln \
#                --force \
#                --symbolic \
#                "/usr/lib/systemd/system/${service_name}@.service" \
#                "${AI_MOUNTPOINT_PATH}etc/systemd/system/multi-user.target.wants/${service_name}@${network_device_name}.service"
        fi
    done
    local service_name
    for service_name in "${AI_NEEDED_SERVICES[@]}"; do
        bl.logging.info "Enable \"$service_name\" service."
        ai.changeroot_to_mountpoint \
            systemctl \
            enable \
            "${service_name}.service"
    done
}
alias ai.determine_partition_uuid=ai_determine_partition_uuid
ai_determine_partition_uuid() {
    local -r __documentation__='
        Determines uuid by given identifier.
    '
    command lsblk --noheadings --output PARTLABEL,UUID "$AI_TARGET" | \
        command grep "$1" | \
            command sed --regexp-extended 's/.+ (.+)$/\1/'
}
alias ai.get_hosts_content=ai_get_hosts_content
ai_get_hosts_content() {
    local -r __documentation__='
        Provides the file content for the "/etc/hosts".

        >>> ai.get_hosts_content my-host
        #<IP-Adress> <computername.workgroup> <computernames>
        127.0.0.1    localhost.localdomain    localhost my-host
        ::1          ipv6-localhost           ipv6-localhost ipv6-my-host
    '
    cat << EOF
#<IP-Adress> <computername.workgroup> <computernames>
127.0.0.1    localhost.localdomain    localhost $1
::1          ipv6-localhost           ipv6-localhost ipv6-$1
EOF
}
# NOTE: Depends on "ai.get_hosts_content", "ai.enable_services"
alias ai.configure=ai_configure
ai_configure() {
    local -r __documentation__='
        Provides generic linux configuration mechanism. If new systemd programs
        are used (if first argument is "true") they could have problems in
        change root environment without and exclusive dbus connection.
    '
    if $AI_ENCRYPT; then
        bl.logging.info \
            Configure initramfs to support decrypting root system at boot.
        sed \
            --in-place \
            --regexp-extended \
            's/^(MODULES=\().*(\))$/\1vfat\2/' \
            "${AI_MOUNTPOINT_PATH}etc/mkinitcpio.conf"
        sed \
            --in-place \
            --regexp-extended \
            's/^(HOOKS=\().+(\))$/\1base systemd autodetect block filesystems keyboard kms modconf sd-encrypt sd-vconsole\2/' \
            "${AI_MOUNTPOINT_PATH}etc/mkinitcpio.conf"
    fi

    bl.logging.info \
        "Make keyboard layout permanent to \"${AI_KEYBOARD_LAYOUT}\"."
    if [ "$1" = true ]; then
        ai.changeroot_to_mountpoint localectl set-keymap "$AI_KEYBOARD_LAYOUT"
        ai.changeroot_to_mountpoint localectl set-locale LANG=en_US.utf8
        ai.changeroot_to_mountpoint locale-gen set-keymap "$AI_KEYBOARD_LAYOUT"
    else
        echo -e "$AI_KEY_MAP_CONFIGURATION_FILE_CONTENT" \
            1>"${AI_MOUNTPOINT_PATH}etc/vconsole.conf"
    fi

    bl.logging.info "Set localtime \"${AI_LOCAL_TIME}\"."
    if [ "$1" = true ]; then
        ai.changeroot_to_mountpoint timedatectl set-timezone "$AI_LOCAL_TIME"
    else
        ln \
            --symbolic \
            --force "/usr/share/zoneinfo/${AI_LOCAL_TIME}" \
            "${AI_MOUNTPOINT_PATH}etc/localtime"
    fi

    bl.logging.info Activate date time synchronization.
    # NOTE: "timedatectl" needs a running systemd, so enable the service.
    ai.changeroot_to_mountpoint systemctl enable systemd-timesyncd.service

    bl.logging.info "Set hostname to \"$AI_HOST_NAME\"."
    if [ "$1" = true ]; then
        ai.changeroot_to_mountpoint hostnamectl set-hostname "$AI_HOST_NAME"
    else
        echo "$AI_HOST_NAME" \
            1>"${AI_MOUNTPOINT_PATH}etc/hostname"
    fi

    bl.logging.info Set hosts.
    ai.get_hosts_content "$AI_HOST_NAME" \
        1>"${AI_MOUNTPOINT_PATH}etc/hosts"

    if [[ "$1" != true ]]; then
        bl.logging.info "Set root password to \"root\"."
        ai.changeroot_to_mountpoint \
            /usr/bin/env bash -c \
                "echo root:${AI_PASSWORD} | \$(which chpasswd)"
    fi

    bl.exception.try
        ai.enable_services
    bl.exception.catch_single
        bl.logging.warn Enabling services has failed.

    local user_name
    for user_name in "${AI_USER_NAMES[@]}"; do
        bl.logging.info "Add user: \"$user_name\"."
        # NOTE: We could only create a home directory with right rights if we
        # are root.
        bl.exception.try
            ai.changeroot_to_mountpoint \
                useradd \
                "$(
                    if (( UID == 0 )); then
                        echo --create-home
                    else
                        echo --no-create-home
                    fi
                )" \
                --no-user-group \
                --shell \
                /usr/bin/bash \
                "$user_name"
        bl.exception.catch_single
            bl.logging.warn "Adding user \"${user_name}\" failed."
        bl.logging.info \
            "Set password for \"${user_name}\" to \"${user_name}\"."
        ai.changeroot_to_mountpoint \
            /usr/bin/env bash -c \
                "echo '${user_name}:${user_name}' | \$(which chpasswd)"
    done

    return $?
}
alias ai.configure_pacman=ai_configure_pacman
ai_configure_pacman() {
    local -r __documentation__='
        Enables all mirrors of configured country in mirror list.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> mkdir --parents "${AI_MOUNTPOINT_PATH}etc/pacman.d"
        >>> printf "%s\n" \
        >>>     "## Germany" "#Server = https://de.tld" "" \
        >>>     "## France" "#Server = https://fr.tld" \
        >>>         >"${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
        >>> ai.configure_pacman
        >>> command grep --invert-match "^$" \
        >>>     "${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
        ## Germany
        Server = https://de.tld
        ## France
        #Server = https://fr.tld
    '
    bl.logging.info "Enable mirrors in \"${AI_COUNTRY_WITH_MIRRORS}\"."
    local buffer_file="$(mktemp --suffix -archinstall-processed-mirrorlist)"
    bl.exception.try
    {
        local in_area=false
        local -i line_number=0
        local line
        while read -r line; do
            (( line_number = ( line_number + 1 ) ))
            if [ "$line" = "## $AI_COUNTRY_WITH_MIRRORS" ]; then
                in_area=true
            elif [ "$line" = '' ]; then
                in_area=false
            elif $in_area && [ "${line:0:1}" = '#' ]; then
                line="${line:1}"
            fi
            echo "$line"
        done < "${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist" \
            1>"$buffer_file"
        cat "$buffer_file" \
            1>"${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
    }
    bl.exception.catch_single
    {
        rm --force "$buffer_file"
        # shellcheck disable=SC2154
        bl.logging.error_exception "$BL_EXCEPTION_LAST_TRACEBACK"
    }
    rm --force "$buffer_file"
}
alias ai.determine_auto_partitioning=ai_determine_auto_partitioning
ai_determine_auto_partitioning() {
    local -r __documentation__='
        Determine whether we should perform our auto partitioning mechanism.

        >>> ai.determine_auto_partitioning <<<YES
        >>> echo " $AI_AUTO_PARTITIONING"
        Do you want auto partioning? [yes|NO]: true

        >>> ai.determine_auto_partitioning < <(printf "maybe\n\n")
        >>> echo " $AI_AUTO_PARTITIONING"
        Do you want auto partioning? [yes|NO]:Do you want auto partioning? [yes|NO]: false

        >>> local AI_AUTO_PARTITIONING=true
        >>> ai.determine_auto_partitioning
        >>> echo "$AI_AUTO_PARTITIONING"
        true
    '
    if ! $AI_AUTO_PARTITIONING; then
        while true; do
            bl.logging.plain -n 'Do you want auto partioning? [yes|NO]:'
            local auto_partitioning
            read -r auto_partitioning
            if \
                [ "$auto_partitioning" = '' ] || \
                [ "$(
                    echo "$auto_partitioning" | tr '[:upper:]' '[:lower:]'
                )" = no ]
            then
                AI_AUTO_PARTITIONING=false
                break
            elif \
                [ "$(
                    echo "$auto_partitioning" | tr '[:upper:]' '[:lower:]'
                )" = yes ]
            then
                AI_AUTO_PARTITIONING=true
                break
            fi
        done
    fi
}
alias ai.create_url_lists=ai_create_url_lists
ai_create_url_lists() {
    local -r __documentation__='
        Generates all web urls for needed packages.
    '
    local serialized_url_list
    local -i temporary_return_code=0
    local -i return_code=0
    bl.logging.info Downloading latest mirror list.
    local -a url_list=()
    local url
    for url in "${AI_PACKAGE_SOURCE_URLS[@]}"; do
        bl.logging.info "Retrieve repository source url list from \"$url\"."
        if serialized_url_list="$(
            command curl \
                "$url" \
                --location \
                --max-time "$AI_NETWORK_TIMEOUT_IN_SECONDS" \
                --retry 10 \
                --retry-all-errors \
                --retry-delay 2 | \
                    command sed \
                        --regexp-extended 's/^#Server = (http)/\1/g' | \
                            command sed --regexp-extended '/^#.+$/d' | \
                                command sed \
                                    --regexp-extended 's/\/\$repo\/.+$//g' | \
                                        command sed \
                                            --regexp-extended \
                                            's/(^\s+)|(\s+$)//g' | \
                                                command sed \
                                                    --regexp-extended '/^$/d'
        )"; then
            mapfile -t url_list <<<"$serialized_url_list"
        else
            bl.logging.warn "Retrieving repository source url list from \"$url\" failed."
        fi
        [ "$serialized_url_list" != '' ] && break
    done
    local -a package_source_urls=(
        "${url_list[@]}" "${AI_PACKAGE_URLS[@]}")
    local -a package_urls=()
    local name
    for name in core extra; do
        for url in "${AI_PACKAGE_URLS[@]}"; do
            bl.logging.info "Retrieve repository \"$name\" from \"$url\"."
            if serialized_url_list="$(
                command curl \
                    --location \
                    --retry 3 \
                    --retry-all-errors \
                    --retry-delay 1 \
                    --max-time "$AI_NETWORK_TIMEOUT_IN_SECONDS" \
                    "${url}/$name/os/${AI_CPU_ARCHITECTURE}" | \
                        command sed \
                            --quiet \
                            "s>.*href=\"\\([^\"]*.\\(tar.xz\\|tar.zst\\|db\\)\\).*>${url}/$name/os/${AI_CPU_ARCHITECTURE}/\\1>p" | \
                                command sed 's:/./:/:g' | \
                                    sort --unique
            )"; then
                mapfile -t url_list <<<"$serialized_url_list"
            else
                bl.logging.warn "Retrieving repository \"$name\" from \"$url\" failed."
            fi
        done
        # NOTE: "return_code" remains with an error code if there was given one
        # in any iteration.
        (( temporary_return_code != 0 )) && \
            return_code=$temporary_return_code
        package_urls+=("${url_list[@]}")
    done
    bl.array.unique "${package_source_urls[*]}"
    echo
    echo "${package_urls[@]}"
    return $return_code
}
alias ai.decode_url=ai_decode_url
ai_decode_url() {
    local -r __documentation__='
        Decodes given url encoded string.

        >>> ai.decode_url libsigc%2B%2B-2.12.1-1-x86_64.pkg.tar.zst
        libsigc++-2.12.1-1-x86_64.pkg.tar.zst
    '
    printf '%b' "${1//%/\\x}"
}
alias ai.determine_cached_package_file_name=ai_determine_cached_package_file_name
ai_determine_cached_package_file_name() {
    local -r __documentation__='
        Determines the newest package file name for given package name in
        current package cache.

        >>> local AI_CACHE_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> touch "${AI_CACHE_PATH}"{a-1.0-1-any.pkg.tar.xz,aab-2.0-1-any.pkg.tar.zst}
        >>> touch "${AI_CACHE_PATH}"{a-1.2-1-any.pkg.tar.zst,a-1.2-1-any.pkg.tar.zst.sig}
        >>> touch "${AI_CACHE_PATH}"{a-extra-3.0-1-any.pkg.tar.zst,a+b-3.0-1-any.pkg.tar.zst}
        >>> ai.determine_cached_package_file_name a
        >>> ai.determine_cached_package_file_name a+b
        >>> ai.determine_cached_package_file_name b; echo $?
        a-1.2-1-any.pkg.tar.zst
        a+b-3.0-1-any.pkg.tar.zst
        1
    '
    local -r package_name="$1"
    local -r file_names="$(
        command find \
            "$AI_CACHE_PATH" \
            -mindepth 1 \
            -maxdepth 1 \
            -regex ".*/$(
                ai.escape_regular_expression "$package_name"
            )-[0-9][^/]*\.pkg\.tar\.[^/.]+" | \
                command sed --regexp-extended 's:^.*/([^/]+)$:\1:')"
    local file_name=''
    local -i highest_raw_version=0
    local name
    for name in $file_names; do
        local -i raw_version="$(bl.number.normalize_version "$name")"
        if [[ "$file_name" = '' ]] || (( raw_version > highest_raw_version ))
        then
            file_name="$name"
            highest_raw_version=$raw_version
        fi
    done
    [[ "$file_name" = '' ]] && return 1
    echo "$file_name"
}
alias ai.escape_regular_expression=ai_escape_regular_expression
ai_escape_regular_expression() {
    local -r __documentation__='
        Escapes all characters with special meaning in regular expressions.
        Needed since package names may contain characters like "." or "+"
        (e.g. "libsigc++").

        >>> ai.escape_regular_expression libsigc++-2.12
        libsigc\+\+-2\.12
    '
    echo "$1" | \
        command sed 's/[][\.*^$+?]/\\&/g'
}
alias ai.determine_package_dependencies=ai_determine_package_dependencies
ai_determine_package_dependencies() {
    local -r __documentation__='
        Determines all package dependencies. Returns a list of needed packages
        for given package determined by given database.
        NOTE: We append and prepend always a whitespace to simply identify
        duplicates without using extended regular expression and package name
        escaping.

        ```
            ai.determine_package_dependencies glibc /path/to/db
        ```

        >>> local database_path="$(ai_bl_doctest_mktemp --directory)"
        >>> mkdir "${database_path}/"{alpha-1.0-1,beta-2.0-1,gamma-1.0-1,z-1.0-1}
        >>> mkdir "${database_path}/"{lib-1.0-1,lib_c-1.0-1}
        >>> printf "%%NAME%%\nalpha\n\n%%DEPENDS%%\nbeta>=2\ngamma\nz\nlib_c>=2\n" \
        >>>     >"${database_path}/alpha-1.0-1/desc"
        >>> printf "%%NAME%%\nbeta\n" >"${database_path}/beta-2.0-1/desc"
        >>> printf "%%NAME%%\nz\n" >"${database_path}/z-1.0-1/desc"
        >>> printf "%%NAME%%\nlib\n" >"${database_path}/lib-1.0-1/desc"
        >>> printf "%%NAME%%\nlib_c\n" >"${database_path}/lib_c-1.0-1/desc"
        >>> printf "%%NAME%%\ngamma\n\n%%DEPENDS%%\nbeta\n" \
        >>>     >"${database_path}/gamma-1.0-1/desc"
        >>> ai.determine_package_dependencies alpha "$database_path"
        alpha
        beta
        gamma
        z
        lib_c

        >>> local database_path="$(ai_bl_doctest_mktemp --directory)"
        >>> ai.determine_package_dependencies alpha "$database_path"; echo $?
        1
    '
    local -r given_package_name="$1"
    local -r database_directory_path="$2"
    local package_names_to_ignore=" $3 "
    local package_description_file_path
    if package_description_file_path="$(
        ai.determine_package_description_file_path \
            "$given_package_name" \
            "$database_directory_path"
    )"; then
        local -r resolved_package_name="$(
            echo "$package_description_file_path" | \
                sed --regexp-extended 's:^.*/([^/]+)-[0-9]+[^/]*/desc$:\1:' | \
                    sed --regexp-extended 's/(-[0-9]+.*)+$//')"
        # NOTE: We do not simple print "$1" because given (providing) names
        # do not have the corresponding package name.
        echo "$resolved_package_name"
        package_names_to_ignore+=" $resolved_package_name"
        local package_dependency_descriptions
        mapfile -t package_dependency_descriptions 2>/dev/null <<<"$(
            command grep \
                --null-data \
                --only-matching \
                --perl-regexp \
                '%DEPENDS%(\n.+)+(\n|$)' \
                <"$package_description_file_path" | \
                    command sed '/%DEPENDS%/d' || \
                        true
        )"
        local package_dependency_description
        local -a dependent_package_names=()
        for package_dependency_description in "${package_dependency_descriptions[@]}"
        do
            local package_name="$(
                echo "$package_dependency_description" | \
                    command grep \
                        --extended-regexp \
                        --only-matching \
                        '^[a-zA-Z0-9@_+][-a-zA-Z0-9@._+]*' | \
                            sed --regexp-extended 's/^(.+)[><=].+$/\1/'
            )"
            # NOTE: The dependency section may end with an empty line.
            [[ "$package_name" = '' ]] && \
                continue
            local alias
            if alias="$(
                bl.dictionary.get \
                    AI_KNOWN_DEPENDENCY_ALIASES \
                    "$package_name"
            )"; then
                package_name="$alias"
            fi
            if [[ "$package_names_to_ignore" == *" $package_name "* ]]; then
                continue
            fi
            dependent_package_names+=("$package_name")
        done
        package_names_to_ignore+=" ${dependent_package_names[*]}"
        for package_name in "${dependent_package_names[@]}"; do
            bl.exception.try
                ai.determine_package_dependencies \
                    "$package_name" \
                    "$database_directory_path" \
                    "$package_names_to_ignore"
            bl.exception.catch_single
                bl.logging.warn \
                    "Needed package \"$package_name\" for \"$given_package_name\" couldn't be found in database \"$database_directory_path\"."
        done
    else
        return 1
    fi
    return 0
}
alias ai.determine_package_description_file_path=ai_determine_package_description_file_path
ai_determine_package_description_file_path() {
    local -r __documentation__='
        Determines the package directory name from given package name in given
        database folder.

        >>> local database_path="$(ai_bl_doctest_mktemp --directory)"
        >>> mkdir "${database_path}/"{a-1.0-1,a-1.2-1,b-2.0-1,c-1.0-1,aab-1.0-1,a+b-1.0-1}
        >>> printf "%%NAME%%\nb\n\n%%PROVIDES%%\nlibb\n\n" \
        >>>     >"${database_path}/b-2.0-1/desc"
        >>> printf "%%NAME%%\nc\n\n%%PROVIDES%%\nlibfoo++\n\n" \
        >>>     >"${database_path}/c-1.0-1/desc"
        >>> ai.determine_package_description_file_path a "$database_path" | \
        >>>     sed "s:${database_path}/::"
        >>> ai.determine_package_description_file_path libb "$database_path" | \
        >>>     sed "s:${database_path}/::"
        >>> ai.determine_package_description_file_path libfoo++ "$database_path" | \
        >>>     sed "s:${database_path}/::"
        >>> ai.determine_package_description_file_path a+b "$database_path" | \
        >>>     sed "s:${database_path}/::"
        >>> ai.determine_package_description_file_path xyz "$database_path"; \
        >>>     echo $?
        a-1.2-1/desc
        b-2.0-1/desc
        c-1.0-1/desc
        a+b-1.0-1/desc
        1
    '
    local -r package_name="$1"
    local -r database_directory_path="$2"
    # NOTE: Package names may contain regular expression special characters
    # like "+" (e.g. "libsigc++").
    local -r escaped_package_name="$(
        ai.escape_regular_expression "$package_name")"
    local package_description_file_path="$(
        command grep \
            "%PROVIDES%\\n(.+\\n)*\\Q${package_name}\\E\\n(.+\\n)*\\n" \
            --files-with-matches \
            --null-data \
            --perl-regexp \
            --recursive \
            "$database_directory_path"
    )"
    if [ "$package_description_file_path" = '' ]; then
        local regular_expression
        for regular_expression in \
            '^\(.*/\)?'"$escaped_package_name"'$' \
            '^\(.*/\)?'"$escaped_package_name"'-[0-9]+[0-9.\-]*$' \
            '^\(.*/\)?'"$escaped_package_name"'-[0-9]+[0-9.a-zA-Z-]*$' \
            '^\(.*/\)?'"$escaped_package_name"'-git-[0-9]+[0-9.a-zA-Z-]*$' \
            '^\(.*/\)?'"$escaped_package_name"'[0-9]+-[0-9.a-zA-Z-]+\(-[0-9.a-zA-Z-]\)*$' \
            '^\(.*/\)?[0-9]+'"$escaped_package_name"'[0-9]+-[0-9a-zA-Z\.]+\(-[0-9a-zA-Z\.]\)*$' \
            '^\(.*/\)?'"$escaped_package_name"'-.+$' \
            '^\(.*/\)?.+-'"$escaped_package_name"'-.+$' \
            '^\(.*/\)?'"$escaped_package_name"'.+$' \
            '^\(.*/\)?'"$escaped_package_name"'.*$' \
            '^\(.*/\)?.*'"$escaped_package_name"'.*$'
        do
            package_description_file_path="$(
                command find \
                    "$database_directory_path" \
                    -mindepth 1 \
                    -maxdepth 1 \
                    -regex "$regular_expression"
            )"
            if [[ "$package_description_file_path" != '' ]]; then
                local -i number_of_results="$(
                    echo "$package_description_file_path" | \
                        wc --words)"
                if (( number_of_results > 1 )); then
                    # NOTE: We want to use newer package if their are two
                    # candidates.
                    local description_file_path
                    local -i highest_raw_version=0
                    for description_file_path in $package_description_file_path
                    do
                        # NOTE: Only the package directory name should be
                        # considered since database paths may contain digits.
                        local raw_version="$(
                            bl.number.normalize_version \
                                "$(basename "$description_file_path")")"
                        if (( raw_version > highest_raw_version )); then
                            package_description_file_path="$description_file_path"
                            highest_raw_version=$raw_version
                        fi
                    done
                fi
                echo "${package_description_file_path}/desc"
                return
            fi
        done
    else
        echo "$package_description_file_path"
        return
    fi
    return 1
}
alias ai.determine_pacmans_needed_packages=ai_determine_pacmans_needed_packages
ai_determine_pacmans_needed_packages() {
    local -r __documentation__='
        Reads pacmans database and determine pacmans dependencies.
    '
    if [[ "$1" != '' ]]; then
        local -r core_database_url="$(
            echo "$1" | \
                command grep \
                    --only-matching \
                    --extended-regexp \
                    ' [^ ]+core\.db ' | \
                        sed --regexp-extended 's/(^ *)|( *$)//g')"
        bl.exception.try
            command curl \
                "$core_database_url" \
                --location \
                --retry 3 \
                --retry-all-errors \
                --retry-delay 1 \
                --max-time "$AI_NETWORK_TIMEOUT_IN_SECONDS" \
                    >"${AI_CACHE_PATH}$(basename "$core_database_url")"
        bl.exception.catch_single
            bl.logging.warn \
                "Could not retrieve latest database file from determined url \"$core_database_url\"."
    fi
    if [ -f "${AI_CACHE_PATH}core.db" ]; then
        local -r database_directory_path="$(
            mktemp --directory --suffix -archinstall-core-database)"
        bl.exception.try
        {
            local -a packages=()
            tar \
                --directory "$database_directory_path" \
                --extract \
                --file "${AI_CACHE_PATH}core.db" \
                --gzip
            local package_name
            for package_name in "${AI_NEEDED_PACKAGES[@]}"; do
                local needed_packages
                mapfile -t needed_packages <<<"$(
                    ai.determine_package_dependencies \
                        "$package_name" \
                        "$database_directory_path" | \
                            sort --unique
                )"
                packages+=("${needed_packages[@]}")
            done
            rm --force --recursive "$database_directory_path"
            bl.array.unique "${packages[*]}"
        }
        bl.exception.catch_single
        {
            rm --force --recursive "$database_directory_path"
            # shellcheck disable=SC2154
            bl.logging.error_exception "$BL_EXCEPTION_LAST_TRACEBACK"
        }
        return 0
    fi
    bl.logging.critical \
        "No database file (\"${AI_CACHE_PATH}core.db\") could be found."
    return 1
}
alias ai.download_and_extract_pacman=ai_download_and_extract_pacman
ai_download_and_extract_pacman() {
    local -r __documentation__='
        Downloads all packages from arch linux needed to run pacman.

        >>> local source_path="$(ai_bl_doctest_mktemp --directory)"
        >>> local AI_CACHE_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> mkdir --parents \
        >>>     "${source_path}/database/"{filesystem-1.0-1,pacman-7.0-1} \
        >>>     "${source_path}/filesystem/etc" \
        >>>     "${source_path}/pacman/usr/bin"
        >>> printf "%%NAME%%\nfilesystem\n" \
        >>>     >"${source_path}/database/filesystem-1.0-1/desc"
        >>> printf "%%NAME%%\npacman\n\n%%DEPENDS%%\nfilesystem\n" \
        >>>     >"${source_path}/database/pacman-7.0-1/desc"
        >>> tar \
        >>>     --create \
        >>>     --directory "${source_path}/database" \
        >>>     --file "${source_path}/core.db" \
        >>>     --gzip \
        >>>     .
        >>> touch "${source_path}/filesystem/etc/hostname"
        >>> touch "${source_path}/pacman/usr/bin/pacman"
        >>> local name
        >>> for name in filesystem-1.0-1 pacman-7.0-1; do
        >>>     tar \
        >>>         --create \
        >>>         --directory "${source_path}/${name%%-*}" \
        >>>         --file "${source_path}/${name}-any.pkg.tar.xz" \
        >>>         --xz \
        >>>         .
        >>> done
        >>> ai.download_and_extract_pacman " $(
        >>>     printf "file://${source_path}/%s " \
        >>>         core.db \
        >>>         filesystem-1.0-1-any.pkg.tar.xz \
        >>>         pacman-6.0-1-any.pkg.tar.xz \
        >>>         pacman-7.0-1-any.pkg.tar.xz
        >>> )" 2>/dev/null
        >>> echo $?
        >>> find "$AI_MOUNTPOINT_PATH" -type f | \
        >>>     sed "s:${AI_MOUNTPOINT_PATH}::" | \
        >>>         sort
        0
        etc/hostname
        usr/bin/pacman
    '
    local serialized_needed_packages
    serialized_needed_packages="$(
        ai.determine_pacmans_needed_packages "$1")"
    # shellcheck disable=SC2181
    if [ $? = 0 ]; then
        local needed_packages
        IFS=' ' read -r -a needed_packages <<<"$serialized_needed_packages"
        bl.logging.info "Needed packages are: \"$(
            echo "${needed_packages[@]}" | \
                command sed 's/ /", "/g'
        )\"."
        bl.logging.info \
            "Retrieve and extract each package into our new system located in \"$AI_MOUNTPOINT_PATH\"."
        local -a urls
        read -r -a urls <<<"$1"
        # NOTE: Decode all urls at once to avoid spawning sub processes for
        # each of the (many thousand) urls per needed package.
        local -a decoded_urls
        read -r -a decoded_urls <<<"$(ai.decode_url "$1")"
        local package_name
        for package_name in "${needed_packages[@]}"; do
            local escaped_package_name="$(
                ai.escape_regular_expression "$package_name")"
            local file_name=''
            if [[ "$1" != '' ]]; then
                # NOTE: We want to use the newest package if there are
                # multiple candidates. Only the (url decoded) file name should
                # be considered since mirror urls may contain digits.
                local package_url=''
                local -i highest_raw_version=0
                local -i index
                for index in "${!urls[@]}"; do
                    local name="${decoded_urls[index]##*/}"
                    if [[ "$name" =~ ^${escaped_package_name}-[0-9] ]]; then
                        local -i raw_version="$(
                            bl.number.normalize_version "$name")"
                        if [[
                            "$package_url" = '' ||
                            raw_version -gt highest_raw_version
                        ]]; then
                            package_url="${urls[index]}"
                            highest_raw_version=$raw_version
                        fi
                    fi
                done
                if [[ "$package_url" != '' ]]; then
                    bl.exception.try
                    {
                        file_name="$(
                            ai.decode_url "$(basename "$package_url")")"
                        command curl \
                            "$package_url" \
                            --location \
                            --continue-at - \
                            --max-time "$AI_NETWORK_TIMEOUT_IN_SECONDS" \
                            --output "${AI_CACHE_PATH}${file_name}" \
                            --retry 3 \
                            --retry-all-errors \
                            --retry-delay 1
                    }
                    bl.exception.catch_single
                    {
                        file_name=''
                        bl.logging.warn \
                            "Could not retrieve package \"$package_name\" from url \"$package_url\"."
                    }
                fi
            fi
            # If "file_name" couldn't be determined via server determine it via
            # current package cache.
            if [ "$file_name" = '' ]; then
                file_name="$(
                    ai.determine_cached_package_file_name "$package_name")"
            fi
            if [[
                "$file_name" = '' || \
                ! -f "${AI_CACHE_PATH}${file_name}"
            ]]; then
                bl.logging.error_exception \
                    "A suitable file for package \"$package_name\" could not be determined."
            fi
            bl.logging.info "Install package \"$file_name\" manually."
            # NOTE: "tar" determines needed decompression (e.g. "xz" or "zstd")
            # by itself.
            tar \
                --directory "$AI_MOUNTPOINT_PATH" \
                --extract \
                --file "${AI_CACHE_PATH}${file_name}" || \
                    return $?
        done
    else
        return 1
    fi
}
alias ai.format_boot_partition=ai_format_boot_partition
ai_format_boot_partition() {
    local -r __documentation__='
        Prepares the boot partition.
    '
    bl.logging.info Make boot partition.
    local boot_partition_device_path="${AI_TARGET}1"
    if [ ! -b "$boot_partition_device_path" ]; then
        boot_partition_device_path="${AI_TARGET}p1"
    fi
    mkfs.vfat -F 32 "$boot_partition_device_path"
    if hash dosfslabel 2>/dev/null; then
        dosfslabel "$boot_partition_device_path" "$AI_BOOT_PARTITION_LABEL"
    else
        bl.logging.warn \
            "\"dosfslabel\" doesn't seem to be installed. Creating a boot partition label failed."
    fi
}
alias ai.format_system_partition=ai_format_system_partition
ai_format_system_partition() {
    local -r __documentation__='
        Prepares the system partition.
    '
    local output_device="$AI_TARGET"
    if [ -b "${AI_TARGET}2" ]; then
        output_device="${AI_TARGET}2"
    elif [ -b "${AI_TARGET}p2" ]; then
        output_device="${AI_TARGET}p2"
    fi
    bl.logging.info "Make system partition at \"$output_device\"."
    if $AI_ENCRYPT; then
        bl.logging.info \
            "Encrypt system partition at \"$output_device\" and map to \"cryptroot\"."
        echo -n "$AI_PASSWORD" | \
            cryptsetup \
                --batch-mode \
                --force-password \
                --key-file - \
                luksFormat \
                "$output_device"
        echo -n "$AI_PASSWORD" | \
            cryptsetup \
                --batch-mode \
                --key-file - \
                open \
                "$output_device" \
                cryptroot
        output_device=/dev/mapper/cryptroot
    fi
    mkfs.btrfs --force --label "$AI_SYSTEM_PARTITION_LABEL" "$output_device"
    bl.logging.info "Creating a root sub volume in \"$output_device\"."
    # NOTE: It is more reliable if we do not use the partition label here if
    # some pre or post processing by other tools will be done.
    mount "$output_device" "$AI_MOUNTPOINT_PATH"
    btrfs subvolume create "${AI_MOUNTPOINT_PATH}root"
    umount "$AI_MOUNTPOINT_PATH"
    if $AI_ENCRYPT; then
        cryptsetup close cryptroot
    fi
}
# NOTE: Depends on "ai.format_system_partition"
alias ai.format_partitions=ai_format_partitions
ai_format_partitions() {
    local -r __documentation__='
        Performs formating part.
    '
    ai.format_boot_partition
    ai.format_system_partition
}
alias ai.generate_fstab_configuration_file=ai_generate_fstab_configuration_file
ai_generate_fstab_configuration_file() {
    local -r __documentation__='
        Writes the fstab configuration file.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> local AI_ENCRYPT=true
        >>> mkdir "${AI_MOUNTPOINT_PATH}etc"
        >>> ai.generate_fstab_configuration_file
        >>> command grep --invert-match "^#" "${AI_MOUNTPOINT_PATH}etc/fstab" | \
        >>>     cut --delimiter " " --fields 1
        /dev/mapper/cryptroot
        PARTLABEL=uefiBoot
    '
    bl.logging.info Generate fstab config.
    if ! $AI_ENCRYPT && hash genfstab 2>/dev/null; then
        # NOTE: Mountpoint shouldn't have a path separator at the end.
        genfstab \
            -L \
            -p "${AI_MOUNTPOINT_PATH%?}" \
            1>>"${AI_MOUNTPOINT_PATH}etc/fstab"
    else
        cat << EOF 1>>"${AI_MOUNTPOINT_PATH}etc/fstab"
# Added during installation.
# <file system>                    <mount point> <type> <options>                                                                                            <dump> <pass>
# "compress=lzo" has lower compression ratio by better cpu performance.
$($AI_ENCRYPT && echo /dev/mapper/cryptroot || echo "PARTLABEL=${AI_SYSTEM_PARTITION_LABEL}") /             btrfs  autodefrag,compress=zlib,discard,noatime,nodiratime,ssd,space_cache,subvol=root                    0      0
PARTLABEL=$AI_BOOT_PARTITION_LABEL   /boot/        vfat   codepage=437,dmask=0077,errors=remount-ro,fmask=0077,iocharset=iso8859-1,noatime,relatime,rw,shortname=mixed 0      0
EOF
    fi
}
alias ai.load_cache=ai_load_cache
ai_load_cache() {
    local -r __documentation__='
        Load previous downloaded packages and database.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> local AI_CACHE_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> touch "${AI_CACHE_PATH}"{core.db,a.pkg.tar.xz,b.pkg.tar.zst}
        >>> ai.load_cache
        >>> ls "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync"
        >>> ls "${AI_MOUNTPOINT_PATH}var/cache/pacman/pkg"
        core.db
        a.pkg.tar.xz
        b.pkg.tar.zst

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> local AI_CACHE_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> ai.load_cache
        >>> ls "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync"; echo $?
        0
    '
    bl.logging.info Load cached databases.
    mkdir --parents "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync"
    bl.exception.try
        cp \
            --no-clobber \
            --preserve \
            "$AI_CACHE_PATH"*.db \
            "${AI_MOUNTPOINT_PATH}var/lib/pacman/sync/" \
                2>/dev/null
    bl.exception.catch_single
        bl.logging.info No local database available to load from cache.
    bl.logging.info Load cached packages.
    mkdir --parents "${AI_MOUNTPOINT_PATH}var/cache/pacman/pkg"
    bl.exception.try
        cp \
            --no-clobber \
            --preserve \
            "$AI_CACHE_PATH"*.pkg.tar.* \
            "${AI_MOUNTPOINT_PATH}var/cache/pacman/pkg/" \
                2>/dev/null
    bl.exception.catch_single
        bl.logging.info No local packages available to load from cache.
}
alias ai.make_partitions=ai_make_partitions
ai_make_partitions() {
    local -r __documentation__='
        Performs the auto partitioning.
    '
    if $AI_AUTO_PARTITIONING; then
        bl.logging.info Check block device size.
        local blockdevice_space_in_mega_byte="$(("$(
            blockdev --getsize64 "$AI_TARGET"
        )" * 1024 ** 2))"
        if (( $((
            AI_NEEDED_SYSTEM_SPACE_IN_MEGA_BYTE + \
            AI_BOOT_SPACE_IN_MEGA_BYTE
        )) < blockdevice_space_in_mega_byte )); then
            bl.logging.info Create boot and system partitions.
            # o: create a new empty GUID partition table (GPT)
            # Y: Confirm (yes)
            # n: add a new partition
            # POSITION (Enter -> Next available number)
            # SECTOR (Enter -> Next available)
            # SIZE (in megabyte in this case)
            # PARTITION_TYPE (EFI in this case)
            # n: add a new partition
            # POSITION (Enter -> Next available number)
            # SECTOR (Enter -> Next available)
            # SIZE (Enter -> all available)
            # PARTITION_TYPE (Enter -> Linux System)
            # c: change a partition's name
            # PARTITION_NUMBER
            # NAME
            # c: change a partition's name
            # PARTITION_NUMBER
            # NAME
            # w: write table to disk and exit
            # Y: Confirm (yes)
            gdisk "$AI_TARGET" << EOF
o
Y
n


${AI_BOOT_SPACE_IN_MEGA_BYTE}M
ef00
n




c
1
$AI_BOOT_PARTITION_LABEL
c
2
$AI_SYSTEM_PARTITION_LABEL
w
Y
EOF
        else
            bl.logging.critical \
                "Not enough space on \"$AI_TARGET\" (\"$blockdevice_space_in_mega_byte\" megabyte). We need at least \"$((AI_NEEDED_SYSTEM_SPACE_IN_MEGA_BYTE + AI_BOOT_SPACE_IN_MEGA_BYTE))\" megabyte."
        fi
    else
        bl.logging.info \
            "At least you have to create two partitions. The first one will be used as boot partition labeled to \"${AI_BOOT_PARTITION_LABEL}\" and second one will be used as system partition and labeled to \"${AI_SYSTEM_PARTITION_LABEL}\". Press Enter to continue."
        read -r
        bl.logging.info Show blockdevices. Press Enter to continue.
        lsblk
        read -r
        bl.logging.info Create partitions manually.
        gdisk "$AI_TARGET"
    fi
}
alias ai.pack_result=ai_pack_result
ai_pack_result() {
    local -r __documentation__='
        Packs the resulting system to provide files owned by root without
        root permissions.
    '
    if (( UID != 0 )); then
        bl.logging.info \
            "System will be packed into \"${AI_MOUNTPOINT_PATH}.tar\" to provide root owned files. You have to extract this archiv as root."
        tar \
            cvf \
            "${AI_MOUNTPOINT_PATH}.tar" \
            "$AI_MOUNTPOINT_PATH" \
            --owner root \
        rm \
            "$AI_MOUNTPOINT_PATH"* \
            --force \
            --recursive
        return $?
    fi
}
alias ai.prepare_blockdevices=ai_prepare_blockdevices
ai_prepare_blockdevices() {
    local -r __documentation__='
        Prepares given block devices to make it ready for fresh installation.
    '
    umount --force "${AI_TARGET}"* 2>/dev/null || \
        true
    umount --force "$AI_MOUNTPOINT_PATH" 2>/dev/null || \
        true
    cryptsetup close cryptroot 2>/dev/null || \
        true
    swapoff "${AI_TARGET}"* 2>/dev/null || \
        true
}
alias ai.prepare_installation=ai_prepare_installation
ai_prepare_installation() {
    local -r __documentation__='
        Deletes previous installed things in given output target. And creates a
        package cache directory.
    '
    mkdir --parents "$AI_CACHE_PATH"
    if [ -b "$AI_TARGET" ]; then
        bl.logging.info Mount system partition.
        if $AI_SYSTEM_PARTITION_INSTALLATION_ONLY; then
            local source_selector="$AI_TARGET"
            if $AI_ENCRYPT; then
                echo -n "$AI_PASSWORD" | \
                    cryptsetup \
                        --batch-mode \
                        --key-file - \
                        open \
                        "$AI_TARGET" \
                        cryptroot
                source_selector=/dev/mapper/cryptroot
            fi
            # NOTE: It is more reliable to use the specified partition since
            # auto partitioning could be turned off and labels set wrong.
            mount \
                --options subvol=root \
                "$source_selector" \
                "$AI_MOUNTPOINT_PATH"
        else
            local source_selector="PARTLABEL=${AI_SYSTEM_PARTITION_LABEL}"
            if $AI_ENCRYPT; then
                echo -n "$AI_PASSWORD" | \
                    cryptsetup \
                        --batch-mode \
                        --key-file - \
                        open \
                        "/dev/disk/by-partlabel/${AI_SYSTEM_PARTITION_LABEL}" \
                        cryptroot
                source_selector=/dev/mapper/cryptroot
            fi
            mount \
                --options subvol=root \
                "$source_selector" \
                "$AI_MOUNTPOINT_PATH"
        fi
    fi
    bl.logging.info "Clear previous installations in \"$AI_MOUNTPOINT_PATH\"."
    rm "$AI_MOUNTPOINT_PATH"* --force --recursive &>/dev/null || \
        true
    if ! $AI_SYSTEM_PARTITION_INSTALLATION_ONLY && [ -b "$AI_TARGET" ]; then
        bl.logging.info \
            "Mount boot partition in \"${AI_MOUNTPOINT_PATH}boot/\"."
        mkdir --parents "${AI_MOUNTPOINT_PATH}boot/"
        mount PARTLABEL="$AI_BOOT_PARTITION_LABEL" "${AI_MOUNTPOINT_PATH}boot/"
        rm "${AI_MOUNTPOINT_PATH}boot/"* --force --recursive
    fi
    bl.logging.info Set filesystem rights.
    chmod 755 "$AI_MOUNTPOINT_PATH"
    read -r -a AI_PACKAGES <<< "$(bl.array.unique "${AI_PACKAGES[*]}")"
}
alias ai.prepare_next_boot=ai_prepare_next_boot
ai_prepare_next_boot() {
    local -r __documentation__='
        Reboots into fresh installed system if previous defined.
    '
    if $AI_ENCRYPT; then
        # NOTE: We have to rebuild initramfs to support decryption utilities
        # during boot.
        # NOTE: Because of non matching "btrfs.fsck" binary it results on non
        # zero exit code.
        ai.changeroot_to_mountpoint mkinitcpio --allpresets || true
    fi
    if [ -b "$AI_TARGET" ]; then
        ai.generate_fstab_configuration_file
        ai.add_boot_entries
        ai.prepare_blockdevices
        if $AI_AUTOMATIC_REBOOT; then
            bl.logging.info Reboot into new operating system.
            systemctl reboot &>/dev/null || reboot
        fi
    fi
}
alias ai.tidy_up_system=ai_tidy_up_system
ai_tidy_up_system() {
    local -r __documentation__='
        Deletes some unneeded locations in new installs operating system.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> mkdir --parents "${AI_MOUNTPOINT_PATH}"{etc,var/cache/pacman/pkg}
        >>> touch "${AI_MOUNTPOINT_PATH}"{.INSTALL,.PKGINFO}
        >>> ai.tidy_up_system
        >>> find "$AI_MOUNTPOINT_PATH" -mindepth 1 | \
        >>>     sed "s:${AI_MOUNTPOINT_PATH}::" | \
        >>>         sort
        etc
        var
        var/cache
    '
    bl.logging.info Tidy up new build system.
    local file_path
    for file_path in "${AI_UNNEEDED_FILE_LOCATIONS[@]}"; do
        bl.logging.info "Deleting \"${AI_MOUNTPOINT_PATH}${file_path}\"."
        rm "${AI_MOUNTPOINT_PATH}$file_path" --force --recursive
    done
}
## endregion
## region install arch linux steps.
alias ai.make_pacman_portable=ai_make_pacman_portable
ai_make_pacman_portable() {
    local -r __documentation__='
        Disables signature checks and registers temporary download mirrors.

        >>> local AI_MOUNTPOINT_PATH="$(ai_bl_doctest_mktemp --directory)/"
        >>> mkdir --parents "${AI_MOUNTPOINT_PATH}etc/pacman.d"
        >>> printf "%s\n" \
        >>>     CheckSpace \
        >>>     "SigLevel    = Required DatabaseOptional" \
        >>>     "LocalFileSigLevel = Optional" \
        >>>         >"${AI_MOUNTPOINT_PATH}etc/pacman.conf"
        >>> ai.make_pacman_portable https://a.tld
        >>> cat "${AI_MOUNTPOINT_PATH}etc/pacman.conf"
        >>> cat "${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
        SigLevel = Never TrustAll
        LocalFileSigLevel = Never TrustAll
        Server = https://a.tld/$repo/os/$arch
    '
    # Copy systems resolv.conf to new installed system.
    cp /etc/resolv.conf "${AI_MOUNTPOINT_PATH}etc/"
    command sed \
        --in-place \
        --quiet \
        '/^[ \t]*CheckSpace/ !p' \
        "${AI_MOUNTPOINT_PATH}etc/pacman.conf"
    command sed \
        --in-place \
        --regexp-extended \
        's/^[ \t]*(((Local|Remote)?File)?SigLevel)[ \t].*/\1 = Never TrustAll/g' \
        "${AI_MOUNTPOINT_PATH}etc/pacman.conf"
    bl.logging.info Register temporary mirrors to download new packages.
    if [ "$1" = '' ]; then
        cp \
            /etc/pacman.d/mirrorlist \
            "${AI_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
    else
        ai.append_temporary_install_mirrors "$1"
    fi
}
# NOTE: Depends on "ai.make_pacman_portable"
alias ai.generic_linux_steps=ai_generic_linux_steps
ai_generic_linux_steps() {
    local -r __documentation__='
        This functions performs creating an arch linux system from any linux
        system base.
    '
    bl.logging.info Create a list with urls for existing packages.
    local -a url_lists
    mapfile -t url_lists <<<"$(ai.create_url_lists)"
    ai.download_and_extract_pacman "${url_lists[1]}"
    ai.make_pacman_portable "${url_lists[0]}"

    bl.logging.info Ensure having valid install user available.
    if ! ai.changeroot_to_mountpoint getent group alpm &>/dev/null; then
        ai.changeroot_to_mountpoint groupadd --gid 701 alpm
    fi
    if ! ai.changeroot_to_mountpoint id alpm &>/dev/null; then
      ai.changeroot_to_mountpoint useradd \
          --uid 701 \
          --gid alpm \
          --home / \
          --shell /usr/bin/nologin \
          alpm
    fi

    bl.logging.info Initialize keys.
    bl.exception.try
    {
        ai.changeroot_to_mountpoint /usr/bin/pacman-key --init
        ai.changeroot_to_mountpoint /usr/bin/pacman-key --refresh-keys
    }
    bl.exception.catch_single
        bl.logging.warn Creating keys was not successful.

    bl.logging.info Update package databases.
    bl.exception.try
        ai.changeroot_to_mountpoint /usr/bin/pacman \
            --arch "$AI_CPU_ARCHITECTURE" \
            --refresh \
            --sync
    bl.exception.catch_single
        bl.logging.info Updating package database failed. Operating offline.

    bl.logging.info "Install needed packages \"$(
        echo "${AI_PACKAGES[@]}" | \
            command sed 's/ /", "/g'
    )\" to \"$AI_TARGET\"."
    ai.changeroot_to_mountpoint /usr/bin/pacman \
        --arch "$AI_CPU_ARCHITECTURE" \
        --needed \
        --noconfirm \
        --overwrite '*' \
        --sync \
        "${AI_PACKAGES[@]}"

    return $?
}
alias ai.with_existing_pacman=ai_with_existing_pacman
ai_with_existing_pacman() {
    local -r __documentation__='
        Installs arch linux via patched (to be able to operate offline)
        pacstrap of pacman directly.
    '
    bl.logging.info Update package databases.
    bl.exception.try
        pacman \
            --arch "$AI_CPU_ARCHITECTURE" \
            --refresh \
            --root "$AI_MOUNTPOINT_PATH" \
            --sync
    bl.exception.catch_single
        bl.logging.info \
            Updating package database failed. Operating offline.
    bl.logging.info "Install needed packages \"$(
        echo "${AI_PACKAGES[@]}" | \
            command sed 's/ /", "/g'
    )\" to \"$AI_TARGET\"."
    if hash pacstrap &>/dev/null; then
        bl.logging.info Patch pacstrap to handle offline installations.
        # NOTE: Newer pacstrap versions hold the pacman mode in a variable.
        command sed \
            --regexp-extended \
            --expression 's/(pacman.+-(S|-sync))(y|--refresh)/\1/g' \
            --expression 's/^pacmode=-Sy$/pacmode=-S/' \
                <"$(command -v pacstrap)" \
                1>"${AI_CACHE_PATH}patchedOfflinePacstrap.sh"
        chmod +x "${AI_CACHE_PATH}patchedOfflinePacstrap.sh"
        "${AI_CACHE_PATH}patchedOfflinePacstrap.sh" \
            "$AI_MOUNTPOINT_PATH" \
            "${AI_PACKAGES[@]}"
        local return_code=$?
        rm "${AI_CACHE_PATH}patchedOfflinePacstrap.sh"
        return $return_code
    fi
    pacman \
        --overwrite '*' \
        --root "$AI_MOUNTPOINT_PATH" \
        --sync \
        --noconfirm \
        "${AI_NEEDED_PACKAGES[@]}"
    ai.make_pacman_portable
    ai.changeroot_to_mountpoint \
        /usr/bin/pacman \
        --arch "$AI_CPU_ARCHITECTURE" \
        --needed \
        --noconfirm \
        --overwrite '*' \
        --sync \
        "${AI_PACKAGES[@]}"
    return $?
}
## endregion
## region controller
alias ai.main=ai_main
ai_main() {
    local -r __documentation__='
        Provides the main module scope.

        >>> ai.main --help
        +bl.doctest.multiline_ellipsis
        ...
        Usage: arch-install [options]
        ...
    '
    bl.exception.activate
    ai.commandline_interface "$@"
    AI_PACKAGES+=(
        "${AI_BASIC_PACKAGES[@]}"
        "${AI_ADDITIONAL_PACKAGES[@]}"
    )
    if $AI_ADD_COMMON_ADDITIONAL_PACKAGES; then
        AI_PACKAGES+=("${AI_COMMON_ADDITIONAL_PACKAGES[@]}")
    fi
    if [ ! -e "$AI_TARGET" ]; then
        mkdir --parents "$AI_TARGET"
    fi
    if [ -d "$AI_TARGET" ]; then
        AI_MOUNTPOINT_PATH="$AI_TARGET"
        if [[ ! "$AI_MOUNTPOINT_PATH" =~ .*/$ ]]; then
            AI_MOUNTPOINT_PATH+=/
        fi
    elif [ -b "$AI_TARGET" ]; then
        # NOTE: Only needed for booting without boot loader:
        # AI_PACKAGES+=(efibootmgr)
        AI_PACKAGES+=()
        ai.prepare_blockdevices
        bl.exception.try
        {
            if $AI_SYSTEM_PARTITION_INSTALLATION_ONLY; then
                ai.format_system_partition
            else
                ai.determine_auto_partitioning
                bl.logging.info Make partitions: Create a boot and system partition.
                ai.make_partitions
                bl.logging.info Format partitions.
                ai.format_partitions
            fi
        }
        bl.exception.catch_single
        {
            ai.prepare_blockdevices
            bl.logging.error_exception "$BL_EXCEPTION_LAST_TRACEBACK"
        }
    else
        bl.logging.error_exception "Could not install into \"$AI_TARGET\"."
    fi
    ai.prepare_installation
    bl.exception.try
        ai.load_cache
    bl.exception.catch_single
        bl.logging.info No package cache was loaded.
    if (( UID == 0 )) && ! $AI_PREVENT_USING_EXISTING_PACMAN && \
        hash pacman 2>/dev/null
    then
        ai.with_existing_pacman
    else
        ai.generic_linux_steps
    fi
    local -ir return_code=$?
    bl.exception.try
        ai.cache
    bl.exception.catch_single
        bl.logging.warn \
            Caching current downloaded packages and generated database \
            failed.
    (( return_code == 0 )) && \
        ai.configure_pacman
    ai.tidy_up_system
    ai.configure
    ai.prepare_next_boot
    ai.pack_result
    bl.logging.info \
        "Generating operating system into \"$AI_TARGET\" has successfully finished."
    bl.exception.deactivate
}
## endregion
# endregion
if bl.tools.is_main; then
    ai.main "$@"
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
