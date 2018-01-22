#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC2016,SC2155
# region import
# shellcheck source=./module.sh
source "$(dirname "${BASH_SOURCE[0]}")/module.sh"
bl.module.import bashlink.logging
# endregion
# region variables
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
# This list should be in the order they should be mounted before using.
# NOTE: Mount binds has to be declared as absolute paths.
archInstall_needed_mountpoints=(
    /proc
    /sys
    /sys/firmware/efi/efivars
    /dev
    /dev/pts
    /dev/shm
    /run
    /tmp
)
archInstall_packages=()
archInstall_packages_sourceUrls=(
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
archInstall_key_map_configuration_file_content="KEYMAP=${archInstall_keyboard_layout}\nFONT=Lat2-Terminus16\nFONT_MAP="
# NOTE: This properties aren't needed in the future with supporting "localectl"
# program.
archInstall_local_time=EUROPE/Berlin
archInstall_needed_services=()
archInstall_needed_system_space_in_mega_byte=512
archInstall_output_system=archInstall
archInstall_package_cache_path=archInstallPackageCache
archInstall_prevent_using_native_arch_change_root=false
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

-d --debug Gives you any output from all tools which are used (default: "$archInstall_debug").

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

-y --prevent-using-native-arch-chroot Ignores presence of "arch-chroot" to use it for chroot into newly created operating system (default: "$archInstall_prevent_using_native_arch_change_root").

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
    echo -e "\nUsage: $0 [options]\n"
    archInstall.print_usage_message "$@"
    echo -e '\nExamples:\n'
    archInstall.print_usage_examples "$@"
    echo -e '\nOption descriptions:\n'
    archInstall.print_command_line_option_description "$@"
    echo
}
alias archInstall.command_line_interface=archInstall_command_line_interface
archInstall_command_line_interface() {
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
                archInstall_prevent_using_native_arch_change_root=true
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
                archInstall_needed_system_in_mega_byte="$1"
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
    if [[ "$UID" != '0' ]] && ! (
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
                read archInstall_host_name
                if [[ "$(echo "$archInstall_host_name" | tr '[A-Z]' '[a-z]')" != '' ]]; then
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
    archInstall.load_cache
    bl.logging.info Patch pacstrap to handle offline installations.
    cat $(which pacstrap) | sed --regexp-extended \
        's/(pacman.+-(S|-sync))(y|--refresh)/\1/g' \
        1>${_PACKAGE_CACHE_PATH}/patchedOfflinePacman.sh
    chmod +x "${_PACKAGE_CACHE_PATH}/patchedOfflinePacman.sh"
    bl.logging.info Update package databases.
    (
        pacman \
            --arch "$archInstall_cpu_architecture" \
            --refresh \
            --root "$archInstall_mountpoint_path"
            --sync || \
                true
    )
    bl.logging.info \
        "Install needed packages \"$(echo "${archInstall_packages[@]}" | sed \
        --regexp-extended 's/(^ +| +$)//g' | sed \
        's/ /", "/g')\" to \"$archInstall_output_system\"."
    "${archInstall_package_cache_path}/patchedOfflinePacman.sh" \
        -d "$archInstall_mountpoint_path" "${archInstall_packages[@]}" \
        --force
    rm "${_PACKAGE_CACHE_PATH}/patchedOfflinePacman.sh"
    local return_code=$?
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
    bl.logging.info Create a list with urls for needed packages.
    archInstall.download_and_extract_pacman \
        $(archInstall.create_package_url_list)
    # Create root filesystem only if not exists.
    (
        test -e "${archIstall_mountpoint_path}etc/mtab" || \
        echo 'rootfs / rootfs rw 0 0' \
            1>"${archInstall_mountpoint_path}etc/mtab"
    )
    # Copy systems resolv.conf to new installed system.
    # If the native "arch-chroot" is used it will mount the file into the
    # change root environment.
    cp /etc/resolv.conf "${archInstall_mounpoint_path}etc/"
    ! "$archInstall_prevent_using_native_arch_change_root" && \
        hash arch-chroot 2>/dev/null
    mv "${archInstall_mountpoint_path}etc/resolv.conf" \
        "${archInstall_mountpoint_path}etc/resolv.conf.old" 2>/dev/null
    sed --in-place --quiet '/^[ \t]*CheckSpace/ !p' \
        "${archInstall_mountpoint_path}etc/pacman.conf"
    sed --in-place "s/^[ \t]*SigLevel[ \t].*/SigLevel = Never/" \
        "${archInstall_mountpoint_path}etc/pacman.conf"
    bl.logging.info Create temporary mirrors to download new packages.
    archInstall.append_temporary_install_mirrors
    (
        archInstall.load_cache || \
            bl.logging.info No package cache was loaded.
    )
    bl.logging.info Update package databases.
    (
        archInstall.change_root_to_mount_point \
            /usr/bin/pacman \
            --arch "$archInstall_cpu_architecture" \
            --refresh \
            --sync || \
                true
    )
    bl.logging.info
        "Install needed packages \"$(
            echo "${archInstall_packages[@]}" | \
            sed --regexp-extended 's/(^ +| +$)//g' | \
            sed 's/ /", "/g'
        )\" to \"$archInstall_output_system\"."
    archInstall.change_root_to_mount_point \
        /usr/bin/pacman \
        --arch "$archInstall_cpu_architecture" \
        --force \
        --sync \
        --needed \
        --noconfirm \
        "${archInstall_packages[@]}"
    local return_code=$?
    (
        archInstall.cache || \
        bl.logging.warn \
            Caching current downloaded packages and generated database failed.
    )
    (( return_code == 0 )) && archInstall.configure_pacman
    return $?
}
## endregion
## region helper
# TODO sync with bashlink
### region change root functions
alias archInstall.change_root_to_mountpoint=archInstall_change_root_to_mountpoint
archInstall_change_root_to_mount_point() {
    # This function performs a changeroot to currently set mountpoint path.
    archInstall.change_root "$_MOUNTPOINT_PATH" "$@"
    return $?
}
alias archInstall.change_root=archInstall_change_root
archInstall_change_root() {
    # This function emulates the arch linux native "arch-chroot" function.
    if [ "$1" = / ]; then
        shift
        "$@"
        return $?
    else
        if ! $archInstall_prevent_using_native_arch_change_root && \
            hash arch-chroot 2>/dev/null
        then
            arch-chroot "$@"
            return $?
        fi
        archInstall.change_root_via_mount "$@"
        return $?
    fi
    return $?
}
alias archInstall.change_root_via_mount=archInstall_change_root_via_mount
archInstall_change_root_via_mount() {
    # Performs a change root by mounting needed host locations in change
    # root environment.
    local mountpoint_path
    for mountpoint_path in "${archInstall_needed_mountpoints[@]}"; do
        mountpointPath="${mountpointPath:1}" && \
        if [ ! -e "${_MOUNTPOINT_PATH}${mountpointPath}" ]; then
            mkdir --parents "${_MOUNTPOINT_PATH}${mountpointPath}" \
                1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
        fi
        if ! mountpoint -q "${_MOUNTPOINT_PATH}${mountpointPath}"; then
            if [ "$mountpointPath" == 'proc' ]; then
                mount "/${mountpointPath}" \
                    "${_MOUNTPOINT_PATH}${mountpointPath}" --types \
                    "$mountpointPath" --options nosuid,noexec,nodev \
                    1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            elif [ "$mountpointPath" == 'sys' ]; then
                mount "/${mountpointPath}" \
                    "${_MOUNTPOINT_PATH}${mountpointPath}" --types sysfs \
                    --options nosuid,noexec,nodev 1>"$_STANDARD_OUTPUT" \
                    2>"$_ERROR_OUTPUT"
            elif [ "$mountpointPath" == 'dev' ]; then
                mount udev "${_MOUNTPOINT_PATH}${mountpointPath}" --types \
                    devtmpfs --options mode=0755,nosuid \
                    1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            elif [ "$mountpointPath" == 'dev/pts' ]; then
                mount devpts "${_MOUNTPOINT_PATH}${mountpointPath}" \
                    --types devpts --options \
                    mode=0620,gid=5,nosuid,noexec 1>"$_STANDARD_OUTPUT" \
                    2>"$_ERROR_OUTPUT"
            elif [ "$mountpointPath" == 'dev/shm' ]; then
                mount shm "${_MOUNTPOINT_PATH}${mountpointPath}" --types \
                    tmpfs --options mode=1777,nosuid,nodev \
                    1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            elif [ "$mountpointPath" == 'run' ]; then
                mount "/${mountpointPath}" \
                    "${_MOUNTPOINT_PATH}${mountpointPath}" --types tmpfs \
                    --options nosuid,nodev,mode=0755 \
                    1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            elif [ "$mountpointPath" == 'tmp' ]; then
                mount run "${_MOUNTPOINT_PATH}${mountpointPath}" --types \
                    tmpfs --options mode=1777,strictatime,nodev,nosuid \
                    1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            elif [ -f "/${mountpointPath}" ]; then
                mount "/${mountpointPath}" \
                    "${_MOUNTPOINT_PATH}${mountpointPath}" --bind
            else
                archInstallLog 'warning' \
                    "Mountpoint \"/${mountpointPath}\" couldn't be handled."
            fi
        fi
    done
    archInstallPerformChangeRoot "$@"
    local returnCode=$?
    # Reverse mountpoint list to unmount them in reverse order.
    local reverseNeededMountpoints && \
    for mountpointPath in ${_NEEDED_MOUNTPOINTS[*]}; do
        reverseNeededMountpoints="$mountpointPath ${reverseNeededMountpoints[*]}"
    done
    for mountpointPath in ${reverseNeededMountpoints[*]}; do
        mountpointPath="${mountpointPath:1}" && \
        if mountpoint -q "${_MOUNTPOINT_PATH}${mountpointPath}" || \
            [ -f "/${mountpointPath}" ]
        then
            # If unmounting doesn't work try to unmount in lazy mode
            # (when mountpoints are not needed anymore).
            umount "${_MOUNTPOINT_PATH}${mountpointPath}" \
                1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" || \
            (archInstallLog 'warning' "Unmounting \"${_MOUNTPOINT_PATH}${mountpointPath}\" fails so unmount it in force mode." && \
             umount -f "${_MOUNTPOINT_PATH}${mountpointPath}" \
                 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT") || \
            (archInstallLog 'warning' "Unmounting \"${_MOUNTPOINT_PATH}${mountpointPath}\" in force mode fails so unmount it if mountpoint isn't busy anymore." && \
             umount -l "${_MOUNTPOINT_PATH}${mountpointPath}" \
                 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT")
            # NOTE: "returnCode" remains with an error code if there was
            # given one in all iterations.
            [[ $? != 0 ]] && returnCode=$?
        else
            archInstallLog 'warning' \
                "Location \"${_MOUNTPOINT_PATH}${mountpointPath}\" should be a mountpoint but isn't."
        fi
    done
    return $returnCode
}
archInstallPerformChangeRoot() {
    # Perform the available change root program wich needs at least rights.
    if [[ "$UID" == '0' ]]; then
        chroot "$@" 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
        return $?
    fi
    fakeroot fakechroot chroot "$@" 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT"
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
        archInstall.change_root_to_mount_point \
            localectl \
            set-keymap "$archInstall_keyboard_layout"
        archInstall.change_root_to_mount_point \
            localectl \
            set-locale LANG=en_US.utf8
        archInstall.change_root_to_mount_point \
            locale-gen \
            set-keymap "$archInstall_keyboard_layout"
    else
        echo \
            -e "$archInstall_key_map_configuration_file_content" \
            1>"${archInstall_mountpoint_path}etc/vconsole.conf"
    fi
    bl.logging.info "Set localtime \"$_LOCAL_TIME\"."
    if [ "$1" = true ]; then
        archInstall.change_root_to_mount_point \
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
        archInstall.change_root_to_mount_point \
            hostnamectl \
            set-hostname "$archInstall_host_name"
    else
        echo \
            -e "$archInstall_host_name" 1>"${archInstall_mountpoint_path}etc/hostname" \
    fi
    bl.logging.info Set hosts.
    archInstall.get_hosts_content "$archInstall_host_name" \
        1>"${archInstall_mountpoint_path}etc/hosts"
    if [[ "$1" != 'true' ]]; then
        bl.logging.info Set root password to \"root\".
        archInstall.change_root_to_mount_point \
            /usr/bin/env bash \
            -c "echo root:root | \$(which chpasswd)"
    fi
    archInstall.enable_services
    local user_name
    for user_name in "$archInstall_user_names[@]}"; do
        bl.logging.info "Add user: \"$userName\"."
        # NOTE: We could only create a home directory with right rights if we
        # are root.
        (
            archInstall.change_root_to_mount_point \
                useradd "$(
                    if [[ "$UID" == '0' ]]; then
                        echo '--create-home '
                    else
                        echo '--no-create-home'
                    fi
                ) --no-user-group --shell /usr/bin/bash" \
                "$userName" || (
                    bl.logging.warn "Adding user \"$userName\" failed." && \
                    false
                )
        )
        bl.logging.info "Set password for \"$userName\" to \"$userName\"."
        archInstall.change_root_to_mount_point \
            /usr/bin/env bash \
            -c "echo ${userName}:${userName} | \$(which chpasswd)"
    done
    return $?
}
alias archInstall.enable_services=archInstall_enable_services
archInstall_enable_services() {
    # Enable all needed services.
    local network_device_name
    for network_device_name in $(
        ip addr | \
        grep --extended-regexp --only-matching '^[0-9]+: .+: ' | \
        sed --regexp-extended 's/^[0-9]+: (.+): $/\1/g'
    ); do
        if [[ ! "$(
            echo "$network_device_name" | \
            grep --extended-regexp '^(lo|loopback|localhost)$'
        )" ]]; then
            local service_name=dhcpcd
            local connection=ethernet
            local description='A basic dhcp connection'
            local additional_properties=''
            if [ "${network_device_name:0:1}" = e ]; then
                bl.logging.info \
                    "Enable dhcp service on wired network device \"$networkDeviceName\"."
                service_name=netctl-ifplugd
                connection=ethernet
                description='A basic ethernet dhcp connection'
            elif [ "${networkDeviceName:0:1}" = w ]; then
                bl.logging.info \
                    "Enable dhcp service on wireless network device \"$networkDeviceName\"."
                service_name=netctl-auto
                connection=wireless
                description='A simple WPA encrypted wireless connection'
                additional_properties="\nSecurity=wpa\nESSID='home'\nKey='home'"
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
    for serviceName in "${archInstall_needed_services[@]}"; do
        bl.logging.info "Enable \"$service_name\" service."
        archInstall.change_root_to_mount_point \
            systemctl \
            enable \
            "${service_name}.service"
        [[ $? != 0 ]] && return $?
    done
}
alias archInstall.tidy_up_system=archInstall_tidy_up_system
archInstall_tidy_up_system() {
    # Deletes some unneeded locations in new installs operating system.
    local return_code=0
    bl.logging.info Tidy up new build system.
    local file_path
    for filePath in "${archInstall_unneeded_file_locations[@]}"; do
        bl.logging.info "Deleting \"$archInstall_mountpoint_path\"."
        rm \
            "${archInstall_mountpoint_path}$file_path" \
            --force \
            --recursive
        [[ $? != 0 ]] && return $?
    done
}
alias archInstall.append_temporary_install_mirrors=archInstall_append_temporary_install_mirrors
archInstall_append_temporary_install_mirrors() {
    # Appends temporary used mirrors to download missing packages during
    # installation.
    local url
    for url in "${archInstall_packages_source_urls[@]}"; do
        echo \
            "Server = $url/\$repo/os/$archInstall_cpu_architecture" \
                1>>"${_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist"
        [[ $? != 0 ]] && return $?
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
    local return_code=0
    local list_buffer_file="$(mktemp)"
    local repository_name
    for repositoryName in core community extra; do
        wget \
            --quiet \
            --output-document - \
            "${archInstall_packages_source_urls[0]}/$repository_name/os/$archInstall_cpu_architecture/" | \
                sed \
                --quiet \
                "s|.*href=\"\\([^\"]*\\).*|${archInstall_packages_source_urls[0]}\\/$repository_name\\/os\\/$archInstall_cpu_architecture\\/\\1|p" | \
                    grep --invert-match 'sig$' | \
                        uniq 1>>"$list_buffer_file"
        # NOTE: "return_code" remains with an error code if there was given
        # one in all iterations.
        [[ $? != 0 ]] && return_code=$?
    done
    bl.logging.plain "$list_buffer_file"
    return $return_code
}
alias archInstall.determine_pacmans_needed_packages=archInstall_determine_pacmans_needed_packages
archInstall_determine_pacmans_needed_packages() {
    # Reads pacmans database and determine pacman's dependencies.
    local core_database_url="$(grep "core\.db" "$0" | head --lines 1)"
    wget \
        "$core_database_url" \
        --directory-prefix "${archInstall_package_cache_path}/" \
        --timestamping
    if [ -f "${archInstall_package_cache_path}/core.db" ]; then
        local database_location="$(mktemp --directory)"
        tar \
            --directory "$databaseLocation" \
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
archInstallDeterminePackageDependencies() {
    # Determines all package dependencies. Returns a list of needed
    # packages for given package determined by given database.
    # NOTE: We append and prepend always a whitespace to simply identify
    # duplicates without using extended regular expression and packname
    # escaping.
    _NEEDED_PACKAGES+=" $1 " && \
    _NEEDED_PACKAGES="$(echo "$_NEEDED_PACKAGES" | sed --regexp-extended \
        's/ +/ /g')" && \
    local returnCode=0 && \
    local \
        packageDirectoryPath=$(archInstallDeterminePackageDirectoryName \
        "$@") && \
    if [ "$packageDirectoryPath" ]; then
        local packageDependencyDescription && \
        for packageDependencyDescription in $(cat \
            "${packageDirectoryPath}depends" | grep --perl-regexp \
            --null-data --only-matching '%DEPENDS%(\n.+)+' | grep \
            --extended-regexp --invert-match '^%.+%$')
        do
            local packageName=$(echo "$packageDependencyDescription" | \
                grep --extended-regexp --only-matching '^[-a-zA-Z0-9]+')
            if ! echo "$_NEEDED_PACKAGES" 2>"$_ERROR_OUTPUT" | grep \
                " $packageName " 1>/dev/null 2>/dev/null
            then
                archInstallDeterminePackageDependencies "$packageName" \
                    "$2" recursive || \
                archInstallLog 'warning' \
                    "Needed package \"$packageName\" for \"$1\" couldn't be found in database in \"$2\"."
            fi
        done
    else
        returnCode=1
    fi
    # Trim resulting list.
    if [[ ! "$3" ]]; then
        _NEEDED_PACKAGES="$(echo "${_NEEDED_PACKAGES}" | sed \
            --regexp-extended 's/(^ +| +$)//g')"
    fi
    return $returnCode
}
archInstallDeterminePackageDirectoryName() {
    # Determines the package directory name from given package name in
    # given database.
    local packageDirectoryPath=$(grep "%PROVIDES%\n(.+\n)*$1\n(.+\n)*\n" \
        --perl-regexp --null-data "$2" --recursive --files-with-matches | \
        grep --extended-regexp '/depends$' | sed 's/depends$//' | head \
        --lines 1)
    if [ ! "$packageDirectoryPath" ]; then
        local regexPattern
        for packageDirectoryPattern in \
            "^$1-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$" \
            "^$1[0-9]+-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$" \
            "^[0-9]+$1[0-9]+-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$" \
            "^[0-9a-zA-Z]*acm[0-9a-zA-Z]*-([0-9a-zA-Z\.]+-[0-9a-zA-Z\.])$"
        do
            local packageDirectoryName=$(ls -1 "$2" | grep \
                --extended-regexp "$packageDirectoryPattern")
            if [ "$packageDirectoryName" ]; then
                break
            fi
        done
        if [ "$packageDirectoryName" ]; then
            packageDirectoryPath="$2/$packageDirectoryName/"
        fi
    fi
    echo "$packageDirectoryPath"
    return $?
}
archInstallDownloadAndExtractPacman() {
    # Downloads all packages from arch linux needed to run pacman.
    local listBufferFile="$1" && \
    if archInstallDeterminePacmansNeededPackages "$listBufferFile"; then
        archInstallLog \
            "Needed packages are: \"$(echo "${_NEEDED_PACKAGES[*]}" | sed \
            's/ /", "/g')\"." && \
        archInstallLog \
            "Download and extract each package into our new system located in \"$_MOUNTPOINT_PATH\"." && \
        local packageName && \
        for packageName in ${_NEEDED_PACKAGES[*]}; do
            local packageUrl=$(grep "$packageName-[0-9]" \
                "$listBufferFile" | head --lines 1)
            local fileName=$(echo $packageUrl \
                | sed 's/.*\/\([^\/][^\/]*\)$/\1/')
            # If "fileName" couldn't be determined via server determine it
            # via current package cache.
            if [ ! "$fileName" ]; then
                fileName=$(ls $_PACKAGE_CACHE_PATH | grep \
                    "$packageName-[0-9]" | head --lines 1)
            fi
            if [ "$fileName" ]; then
                wget "$packageUrl" --timestamping --continue \
                    --directory-prefix "${_PACKAGE_CACHE_PATH}/" \
                    1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            else
                archInstallLog \
                    'error' "A suitable file for package \"$packageName\" could not be determined."
            fi
            archInstallLog "Install package \"$fileName\" manually." && \
            xz --decompress --to-stdout "$_PACKAGE_CACHE_PATH/$fileName" \
                2>"$_ERROR_OUTPUT" | tar --extract --directory \
                "$_MOUNTPOINT_PATH" 1>"$_STANDARD_OUTPUT" \
                2>"$_ERROR_OUTPUT"
            local returnCode=$? && [[ $returnCode != 0 ]] && \
                return $returnCode
        done
    else
        return $?
    fi
    return 0
}
archInstallMakePartitions() {
    # Performs the auto partitioning.
    if $archInstall_auto_partitioning; then
        archInstallLog 'Check block device size.' && \
        local blockDeviceSpaceInMegaByte=$(($(blockdev --getsize64 \
            "$_OUTPUT_SYSTEM") * 1024 ** 2)) && \
        if [[ $(($_NEEDED_SYSTEM_SPACE_IN_MEGA_BYTE + \
              $_BOOT_SPACE_IN_MEGA_BYTE)) -le \
              $blockDeviceSpaceInMegaByte ]]; then
            archInstallLog 'Create boot and system partitions.' && \
            gdisk "$_OUTPUT_SYSTEM" << EOF \
                1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
o
Y
n


${_BOOT_SPACE_IN_MEGA_BYTE}M
ef00
n




c
1
$_BOOT_PARTITION_LABEL
c
2
$_SYSTEM_PARTITION_LABEL
w
Y
EOF
            # NOTE: "gdisk" returns an error code even if it runs
            # successfully.
            true
        else
            archInstallLog 'error' "Not enough space on \"$_OUTPUT_SYSTEM\" (\"$blockDeviceSpaceInByte\" byte). We need at least \"$(($_NEEDED_SYSTEM_SPACE_IN_BYTE + $_BOOT_SPACE_IN_BYTE))\" byte."
        fi
    else
        archInstallLog \
            "At least you have to create two partitions. The first one will be used as boot partition labeled to \"${_BOOT_PARTITION_LABEL}\" and second one will be used as system partition and labeled to \"${_SYSTEM_PARTITION_LABEL}\". Press Enter to continue." && \
        read && \
        archInstallLog 'Show blockdevices. Press Enter to continue.' && \
        lsblk && \
        read && \
        archInstallLog 'Create partitions manually.' && \
        gdisk "$_OUTPUT_SYSTEM"
    fi
    return $?
}
archInstallGenerateFstabConfigurationFile() {
    # Writes the fstab configuration file.
    archInstallLog 'Generate fstab config.' && \
    if hash genfstab 1>"$_STANDARD_OUTPUT" 2>/dev/null; then
        # NOTE: Mountpoint shouldn't have a path separator at the end.
        genfstab -L -p "${_MOUNTPOINT_PATH%?}" \
            1>>"${_MOUNTPOINT_PATH}etc/fstab" 2>"$_ERROR_OUTPUT"
    else
        cat << EOF 1>>"${_MOUNTPOINT_PATH}etc/fstab" 2>"$_ERROR_OUTPUT"
# Added during installation.
# <file system>                    <mount point> <type> <options>                                                                                            <dump> <pass>
# "compress=lzo" has lower compression ratio by better cpu performance.
PARTLABEL=$_SYSTEM_PARTITION_LABEL /             btrfs  relatime,ssd,discard,space_cache,autodefrag,inode_cache,subvol=root,compress=zlib                    0      0
PARTLABEL=$_BOOT_PARTITION_LABEL   /boot/        vfat   rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro 0      0
EOF
    fi
    return $?
}
archInstallUnmountInstalledSystem() {
    # Unmount previous installed system.
    archInstallLog 'Unmount installed system.' && \
    sync 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    cd / 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    umount "${_MOUNTPOINT_PATH}/boot" 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT"
    umount "$_MOUNTPOINT_PATH" 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    return $?
}
archInstallPrepareNextBoot() {
    # Reboots into fresh installed system if previous defined.
    if [ -b "$_OUTPUT_SYSTEM" ]; then
        archInstallGenerateFstabConfigurationFile && \
        archInstallAddBootEntries
        archInstallUnmountInstalledSystem
        local returnCode=$? && \
        if [[ $returnCode == 0 ]] && \
           $archInstall_automatic_reboot
        then
            archInstallLog 'Reboot into new operating system.'
            systemctl reboot 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" || \
            reboot 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
            return $?
        fi
        return $returnCode
    fi
    return $?
}
archInstallConfigurePacman() {
    # Disables signature checking for incoming packages.
    archInstallLog "Enable mirrors in \"$_COUNTRY_WITH_MIRRORS\"."
    local bufferFile=$(mktemp)
    local inArea=false
    local lineNumber=0
    local line
    while read line; do
        lineNumber=$(($lineNumber + 1)) && \
        if [[ "$line" == "## $_COUNTRY_WITH_MIRRORS" ]]; then
            inArea=true
        elif [[ "$line" == '' ]]; then
            inArea=false
        elif $inArea && [[ ${line:0:1} == '#' ]]; then
            line=${line:1}
        fi
        echo "$line"
    done < "${_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist" 1>"$bufferFile"
    cat "$bufferFile" 1>"${_MOUNTPOINT_PATH}etc/pacman.d/mirrorlist" \
        2>"$_ERROR_OUTPUT" && \
    archInstallLog \
        "Change signature level to \"Never\" for pacman's packages." && \
    sed --regexp-extended --in-place 's/^(SigLevel *= *).+$/\1Never/g' \
        "${_MOUNTPOINT_PATH}etc/pacman.conf" 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT"
    return $?
}
archInstallDetermineAutoPartitioning() {
    # Determine whether we should perform our auto partitioning mechanism.
    if ! $archInstall_auto_partitioning; then
        while true; do
            local auto_partitioning
            echo -n 'Do you want auto partioning? [yes|NO]: ' && \
            read auto_partitioning
            if [[ "$auto_partitioning" == '' ]] || \
               [[ $(echo "$auto_partitioning" | tr '[A-Z]' '[a-z]') == 'no' ]]
            then
                archInstall_auto_partitioning=false
                break
            elif [[ $(echo "$auto_partitioning" | tr '[A-Z]' '[a-z]') == 'yes' ]]
            then
                archInstall_auto_partitioning=true
                break
            fi
        done
    fi
    return 0
}
archInstallGetHostsContent() {
    # Provides the file content for the "/etc/hosts".
    cat << EOF
#<IP-Adress> <computername.workgroup> <computernames>
127.0.0.1    localhost.localdomain    localhost $1
::1          ipv6-localhost           ipv6-localhost ipv6-$1
EOF
}
archInstallPrepareBlockdevices() {
    # Prepares given block devices to make it ready for fresh installation.
    archInstallLog \
        "Unmount needed devices and devices pointing to our temporary system mount point \"$_MOUNTPOINT_PATH\"."
    umount -f "${_OUTPUT_SYSTEM}"* 1>"$_STANDARD_OUTPUT" 2>/dev/null
    umount -f "$_MOUNTPOINT_PATH" 1>"$_STANDARD_OUTPUT" 2>/dev/null
    swapoff "${_OUTPUT_SYSTEM}"* 1>"$_STANDARD_OUTPUT" 2>/dev/null
    archInstallLog \
        'Make partitions. Make a boot and system partition.' && \
    archInstallMakePartitions && \
    archInstallLog 'Format partitions.' && \
    archInstallFormatPartitions
    return $?
}
archInstallFormatSystemPartition() {
    # Prepares the system partition.
    local outputDevice="$_OUTPUT_SYSTEM" && \
    if [ -b "${_OUTPUT_SYSTEM}2" ]; then
        outputDevice="${_OUTPUT_SYSTEM}2"
    fi
    archInstallLog \
        "Make system partition at \"$outputDevice\"." && \
    mkfs.btrfs --force --label "$_SYSTEM_PARTITION_LABEL" "$outputDevice" \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    archInstallLog \
        "Creating a root sub volume in \"$outputDevice\"." && \
    mount PARTLABEL="$_SYSTEM_PARTITION_LABEL" "$_MOUNTPOINT_PATH" \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    btrfs subvolume create "${_MOUNTPOINT_PATH}root" \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    umount "$_MOUNTPOINT_PATH" 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    return $?
}
archInstallFormatBootPartition() {
    # Prepares the boot partition.
    archInstallLog 'Make boot partition.' && \
    mkfs.vfat -F 32 "${_OUTPUT_SYSTEM}1" \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    if hash dosfslabel 1>"$_STANDARD_OUTPUT" 2>/dev/null; then
        dosfslabel "${_OUTPUT_SYSTEM}1" "$_BOOT_PARTITION_LABEL" \
            1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    else
        archInstallLog 'warning' \
            "\"dosfslabel\" doesn't seem to be installed. Creating a boot partition label failed."
    fi
    return $?
}
archInstallFormatPartitions() {
    # Performs formating part.
    archInstallFormatSystemPartition && \
    archInstallFormatBootPartition
    return $?
}
archInstallAddBootEntries() {
    # Creates an uefi boot entry.
    if hash efibootmgr 1>"$_STANDARD_OUTPUT" 2>/dev/null; then
        archInstallLog 'Configure efi boot manager.' && \
        cat << EOF 1>"${_MOUNTPOINT_PATH}/boot/startup.nsh" 2>"$_ERROR_OUTPUT"
\vmlinuz-linux initrd=\initramfs-linux.img root=PARTLABEL=${_SYSTEM_PARTITION_LABEL} rw rootflags=subvol=root quiet loglevel=2 acpi_osi="!Windows 2012"
EOF
        archInstallChangeRootToMountPoint efibootmgr --create --disk \
            "$_OUTPUT_SYSTEM" --part 1 -l '\vmlinuz-linux' --label \
            "$_FALLBACK_BOOT_ENTRY_LABEL" --unicode \
            "initrd=\initramfs-linux-fallback.img root=PARTLABEL=${_SYSTEM_PARTITION_LABEL} rw rootflags=subvol=root break=premount break=postmount acpi_osi=\"!Windows 2012\"" \
            1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" || \
        archInstallLog 'warning' \
            "Adding boot entry \"${_FALLBACK_BOOT_ENTRY_LABEL}\" failed."
        # NOTE: Boot entry to boot on next reboot should be added at last.
        archInstallChangeRootToMountPoint efibootmgr --create --disk \
            "$_OUTPUT_SYSTEM" --part 1 -l '\vmlinuz-linux' --label \
            "$_BOOT_ENTRY_LABEL" --unicode \
            "initrd=\initramfs-linux.img root=PARTLABEL=${_SYSTEM_PARTITION_LABEL} rw rootflags=subvol=root quiet loglevel=2 acpi_osi=\"!Windows 2012\"" \
            1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" || \
        archInstallLog 'warning' \
            "Adding boot entry \"${_BOOT_ENTRY_LABEL}\" failed."
    else
        archInstallLog 'warning' \
            "\"efibootmgr\" doesn't seem to be installed. Creating a boot entry failed."
    fi
    return $?
}
archInstallLoadCache() {
    # Load previous downloaded packages and database.
    archInstallLog 'Load cached databases.' && \
    mkdir --parents \
        "$_MOUNTPOINT_PATH"var/lib/pacman/sync \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    cp --no-clobber --preserve "$_PACKAGE_CACHE_PATH"/*.db \
        "$_MOUNTPOINT_PATH"var/lib/pacman/sync/ \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    archInstallLog 'Load cached packages.' && \
    mkdir --parents "$_MOUNTPOINT_PATH"var/cache/pacman/pkg \
        1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT" && \
    cp --no-clobber --preserve "$_PACKAGE_CACHE_PATH"/*.pkg.tar.xz \
        "$_MOUNTPOINT_PATH"var/cache/pacman/pkg/ 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT"
    return $?
}
archInstallCache() {
    # Cache previous downloaded packages and database.
    archInstallLog 'Cache loaded packages.'
    cp --force --preserve \
        "$_MOUNTPOINT_PATH"var/cache/pacman/pkg/*.pkg.tar.xz \
        "$_PACKAGE_CACHE_PATH"/ 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT" && \
    archInstallLog 'Cache loaded databases.' && \
    cp --force --preserve \
        "$_MOUNTPOINT_PATH"var/lib/pacman/sync/*.db \
        "$_PACKAGE_CACHE_PATH"/ 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    return $?
}
archInstallPrepareInstallation() {
    # Deletes previous installed things in given output target. And creates
    # a package cache directory.
    mkdir --parents "$_PACKAGE_CACHE_PATH" 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT" && \
    if [ -b "$_OUTPUT_SYSTEM" ]; then
        archInstallLog 'Mount system partition.' && \
        mount PARTLABEL="$_SYSTEM_PARTITION_LABEL" -o subvol=root \
            "$_MOUNTPOINT_PATH" 1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    fi
    archInstallLog \
        "Clear previous installations in \"$_MOUNTPOINT_PATH\"." && \
    rm "$_MOUNTPOINT_PATH"* --recursive --force 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT" && \
    if [ -b "$_OUTPUT_SYSTEM" ]; then
        archInstallLog \
            "Mount boot partition in \"${_MOUNTPOINT_PATH}boot/\"." && \
        mkdir --parents "${_MOUNTPOINT_PATH}boot/" && \
        mount PARTLABEL="$_BOOT_PARTITION_LABEL" \
            "${_MOUNTPOINT_PATH}boot/" 1>"$_STANDARD_OUTPUT" \
            2>"$_ERROR_OUTPUT" && \
        rm "${_MOUNTPOINT_PATH}boot/"* --recursive --force \
            1>"$_STANDARD_OUTPUT" 2>"$_ERROR_OUTPUT"
    fi
    archInstallLog 'Set filesystem rights.' && \
    chmod 755 "$_MOUNTPOINT_PATH" 1>"$_STANDARD_OUTPUT" \
        2>"$_ERROR_OUTPUT" && \
    local returnCode=$?
    # Make a uniqe array.
    _PACKAGES=$(echo "${_PACKAGES[*]}" | tr ' ' '\n' | sort -u | tr '\n' \
        ' ')
    return $returnCode
}
## endregion
## region controller
main() {
    # Provides the main module scope.
    bl.logging.set_command_output_off
    archInstall.command_line_interface "$@" || return $?
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
            grep --quiet --extended-regexp '[0-9]$'
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
    main "$@"
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
