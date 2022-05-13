#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# [Project page](https://torben.website/archinstall)

# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. See https://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC1004,SC2016,SC2034,SC2155
# region import
if [ -f "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh" ]; then
    # shellcheck disable=SC1090
    source "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh"
elif [ -f "/usr/lib/bashlink/module.sh" ]; then
    # shellcheck disable=SC1091
    source "/usr/lib/bashlink/module.sh"
else
    declare -g ai_cache_path="$(
        echo "$@" | \
            sed \
                --regexp-extended \
                's/(^| )(-o|--cache-path)(=| +)(.+[^ ])($| +-)/\4/'
    )"
    [ "$ai_cache_path" = "$*" ] && \
        ai_cache_path=archInstallCache
    ai_cache_path="${ai_cache_path%/}/"
    declare -gr bl_module_remote_module_cache_path="${ai_cache_path}bashlink"
    mkdir --parents "$bl_module_remote_module_cache_path"
    declare -gr bl_module_retrieve_remote_modules=true
    if ! (
        [ -f "${bl_module_remote_module_cache_path}/module.sh" ] || \
        command curl \
            https://raw.githubusercontent.com/thaibault/bashlink/master/module.sh \
                >"${bl_module_remote_module_cache_path}/module.sh"
    ); then
        echo Needed bashlink library could not be retrieved. 1>&2
        rm \
            --force \
            --recursive \
            "${bl_module_remote_module_cache_path}/module.sh"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${bl_module_remote_module_cache_path}/module.sh"
    rm --force --recursive "${bl_module_remote_module_cache_path}/module.sh"
fi
bl.module.import bashlink.changeroot
bl.module.import bashlink.dictionary
bl.module.import bashlink.exception
bl.module.import bashlink.logging
bl.module.import bashlink.number
bl.module.import bashlink.tools
# endregion
# region variables
declare -gr ai__documentation__='
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
            https://raw.githubusercontent.com/thaibault/archinstall/master/archinstall.sh \
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
declare -agr ai__dependencies__=(
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
)
declare -agr ai__optional_dependencies__=(
    # Dependencies for blockdevice integration
    'blockdev: Call block device ioctls from the command line (part of util-linux).'
    'btrfs: Control a btrfs filesystem (part of btrfs-progs).'
    'cryptsetup: Userspace setup tool for transparent encryption of block devices using dm-crypt.'
    'efibootmgr: Manipulate the EFI Boot Manager (part of efibootmgr).'
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
declare -agr ai_basic_packages=(base linux ntp which)
declare -agr ai_common_additional_packages=(base-devel python sudo)

declare -ag ai_additional_packages=()
declare -g ai_add_common_additional_packages=false
# After determining dependencies a list like this will be stored:
# "bash", "curl", "glibc", "openssl", "pacman", "readline", "xz", "tar" ...
declare -ag ai_needed_packages=(filesystem pacman)

# Defines where to mount temporary new filesystem.
# NOTE: Path has to be end with a system specified delimiter.
declare -g ai_mountpoint_path=/mnt/

bl.dictionary.set ai_known_dependency_aliases libncursesw.so ncurses

declare -ag ai_package_source_urls=(
    'https://www.archlinux.org/mirrorlist/?country=DE&protocol=http&ip_version=4&use_mirror_status=on'
)
declare -ag ai_package_urls=(
    https://mirrors.kernel.org/archlinux
)

declare -gi ai_network_timeout_in_seconds=6

declare -ag ai_unneeded_file_locations=(.INSTALL .PKGINFO var/cache/pacman)
## region command line arguments

declare -g ai_auto_partitioning=false
declare -g ai_boot_entry_label=archLinux
declare -g ai_boot_partition_label=uefiBoot
# NOTE: A FAT32 partition has to be at least 2048 MB large.
declare -gi ai_boot_space_in_mega_byte=2048
declare -g ai_fallback_boot_entry_label=archLinuxFallback

declare -gi ai_needed_system_space_in_mega_byte=512
declare -g ai_system_partition_label=system
declare -g ai_system_partition_installation_only=false

# NOTE: Each value which is present in "/etc/pacman.d/mirrorlist" is ok.
declare -g ai_country_with_mirrors=Germany
# NOTE: This properties aren't needed in the future with supporting "localectl"
# program.
declare -g ai_local_time=EUROPE/Berlin

# NOTE: Possible constant values are "i686", "x86_64" "arm" or "any".
declare -g ai_cpu_architecture="$(uname -m)"

declare -g ai_host_name=''

declare -g ai_keyboard_layout=de-latin1
declare -g ai_key_map_configuration_file_content="KEYMAP=${ai_keyboard_layout}"$'\nFONT=Lat2-Terminus16\nFONT_MAP='

declare -ag ai_needed_services=(ntpd systemd-networkd systemd-resolved)

declare -g ai_target=archInstall

declare -g ai_encrypt=false
declare -g ai_password=root
declare -ag ai_user_names=()

declare -g ai_prevent_using_native_arch_changeroot=false
declare -g ai_prevent_using_existing_pacman=false
declare -g ai_automatic_reboot=false
## endregion
bl_module_scope_rewrites+=('^archinstall([._][a-zA-Z_-]+)?$/ai\1/')
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


-u --user-names [USER_NAMES [USER_NAMES ...]], Defines user names for new system (default: "${ai_user_names[@]}").

-n --host-name HOST_NAME Defines name for new system (default: "$ai_host_name").


-c --cpu-architecture CPU_ARCHITECTURE Defines architecture (default: "$ai_cpu_architecture").

-t --target TARGET Defines where to install new operating system. You can provide a full disk or patition via blockdevice such as "/dev/sda" or "/dev/sda1". You can also provide a diretory path such as "/tmp/lifesystem" (default: "$ai_target").


-l --local-time LOCAL_TIME Local time for you system (default: "$ai_local_time").

-i --keyboard-layout LAYOUT Defines needed keyboard layout (default: "$ai_keyboard_layout").

-k --key-map-configuration FILE_CONTENT Keyboard map configuration (default: "$ai_key_map_configuration_file_content").

-m --country-with-mirrors COUNTRY Country for enabling servers to get packages from (default: "$ai_country_with_mirrors").


-r --reboot Reboot after finishing installation.

-p --prevent-using-existing-pacman Ignores presence of pacman to use it for install operating system (default: "$ai_prevent_using_existing_pacman").

-y --prevent-using-native-arch-chroot Ignores presence of "arch-chroot" to use it for chroot into newly created operating system (default: "$ai_prevent_using_native_arch_changeroot").

-a --auto-paritioning Defines to do partitioning on founded block device automatic.


-b --boot-partition-label LABEL Partition label for uefi boot partition (default: "$ai_boot_partition_label").

-s --system-partition-label LABEL Partition label for system partition (default: "$ai_system_partition_label").


-e --boot-entry-label LABEL Boot entry label (default: "$ai_boot_entry_label").

-f --fallback-boot-entry-label LABEL Fallback boot entry label (default: "$ai_fallback_boot_entry_label").


-w --boot-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your boot partition (default: "$ai_boot_space_in_mega_byte megabyte"). This partition is used for kernel and initramfs only.

-q --needed-system-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your system partition (default: "$ai_needed_system_space_in_mega_byte megabyte"). This partition is used for the whole operating system.


-z --install-common-additional-packages, (default: "$ai_add_common_additional_packages") If present the following packages will be installed: "${ai_common_additional_packages[*]}".

-g --additional-packages [PACKAGES [PACKAGES ...]], You can give a list with additional available packages (default: "${ai_additional_packages[@]}").

-j --needed-services [SERVICES [SERVICES ...]], You can give a list with additional available services (default: "${ai_needed_services[@]}").

-o --cache-path PATH Define where to load and save downloaded dependencies (default: "$ai_cache_path").


-S --system-partition-installation-only Interpret given input as single partition to use as target only (Will be determined automatically if not set explicitely).

-E --encrypt Encrypts system partition.

-P --password Password to use for root login (and encryption if corresponding flag is set).


-x --timeout NUMBER_OF_SECONDS Defines time to wait for requests (default: $ai_network_timeout_in_seconds).
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
    echo -e "$ai__documentation__"
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
                    ai_user_names+=("$1")
                    shift
                done
                ;;
            -n|--host-name)
                shift
                ai_host_name="$1"
                shift
                ;;

            -c|--cpu-architecture)
                shift
                ai_cpu_architecture="$1"
                shift
                ;;
            -t|--target)
                shift
                ai_target="$1"
                shift
                ;;

            -l|--local-time)
                shift
                ai_local_time="$1"
                shift
                ;;
            -i|--keyboard-layout)
                shift
                ai_keyboard_layout="$1"
                shift
                ;;
            -k|--key-map-configuation)
                shift
                ai_key_map_configuration_file_content="$1"
                shift
                ;;
            -m|--country-with-mirrors)
                shift
                ai_country_with_mirrors="$1"
                shift
                ;;

            -r|--reboot)
                shift
                ai_automatic_reboot=true
                ;;
            -a|--auto-partitioning)
                shift
                ai_auto_partitioning=true
                ;;
            -p|--prevent-using-existing-pacman)
                shift
                ai_prevent_using_existing_pacman=true
                ;;
            -y|--prevent-using-native-arch-chroot)
                shift
                ai_prevent_using_native_arch_changeroot=true
                ;;

            -b|--boot-partition-label)
                shift
                ai_boot_partition_label="$1"
                shift
                ;;
            -s|--system-partition-label)
                shift
                ai_system_partition_label="$1"
                shift
                ;;

            -e|--boot-entry-label)
                shift
                ai_boot_entry_label="$1"
                shift
                ;;
            -f|--fallback-boot-entry-label)
                shift
                ai_fallback_boot_entry_label="$1"
                shift
                ;;

            -w|--boot-space-in-mega-byte)
                shift
                ai_boot_space_in_mega_byte="$1"
                shift
                ;;
            -q|--needed-system-space-in-mega-byte)
                shift
                ai_needed_system_space_in_mega_byte="$1"
                shift
                ;;

            -z|--add-common-additional-packages)
                shift
                ai_add_common_additional_packages=true
                ;;
            -g|--additional-packages)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    ai_additional_packages+=("$1")
                    shift
                done
                ;;
            -j|--needed-services)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    ai_needed_services+=("$1")
                    shift
                done
                ;;
            -o|--cache-path)
                shift
                ai_cache_path="${1%/}/"
                shift
                ;;

            -S|--system-partition-installation-only)
                shift
                ai_system_partition_installation_only=true
                ;;

            -E|--encrypt)
                shift
                ai_encrypt=true
                ;;
            -P|--password)
                shift
                ai_password="$1"
                shift
                ;;

            -x|--timeout)
                shift
                ai_network_timeout_in_seconds="$1"
                shift
                ;;

            '')
                shift || \
                    true
                break
                ;;
            *)
                logging.error "Given argument: \"$1\" is not available."
                bl.logging.plain "$(ai.get_help_message)"
                return 1
        esac
    done
    if \
        [[ "$UID" != 0 ]] && \
        ! {
            hash fakeroot 2>/dev/null && \
            hash fakechroot 2>/dev/null && \
            { [ -e "$ai_target" ] && [ -d "$ai_target" ]; }
        }
    then
        bl.logging.error_exception \
            "You have to run this script as \"root\" not as \"$USER\". You can alternatively install \"fakeroot\", \"fakechroot\" and install into a directory."
    fi
    if bl.tools.is_main; then
        if [ "$ai_host_name" = '' ]; then
            while true; do
                bl.logging.plain -n 'Please set hostname for new system: '
                read -r ai_host_name
                if [[ "$(
                    echo "$ai_host_name" | \
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
        ! $ai_system_partition_installation_only && \
        ! $ai_auto_partitioning && \
        echo "$ai_target" | \
            "$(which grep)" --quiet --extended-regexp '[0-9]$'
    then
        ai_system_partition_installation_only=true
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
    if ! $ai_prevent_using_native_arch_changeroot && \
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
    ai.changeroot "$ai_mountpoint_path" "$@"
    return $?
}
### endregion
alias ai.add_boot_entries=ai_add_boot_entries
ai_add_boot_entries() {
    local -r __documentation__='
        Creates an uefi boot entry.
    '
    if ai.changeroot_to_mountpoint bash -c 'hash efibootmgr' \
        2>/dev/null
    then
        bl.logging.info Configure efi boot manager.
        local root_boot_selector="root=PARTLABEL=${ai_system_partition_label}"
        if $ai_encrypt; then
            mkdir --parents "${ai_mountpoint_path}boot/keys"
            echo -n "$ai_password" \
                >"${ai_mountpoint_path}boot/keys/boot.luks.password.txt"
            root_boot_selector="rd.luks.key=$(ai.determine_partition_uuid "$ai_system_partition_label")=/keys/boot.luks.password.txt:UUID=$(ai.determine_partition_uuid "$ai_boot_partition_label") rd.luks.name=$(ai.determine_partition_uuid "$ai_system_partition_label")=cryptroot rd.luks.options=timeout=36000 rd.luks.options=$(ai.determine_partition_uuid "$ai_system_partition_label")=keyfile-timeout=2s root=/dev/mapper/cryptroot rw rootflags=subvol=root rootflags=x-systemd.device-timeout=36030"
        fi
        local -r kernel_command_line="initrd=\\initramfs-linux.img ${root_boot_selector} quiet loglevel=2"
        echo "\\vmlinuz-linux ${kernel_command_line}" \
            >"${ai_mountpoint_path}/boot/startup.nsh"
        ai.changeroot_to_mountpoint efibootmgr \
            --create \
            --disk "$ai_target" \
            --label "$ai_fallback_boot_entry_label" \
            --loader '\vmlinuz-linux' \
            --part 1 \
            --unicode \
            "initrd=\\initramfs-linux-fallback.img ${root_boot_selector} break=premount break=postmount" || \
                bl.logging.warn \
                    "Adding boot entry \"${ai_fallback_boot_entry_label}\" failed."
        # NOTE: Boot entry to boot on next reboot should be added at last.
        ai.changeroot_to_mountpoint efibootmgr \
            --create \
            --disk "$ai_target" \
            --label "$ai_boot_entry_label" \
            --loader '\vmlinuz-linux' \
            --part 1 \
            --unicode \
            "$kernel_command_line" || \
                bl.logging.warn \
                    "Adding boot entry \"${ai_boot_entry_label}\" failed."
    else
        bl.logging.warn \
            "\"efibootmgr\" doesn't seem to be installed. Creating a boot entry failed."
    fi
}
alias ai.append_temporary_install_mirrors=ai_append_temporary_install_mirrors
ai_append_temporary_install_mirrors() {
    local -r __documentation__='
        Appends temporary used mirrors to download missing packages during
        installation.
    '
    local url
    for url in $1; do
        echo "Server = $url/\$repo/os/\$arch" \
            1>>"${ai_mountpoint_path}etc/pacman.d/mirrorlist"
    done
}
alias ai.cache=ai_cache
ai_cache() {
    local -r __documentation__='
        Cache previous downloaded packages and database.
    '
    bl.logging.info Cache loaded packages.
    cp \
        --force \
        --preserve \
        "${ai_mountpoint_path}var/cache/pacman/pkg/"*.pkg.tar.xz \
        "$ai_cache_path"
    bl.logging.info Cache loaded databases.
    cp \
        --force \
        --preserve \
        "${ai_mountpoint_path}var/lib/pacman/sync/"*.db \
        "$ai_cache_path"
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
            bl.logging.info "Found network device \"$network_device_name\"."
            cat << EOF 1>"${ai_mountpoint_path}etc/systemd/network/20-ethernet.network"
[Match]
Name=en*
Name=eth*

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes

[DHCP]
RouteMetric=512
EOF
            cat << EOF 1>"${ai_mountpoint_path}etc/systemd/network/20-wireless.network"
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
#        cat << EOF 1>"${ai_mountpoint_path}etc/netctl/${network_device_name}-dhcp"
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
#                "${ai_mountpoint_path}etc/systemd/system/multi-user.target.wants/${service_name}@${network_device_name}.service"
        fi
    done
    local service_name
    for service_name in "${ai_needed_services[@]}"; do
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
    command lsblk --noheadings --output PARTLABEL,UUID "$ai_target" | \
        command grep "$1" | \
            command sed --regexp-extended 's/.+ (.+)$/\1/'
}
alias ai.get_hosts_content=ai_get_hosts_content
ai_get_hosts_content() {
    local -r __documentation__='
        Provides the file content for the "/etc/hosts".
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
    if $ai_encrypt; then
        bl.logging.info \
            Configure initramfs to support decrypting root system at boot.
        sed \
            --in-place \
            --regexp-extended \
            's/^(MODULES=\().*(\))$/\1vfat\2/' \
            "${ai_mountpoint_path}etc/mkinitcpio.conf"
        sed \
            --in-place \
            --regexp-extended \
            's/^(HOOKS=\().+(\))$/\1base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems\2/' \
            "${ai_mountpoint_path}etc/mkinitcpio.conf"
    fi
    bl.logging.info \
        "Make keyboard layout permanent to \"${ai_keyboard_layout}\"."
    if [ "$1" = true ]; then
        ai.changeroot_to_mountpoint localectl set-keymap "$ai_keyboard_layout"
        ai.changeroot_to_mountpoint localectl set-locale LANG=en_US.utf8
        ai.changeroot_to_mountpoint locale-gen set-keymap "$ai_keyboard_layout"
    else
        echo -e "$ai_key_map_configuration_file_content" \
            1>"${ai_mountpoint_path}etc/vconsole.conf"
    fi
    bl.logging.info "Set localtime \"$ai_local_time\"."
    if [ "$1" = true ]; then
        ai.changeroot_to_mountpoint timedatectl set-timezone "$ai_local_time"
    else
        ln \
            --symbolic \
            --force "/usr/share/zoneinfo/${ai_local_time}" \
            "${ai_mountpoint_path}etc/localtime"
    fi
    bl.logging.info "Set hostname to \"$ai_host_name\"."
    if [ "$1" = true ]; then
        ai.changeroot_to_mountpoint hostnamectl set-hostname "$ai_host_name"
    else
        echo "$ai_host_name" \
            1>"${ai_mountpoint_path}etc/hostname"
    fi
    bl.logging.info Set hosts.
    ai.get_hosts_content "$ai_host_name" \
        1>"${ai_mountpoint_path}etc/hosts"
    if [[ "$1" != true ]]; then
        bl.logging.info "Set root password to \"root\"."
        ai.changeroot_to_mountpoint \
            /usr/bin/env bash -c \
                "echo root:${ai_password} | \$(which chpasswd)"
    fi
    bl.exception.try
        ai.enable_services
    bl.exception.catch_single
        bl.logging.warn Enabling services has failed.
    local user_name
    for user_name in "${ai_user_names[@]}"; do
        bl.logging.info "Add user: \"$user_name\"."
        # NOTE: We could only create a home directory with right rights if we
        # are root.
        bl.exception.try
            ai.changeroot_to_mountpoint \
                useradd "$(
                    if (( UID == 0 )); then
                        echo --create-home
                    else
                        echo --no-create-home
                    fi
                ) --no-user-group --shell /usr/bin/bash" \
                "$user_name"
        bl.exception.catch_single
            bl.logging.warn "Adding user \"$user_name\" failed."
        bl.logging.info "Set password for \"$user_name\" to \"$user_name\"."
        ai.changeroot_to_mountpoint \
            /usr/bin/env bash -c \
                "echo ${user_name}:${user_name} | \$(which chpasswd)"
    done
    return $?
}
alias ai.configure_pacman=ai_configure_pacman
ai_configure_pacman() {
    local -r __documentation__='
        Disables signature checking for incoming packages.
    '
    bl.logging.info "Enable mirrors in \"$ai_country_with_mirrors\"."
    local buffer_file="$(mktemp --suffix -archinstall-processed-mirrorlist)"
    bl.exception.try
    {
        local in_area=false
        local -i line_number=0
        local line
        while read -r line; do
            (( line_number = (( line_number + 1 )) ))
            if [ "$line" = "## $ai_country_with_mirrors" ]; then
                in_area=true
            elif [ "$line" = '' ]; then
                in_area=false
            elif $in_area && [ "${line:0:1}" = '#' ]; then
                line="${line:1}"
            fi
            echo "$line"
        done < "${ai_mountpoint_path}etc/pacman.d/mirrorlist" \
            1>"$buffer_file"
        cat "$buffer_file" \
            1>"${ai_mountpoint_path}etc/pacman.d/mirrorlist"
    }
    bl.exception.catch_single
    {
        rm --force "$buffer_file"
        # shellcheck disable=SC2154
        bl.logging.error_exception "$bl_exception_last_traceback"
    }
    rm --force "$buffer_file"
}
alias ai.determine_auto_partitioning=ai_determine_auto_partitioning
ai_determine_auto_partitioning() {
    local -r __documentation__='
        Determine whether we should perform our auto partitioning mechanism.
    '
    if ! $ai_auto_partitioning; then
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
                ai_auto_partitioning=false
                break
            elif \
                [ "$(
                    echo "$auto_partitioning" | tr '[:upper:]' '[:lower:]'
                )" = yes ]
            then
                ai_auto_partitioning=true
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
    for url in "${ai_package_source_urls[@]}"; do
        bl.logging.info "Retrieve repository source url list from \"$url\"."
        if serialized_url_list="$(
            command curl \
                "$url" \
                --max-time "$ai_network_timeout_in_seconds" \
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
        "${url_list[@]}" "${ai_package_urls[@]}")
    local -a package_urls=()
    local name
    for name in core community extra; do
        for url in "${ai_package_urls[@]}"; do
            bl.logging.info "Retrieve repository \"$name\" from \"$url\"."
            if serialized_url_list="$(
                command curl \
                    --retry 3 \
                    --retry-all-errors \
                    --retry-delay 1 \
                    --max-time "$ai_network_timeout_in_seconds" \
                    "${url}/$name/os/$ai_cpu_architecture" | \
                        command sed \
                            --quiet \
                            "s>.*href=\"\\([^\"]*.\\(tar.xz\\|db\\)\\).*>${url}/$name/os/$ai_cpu_architecture/\\1>p" | \
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
                        '^[a-zA-Z0-9][-a-zA-Z0-9.]+' | \
                            sed --regexp-extended 's/^(.+)[><=].+$/\1/'
            )"
            local alias
            if alias="$(
                bl.dictionary.get \
                    ai_known_dependency_aliases \
                    "$package_name"
            )"; then
                package_name="$alias"
            fi
            if echo "$package_names_to_ignore" | grep --quiet " $package_name "
            then
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
ai.determine_package_description_file_path() {
    local -r __documentation__='
        Determines the package directory name from given package name in given
        database folder.
    '
    local -r package_name="$1"
    local -r database_directory_path="$2"
    local -r package_description_file_path="$(
        command grep \
            "%PROVIDES%\\n(.+\\n)*$package_name\\n(.+\\n)*\\n" \
            --files-with-matches \
            --null-data \
            --perl-regexp \
            --recursive \
            "$database_directory_path"
    )"
    if [ "$package_description_file_path" = '' ]; then
        local regular_expression
        for regular_expression in \
            '^\(.*/\)?'"$package_name"'$' \
            '^\(.*/\)?'"$package_name"'-[0-9]+[0-9.\-]*$' \
            '^\(.*/\)?'"$package_name"'-[0-9]+[0-9.a-zA-Z-]*$' \
            '^\(.*/\)?'"$package_name"'-git-[0-9]+[0-9.a-zA-Z-]*$' \
            '^\(.*/\)?'"$package_name"'[0-9]+-[0-9.a-zA-Z-]+\(-[0-9.a-zA-Z-]\)*$' \
            '^\(.*/\)?[0-9]+'"$package_name"'[0-9]+-[0-9a-zA-Z\.]+\(-[0-9a-zA-Z\.]\)*$' \
            '^\(.*/\)?'"$package_name"'-.+$' \
            '^\(.*/\)?.+-'"$package_name"'-.+$' \
            '^\(.*/\)?'"$package_name"'.+$' \
            '^\(.*/\)?'"$package_name"'.*$' \
            '^\(.*/\)?.*'"$package_name"'.*$'
        do
            package_description_file_path="$(
                command find \
                    "$database_directory_path" \
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
                        local raw_version="$(
                            bl.number.normalize_version \
                                "$description_file_path")"
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
                --retry 3 \
                --retry-all-errors \
                --retry-delay 1 \
                --max-time="$ai_network_timeout_in_seconds" \
                --netrc-file "$(basename "$core_database_url")" \
                    >"${ai_cache_path}$(basename "$core_database_url")"
        bl.exception.catch_single
            bl.logging.warn \
                "Could not retrieve latest database file from determined url \"$core_database_url\"."
    fi
    if [ -f "${ai_cache_path}core.db" ]; then
        local -r database_directory_path="$(
            mktemp --directory --suffix -archinstall-core-database)"
        bl.exception.try
        {
            local -a packages=()
            tar \
                --directory "$database_directory_path" \
                --extract \
                --file "${ai_cache_path}core.db" \
                --gzip
            local package_name
            for package_name in "${ai_needed_packages[@]}"; do
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
            bl.logging.error_exception "$bl_exception_last_traceback"
        }
        return 0
    fi
    bl.logging.critical \
        "No database file (\"${ai_cache_path}core.db\") could be found."
    return 1
}
alias ai.download_and_extract_pacman=ai_download_and_extract_pacman
ai_download_and_extract_pacman() {
    local -r __documentation__='
        Downloads all packages from arch linux needed to run pacman.
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
            "Retrieve and extract each package into our new system located in \"$ai_mountpoint_path\"."
        local package_name
        for package_name in "${needed_packages[@]}"; do
            local file_name=''
            if [[ "$1" != '' ]]; then
                local package_url="$(
                    echo "$1" | \
                        tr ' ' '\n' | \
                            command grep "/${package_name}-[0-9]")"
                local number_of_results="$(echo "$package_url" | wc --words)"
                if (( number_of_results > 1 )); then
                    # NOTE: We want to use newer package if their are two
                    # results.
                    local url
                    local highest_raw_version=0
                    for url in $package_url; do
                        local raw_version="$(
                            bl.number.normalize_version "$url")"
                        if (( raw_version > highest_raw_version )); then
                            package_url="$url"
                            highest_raw_version=$raw_version
                        fi
                    done
                fi
                bl.exception.try
                {
                    command curl \
                        "$package_url" \
                        --continue-at - \
                        --max-time "$ai_network_timeout_in_seconds" \
                        --netrc-file "$(basename "$package_url")" \
                        --retry 3 \
                        --retry-all-errors \
                        --retry-delay 1 \
                            >"${ai_cache_path}$(basename "$package_url")"
                    file_name="$(
                        echo "$package_url" | \
                            command sed 's/.*\/\([^\/][^\/]*\)$/\1/')"
                    # NOTE: We have to decode given url.
                    file_name="$(printf '%b' "${file_name//%/\\x}")"
                }
                bl.exception.catch_single
                    bl.logging.warn \
                        "Could not retrieve package \"$package_name\" from url \"$package_url\"."
            fi
            # If "file_name" couldn't be determined via server determine it via
            # current package cache.
            if [ "$file_name" = '' ]; then
                file_name="$(
                    command find \
                        "$ai_cache_path" \
                        -maxdepth 1 \
                        -regex ".*/$package_name-[0-9].*" | \
                            sed --regexp-extended 's:^.*/([^/]+)$:\1:')"
                local number_of_results="$(echo "$file_name" | wc --words)"
                if (( number_of_results > 1 )); then
                    # NOTE: We want to use newer package if their are two
                    # results.
                    local name
                    local highest_raw_version=0
                    for name in $file_name; do
                        bl.exception.try
                            bl.number.normalize_version "$name" 6
                        bl.exception.catch_single
                            true
                        local raw_version="$(
                            bl.number.normalize_version "$name")"
                        if (( raw_version > highest_raw_version )); then
                            file_name="$name"
                            highest_raw_version=$raw_version
                        fi
                    done
                fi
            fi
            if [[
                "$file_name" = '' || \
                ! -f "${ai_cache_path}${file_name}"
            ]]; then
                bl.logging.error_exception \
                    "A suitable file for package \"$package_name\" could not be determined."
            fi
            bl.logging.info "Install package \"$file_name\" manually."
            xz \
                --decompress \
                --to-stdout \
                "${ai_cache_path}$file_name" | \
                    tar \
                        --directory "$ai_mountpoint_path" \
                        --extract || \
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
    local boot_partition_device_path="${ai_target}1"
    if [ ! -b "$boot_partition_device_path" ]; then
        boot_partition_device_path="${ai_target}p1"
    fi
    mkfs.vfat -F 32 "$boot_partition_device_path"
    if hash dosfslabel 2>/dev/null; then
        dosfslabel "$boot_partition_device_path" "$ai_boot_partition_label"
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
    local output_device="$ai_target"
    if [ -b "${ai_target}2" ]; then
        output_device="${ai_target}2"
    elif [ -b "${ai_target}p2" ]; then
        output_device="${ai_target}p2"
    fi
    bl.logging.info "Make system partition at \"$output_device\"."
    if $ai_encrypt; then
        bl.logging.info \
            "Encrypt system partition at \"$output_device\" and map to \"cryptroot\"."
        echo -n "$ai_password" | \
            cryptsetup \
                --batch-mode \
                --force-password \
                --key-file - \
                luksFormat \
                "$output_device"
        echo -n "$ai_password" | \
            cryptsetup \
                --batch-mode \
                --key-file - \
                open \
                "$output_device" \
                cryptroot
        output_device=/dev/mapper/cryptroot
    fi
    mkfs.btrfs --force --label "$ai_system_partition_label" "$output_device"
    bl.logging.info "Creating a root sub volume in \"$output_device\"."
    # NOTE: It is more reliable if we do not use the partition label here if
    # some pre or post processing by other tools will be done.
    mount "$output_device" "$ai_mountpoint_path"
    btrfs subvolume create "${ai_mountpoint_path}root"
    umount "$ai_mountpoint_path"
    if $ai_encrypt; then
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
    '
    bl.logging.info Generate fstab config.
    if ! $ai_encrypt && hash genfstab 2>/dev/null; then
        # NOTE: Mountpoint shouldn't have a path separator at the end.
        genfstab \
            -L \
            -p "${ai_mountpoint_path%?}" \
            1>>"${ai_mountpoint_path}etc/fstab"
    else
        cat << EOF 1>>"${ai_mountpoint_path}etc/fstab"
# Added during installation.
# <file system>                    <mount point> <type> <options>                                                                                            <dump> <pass>
# "compress=lzo" has lower compression ratio by better cpu performance.
$($ai_encrypt && echo /dev/mapper/cryptroot || echo "PARTLABEL=${ai_system_partition_label}") /             btrfs  autodefrag,compress=zlib,discard,noatime,nodiratime,ssd,space_cache,subvol=root                    0      0
PARTLABEL=$ai_boot_partition_label   /boot/        vfat   codepage=437,dmask=0077,errors=remount-ro,fmask=0077,iocharset=iso8859-1,noatime,relatime,rw,shortname=mixed 0      0
EOF
    fi
}
alias ai.load_cache=ai_load_cache
ai_load_cache() {
    local -r __documentation__='
        Load previous downloaded packages and database.
    '
    bl.logging.info Load cached databases.
    mkdir --parents "${ai_mountpoint_path}var/lib/pacman/sync"
    bl.exception.try
        cp \
            --no-clobber \
            --preserve \
            "$ai_cache_path"*.db \
            "${ai_mountpoint_path}var/lib/pacman/sync/" \
                2>/dev/null
    bl.exception.catch_single
        bl.logging.info No local database available to load from cache.
    bl.logging.info Load cached packages.
    mkdir --parents "${ai_mountpoint_path}var/cache/pacman/pkg"
    bl.exception.try
        cp \
            --no-clobber \
            --preserve \
            "$ai_cache_path"*.pkg.tar.xz \
            "${ai_mountpoint_path}var/cache/pacman/pkg/" \
                2>/dev/null
    bl.exception.catch_single
        bl.logging.info No local packages available to load from cache.
}
alias ai.make_partitions=ai_make_partitions
ai_make_partitions() {
    local -r __documentation__='
        Performs the auto partitioning.
    '
    if $ai_auto_partitioning; then
        bl.logging.info Check block device size.
        local blockdevice_space_in_mega_byte="$(("$(
            blockdev --getsize64 "$ai_target"
        )" * 1024 ** 2))"
        if (( $((
            ai_needed_system_space_in_mega_byte + \
            ai_boot_space_in_mega_byte
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
            gdisk "$ai_target" << EOF
o
Y
n


${ai_boot_space_in_mega_byte}M
ef00
n




c
1
$ai_boot_partition_label
c
2
$ai_system_partition_label
w
Y
EOF
        else
            bl.logging.critical \
                "Not enough space on \"$ai_target\" (\"$blockdevice_space_in_mega_byte\" megabyte). We need at least \"$((ai_needed_system_space_in_mega_byte + ai_boot_space_in_mega_byte))\" megabyte."
        fi
    else
        bl.logging.info \
            "At least you have to create two partitions. The first one will be used as boot partition labeled to \"${ai_boot_partition_label}\" and second one will be used as system partition and labeled to \"${ai_system_partition_label}\". Press Enter to continue."
        read -r
        bl.logging.info Show blockdevices. Press Enter to continue.
        lsblk
        read -r
        bl.logging.info Create partitions manually.
        gdisk "$ai_target"
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
            "System will be packed into \"$ai_mountpoint_path.tar\" to provide root owned files. You have to extract this archiv as root."
        tar \
            cvf \
            "${ai_mountpoint_path}.tar" \
            "$ai_mountpoint_path" \
            --owner root \
        rm \
            "$ai_mountpoint_path"* \
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
    umount --force "${ai_target}"* 2>/dev/null || \
        true
    umount --force "$ai_mountpoint_path" 2>/dev/null || \
        true
    cryptsetup close cryptroot 2>/dev/null || \
        true
    swapoff "${ai_target}"* 2>/dev/null || \
        true
}
alias ai.prepare_installation=ai_prepare_installation
ai_prepare_installation() {
    local -r __documentation__='
        Deletes previous installed things in given output target. And creates a
        package cache directory.
    '
    mkdir --parents "$ai_cache_path"
    if [ -b "$ai_target" ]; then
        bl.logging.info Mount system partition.
        if $ai_system_partition_installation_only; then
            local source_selector="$ai_target"
            if $ai_encrypt; then
                echo -n "$ai_password" | \
                    cryptsetup \
                        --batch-mode \
                        --key-file - \
                        open \
                        "$ai_target" \
                        cryptroot
                source_selector=/dev/mapper/cryptroot
            fi
            # NOTE: It is more reliable to use the specified partition since
            # auto partitioning could be turned off and labels set wrong.
            mount \
                --options subvol=root \
                "$source_selector" \
                "$ai_mountpoint_path"
        else
            local source_selector="PARTLABEL=${ai_system_partition_label}"
            if $ai_encrypt; then
                echo -n "$ai_password" | \
                    cryptsetup \
                        --batch-mode \
                        --key-file - \
                        open \
                        "/dev/disk/by-partlabel/${ai_system_partition_label}" \
                        cryptroot
                source_selector=/dev/mapper/cryptroot
            fi
            mount \
                --options subvol=root \
                "$source_selector" \
                "$ai_mountpoint_path"
        fi
    fi
    bl.logging.info "Clear previous installations in \"$ai_mountpoint_path\"."
    rm "$ai_mountpoint_path"* --force --recursive &>/dev/null || \
        true
    if ! $ai_system_partition_installation_only && [ -b "$ai_target" ]; then
        bl.logging.info \
            "Mount boot partition in \"${ai_mountpoint_path}boot/\"."
        mkdir --parents "${ai_mountpoint_path}boot/"
        mount PARTLABEL="$ai_boot_partition_label" "${ai_mountpoint_path}boot/"
        rm "${ai_mountpoint_path}boot/"* --force --recursive
    fi
    bl.logging.info Set filesystem rights.
    chmod 755 "$ai_mountpoint_path"
    read -r -a ai_packages <<< "$(bl.array.unique "${ai_packages[*]}")"
}
alias ai.prepare_next_boot=ai_prepare_next_boot
ai_prepare_next_boot() {
    local -r __documentation__='
        Reboots into fresh installed system if previous defined.
    '
    if $ai_encrypt; then
        # NOTE: We have to rebuild initramfs to support decryption utilities
        # during boot.
        # NOTE: Because of non matching "btrfs.fsck" binary it results on non
        # zero exit code.
        ai.changeroot_to_mountpoint mkinitcpio --allpresets || true
    fi
    if [ -b "$ai_target" ]; then
        ai.generate_fstab_configuration_file
        ai.add_boot_entries
        ai.prepare_blockdevices
        if $ai_automatic_reboot; then
            bl.logging.info Reboot into new operating system.
            systemctl reboot &>/dev/null || reboot
        fi
    fi
}
alias ai.tidy_up_system=ai_tidy_up_system
ai_tidy_up_system() {
    local -r __documentation__='
        Deletes some unneeded locations in new installs operating system.
    '
    bl.logging.info Tidy up new build system.
    local file_path
    for file_path in "${ai_unneeded_file_locations[@]}"; do
        bl.logging.info "Deleting \"${ai_mountpoint_path}${file_path}\"."
        rm "${ai_mountpoint_path}$file_path" --force --recursive
    done
}
## endregion
## region install arch linux steps.
alias ai.make_pacman_portable=ai_make_pacman_portable
ai_make_pacman_portable() {
    local -r __documentation__='
        Disables signature checks and registers temporary download mirrors.
    '
    # Copy systems resolv.conf to new installed system.
    cp /etc/resolv.conf "${ai_mountpoint_path}etc/"
    command sed \
        --in-place \
        --quiet \
        '/^[ \t]*CheckSpace/ !p' \
        "${ai_mountpoint_path}etc/pacman.conf"
    command sed \
        --in-place \
        --regexp-extended \
        's/^[ \t]*(((Local|Remote)?File)?SigLevel)[ \t].*/\1 = Never TrustAll/g' \
        "${ai_mountpoint_path}etc/pacman.conf"
    bl.logging.info Register temporary mirrors to download new packages.
    if [ "$1" = '' ]; then
        cp \
            /etc/pacman.d/mirrorlist \
            "${ai_mountpoint_path}etc/pacman.d/mirrorlist"
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
            --arch "$ai_cpu_architecture" \
            --refresh \
            --sync
    bl.exception.catch_single
        bl.logging.info Updating package database failed. Operating offline.
    bl.logging.info "Install needed packages \"$(
        echo "${ai_packages[@]}" | \
            command sed 's/ /", "/g'
    )\" to \"$ai_target\"."
    ai.changeroot_to_mountpoint /usr/bin/pacman \
        --arch "$ai_cpu_architecture" \
        --needed \
        --noconfirm \
        --overwrite \
        --sync \
        "${ai_packages[@]}"
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
            --arch "$ai_cpu_architecture" \
            --refresh \
            --root "$ai_mountpoint_path" \
            --sync
    bl.exception.catch_single
        bl.logging.info \
            Updating package database failed. Operating offline.
    bl.logging.info "Install needed packages \"$(
        echo "${ai_packages[@]}" | \
            command sed 's/ /", "/g'
    )\" to \"$ai_target\"."
    if hash pacstrap &>/dev/null; then
        bl.logging.info Patch pacstrap to handle offline installations.
        command sed \
            --regexp-extended \
            's/(pacman.+-(S|-sync))(y|--refresh)/\1/g' \
                <"$(command -v pacstrap)" \
                1>"${ai_cache_path}patchedOfflinePacstrap.sh"
        chmod +x "${ai_cache_path}patchedOfflinePacstrap.sh"
        "${ai_cache_path}patchedOfflinePacstrap.sh" \
            -d "$ai_mountpoint_path" \
            "${ai_packages[@]}" \
            --overwrite
        local return_code=$?
        rm "${ai_cache_path}patchedOfflinePacstrap.sh"
        return $return_code
    fi
    pacman \
        --overwrite \
        --root "$ai_mountpoint_path" \
        --sync \
        --noconfirm \
        "${ai_needed_packages[@]}"
    ai.make_pacman_portable
    ai.changeroot_to_mountpoint \
        /usr/bin/pacman \
        --arch "$ai_cpu_architecture" \
        --needed \
        --noconfirm \
        --overwrite \
        --sync \
        "${ai_packages[@]}"
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
    ai_packages+=(
        "${ai_basic_packages[@]}"
        "${ai_additional_packages[@]}"
    )
    if $ai_add_common_additional_packages; then
        ai_packages+=("${ai_common_additional_packages[@]}")
    fi
    if [ ! -e "$ai_target" ]; then
        mkdir --parents "$ai_target"
    fi
    if [ -d "$ai_target" ]; then
        ai_mountpoint_path="$ai_target"
        if [[ ! "$ai_mountpoint_path" =~ .*/$ ]]; then
            ai_mountpoint_path+=/
        fi
    elif [ -b "$ai_target" ]; then
        ai_packages+=(efibootmgr)
        ai.prepare_blockdevices
        bl.exception.try
        {
            if $ai_system_partition_installation_only; then
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
            bl.logging.error_exception "$bl_exception_last_traceback"
        }
    else
        bl.logging.error_exception "Could not install into \"$ai_target\"."
    fi
    ai.prepare_installation
    bl.exception.try
        ai.load_cache
    bl.exception.catch_single
        bl.logging.info No package cache was loaded.
    if (( UID == 0 )) && ! $ai_prevent_using_existing_pacman && \
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
        "Generating operating system into \"$ai_target\" has successfully finished."
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
