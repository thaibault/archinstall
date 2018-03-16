#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de
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
    archInstall_bashlink_path="$(mktemp --directory --suffix -bashlink)/bashlink/"
    mkdir "$archInstall_bashlink_path"
    if wget \
        https://goo.gl/UKF5JG \
        --output-document "${archInstall_bashlink_path}module.sh" \
        --quiet
    then
        bl_module_retrieve_remote_modules=true
        # shellcheck disable=SC1090
        source "${archInstall_bashlink_path}/module.sh"
    else
        echo Needed bashlink library not found 1>&2
        exit 1
    fi
fi
bl.module.import bashlink.changeroot
bl.module.import bashlink.exception
bl.module.import bashlink.logging
bl.module.import bashlink.number
bl.module.import bashlink.tools
# endregion
# region variables
archInstall__documentation__='
    This module installs a linux from scratch by the arch way. You will end up
    in ligtweigth linux with pacman as packetmanager. You can directly install
    into a given blockdevice, partition or any directory (see command line
    option "--output-system"). Note that every needed information which is not
    given via command line will be asked interactivly on start. This script is
    as unnatted it could be, which means you can relax after providing all
    needed informations in the beginning till your new system is ready to boot.

    Start install progress command (Assuming internet is available):

    ```bash
        wget \
            http://torben.website/clientNode/data/distributionBundle/index.compiled.js \
            \ -O archInstall.sh && chmod +x archInstall.sh
    ```

    Note that you only get very necessary output until you provide "--verbose"
    as commandline option.

    Examples:

    Start install progress command on first found blockdevice:

    ```bash
        arch-install --output-system /dev/sda
    ```

    Install directly into a given partition with verbose output:

    ```bash
        arch-install --output-system /dev/sda1 --verbose
    ```

    Install directly into a given directory with addtional packages included:

    ```bash
        arch-install --output-system /dev/sda1 --verbose -f vim net-tools
    ```
'
archinstall__dependencies__=(
    bash
    blkid
    cat
    chroot
    grep
    ln
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
    wget
    xz
)
archinstall__optional_dependencies__=(
    # Dependencies for blockdevice integration
    'blockdev: Call block device ioctls from the command line (part of util-linux).'
    'btrfs: Control a btrfs filesystem (part of btrfs-progs).'
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
archInstall_basic_packages=(base ifplugd)
archInstall_common_additional_packages=(base-devel python sudo)
# Defines where to mount temporary new filesystem.
# NOTE: Path has to be end with a system specified delimiter.
archInstall_mountpoint_path=/mnt/
# After determining dependencies a list like this will be stored:
# "bash", "curl", "glibc", "openssl", "pacman", "readline", "xz", "tar" ...
archInstall_needed_packages=(filesystem pacman)
archInstall_package_source_urls=(
    'https://www.archlinux.org/mirrorlist/?country=DE&protocol=http&ip_version=4&use_mirror_status=on'
)
archInstall_package_urls=(
    https://mirrors.kernel.org/archlinux
)
archInstall_unneeded_file_locations=(.INSTALL .PKGINFO var/cache/pacman)
## region command line arguments
archInstall_additional_packages=()
archInstall_add_common_additional_packages=false
archInstall_automatic_reboot=false
archInstall_auto_partitioning=true
archInstall_boot_entry_label=archLinux
archInstall_boot_partition_label=uefiBoot
# NOTE: A FAT32 partition has to be at least 512 MB large.
archInstall_boot_space_in_mega_byte=512
# NOTE: Each value which is present in "/etc/pacman.d/mirrorlist" is ok.
archInstall_country_with_mirrors=Germany
# NOTE: Possible constant values are "i686", "x86_64" "arm" or "any".
archInstall_cpu_architecture="$(uname -m)"
archInstall_fallback_boot_entry_label=archLinuxFallback
archInstall_host_name=''
archInstall_keyboard_layout=de-latin1
archInstall_key_map_configuration_file_content="KEYMAP=${archInstall_keyboard_layout}"$'\nFONT=Lat2-Terminus16\nFONT_MAP='
# NOTE: This properties aren't needed in the future with supporting "localectl"
# program.
archInstall_local_time=EUROPE/Berlin
archInstall_needed_services=()
archInstall_needed_system_space_in_mega_byte=512
archInstall_output_system=archInstall
archInstall_package_cache_path=archInstallPackageCache
archInstall_prevent_using_native_arch_changeroot=false
archInstall_prevent_using_existing_pacman=false
archInstall_system_partition_label=system
archInstall_user_names=()
## endregion
# endregion
# region functions
## region command line interface
alias archInstall.print_commandline_option_description=archInstall_print_commandline_option_description
archInstall_print_commandline_option_description() {
    local __documentation__='
        Prints descriptions about each available command line option.
        NOTE: All letters are used for short options.
        NOTE: "-k" and "--key-map-configuration" is not needed in the future.

        >>> archInstall.print_commandline_option_description
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        -h --help Shows this help message.
        ...
    '
    bl.logging.cat << EOF
-h --help Shows this help message.

-v --verbose Tells you what is going on.

-d --debug Gives you any output from all tools which are used (default: "false").


-u --user-names [USER_NAMES [USER_NAMES ...]], Defines user names for new system (default: "${archInstall_user_names[@]}").

-n --host-name HOST_NAME Defines name for new system (default: "$archInstall_host_name").


-c --cpu-architecture CPU_ARCHITECTURE Defines architecture (default: "$archInstall_cpu_architecture").

-o --output-system OUTPUT_SYSTEM Defines where to install new operating system. You can provide a full disk or patition via blockdevice such as "/dev/sda" or "/dev/sda1". You can also provide a diretory path such as "/tmp/lifesystem" (default: "$archInstall_output_system").


-x --local-time LOCAL_TIME Local time for you system (default: "$archInstall_local_time").

-b --keyboard-layout LAYOUT Defines needed keyboard layout (default: "$archInstall_keyboard_layout").

-k --key-map-configuration FILE_CONTENT Keyboard map configuration (default: "$archInstall_key_map_configuration_file_content").

-m --country-with-mirrors COUNTRY Country for enabling servers to get packages from (default: "$archInstall_country_with_mirrors").


-r --no-reboot Prevents to reboot after finishing installation.

-p --prevent-using-existing-pacman Ignores presence of pacman to use it for install operating system (default: "$archInstall_prevent_using_existing_pacman").

-y --prevent-using-native-arch-chroot Ignores presence of "arch-chroot" to use it for chroot into newly created operating system (default: "$archInstall_prevent_using_native_arch_changeroot").

-a --auto-paritioning Defines to do partitioning on founded block device automatic.


-e --boot-partition-label LABEL Partition label for uefi boot partition (default: "$archInstall_boot_partition_label").

-g --system-partition-label LABEL Partition label for system partition (default: "$archInstall_system_partition_label").


-i --boot-entry-label LABEL Boot entry label (default: "$archInstall_boot_entry_label").

-s --fallback-boot-entry-label LABEL Fallback boot entry label (default: "$archInstall_fallback_boot_entry_label").


-w --boot-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your boot partition (default: "$archInstall_boot_space_in_mega_byte megabyte"). This partition is used for kernel and initramfs only.

-q --needed-system-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your system partition (default: "$archInstall_needed_system_space_in_mega_byte megabyte"). This partition is used for the whole operating system.


-z --install-common-additional-packages, (default: "$archInstall_add_common_additional_packages") If present the following packages will be installed: "${archInstall_common_additional_packages[*]}".

-f --additional-packages [PACKAGES [PACKAGES ...]], You can give a list with additional available packages (default: "${archInstall_additional_packages[@]}").

-j --needed-services [SERVICES [SERVICES ...]], You can give a list with additional available services (default: "${archInstall_needed_services[@]}").

-t --package-cache-path PATH Define where to load and save downloaded packages (default: "$archInstall_package_cache_path").
EOF
}
alias archInstall.print_help_message=archInstall_print_help_message
archInstall_print_help_message() {
    local __documentation__='
        Provides a help message for this module.

        >>> archInstall.print_help_message
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        ...
        Usage: arch-install [options]
        ...
    '
    bl.logging.plain $'\nUsage: arch-install [options]\n'
    bl.logging.plain "$archInstall__documentation__"
    bl.logging.plain $'\nOption descriptions:\n'
    archInstall.print_commandline_option_description "$@"
    bl.logging.plain
}
# NOTE: Depends on "archInstall.print_commandline_option_description" and
# "archInstall.print_help_message".
alias archInstall.commandline_interface=archInstall_commandline_interface
archInstall_commandline_interface() {
    local __documentation__='
        Provides the command line interface and interactive questions.

        >>> archInstall.commandline_interface --help
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        ...
        Usage: arch-install [options]
        ...
    '
    bl.logging.set_commands_level debug
    while true; do
        case "$1" in
            -h|--help)
                shift
                archInstall.print_help_message "$0"
                exit 0
                ;;
            -v|--verbose)
                shift
                bl.logging.set_level info
                ;;
            -d|--debug)
                shift
                bl.logging.set_level debug
                ;;

            -u|--user-names)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    archInstall_user_names+=("$1")
                    shift
                done
                ;;
            -n|--host-name)
                shift
                archInstall_host_name="$1"
                shift
                ;;

            -c|--cpu-architecture)
                shift
                archInstall_cpu_architecture="$1"
                shift
                ;;
            -o|--output-system)
                shift
                archInstall_output_system="$1"
                shift
                ;;

            -x|--local-time)
                shift
                archInstall_local_time="$1"
                shift
                ;;
            -b|--keyboard-layout)
                shift
                archInstall_keyboard_layout="$1"
                shift
                ;;
            -k|--key-map-configuation)
                shift
                archInstall_key_map_configuration_file_content="$1"
                shift
                ;;
            -m|--country-with-mirrors)
                shift
                archInstall_country_with_mirrors="$1"
                shift
                ;;

            -r|--reboot)
                shift
                archInstall_automatic_reboot=true
                ;;
            -a|--auto-partitioning)
                shift
                archInstall_auto_partitioning=true
                ;;
            -p|--prevent-using-existing-pacman)
                shift
                archInstall_prevent_using_existing_pacman=true
                ;;
            -y|--prevent-using-native-arch-chroot)
                shift
                archInstall_prevent_using_native_arch_changeroot=true
                ;;

            -e|--boot-partition-label)
                shift
                archInstall_boot_partition_label="$1"
                shift
                ;;
            -g|--system-partition-label)
                shift
                archInstall_system_partition_label="$1"
                shift
                ;;

            -i|--boot-entry-label)
                shift
                archInstall_boot_entry_label="$1"
                shift
                ;;
            -s|--fallback-boot-entry-label)
                shift
                archInstall_fallback_boot_entry_label="$1"
                shift
                ;;

            -w|--boot-space-in-mega-byte)
                shift
                archInstall_boot_space_in_mega_byte="$1"
                shift
                ;;
            -q|--needed-system-space-in-mega-byte)
                shift
                archInstall_needed_system_space_in_mega_byte="$1"
                shift
                ;;

            -z|--add-common-additional-packages)
                shift
                archInstall_add_common_additional_packages=false
                ;;
            -f|--additional-packages)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    archInstall_additional_packages+=("$1")
                    shift
                done
                ;;
            -j|--needed-services)
                shift
                while [[ "$1" =~ ^[^-].+$ ]]; do
                    archInstall_needed_services+=("$1")
                    shift
                done
                ;;
            -t|--package-cache-path)
                shift
                archInstall_package_cache_path="$1"
                shift
                ;;

            '')
                shift || \
                    true
                break
                ;;
            *)
                logging.critical "Given argument: \"$1\" is not available."
                archInstall.print_help_message "$0"
                return 1
        esac
    done
    if [[ "$UID" != 0 ]] && ! (
        hash fakeroot 2>/dev/null && \
        hash fakechroot 2>/dev/null && \
        ([ -e "$archInstall_output_system" ] && \
        [ -d "$archInstall_output_system" ]))
    then
        bl.logging.critical \
            "You have to run this script as \"root\" not as \"${USER}\". You can alternatively install \"fakeroot\", \"fakechroot\" and install into a directory."
        exit 2
    fi
    if bl.tools.is_main; then
        if [ "$archInstall_host_name" = '' ]; then
            while true; do
                bl.logging.plain -n 'Please set hostname for new system: '
                read -r archInstall_host_name
                if [[ "$(
                    echo "$archInstall_host_name" | \
                        tr '[:upper:]' '[:lower:]'
                )" != '' ]]; then
                    break
                fi
            done
        fi
    fi
    return 0
}
## endregion
## region helper
### region change root functions
alias archInstall.changeroot=archInstall_changeroot
archInstall_changeroot() {
    local __documentation__='
        This function emulates the arch linux native "arch-chroot" function.
    '
    if ! $archInstall_prevent_using_native_arch_changeroot && \
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
alias archInstall.changeroot_to_mountpoint=archInstall_changeroot_to_mountpoint
archInstall_changeroot_to_mountpoint() {
    local __documentation__='
        This function performs a changeroot to currently set mountpoint path.
    '
    archInstall.changeroot "$archInstall_mountpoint_path" "$@"
    return $?
}
### endregion
alias archInstall.add_boot_entries=archInstall_add_boot_entries
archInstall_add_boot_entries() {
    local __documentation__='
        Creates an uefi boot entry.
    '
    if hash efibootmgr 2>/dev/null; then
        bl.logging.info Configure efi boot manager.
        cat << EOF \
            1>"${archInstall_mountpoint_path}/boot/startup.nsh"
\\vmlinuz-linux initrd=\\initramfs-linux.img root=PARTLABEL=${archInstall_system_partition_label} rw rootflags=subvol=root quiet loglevel=2 acpi_osi="!Windows 2012"
EOF
        archInstall.changeroot_to_mountpoint \
            efibootmgr \
            --create \
            --disk "$archInstall_output_system" \
            -l '\vmlinuz-linux' \
            --label "$archInstall_fallback_boot_entry_label" \
            --part 1 \
            --unicode \
            "initrd=\\initramfs-linux-fallback.img root=PARTLABEL=${archInstall_system_partition_label} rw rootflags=subvol=root break=premount break=postmount acpi_osi=\"!Windows 2012\"" || \
                bl.logging.warn \
                    "Adding boot entry \"${archInstall_fallback_boot_entry_label}\" failed."
        # NOTE: Boot entry to boot on next reboot should be added at last.
        archInstall.changeroot_to_mountpoint \
            efibootmgr \
            --create \
            --disk "$archInstall_output_system" \
            -l '\vmlinuz-linux' \
            --label "$archInstall_boot_entry_label" \
            --part 1 \
            --unicode \
            "initrd=\\initramfs-linux.img root=PARTLABEL=${archInstall_system_partition_label} rw rootflags=subvol=root quiet loglevel=2 acpi_osi=\"!Windows 2012\"" || \
                bl.logging.warn \
                    "Adding boot entry \"${archInstall_boot_entry_label}\" failed."
    else
        bl.logging.warn \
            "\"efibootmgr\" doesn't seem to be installed. Creating a boot entry failed."
    fi
}
alias archInstall.append_temporary_install_mirrors=archInstall_append_temporary_install_mirrors
archInstall_append_temporary_install_mirrors() {
    local __documentation__='
        Appends temporary used mirrors to download missing packages during
        installation.
    '
    local url
    for url in $1; do
        echo "Server = $url/\$repo/os/\$arch" \
            1>>"${archInstall_mountpoint_path}etc/pacman.d/mirrorlist"
    done
}
alias archInstall.cache=archInstall_cache
archInstall_cache() {
    local __documentation__='
        Cache previous downloaded packages and database.
    '
    bl.logging.info Cache loaded packages.
    cp \
        --force \
        --preserve \
        "${archInstall_mountpoint_path}var/cache/pacman/pkg/"*.pkg.tar.xz \
        "${archInstall_package_cache_path}/"
    bl.logging.info Cache loaded databases.
    cp \
        --force \
        --preserve \
        "${archInstall_mountpoint_path}var/lib/pacman/sync/"*.db \
        "${archInstall_package_cache_path}/"
    return $?
}
alias archInstall.enable_services=archInstall_enable_services
archInstall_enable_services() {
    local __documentation__='
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
            local service_name=dhcpcd
            local connection=ethernet
            local description='A basic dhcp connection'
            local additional_properties=''
            if [ "${network_device_name:0:1}" = e ]; then
                bl.logging.info \
                    "Enable dhcp service on wired network device \"$network_device_name\"."
                service_name=netctl-ifplugd
                connection=ethernet
                description='A basic ethernet dhcp connection'
            elif [ "${network_device_name:0:1}" = w ]; then
                bl.logging.info \
                    "Enable dhcp service on wireless network device \"$network_device_name\"."
                service_name=netctl-auto
                connection=wireless
                description='A simple WPA encrypted wireless connection'
                additional_properties=$'\nSecurity=wpa\nESSID='"'home'"$'\nKey='"'home'"
            fi
        cat << EOF 1>"${archInstall_mountpoint_path}etc/netctl/${network_device_name}-dhcp"
Description='${description}'
Interface=${network_device_name}
Connection=${connection}
IP=dhcp
## for DHCPv6
#IP6=dhcp
## for IPv6 autoconfiguration
#IP6=stateless${additional_properties}
EOF
            ln \
                --force \
                --symbolic \
                "/usr/lib/systemd/system/${service-name}@.service" \
                "${archInstall_mountpoint_path}etc/systemd/system/multi-user.target.wants/${service_name}@${network_device_name}.service"
        fi
    done
    local service_name
    for service_name in "${archInstall_needed_services[@]}"; do
        bl.logging.info "Enable \"$service_name\" service."
        archInstall.changeroot_to_mountpoint \
            systemctl \
            enable \
            "${service_name}.service"
    done
}
alias archInstall.get_hosts_content=archInstall_get_hosts_content
archInstall_get_hosts_content() {
    local __documentation__='
        Provides the file content for the "/etc/hosts".
    '
    cat << EOF
#<IP-Adress> <computername.workgroup> <computernames>
127.0.0.1    localhost.localdomain    localhost $1
::1          ipv6-localhost           ipv6-localhost ipv6-$1
EOF
}
# NOTE: Depends on "archInstall.get_hosts_content", "archInstall.enable_services"
alias archInstall.configure=archInstall_configure
archInstall_configure() {
    local __documentation__='
        Provides generic linux configuration mechanism. If new systemd programs
        are used (if first argument is "true") they could have problems in
        change root environment without and exclusive dbus connection.
    '
    bl.logging.info \
        "Make keyboard layout permanent to \"${archInstall_keyboard_layout}\"."
    if [ "$1" = true ]; then
        archInstall.changeroot_to_mountpoint \
            localectl \
            set-keymap "$archInstall_keyboard_layout"
        archInstall.changeroot_to_mountpoint \
            localectl \
            set-locale LANG=en_US.utf8
        archInstall.changeroot_to_mountpoint \
            locale-gen \
            set-keymap "$archInstall_keyboard_layout"
    else
        echo -e "$archInstall_key_map_configuration_file_content" \
            1>"${archInstall_mountpoint_path}etc/vconsole.conf"
    fi
    bl.logging.info "Set localtime \"$_LOCAL_TIME\"."
    if [ "$1" = true ]; then
        archInstall.changeroot_to_mountpoint \
            timedatectl \
            set-timezone "$archInstall_local_time"
    else
        ln \
            --symbolic \
            --force "/usr/share/zoneinfo/${archInstall_local_time}" \
            "${archInstall_mountpoint_path}etc/localtime"
    fi
    bl.logging.info "Set hostname to \"$archInstall_host_name\"."
    if [ "$1" = true ]; then
        archInstall.changeroot_to_mountpoint \
            hostnamectl \
            set-hostname "$archInstall_host_name"
    else
        echo "$archInstall_host_name" \
            1>"${archInstall_mountpoint_path}etc/hostname"
    fi
    bl.logging.info Set hosts.
    archInstall.get_hosts_content "$archInstall_host_name" \
        1>"${archInstall_mountpoint_path}etc/hosts"
    if [[ "$1" != true ]]; then
        bl.logging.info "Set root password to \"root\"."
        archInstall.changeroot_to_mountpoint \
            /usr/bin/env bash -c 'echo root:root | $(which chpasswd)'
    fi
    bl.exception.try
        archInstall.enable_services
    bl.exception.catch_single
        bl.logging.warn Enabling services has failed.
    local user_name
    for user_name in "${archInstall_user_names[@]}"; do
        bl.logging.info "Add user: \"$user_name\"."
        # NOTE: We could only create a home directory with right rights if we
        # are root.
        bl.exception.try
            archInstall.changeroot_to_mountpoint \
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
        archInstall.changeroot_to_mountpoint \
            /usr/bin/env bash -c \
                "echo ${user_name}:${user_name} | \$(which chpasswd)"
    done
    return $?
}
alias archInstall.configure_pacman=archInstall_configure_pacman
archInstall_configure_pacman() {
    local __documentation__='
        Disables signature checking for incoming packages.
    '
    bl.logging.info "Enable mirrors in \"$archInstall_country_with_mirrors\"."
    local buffer_file="$(mktemp --suffix -archInstall-processed-mirrorlist)"
    bl.exception.try
    {
        local in_area=false
        local line_number=0
        local line
        while read -r line; do
            line_number="$((line_number + 1))"
            if [ "$line" = "## $archInstall_country_with_mirrors" ]; then
                in_area=true
            elif [ "$line" = '' ]; then
                in_area=false
            elif $in_area && [ "${line:0:1}" = '#' ]; then
                line="${line:1}"
            fi
            echo "$line"
        done < "${archInstall_mountpoint_path}etc/pacman.d/mirrorlist" \
            1>"$buffer_file"
        cat "$buffer_file" \
            1>"${archInstall_mountpoint_path}etc/pacman.d/mirrorlist"
    }
    bl.exception.catch_single
    {
        rm --force "$buffer_file"
        bl.logging.error_exception "$bl_exception_last_traceback"
    }
    rm --force "$buffer_file"
    bl.logging.info "Change signature level to \"Never\" for pacman's packages."
    command sed \
        --in-place \
        --regexp-extended \
        's/^(SigLevel *= *).+$/\1Never/g' \
        "${archInstall_mountpoint_path}etc/pacman.conf"
}
alias archInstall.determine_auto_partitioning=archInstall_determine_auto_partitioning
archInstall_determine_auto_partitioning() {
    local __documentation__='
        Determine whether we should perform our auto partitioning mechanism.
    '
    if ! $archInstall_auto_partitioning; then
        while true; do
            bl.logging.plain -n Do you want auto partioning? [yes|NO]:
            local auto_partitioning
            read -r auto_partitioning
            if [ "$auto_partitioning" = '' ] || [ "$(
                echo "$auto_partitioning" | \
                    tr '[:upper:]' '[:lower:]'
            )" = no ]; then
                archInstall_auto_partitioning=false
                break
            elif [ "$(
                echo "$auto_partitioning" | \
                    tr '[:upper:]' '[:lower:]'
            )" = yes ]; then
                archInstall_auto_partitioning=true
                break
            fi
        done
    fi
}
alias archInstall.create_url_lists=archInstall_create_url_lists
archInstall_create_url_lists() {
    local __documentation__='
        Generates all web urls for needed packages.
    '
    local temporary_return_code=0
    local return_code=0
    bl.logging.info Downloading latest mirror list.
    local url_list=()
    local url
    for url in "${archInstall_package_source_urls[@]}"; do
        bl.logging.info "Retrieve repository source url list from \"$url\"."
        mapfile -t url_list <<<$(
            wget \
                "$url" \
                --output-document - | \
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
        ) && break
    done
    local package_source_urls=(
        "${url_list[@]}" "${archInstall_package_urls[@]}")
    local package_urls=()
    local name
    for name in core community extra; do
        for url in "${archInstall_package_urls[@]}"; do
            bl.logging.info "Retrieve repository \"$name\" from \"$url\"."
            mapfile -t url_list <<<$(
                wget \
                    --timeout 5 \
                    --tries 1 \
                    --output-document - \
                    "${url}/$name/os/$archInstall_cpu_architecture" | \
                        command sed \
                            --quiet \
                            "s>.*href=\"\\([^\"]*.\\(tar.xz\\|db\\)\\).*>${url}/$name/os/$archInstall_cpu_architecture/\\1>p" | \
                                command sed 's:/./:/:g' | \
                                    sort --unique
            ) && break
        done
        # NOTE: "return_code" remains with an error code if there was given one
        # in any iteration.
        (( temporary_return_code != 0 )) && \
            return_code=$temporary_return_code
        package_urls+=("${url_list[@]}")
    done
    echo "${package_source_urls[@]}"
    echo "${package_urls[@]}"
    return $return_code
}
alias archInstall.determine_package_dependencies=archInstall_determine_package_dependencies
archInstall_determine_package_dependencies() {
    local __documentation__='
        Determines all package dependencies. Returns a list of needed packages
        for given package determined by given database.
        NOTE: We append and prepend always a whitespace to simply identify
        duplicates without using extended regular expression and package name
        escaping.

        TODO
        #>>> archInstall.determine_package_dependencies glibc
        libnghttp2
    '
    local package_description_file_path
    if package_description_file_path="$(
        archInstall.determine_package_description_file_path "$@"
    )"; then
        # NOTE: We do not simple print "$1" because given (providing) names
        # do not have to corresponding package name.
        echo "$(
            echo "$package_description_file_path" | \
                sed --regexp-extended 's:^.*/([^/]+)-[0-9]+[^/]*/desc$:\1:' | \
                    sed --regexp-extended 's/(-[0-9]+.*)+$//'
        )"
        local package_dependency_description
        command grep \
            --null-data \
            --only-matching \
            --perl-regexp \
            '%DEPENDS%(\n.+)+(\n|$)' < "$package_description_file_path" | \
                command sed '/%DEPENDS%/d' | \
                    while IFS='' read -r package_dependency_description
        do
            local package_name="$(
                echo "$package_dependency_description" | \
                    command grep \
                        --extended-regexp \
                        --only-matching \
                        '^[a-zA-Z0-9][-a-zA-Z0-9.]+' | \
                            sed --regexp-extended 's/^(.+)[><=].+$/\1/'
            )"
            archInstall.determine_package_dependencies \
                "$package_name" \
                "$2" || \
                    bl.logging.warn \
                        "Needed package \"$package_name\" for \"$1\" couldn't be found in database in \"$2\"."
        done
    else
        return 1
    fi
    return 0
}
alias archInstall.determine_package_description_file_path=archInstall_determine_package_description_file_path
archInstall.determine_package_description_file_path() {
    local __documentation__='
        Determines the package directory name from given package name in given
        database folder.
    '
    local package_name="$1"
    local database_directory_path="$2"
    local package_description_file_path="$(
        command grep \
            "%PROVIDES%\n(.+\n)*$package_name\n(.+\n)*\n" \
            --files-with-matches \
            --null-data \
            --perl-regexp \
            --recursive \
            "$database_directory_path"
    )"
    if [ "$package_description_file_path" = '' ]; then
        local regular_expression
        for regular_expression in \
            "^\(.*/\)?$package_name"'$' \
            "^\(.*/\)?$package_name"'-[0-9]+[0-9.\-]*$' \
            "^\(.*/\)?$package_name"'-[0-9]+[0-9.a-zA-Z-]*$' \
            "^\(.*/\)?$package_name"'-git-[0-9]+[0-9.a-zA-Z-]*$' \
            "^\(.*/\)?$package_name"'[0-9]+-[0-9.a-zA-Z-]+\(-[0-9.a-zA-Z-]\)*$' \
            "^\(.*/\)?[0-9]+$package_name"'[0-9]+-[0-9a-zA-Z\.]+\(-[0-9a-zA-Z\.]\)*$' \
            "^\(.*/\)?$package_name"'-.+$' \
            "^\(.*/\)?.+-$package_name"'-.+$' \
            "^\(.*/\)?$package_name"'.+$' \
            "^\(.*/\)?$package_name"'.*$' \
            "^\(.*/\)?.*$package_name"'.*$'
        do
            package_description_file_path="$(
                command find \
                    "$database_directory_path" \
                    -maxdepth 1 \
                    -regex "$regular_expression"
            )"
            if [[ "$package_description_file_path" != '' ]]; then
                local number_of_results="$(
                    echo "$package_description_file_path" | wc --words)"
                if (( number_of_results > 1 )); then
                    # NOTE: We want to use newer package if their are two
                    # candidates.
                    local description_file_path
                    local highest_raw_version=0
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
alias archInstall.determine_pacmans_needed_packages=archInstall_determine_pacmans_needed_packages
archInstall_determine_pacmans_needed_packages() {
    local __documentation__='
        Reads pacmans database and determine pacmans dependencies.
    '
    local core_database_url="$(
        echo "$1" | \
            command grep \
                --only-matching \
                --extended-regexp \
                ' [^ ]+core\.db ' | \
                    sed --regexp-extended 's/(^ *)|( *$)//g')"
    wget \
        "$core_database_url" \
        --directory-prefix "${archInstall_package_cache_path}/" \
        --timestamping
    if [ -f "${archInstall_package_cache_path}/core.db" ]; then
        local database_directory_path="$(
            mktemp --directory --suffix -archInstall-core-database)"
        bl.exception.try
        {
            local packages=()
            tar \
                --directory "$database_directory_path" \
                --extract \
                --file "${archInstall_package_cache_path}/core.db" \
                --gzip
            local package_name
            for package_name in "${archInstall_needed_packages[@]}"; do
                local needed_packages
                mapfile -t needed_packages <<<"$(
                    archInstall.determine_package_dependencies \
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
            bl.logging.error_exception "$bl_exception_last_traceback"
        }
        return 0
    fi
    bl.logging.critical \
        "No database file (\"${archInstall_package_cache_path}/core.db\") could be found."
    return 1
}
alias archInstall.download_and_extract_pacman=archInstall_download_and_extract_pacman
archInstall_download_and_extract_pacman() {
    local __documentation__='
        Downloads all packages from arch linux needed to run pacman.
    '
    local needed_packages=()
    if IFS=' ' read -r -a needed_packages <<< "$(
        archInstall.determine_pacmans_needed_packages "$1"
    )"; then
        bl.logging.info "Needed packages are: \"$(
            echo "${needed_packages[@]}" | \
                command sed 's/ /", "/g'
        )\"."
        bl.logging.info \
            "Download and extract each package into our new system located in \"$archInstall_mountpoint_path\"."
        local package_name
        for package_name in "${needed_packages[@]}"; do
            local package_url="$(
                echo "${1}" | \
                    tr ' ' '\n' | \
                        command grep "/${package_name}-[0-9]")"
            local number_of_results="$(echo "$package_url" | wc --words)"
            if (( number_of_results > 1 )); then
                # NOTE: We want to use newer package if their are two results.
                local url
                local highest_raw_version=0
                for url in $package_url; do
                    local raw_version="$(bl.number.normalize_version "$url")"
                    if (( raw_version > highest_raw_version )); then
                        package_url="$url"
                        highest_raw_version=$raw_version
                    fi
                done
            fi
            local file_name="$(
                echo "$package_url" | \
                    command sed 's/.*\/\([^\/][^\/]*\)$/\1/')"
            # NOTE: We have to decode given url.
            file_name="$(printf '%b' "${file_name//%/\\x}")"
            # If "file_name" couldn't be determined via server determine it via
            # current package cache.
            if [ "$file_name" = '' ]; then
                file_name="$(
                    command find \
                        "$archInstall_package_cache_path" \
                        -maxdepth 1 \
                        -regex "$package_name-[0-9]" | \
                            head --lines 1)"
            fi
            if ! (
                [ "$file_name" = '' ] || \
                wget \
                    "$package_url" \
                    --continue \
                    --directory-prefix "${archInstall_package_cache_path}/" \
                    --timestamping || \
                [ -f "${archInstall_package_cache_path}${file_name}" ]
            ); then
                bl.logging.error_exception \
                    "A suitable file for package \"$package_name\" could not be determined."
            fi
            bl.logging.info "Install package \"$file_name\" manually."
            xz \
                --decompress \
                --to-stdout \
                "$archInstall_package_cache_path/$file_name" | \
                    tar \
                        --directory "$archInstall_mountpoint_path" \
                        --extract || \
                            return $?
        done
    else
        return 1
    fi
}
alias archInstall.format_boot_partition=archInstall_format_boot_partition
archInstall_format_boot_partition() {
    local __documentation__='
        Prepares the boot partition.
    '
    bl.logging.info Make boot partition.
    mkfs.vfat \
        -F 32 \
        "${archInstall_output_system}1"
    if hash dosfslabel 2>/dev/null; then
        dosfslabel \
            "${archInstall_output_system}1" \
            "$archInstall_boot_partition_label"
    else
        bl.logging.warn \
            "\"dosfslabel\" doesn't seem to be installed. Creating a boot partition label failed."
    fi
}
alias archInstall.format_partitions=archInstall_format_partitions
archInstall_format_partitions() {
    local __documentation__='
        Performs formating part.
    '
    archInstall.format_system_partition
    archInstall.format_boot_partition
}
alias archInstall.format_system_partition=archInstall_format_system_partition
archInstall_format_system_partition() {
    local __documentation__='
        Prepares the system partition.
    '
    local output_device="$archInstall_output_system"
    if [ -b "${archInstall_output_system}2" ]; then
        output_device="${archInstall_output_system}2"
    fi
    bl.logging.info "Make system partition at \"$output_device\"."
    mkfs.btrfs \
        --force \
        --label "$archInstall_system_partition_label" \
        "$output_device"
    bl.logging.info "Creating a root sub volume in \"$output_device\"."
    mount \
        PARTLABEL="$archInstall_system_partition_label" \
        "$archInstall_mountpoint_path"
    btrfs subvolume create "${archInstall_mountpoint_path}root"
    umount "$archInstall_mountpoint_path"
}
alias archInstall.generate_fstab_configuration_file=archInstall_generate_fstab_configuration_file
archInstall_generate_fstab_configuration_file() {
    local __documentation__='
        Writes the fstab configuration file.
    '
    bl.logging.info Generate fstab config.
    if hash genfstab 2>/dev/null; then
        # NOTE: Mountpoint shouldn't have a path separator at the end.
        genfstab \
            -L \
            -p "${archInstall_mountpoint_path%?}" \
            1>>"${archInstall_mountpoint_path}etc/fstab"
    else
        cat << EOF 1>>"${archInstall_mountpoint_path}etc/fstab"
# Added during installation.
# <file system>                    <mount point> <type> <options>                                                                                            <dump> <pass>
# "compress=lzo" has lower compression ratio by better cpu performance.
PARTLABEL=$archInstall_system_partition_label /             btrfs  relatime,ssd,discard,space_cache,autodefrag,inode_cache,subvol=root,compress=zlib                    0      0
PARTLABEL=$archInstall_boot_partition_label   /boot/        vfat   rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro 0      0
EOF
    fi
}
alias archInstall.load_cache=archInstall_load_cache
archInstall_load_cache() {
    local __documentation__='
        Load previous downloaded packages and database.
    '
    bl.logging.info Load cached databases.
    mkdir --parents "${archInstall_mountpoint_path}var/lib/pacman/sync"
    cp \
        --no-clobber \
        --preserve \
        "$archInstall_package_cache_path"/*.db \
        "${archInstall_mountpoint_path}var/lib/pacman/sync/" \
            2>/dev/null
    bl.logging.info Load cached packages.
    mkdir \
        --parents \
        "${archInstall_mountpoint_path}var/cache/pacman/pkg"
    cp \
        --no-clobber \
        --preserve \
        "$archInstall_package_cache_path"/*.pkg.tar.xz \
        "${archInstall_mountpoint_path}var/cache/pacman/pkg/" \
            2>/dev/null
}
alias archInstall.make_partitions=archInstall_make_partitions
archInstall_make_partitions() {
    local __documentation__='
        Performs the auto partitioning.
    '
    if $archInstall_auto_partitioning; then
        bl.logging.info Check block device size.
        local blockdevice_space_in_mega_byte="$(("$(
            blockdev --getsize64 "$archInstall_output_system"
        )" * 1024 ** 2))"
        if [[ $((
            archInstall_needed_system_space_in_mega_byte + \
            archInstall_boot_space_in_mega_byte
        )) -le $blockdevice_space_in_mega_byte ]]; then
            bl.logging.info Create boot and system partitions.
            gdisk "$archInstall_output_system" << EOF \
o
Y
n


${archInstall_boot_space_in_mega_byte}M
ef00
n




c
1
$archInstall_boot_partition_label
c
2
$archInstall_system_partition_label
w
Y
EOF
            # NOTE: "gdisk" returns an error code even if it runs successfully.
            true
        else
            bl.logging.critical \
                "Not enough space on \"$archInstall_output_system\" (\"$blockdevice_space_in_mega_byte\" megabyte). We need at least \"$((archInstall_needed_system_space_in_mega_byte + archInstall_boot_space_in_mega_byte))\" megabyte."

        fi
    else
        bl.logging.info \
            "At least you have to create two partitions. The first one will be used as boot partition labeled to \"${archInstall_boot_partition_label}\" and second one will be used as system partition and labeled to \"${archInstall_system_partition_label}\". Press Enter to continue."
        read -r
        bl.logging.info Show blockdevices. Press Enter to continue.
        lsblk
        read -r
        bl.logging.info Create partitions manually.
        gdisk "$archInstall_output_system"
    fi
}
alias archInstall.pack_result=archInstall_pack_result
archInstall_pack_result() {
    local __documentation__='
        Packs the resulting system to provide files owned by root without
        root permissions.
    '
    if (( UID != 0 )); then
        bl.logging.info \
            "System will be packed into \"$archInstall_mountpoint_path.tar\" to provide root owned files. You have to extract this archiv as root."
        tar \
            cvf \
            "${archInstall_mountpoint_path}.tar" \
            "$archInstall_mountpoint_path" \
            --owner root \
        rm \
            "$archInstall_mountpoint_path"* \
            --force \
            --recursive
        return $?
    fi
}
alias archInstall.prepare_blockdevices=archInstall_prepare_blockdevices
archInstall_prepare_blockdevices() {
    local __documentation__='
        Prepares given block devices to make it ready for fresh installation.
    '
    bl.logging.info \
        "Unmount needed devices and devices pointing to our temporary system mount point \"$archInstall_mountpoint_path\"."
    umount -f "${archInstall_output_system}"* 2>/dev/null
    umount -f "$archInstall_mountpoint_path" 2>/dev/null
    swapoff "${archInstall_output_system}"* 2>/dev/null
    bl.logging.info Make partitions. Make a boot and system partition.
    archInstall.make_partitions
    bl.logging.info Format partitions.
    archInstall.format_partitions
}
alias archInstall.prepare_installation=archInstall_prepare_installation
archInstall_prepare_installation() {
    local __documentation__='
        Deletes previous installed things in given output target. And creates a
        package cache directory.
    '
    mkdir --parents "$archInstall_package_cache_path"
    if [ -b "$archInstall_output_system" ]; then
        bl.logging.info Mount system partition.
        mount \
            PARTLABEL="$archInstall_system_partition_label" \
            -o subvol=root \
            "$archInstall_mountpoint_path"
    fi
    bl.logging.info \
        "Clear previous installations in \"$archInstall_mountpoint_path\"."
    rm "$archInstall_mountpoint_path"* --force --recursive
    if [ -b "$archInstall_output_system" ]; then
        bl.logging.info \
            "Mount boot partition in \"${archInstall_mountpoint_path}boot/\"."
        mkdir --parents "${archInstall_mountpoint_path}boot/"
        mount \
            PARTLABEL="$archInstall_boot_partition_label" \
            "${archInstall_mountpoint_path}boot/"
        rm "${archInstall_mountpoint_path}boot/"* --force --recursive
    fi
    bl.logging.info Set filesystem rights.
    chmod 755 "$archInstall_mountpoint_path"
    # Make an unique array.
    read -r -a archInstall_packages <<< "$(
        bl.array.unique "${archInstall_packages[@]}")"
}
alias archInstall.prepare_next_boot=archInstall_prepare_next_boot
archInstall_prepare_next_boot() {
    local __documentation__='
        Reboots into fresh installed system if previous defined.
    '
    if [ -b "$archInstall_output_system" ]; then
        archInstall.generate_fstab_configuration_file
        archInstall.add_boot_entries
        archInstall.unmount_installed_system
        if $archInstall_automatic_reboot; then
            bl.logging.info Reboot into new operating system.
            systemctl reboot &>/dev/null || reboot
        fi
    fi
}
alias archInstall.tidy_up_system=archInstall_tidy_up_system
archInstall_tidy_up_system() {
    local __documentation__='
        Deletes some unneeded locations in new installs operating system.
    '
    bl.logging.info Tidy up new build system.
    local file_path
    for file_path in "${archInstall_unneeded_file_locations[@]}"; do
        bl.logging.info \
            "Deleting \"${archInstall_mountpoint_path}${file_path}\"."
        rm \
            "${archInstall_mountpoint_path}$file_path" \
            --force \
            --recursive
    done
}
alias archInstall.unmount_installed_system=archInstall_unmount_installed_system
archInstall_unmount_installed_system() {
    local __documentation__='
        Unmount previous installed system.
    '
    bl.logging.info Unmount installed system.
    sync
    cd / && \
    umount "${archInstall_mountpoint_path}/boot"
    umount "$archInstall_mountpoint_path"
}
## endregion
## region install arch linux steps.
alias archInstall.make_pacman_portable=archInstall_make_pacman_portable
archInstall_make_pacman_portable() {
    local __documentation__='
        Disables signature checks and registers temporary download mirrors.
    '
    # Copy systems resolv.conf to new installed system. If the native
    # "arch-chroot" is used it will mount the file into the change root
    # environment.
    cp /etc/resolv.conf "${archInstall_mountpoint_path}etc/"
    if \
        ! "$archInstall_prevent_using_native_arch_changeroot" && \
        hash arch-chroot 2>/dev/null
    then
        mv \
            "${archInstall_mountpoint_path}etc/resolv.conf" \
            "${archInstall_mountpoint_path}etc/resolv.conf.old" \
                2>/dev/null
    fi
    command sed \
        --in-place \
        --quiet \
        '/^[ \t]*CheckSpace/ !p' \
        "${archInstall_mountpoint_path}etc/pacman.conf"
    command sed \
        --in-place \
        --regexp-extended \
        's/^[ \t]*(((Local|Remote)?File)?SigLevel)[ \t].*/\1 = Never TrustAll/g' \
        "${archInstall_mountpoint_path}etc/pacman.conf"
    bl.logging.info Register temporary mirrors to download new packages.
    if [ "$1" = '' ]; then
        cp \
            /etc/pacman.d/mirrorlist \
            "${archInstall_mountpoint_path}etc/pacman.d/mirrorlist"
    else
        bl.logging.plain TODO "$1"
        archInstall.append_temporary_install_mirrors "$1"
    fi
}
# NOTE: Depends on "archInstall.make_pacman_portable"
alias archInstall.generic_linux_steps=archInstall_generic_linux_steps
archInstall_generic_linux_steps() {
    local __documentation__='
        This functions performs creating an arch linux system from any linux
        system base.
    '
    local return_code=0
    bl.logging.info Create a list with urls for existing packages.
    local url_lists
    mapfile -t url_lists <<<"$(archInstall.create_url_lists)"
    archInstall.download_and_extract_pacman "${url_lists[1]}"
    archInstall.make_pacman_portable "${url_lists[0]}"
    bl.exception.try
        archInstall.load_cache
    bl.exception.catch_single
        bl.logging.info No package cache was loaded.
    bl.logging.info Initialize keys.
    bl.exception.try
    {
        archInstall.changeroot_to_mountpoint /usr/bin/pacman-key --init
        archInstall.changeroot_to_mountpoint /usr/bin/pacman-key --refresh-keys
    }
    bl.exception.catch_single
        bl.logging.warn Creating keys was not successful.
    bl.logging.info Update package databases.
    bl.exception.try
        archInstall.changeroot_to_mountpoint \
            /usr/bin/pacman \
            --arch "$archInstall_cpu_architecture" \
            --refresh \
            --sync
    bl.exception.catch_single
        bl.logging.info Updating package database failed. Operating offline.
    bl.logging.info "Install needed packages \"$(
        echo "${archInstall_packages[@]}" | \
            command sed 's/ /", "/g'
    )\" to \"$archInstall_output_system\"."
    archInstall.changeroot_to_mountpoint \
        /usr/bin/pacman \
        --arch "$archInstall_cpu_architecture" \
        --force \
        --sync \
        --needed \
        --noconfirm \
        "${archInstall_packages[@]}"
    return_code=$?
    bl.exception.try
        archInstall.cache
    bl.exception.catch_single
        bl.logging.warn \
            Caching current downloaded packages and generated database \
            failed.
    (( return_code == 0 )) && \
        archInstall.configure_pacman
    return $return_code
}
alias archInstall.with_existing_pacman=archInstall_with_existing_pacman
archInstall_with_existing_pacman() {
    local __documentation__='
        Installs arch linux via patched (to be able to operate offline)
        pacstrap of pacman directly.
    '
    local return_code=0
    archInstall.load_cache
    if hash pacstrap &>/dev/null; then
        bl.logging.info Patch pacstrap to handle offline installations.
        command sed \
            --regexp-extended \
            's/(pacman.+-(S|-sync))(y|--refresh)/\1/g' \
                <"$(command -v pacstrap)" \
                1>"${archInstall_package_cache_path}/patchedOfflinePacstrap.sh"
        chmod +x "${archInstall_package_cache_path}/patchedOfflinePacstrap.sh"
    fi
    bl.logging.info Update package databases.
    pacman \
        --arch "$archInstall_cpu_architecture" \
        --refresh \
        --root "$archInstall_mountpoint_path" \
        --sync || \
            bl.logging.info \
                Updating package database failed. Operating offline.
    bl.logging.info "Install needed packages \"$(
        echo "${archInstall_packages[@]}" | \
            command sed 's/ /", "/g'
    )\" to \"$archInstall_output_system\"."
    if [ -f "${archInstall_package_cache_path}/patchedOfflinePacstrap.sh" ]
    then
        "${archInstall_package_cache_path}/patchedOfflinePacstrap.sh" \
            -d "$archInstall_mountpoint_path" \
            "${archInstall_packages[@]}" \
            --force
        return_code=$?
        rm "${archInstall_package_cache_path}/patchedOfflinePacstrap.sh"
    else
        pacman \
            --force \
            --root "$archInstall_mountpoint_path" \
            --sync \
            --noconfirm \
            filesystem \
            pacman
        archInstall.make_pacman_portable
        archInstall.changeroot_to_mountpoint \
            /usr/bin/pacman \
            --arch "$archInstall_cpu_architecture" \
            --force \
            --sync \
            --needed \
            --noconfirm \
            "${archInstall_packages[@]}"
        return_code=$?
    fi
    archInstall.cache || \
        bl.logging.warn \
            Caching current downloaded packages and generated database failed.
    return $return_code
}
## endregion
## region controller
alias archInstall.main=archInstall_main
archInstall_main() {
    local __documentation__='
        Provides the main module scope.

        >>> archInstall.main --help
        +bl.doctest.multiline_ellipsis
        ...
        Usage: arch-install [options]
        ...
    '
    bl.exception.activate
    archInstall.commandline_interface "$@"
    archInstall_packages+=(
        "${archInstall_basic_packages[@]}"
        "${archInstall_additional_packages[@]}"
    )
    if $archInstall_add_common_additional_packages; then
        archInstall_packages+=("${archInstall_common_additional_packages[@]}")
    fi
    if [ ! -e "$archInstall_output_system" ]; then
        mkdir --parents "$archInstall_output_system"
    fi
    if [ -d "$archInstall_output_system" ]; then
        archInstall_mountpoint_path="$archInstall_output_system"
        if [[ ! "$archInstall_mountpoint_path" =~ .*/$ ]]; then
            archInstall_mountpoint_path+=/
        fi
    elif [ -b "$archInstall_output_system" ]; then
        archInstall_packages+=(efibootmgr)
        if echo "$archInstall_output_system" | \
            command grep --quiet --extended-regexp '[0-9]$'
        then
            archInstall.format_system_partition
        else
            archInstall.determine_auto_partitioning
            archInstall.prepare_blockdevices
        fi
    else
        bl.logging.error_exception \
            "Could not install into \"$archInstall_output_system\"."
    fi
    archInstall.prepare_installation
    if (( UID == 0 )) && ! $archInstall_prevent_using_existing_pacman && \
        hash pacman 2>/dev/null
    then
        archInstall.with_existing_pacman
    else
        archInstall.generic_linux_steps
    fi
    archInstall.tidy_up_system
    archInstall.configure
    archInstall.prepare_next_boot
    archInstall.pack_result
    bl.logging.info \
        "Generating operating system into \"$archInstall_output_system\" has successfully finished."
    bl.exception.deactivate
}
## endregion
# endregion
if bl.tools.is_main; then
    archInstall.main "$@"
    [ -d "$archInstall_bashlink_path" ] && \
        rm --recursive "$archInstall_bashlink_path"
    # shellcheck disable=SC2154
    [ -d "$bl_module_remote_module_cache_path" ] && \
        rm --recursive "$bl_module_remote_module_cache_path"
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
