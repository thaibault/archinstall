#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC1004,SC2016,SC2155
# region import
archInstall_bashlink_path="$(mktemp --directory)/bashlink/"
mkdir "$archInstall_bashlink_path"
wget \
    https://goo.gl/UKF5JG \
    --output-document "${archInstall_bashlink_path}module.sh" \
    --quiet
# shellcheck disable=SC2034
bl_module_retrieve_remote_modules=true
# shellcheck disable=SC1090
source "${archInstall_bashlink_path}/module.sh"
bl.module.import bashlink.changeroot
bl.module.import bashlink.logging
# endregion
# region variables
# shellcheck disable=SC2034
archinstall__documentation__='
    Start install progress command (Assuming internet is available):

    ```bash
        wget \
            http://torben.website/clientNode/data/distributionBundle/index.compiled.js \
            \ -O archInstall.sh && chmod +x archInstall.sh
    ```

    Note that you only get very necessary output until you provide "--verbose"
    as commandline option.
'
# shellcheck disable=SC2034
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
    sync
    touch
    tar
    uniq
    uname
    which
    wget
    xz
)
# shellcheck disable=SC2034
archinstall__optional_dependencies__=(
    # Dependencies for blockdevice integration
    'blockdev: Call block device ioctls from the command line (part of util-linux).'
    'btrfs: Control a btrfs filesystem (part of btrfs-progs).'
    'efibootmgr: Manipulate the EFI Boot Manager (part of efibootmgr).'
    'gdisk: Interactive GUID partition table (GPT) manipulator (part of gptfdisk).'
    # Needed for smart dos filesystem labeling, installing without root
    # permissions or automatic network configuration.
    'arch-chroot: Performs an arch chroot with api file system binding (part of arch-install-scripts).'
    'dosfslabel: Handle dos file systems (part of dosfstools).'
    'fakeroot: Run a command in an environment faking root privileges for file manipulation.'
    'fakechroot: Wraps some c-lib functions to enable programs like "chroot" running without root privileges.'
    'ip: Determines network adapter (part of iproute2).'
    'os-prober: Detects presence of other operating systems.'
)
archInstall_basic_packages=(base ifplugd)
archInstall_common_additional_packages=(base-devel python sudo)
# Defines where to mount temporary new filesystem.
# NOTE: Path has to be end with a system specified delimiter.
archInstall_mountpoint_path=/mnt/
# After determining dependencies a list like this will be stored:
# "pacman", "bash", "readline", "glibc", "libarchive", "acl", "attr", "bzip2",
# "expat", "lzo2", "openssl", "perl", "gdbm", "sh", "db", "gcc-libs", "xz",
# "zlib", "curl", "ca-certificates", "run-parts", "findutils", "coreutils",
# "pam", "cracklib", "libtirpc", "libgssglue", "pambase", "gmp", "libcap",
# "sed", "krb5", "e2fsprogs", "util-linux", "shadow", "libldap", "libsasl",
# "keyutils", "libssh2", "gpgme", "libgpg-error", "pth", "awk", "mpfr",
# "gnupg", "libksba", "libgcrypt", "libassuan", "pinentry", "ncurses",
# "dirmngr", "pacman-mirrorlist", "archlinux-keyring"
archInstall_needed_packages=(filesystem)
archInstall_packages=()
archInstall_package_source_urls=(
    https://mirror.de.leaseweb.net/archlinux
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
archInstall_prevent_using_pacstrap=false
archInstall_system_partition_label=system
archInstall_user_names=()
## endregion
# endregion
# region functions
## region command line interface
alias archInstall.print_usage_message=archInstall_print_usage_message
archInstall_print_usage_message() {
    # Prints a description about how to use this program.
cat << EOF
archInstall installs a linux from scratch by the arch way. You will end up in
ligtweigth linux with pacman as packetmanager.
You can directly install into a given blockdevice, partition or
any directory (see command line option "--output-system").
Note that every needed information which isn't given via command line
will be asked interactivly on start. This script is as unnatted it could
be, which means you can relax after providing all needed informations in
the beginning till your new system is ready to boot.
EOF
}
alias archInstall.print_usage_examples=archInstall.print_usage_examples
archInstall_print_usage_examples() {
    # Prints a description about how to use this program by providing examples.
    cat << EOF
# Start install progress command on first found blockdevice:
>>> $0 --output-system /dev/sda

# Install directly into a given partition with verbose output:
>>> $0 --output-system /dev/sda1 --verbose

# Install directly into a given directory with addtional packages included:
>>> $0 --output-system /dev/sda1 --verbose -f vim net-tools
EOF
}
alias archInstall.print_commandline_option_description=archInstall_print_commandline_option_description
archInstall_print_commandline_option_description() {
    # Prints descriptions about each available command line option.
    # NOTE; All letters are used for short options.
    # NOTE: "-k" and "--key-map-configuration" isn't needed in the future.
    cat << EOF
-h --help Shows this help message.

-v --verbose Tells you what is going on.

-d --debug Gives you any output from all tools which are used (default: "false").

-l --load-environment Simple load the install arch linux scope without doing anything else.


-u --user-names [USER_NAMES [USER_NAMES ...]], Defines user names for new system (default: "${archInstall_user_names[@]}").

-n --host-name HOST_NAME Defines name for new system (default: "$archInstall_host_name").


-c --cpu-architecture CPU_ARCHITECTURE Defines architecture (default: "$archInstall_cpu_architecture").

-o --output-system OUTPUT_SYSTEM Defines where to install new operating system. You can provide a full disk or patition via blockdevice such as "/dev/sda" or "/dev/sda1". You can also provide a diretory path such as "/tmp/lifesystem" (default: "$archInstall_output_system").


-x --local-time LOCAL_TIME Local time for you system (default: "$archInstall_local_time").

-b --keyboard-layout LAYOUT Defines needed keyboard layout (default: "$archInstall_keyboard_layout").

-k --key-map-configuration FILE_CONTENT Keyboard map configuration (default: "$archInstall_key_map_configuration_file_content").

-m --country-with-mirrors COUNTRY Country for enabling servers to get packages from (default: "$archInstall_country_with_mirrors").


-r --no-reboot Prevents to reboot after finishing installation.

-p --prevent-using-pacstrap Ignores presence of pacstrap to use it for install operating system (default: "$archInstall_prevent_using_pacstrap").

-y --prevent-using-native-arch-chroot Ignores presence of "arch-chroot" to use it for chroot into newly created operating system (default: "$archInstall_prevent_using_native_arch_changeroot").

-a --auto-paritioning Defines to do partitioning on founded block device automatic.


-e --boot-partition-label LABEL Partition label for uefi boot partition (default: "$archInstall_boot_partition_label").

-g --system-partition-label LABEL Partition label for system partition (default: "$archInstall_system_partition_label").


-i --boot-entry-label LABEL Boot entry label (default: "$archInstall_boot_entry_label").

-s --fallback-boot-entry-label LABEL Fallback boot entry label (default: "$archInstall_fallback_boot_entry_label").


-w --boot-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your boot partition (default: "$archInstall_boot_space_in_mega_byte MegaByte"). This partition is used for kernel and initramfs only.

-q --needed-system-space-in-mega-byte NUMBER In case if selected auto partitioning you can define the minimum space needed for your system partition (default: "$archInstall_needed_system_space_in_mega_byte MegaByte"). This partition is used for the whole operating system.


-z --install-common-additional-packages, (default: "$archInstall_add_common_additional_packages") If present the following packages will be installed: "${archInstall_common_additional_packages[*]}".

-f --additional-packages [PACKAGES [PACKAGES ...]], You can give a list with additional available packages (default: "${archInstall_additional_packages[@]}").

-j --needed-services [SERVICES [SERVICES ...]], You can give a list with additional available services (default: "${archInstall_needed_services[@]}").

-t --package-cache-path PATH Define where to load and save downloaded packages (default: "$archInstall_package_cache_path").
EOF
}
alias archInstall.print_help_message=archInstall_print_help_message
archInstall_print_help_message() {
    # Provides a help message for this module.
    bl.logging.plain $'\nUsage: '"$0"$' [options]\n'
    archInstall.print_usage_message "$@"
    bl.logging.plain $'\nExamples:\n'
    archInstall.print_usage_examples "$@"
    bl.logging.plain $'\nOption descriptions:\n'
    archInstall.print_commandline_option_description "$@"
    bl.logging.plain
}
alias archInstall.commandline_interface=archInstall_commandline_interface
archInstall_commandline_interface() {
    # Provides the command line interface and interactive questions.
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
                bl.logging.set_command_output_on
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
            -p|--prevent-using-pacstrap)
                shift
                archInstall_prevent_using_pacstrap=true
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
                shift
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
                echo -n 'Please set hostname for new system: '
                read -r archInstall_host_name
                if [[ "$(
                    echo "$archInstall_host_name" | tr '[:upper:]' '[:lower:]'
                )" != '' ]]; then
                    break
                fi
            done
        fi
    fi
    return 0
}
## endregion
## region install arch linux steps.
alias archInstall.with_pacstrap=archInstall_with_pacstrap
archInstall_with_pacstrap() {
    # Installs arch linux via pacstrap.
    local return_code=0
    archInstall.load_cache
    bl.logging.info Patch pacstrap to handle offline installations.
    command sed --regexp-extended \
        's/(pacman.+-(S|-sync))(y|--refresh)/\1/g' \
            <"$(which pacstrap)" \
            1>"${_PACKAGE_CACHE_PATH}/patchedOfflinePacman.sh"
    chmod +x "${_PACKAGE_CACHE_PATH}/patchedOfflinePacman.sh"
    bl.logging.info Update package databases.
    (
        pacman \
            --arch "$archInstall_cpu_architecture" \
            --refresh \
            --root "$archInstall_mountpoint_path" \
            --sync || \
                true
    )
    bl.logging.info \
        "Install needed packages \"$(echo "${archInstall_packages[@]}" | \
            command sed \
                --regexp-extended 's/(^ +| +$)//g' | \
                    command sed \
                        's/ /", "/g')\" to \"$archInstall_output_system\"."
    "${archInstall_package_cache_path}/patchedOfflinePacman.sh" \
        -d "$archInstall_mountpoint_path" "${archInstall_packages[@]}" \
        --force
    rm "${_PACKAGE_CACHE_PATH}/patchedOfflinePacman.sh"
    return_code=$?
    (
        archInstall.cache || \
        bl.logging.warn \
            Caching current downloaded packages and generated database failed.
    )
    return $return_code
}
alias archInstall.generic_linux_steps=archInstall_generic_linux_steps
archInstall_generic_linux_steps() {
    # This functions performs creating an arch linux system from any linux
    # system base.
    local return_code=0
    bl.logging.info Create a list with urls for needed packages.
    archInstall.download_and_extract_pacman \
        "$(archInstall.create_package_url_list)"
    # Create root filesystem only if not exists.
    (
        test -e "${archInstall_mountpoint_path}etc/mtab" || \
        echo 'rootfs / rootfs rw 0 0' \
            1>"${archInstall_mountpoint_path}etc/mtab"
    )
    # Copy systems resolv.conf to new installed system.
    # If the native "arch-chroot" is used it will mount the file into the
    # change root environment.
    cp /etc/resolv.conf "${archInstall_mountpoint_path}etc/"
    ! "$archInstall_prevent_using_native_arch_changeroot" && \
        hash arch-chroot 2>/dev/null
    mv "${archInstall_mountpoint_path}etc/resolv.conf" \
        "${archInstall_mountpoint_path}etc/resolv.conf.old" 2>/dev/null
    command sed \
        --in-place \
        --quiet \
        '/^[ \t]*CheckSpace/ !p' \
        "${archInstall_mountpoint_path}etc/pacman.conf"
    command sed \
        --in-place \
        's/^[ \t]*SigLevel[ \t].*/SigLevel = Never/' \
        "${archInstall_mountpoint_path}etc/pacman.conf"
    bl.logging.info Create temporary mirrors to download new packages.
    archInstall.append_temporary_install_mirrors
    (
        archInstall.load_cache || \
            bl.logging.info No package cache was loaded.
    )
    bl.logging.info Update package databases.
    (
        archInstall.changeroot_to_mount_point \
            /usr/bin/pacman \
            --arch "$archInstall_cpu_architecture" \
            --refresh \
            --sync || \
                true
    )
    bl.logging.info
        "Install needed packages \"$(
            echo "${archInstall_packages[@]}" | \
            command sed --regexp-extended 's/(^ +| +$)//g' | \
                command sed 's/ /", "/g'
        )\" to \"$archInstall_output_system\"."
    archInstall.changeroot_to_mount_point \
        /usr/bin/pacman \
        --arch "$archInstall_cpu_architecture" \
        --force \
        --sync \
        --needed \
        --noconfirm \
        "${archInstall_packages[@]}"
    return_code=$?
    (
        archInstall.cache || \
        bl.logging.warn \
            Caching current downloaded packages and generated database failed.
    )
    (( return_code == 0 )) && archInstall.configure_pacman
    return $return_code
}
## endregion
## region helper
### region change root functions
alias archInstall.changeroot_to_mountpoint=archInstall_changeroot_to_mountpoint
archInstall_changeroot_to_mount_point() {
    # This function performs a changeroot to currently set mountpoint path.
    archInstall.changeroot "$_MOUNTPOINT_PATH" "$@"
    return $?
}
alias archInstall.changeroot=archInstall_changeroot
archInstall_changeroot() {
    # This function emulates the arch linux native "arch-chroot" function.
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
### endregion
alias archInstall.configure=archInstall_configure
archInstall_configure() {
    # Provides generic linux configuration mechanism. If new systemd
    # programs are used (if first argument is "true") they could have
    # problems in change root environment without and exclusive dbus
    # connection.
    bl.logging.info \
        "Make keyboard layout permanent to \"${_KEYBOARD_LAYOUT}\"."
    if [ "$1" = true ]; then
        archInstall.changeroot_to_mount_point \
            localectl \
            set-keymap "$archInstall_keyboard_layout"
        archInstall.changeroot_to_mount_point \
            localectl \
            set-locale LANG=en_US.utf8
        archInstall.changeroot_to_mount_point \
            locale-gen \
            set-keymap "$archInstall_keyboard_layout"
    else
        echo \
            -e "$archInstall_key_map_configuration_file_content" \
            1>"${archInstall_mountpoint_path}etc/vconsole.conf"
    fi
    bl.logging.info "Set localtime \"$_LOCAL_TIME\"."
    if [ "$1" = true ]; then
        archInstall.changeroot_to_mount_point \
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
        archInstall.changeroot_to_mount_point \
            hostnamectl \
            set-hostname "$archInstall_host_name"
    else
        echo -e "$archInstall_host_name" \
            1>"${archInstall_mountpoint_path}etc/hostname"
    fi
    bl.logging.info Set hosts.
    archInstall.get_hosts_content "$archInstall_host_name" \
        1>"${archInstall_mountpoint_path}etc/hosts"
    if [[ "$1" != true ]]; then
        bl.logging.info Set root password to \"root\".
        archInstall.changeroot_to_mount_point \
            /usr/bin/env bash \
            -c "echo root:root | \$(which chpasswd)"
    fi
    archInstall.enable_services
    local user_name
    for user_name in "${archInstall_user_names[@]}"; do
        bl.logging.info "Add user: \"$user_name\"."
        # NOTE: We could only create a home directory with right rights if we
        # are root.
        (
            archInstall.changeroot_to_mount_point \
                useradd "$(
                    if [[ "$UID" == '0' ]]; then
                        echo '--create-home '
                    else
                        echo --no-create-home
                    fi
                ) --no-user-group --shell /usr/bin/bash" \
                "$user_name" || (
                    bl.logging.warn "Adding user \"$user_name\" failed." && \
                    false
                )
        )
        bl.logging.info "Set password for \"$user_name\" to \"$user_name\"."
        archInstall.changeroot_to_mount_point \
            /usr/bin/env bash -c \
                "echo ${user_name}:${user_name} | \$(which chpasswd)"
    done
    return $?
}
alias archInstall.enable_services=archInstall_enable_services
archInstall_enable_services() {
    # Enable all needed services.
    local network_device_name
    for network_device_name in $(
        ip addr | \
        command grep --extended-regexp --only-matching '^[0-9]+: .+: ' | \
        command sed --regexp-extended 's/^[0-9]+: (.+): $/\1/g'
    ); do
        if ! echo "$network_device_name" | \
            command grep --extended-regexp '^(lo|loopback|localhost)$' --quiet
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
    local return_code=0
    local service_name
    for service_name in "${archInstall_needed_services[@]}"; do
        bl.logging.info "Enable \"$service_name\" service."
        archInstall.changeroot_to_mount_point \
            systemctl \
            enable \
            "${service_name}.service"
        return_code=$?
        (( return_code != 0 )) && return $return_code
    done
}
alias archInstall.tidy_up_system=archInstall_tidy_up_system
archInstall_tidy_up_system() {
    # Deletes some unneeded locations in new installs operating system.
    local return_code=0
    bl.logging.info Tidy up new build system.
    local file_path
    for file_path in "${archInstall_unneeded_file_locations[@]}"; do
        bl.logging.info "Deleting \"$archInstall_mountpoint_path\"."
        rm \
            "${archInstall_mountpoint_path}$file_path" \
            --force \
            --recursive
        return_code=$?
        (( return_code != 0 )) && return $return_code
    done
}
alias archInstall.append_temporary_install_mirrors=archInstall_append_temporary_install_mirrors
archInstall_append_temporary_install_mirrors() {
    # Appends temporary used mirrors to download missing packages during
    # installation.
    local return_code
    local url
    for url in "${archInstall_package_source_urls[@]}"; do
        echo \
            "Server = $url/\$repo/os/$archInstall_cpu_architecture" \
                1>>"${_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
        return_code=$?
        (( return_code != 0 )) && return $return_code
    done
}
alias archInstall.pack_result=archInstall_pack_result
archInstall_pack_result() {
    # Packs the resulting system to provide files owned by root without
    # root permissions.
    if [[ "$UID" != '0' ]]; then
        bl.logging.info \
            "System will be packed into \"$_MOUNTPOINT_PATH.tar\" to provide root owned files. You have to extract this archiv as root."
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
alias archInstall.create_package_url_list=archInstall_create_package_url_list
archInstall_create_package_url_list() {
    # Generates all web urls for needed packages.
    local temporary_return_code=0
    local return_code=0
    local list_buffer_file="$(mktemp)"
    local repository_name
    for repository_name in core community extra; do
        wget \
            --quiet \
            --output-document - \
            "${archInstall_package_source_urls[0]}/$repository_name/os/$archInstall_cpu_architecture/" | \
                command sed \
                    --quiet \
                    "s|.*href=\"\\([^\"]*\\).*|${archInstall_package_source_urls[0]}\\/$repository_name\\/os\\/$archInstall_cpu_architecture\\/\\1|p" | \
                        command grep --invert-match 'sig$' | \
                            uniq 1>>"$list_buffer_file"
        temporary_return_code=$?
        # NOTE: "return_code" remains with an error code if there was given
        # one in all iterations.
        (( temporary_return_code != 0 )) && return_code=$temporary_return_code
    done
    bl.logging.plain "$list_buffer_file"
    return $return_code
}
alias archInstall.determine_pacmans_needed_packages=archInstall_determine_pacmans_needed_packages
archInstall_determine_pacmans_needed_packages() {
    # Reads pacmans database and determine pacman's dependencies.
    local core_database_url="$(command grep 'core\.db' "$0" | head --lines 1)"
    wget \
        "$core_database_url" \
        --directory-prefix "${archInstall_package_cache_path}/" \
        --timestamping
    if [ -f "${archInstall_package_cache_path}/core.db" ]; then
        local database_location="$(mktemp --directory)"
        tar \
            --directory "$database_location" \
            --extract \
            --file "${archInstall_package_cache_path}/core.db" \
            --gzip
        archInstall.determine_package_dependencies pacman "$database_location"
        return $?
    else
        bl.logging.critical \
            "No database file (\"${archInstall_package_cache_path}/core.db\") available."
    fi
}
alias archInstall.determine_package_dependencies=archInstall_determine_package_dependencies
archInstall_determine_package_dependencies() {
    # Determines all package dependencies. Returns a list of needed
    # packages for given package determined by given database.
    # NOTE: We append and prepend always a whitespace to simply identify
    # duplicates without using extended regular expression and packname
    # escaping.
    archInstall_needed_packages+=("${1[@]}")
    local package_directory_path="$(
        archInstall.determine_package_directory_name "$@")"
    if [[ "$package_directory_path" != '' ]]; then
        local package_dependency_description
        command grep \
            --null-data \
            --only-matching \
            --perl-regexp \
            '%DEPENDS%(\n.+)+' < "${package_directory_path}depends" | \
                command grep --extended-regexp --invert-match '^%.+%$' | \
                    while IFS= read -r package_dependency_description
        do
            local package_name="$(
                echo "$package_dependency_description" | \
                    command grep \
                        --extended-regexp \
                        --only-matching \
                        '^[-a-zA-Z0-9]+'
            )"
            if ! echo "${archInstall_needed_packages[@]}" | \
                command grep " $package_name " &>/dev/null
            then
                archInstall.determine_package_dependencies \
                    "$package_name" \
                    "$2" \
                    recursive || \
                        bl.logging.warn \
                            "Needed package \"$package_name\" for \"$1\" couldn't be found in database in \"$2\"."
            fi
        done
    else
        return 1
    fi
}
alias archInstall.determine_package_directory_name=archInstall_determine_pacage_directory_name
archInstall.determine_package_directory_nam() {
    # Determines the package directory name from given package name in
    # given database.
    local package_directory_path="$(
        command grep \
            "%PROVIDES%"$'\n(.+\n)*'"$1"$'\n(.+\n)*\n' \
            --files-with-matches \
            --null-data "$2" \
            --perl-regexp \
            --recursive | \
                command grep --extended-regexp '/depends$' | \
                    command sed 's/depends$//' | \
                        head --lines 1
    )"
    if [ ! "$package_directory_path" ]; then
        local regular_expression
        for regular_expression in \
            "^$1"'-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$' \
            "^$1"'[0-9]+-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$' \
            "^[0-9]+$1"'[0-9]+-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$' \
            '^[0-9a-zA-Z]*acm[0-9a-zA-Z]*-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$'
        do
            local package_directory_name="$(
                ls -1 "$2" | \
                    command grep --extended-regexp "$regular_expression"
            )"
            if [ "$package_directory_name" ]; then
                break
            fi
        done
        if [ "$package_directory_name" ]; then
            package_directory_path="$2/$package_directory_name/"
        fi
    fi
    echo "$package_directory_path"
}
alias archInstall.download_and_extract_pacman=archInstall_download_and_extract_pacman
archInstall_download_and_extract_pacman() {
    # Downloads all packages from arch linux needed to run pacman.
    local list_buffer_file="$1"
    if archInstall.determine_pacmans_needed_packages "$list_buffer_file"; then
        bl.logging.info "Needed packages are: \"$(
            echo "${archInstall_needed_packages[@]}" | \
                command sed 's/ /", "/g'
        )\"."
        bl.logging.info \
            "Download and extract each package into our new system located in \"$archInstall_mounpoint_path\"."
        local package_name
        local return_code=0
        for package_name in "${archInstall_needed_packages[@]}"; do
            local package_url="$(
                command grep "${package_name}-[0-9]" "$list_buffer_file" | \
                    head --lines 1
            )"
            local file_name="$(
                echo "$package_url" | command sed 's/.*\/\([^\/][^\/]*\)$/\1/'
            )"
            # If "file_name" couldn't be determined via server determine it via
            # current package cache.
            if [ ! "$file_name" ]; then
                file_name="$(
                    ls $archInstall_package_cache_path | \
                        command grep "$package_name-[0-9]" | \
                            head --lines 1
                )"
            fi
            if [ "$file_name" ]; then
                wget \
                    "$package_url" \
                    --continue \
                    --directory-prefix "${archInstall_package_cache_path}/" \
                    --timestamping
            else
                bl.logging.critical \
                    "A suitable file for package \"$package_name\" could not be determined."
            fi
            bl.logging.indo "Install package \"$file_name\" manually."
            xz \
                --decompress \
                --to-stdout \
                "$archInstall_package_cache_path/$file_name" | \
                    tar \
                        --directory \
                        --extract \
                        "$archInstall_mounpoint_path"
            return_code=$?
            (( return_code != 0 )) && return $return_code
        done
    else
        return 1
    fi
}
alias archInstall.make_partitions=archInstall_make_partitions
archInstall_make_partitions() {
    # Performs the auto partitioning.
    if $archInstall_auto_partitioning; then
        bl.logging.info Check block device size.
        local block_device_space_in_mega_byte="$(("$(
            blockdev --getsize64 "$archInstall_output_system"
        )" * 1024 ** 2))"
        if [[ $((
            $archInstall_needed_system_space_in_mega_byte + \
            $archInstall_boot_space_in_mega_byte
        )) -le $block_device_space_in_mega_byte ]]; then
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
                "Not enough space on \"$archInstall_output_system\" (\"$block_device_space_in_byte\" byte). We need at least \"$(($archInstall_needed_system_space_in_mega_byte + $archInstall_boot_space_in_mega_byte))\" byte."
        fi
    else
        bl.logging.info \
            "At least you have to create two partitions. The first one will be used as boot partition labeled to \"${archInstall_boot_partition_label}\" and second one will be used as system partition and labeled to \"${archInstall_system_partition_label}\". Press Enter to continue."
        read
        bl.logging.info Show blockdevices. Press Enter to continue.
        lsblk
        read
        bl.logging.info Create partitions manually.
        gdisk "$archInstall_output_system"
    fi
}
alias archInstall.generate_fstab_configuration_file=archInstall_generate_fstab_configuration_file
archInstall_generate_fstab_configuration_file() {
    # Writes the fstab configuration file.
    bl.logging.info Generate fstab config.
    if hash genfstab 2>/dev/null; then
        # NOTE: Mountpoint shouldn't have a path separator at the end.
        genfstab \
            -L \
            -p "${archInstall_mounpoint_path%?}" \
            1>>"${archInstall_mounpoint_path}etc/fstab"
    else
        cat << EOF 1>>"${archInstall_mounpoint_path}etc/fstab"
# Added during installation.
# <file system>                    <mount point> <type> <options>                                                                                            <dump> <pass>
# "compress=lzo" has lower compression ratio by better cpu performance.
PARTLABEL=$archInstall_system_partition_label /             btrfs  relatime,ssd,discard,space_cache,autodefrag,inode_cache,subvol=root,compress=zlib                    0      0
PARTLABEL=$archInstall_boot_partition_label   /boot/        vfat   rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro 0      0
EOF
    fi
}
alias archInstall.unmount_installed_system=archInstall_unmount_installed_system
archInstall_unmount_installed_system() {
    # Unmount previous installed system.
    bl.logging.info Unmount installed system.
    sync
    cd /
    umount "${archInstall_mounpoint_path}/boot"
    umount "$archInstall_mounpoint_path"
}
alias archInstall.prepare_next_boot=archInstall_prepare_next_boot
archInstall_prepare_next_boot() {
    # Reboots into fresh installed system if previous defined.
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
alias archInstall.configure_pacman=archInstall_configure_pacman
archInstall_configure_pacman() {
    # Disables signature checking for incoming packages.
    bl.logging.info "Enable mirrors in \"$archInstall_country_with_mirrors\"."
    local buffer_file="$(mktemp)"
    local in_area=false
    local line_number=0
    local line
    while read line; do
        line_number="$(($lineNumber + 1))"
        if [ "$line" = "## $archInstall_country_with_mirrors" ]; then
            in_area=true
        elif [ "$line" = '' ]; then
            in_area=false
        elif $in_area && [ "${line:0:1}" = '#' ]; then
            line="${line:1}"
        fi
        echo "$line"
    done < "${archInstall_mounpoint_path}etc/pacman.d/mirrorlist" \
        1>"$buffer_file"
    cat "$buffer_file" 1>"${archInstall_mounpoint_path}etc/pacman.d/mirrorlist"
    bl.logging.info "Change signature level to \"Never\" for pacman's packages."
    command sed \
        --in-place \
        --regexp-extended \
        's/^(SigLevel *= *).+$/\1Never/g' \
        "${archInstall_mounpoint_path}etc/pacman.conf"
}
alias archInstall.determine_auto_partitioning=archInstall_determine_auto_partitioning
archInstall_determine_auto_partitioning() {
    # Determine whether we should perform our auto partitioning mechanism.
    if ! $archInstall_auto_partitioning; then
        while true; do
            local auto_partitioning
            echo -n 'Do you want auto partioning? [yes|NO]: '
            read auto_partitioning
            if [ "$auto_partitioning" = '' ] || [[
                "$(echo "$auto_partitioning" | tr '[A-Z]' '[a-z]')" = no
            ]]; then
                archInstall_auto_partitioning=false
                break
            elif [ "$(echo "$auto_partitioning" | tr '[A-Z]' '[a-z]')" = yes ]
            then
                archInstall_auto_partitioning=true
                break
            fi
        done
    fi
}
alias archInstall.get_hosts_content=archInstall_get_hosts_content
archInstall_get_hosts_content() {
    # Provides the file content for the "/etc/hosts".
    cat << EOF
#<IP-Adress> <computername.workgroup> <computernames>
127.0.0.1    localhost.localdomain    localhost $1
::1          ipv6-localhost           ipv6-localhost ipv6-$1
EOF
}
alias archInstall.prepare_blockdevices=archInstall_prepare_blockdevices
archInstall_prepare_blockdevices() {
    # Prepares given block devices to make it ready for fresh installation.
    bl.logging.info \
        "Unmount needed devices and devices pointing to our temporary system mount point \"$archInstall_mounpoint_path\"."
    umount -f "${archInstall_output_system}"* 2>/dev/null
    umount -f "$archInstall_mounpoint_path" 2>/dev/null
    swapoff "${archInstall_output_system}"* 2>/dev/null
    bl.logging.info Make partitions. Make a boot and system partition.
    archInstall.make_partitions
    bl.logging.info Format partitions.
    archInstall.format_partitions
}
alias archInstall.format_system_partition=archInstall_format_system_partition
archInstall_format_system_partition() {
    # Prepares the system partition.
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
        "$archInstall_mounpoint_path"
    btrfs subvolume create "${archInstall_mounpoint_path}root"
    umount "$archInstall_mounpoint_path"
}
alias archInstall.format_boot_partition=archInstall_format_boot_partition
archInstall_format_boot_partition() {
    # Prepares the boot partition.
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
    # Performs formating part.
    archInstall.format_system_partition
    archInstall.format_boot_partition
}
alias archInstall.add_boot_entries=archInstall_add_boot_entries
archInstall_add_boot_entries() {
    # Creates an uefi boot entry.
    if hash efibootmgr 2>/dev/null; then
        bl.logging.info Configure efi boot manager.
        cat << EOF 1>"${archInstall_mounpoint_path}/boot/startup.nsh"
\vmlinuz-linux initrd=\initramfs-linux.img root=PARTLABEL=${archInstall_system_partition_label} rw rootflags=subvol=root quiet loglevel=2 acpi_osi="!Windows 2012"
EOF
        archInstall.changeroot_to_mount_point \
            efibootmgr \
            --create \
            --disk "$archInstall_output_system" \
            -l '\vmlinuz-linux' \
            --label "$archInstall_fallback_boot_entry_label" \
            --part 1 \
            --unicode \
            "initrd=\initramfs-linux-fallback.img root=PARTLABEL=${archInstall_system_partition_label} rw rootflags=subvol=root break=premount break=postmount acpi_osi=\"!Windows 2012\"" || \
                bl.logging.warn \
                    "Adding boot entry \"${archInstall_fallback_boot_entry_label}\" failed."
        # NOTE: Boot entry to boot on next reboot should be added at last.
        archInstall.changeroot_to_mount_point \
            efibootmgr \
            --create \
            --disk "$archInstall_output_system" \
            -l '\vmlinuz-linux' \
            --label "$archInstall_boot_entry_label" \
            --part 1 \
            --unicode \
            "initrd=\initramfs-linux.img root=PARTLABEL=${archInstall_system_partition_label} rw rootflags=subvol=root quiet loglevel=2 acpi_osi=\"!Windows 2012\"" || \
                bl.logging.warn \
                    "Adding boot entry \"${archInstall_boot_entry_label}\" failed."
    else
        bl.logging.warn \
            "\"efibootmgr\" doesn't seem to be installed. Creating a boot entry failed."
    fi
}
alias archInstall.load_cache=archInstall_load_cache
archInstall_load_cache() {
    # Load previous downloaded packages and database.
    bl.logging.info Load cached databases.
    mkdir --parents "${archInstall_mounpoint_path}var/lib/pacman/sync"
    cp \
        --no-clobber \
        --preserve \
        "$archInstall_package_cache_path"/*.db \
        "${archInstall_mounpoint_path}var/lib/pacman/sync/"
    bl.logging.info Load cached packages.
    mkdir \
        --parents \
        "${archInstall_mountpoint_path}var/cache/pacman/pkg"
    cp \
        --no-clobber \
        --preserve \
        "$archInstall_package_cache_path"/*.pkg.tar.xz \
        "${archInstall_mounpoint_path}var/cache/pacman/pkg/"
}
alias archInstall.cache=archInstall_cache
archInstall_cache() {
    # Cache previous downloaded packages and database.
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
        "${archInstall_mounpoint_path}var/lib/pacman/sync/"*.db \
        "${archInstall_package_cache_path}/"
    return $?
}
alias archInstall.prepare_installation=archInstall_prepare_installation
archInstall_prepare_installation() {
    # Deletes previous installed things in given output target. And creates
    # a package cache directory.
    mkdir --parents "$archInstall_package_cache_path"
    if [ -b "$archInstall_output_system" ]; then
        bl.logging.info Mount system partition.
        mount \
            PARTLABEL="$archInstall_system_partition_label" \
            -o subvol=root \
            "$archInstall_mounpoint_path"
    fi
    bl.logging.info \
        "Clear previous installations in \"$archInstall_mounpoint_path\"."
    rm "$archInstall_mounpoint_path"* --recursive --force
    if [ -b "$archInstall_output_system" ]; then
        bl.logging.info \
            "Mount boot partition in \"${archInstall_mountpoint_path}boot/\"."
        mkdir --parents "${archInstall_mountpoint_path}boot/"
        mount \
            PARTLABEL="$archInstall_boot_partition_label" \
            "${archInstall_mountpoint_path}boot/"
        rm "${archInstall_mounpoint_path}boot/"* --force --recursive
    fi
    bl.logging.info Set filesystem rights.
    chmod 755 "$archInstall_mountpoint_path"
    # Make an uniqe array.
    archInstall_packages=$(
        echo "${archInstall_packages[@]}" | \
        tr ' ' '\n' | \
        sort -u | \
        tr '\n' ' '
    )
}
## endregion
## region controller
alias archInstall.main=archInstall_main
archInstall_main() {
    # Provides the main module scope.
    bl.logging.set_command_output_off
    archInstall.commandline_interface "$@" || return $?
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
            archInstall.format_system_partition || \
                bl.logging.critical System partition creation failed.
        else
            archInstall.determine_auto_partitioning
            archInstall.prepare_blockdevices || \
                bl.logging.critical Preparing blockdevices failed.
        fi
    else
        bl.logging.critical \
            "Could not install into an existing file \"$archInstall_output_system\"."
    fi
    archInstall.prepare_installation || \
        bl.logging.critical Preparing installation failed.
    if [ "$UID" = 0 ] && ! $archInstall_prevent_using_pacstrap && \
        hash pacstrap 2>/dev/null
    then
        archInstall.with_pacstrap || \
            bl.logging.critical Installation with pacstrap failed.
    else
        archInstall.generic_linux_steps || \
            bl.logging.critical Installation via generic linux steps failed.
    fi
    archInstall.tidy_up_system
    archInstall.configure || \
        bl.logging.critical Configuring installed system failed.
    archInstall.prepare_next_boot || \
        bl.logging.critical Preparing reboot failed.
    archInstall.pack_result || \
        bl.logging.critical \
            Packing system into archiv with files owned by root failed.
    bl.logging.info \
        "Generating operating system into \"$_OUTPUT_SYSTEM\" has successfully finished."
}
## endregion
# endregion
if bl.tools.is_main; then
    archInstall.main "$@"
    rm --recursive "$archInstall_bashlink_path"
    rm --recursive "$bl_module_remote_module_cache_path"
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
