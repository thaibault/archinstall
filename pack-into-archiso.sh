#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. See https://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC2016,SC2034,SC2155
# region import
if [ -f "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh" ]; then
    # shellcheck disable=SC1090
    source "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh"
elif [ -f "/usr/lib/bashlink/module.sh" ]; then
    # shellcheck disable=SC1091
    source "/usr/lib/bashlink/module.sh"
else
    echo Needed bashlink library not found 1>&2
    exit 1
fi
bl.module.import bashlink.logging
bl.module.import bashlink.tools
# endregion
# region variables
declare -gr pia__documentation__='
    This module modifies a given arch linux iso image.

    Packs the current pack-into-archiso.bash script into the archiso image.

    Remaster archiso file.

    ```bash
        pack-into-archiso ./archiso.iso ./remasteredArchiso.iso
    ```

    Remaster archiso file verbosely.

    ```bash
        pack-into-archiso ./archiso.iso ./remasteredArchiso.iso --verbose
    ```

    Show help message.

    ```bash
        pack-into-archiso --help
    ```
'
declare -agr pia__dependencies__=(
    bash
    cdrkit
    grep
    mktemp
    mount
    readlink
    rm
    squashfs-tools
    touch
    umount
)
declare -agr pia__optional_dependencies__=(
    'sudo: Perform action as another user.'
    'arch-install-scripts: Supports to perform an arch-chroot.'
)
## region commandline arguments
declare -g pia_squash_filesystem_compressor=gzip
declare -g pia_keyboard_layout=de-latin1
declare -g pia_key_map_configuration_file_content="KEYMAP=${pia_keyboard_layout}"$'\nFONT=Lat2-Terminus16\nFONT_MAP='
## endregion
declare -g pia_source_path=''
declare -g pia_target_path=''
declare -g pia_mountpoint_path="$(mktemp --directory)"
declare -g pia_temporary_remastering_path="$(mktemp --directory)"
declare -g pia_temporary_filesystem_remastering_path="$(
    mktemp --directory
)/mnt"
declare -g pia_temporary_root_filesystem_remastering_path="$(
    mktemp --directory)"
declare -ag pia_relative_paths_to_squash_filesystem=(
    arch/i686/root-image.fs.sfs
    arch/x86_64/root-image.fs.sfs
)
declare -g pia_relative_source_file_path=archInstall.sh
declare -g pia_relative_target_file_path=usr/bin/
declare -g pia_bashrc_code=$'\nalias getInstallScript='"'wget https://goo.gl/bPAqXB --output-document archInstall.sh && chmod +x archInstall.sh'"$'\nalias install='"'([ -f /root/archInstall.sh ] || getInstallScript);/root/archInstall.sh'"
bl_module_scope_rewrites+=(
    '^pack[._]into[._]archiso([._][a-zA-Z_-]+)?$/pia\1/'
)
# endregion
# region functions
## region command line interface
alias pia.get_commandline_option_description=pia_get_commandline_option_description
pia_get_commandline_option_description() {
    local -r __documentation__='
        Prints descriptions about each available command line option.

        >>> pia.get_commandline_option_description
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        -h --help Shows this help message.
        ...
    '
    # NOTE: "-k" and "--key-map-configuration" isn't needed in the future.
    cat << EOF
-h --help Shows this help message.

-v --verbose Tells you what is going on (default: "false").

-d --debug Gives you any output from all tools which are used (default: "false").

-c --squash-filesystem-compressor Defines the squash filesystem compressor. All supported compressors for "mksquashfs" are possible (default: "$pia_squash_filesystem_compressor").

-k --keyboard-layout Defines needed key map (default: "$pia_keyboard_layout").

-m --key-map-configuration FILE_CONTENT Keyboard map configuration (default: "$pia_key_map_configuration_file_content").
EOF
}
alias pia.get_help_message=pia_get_help_message
pia_get_help_message() {
    local -r __documentation__='
        Provides a help message for this module.

        >>> pia.get_help_message
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        ...
        Usage: pack-into-archiso /path/to/archiso/file.iso /path/to/newly/packe
        ...
    '
    echo -e $'\nUsage: pack-into-archiso /path/to/archiso/file.iso /path/to/newly/packed/archiso/file.iso [options]\n'
    echo -e "$pia__documentation__"
    echo -e $'\nOption descriptions:\n'
    pia.get_commandline_option_description "$@"
    echo
}
alias pia.commandline_interface=pia_commandline_interface
pia_commandline_interface() {
    local -r __documentation__='
        Provides the command line interface and interactive questions.

        >>> pia.commandline_interface
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        You have to provide source and target file path.
        ...
    '
    while true; do
        case "$1" in
            -h|--help)
                shift
                bl.logging.plain "$(pia.get_help_message "$0")"
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
            -c|--squash-filesystem-compressor)
                shift
                pia_squash_filesystem_compressor="$1"
                shift
                ;;
            -k|--keyboard-layout)
                shift
                pia_keyboard_layout="$1"
                shift
                ;;
            -m|--key-map-configuation)
                shift
                pia_key_map_configuration_file_content="$1"
                shift
                ;;

            '')
                shift
                break
                ;;
            *)
                if [[ ! "$pia_source_path" ]]; then
                    pia_source_path="$1"
                elif [[ ! "$pia_target_path" ]]; then
                    pia_target_path="$1"
                    if [ -d "$pia_target_path" ]; then
                        pia_target_path="$(
                            readlink \
                                --canonicalize \
                                "$pia_target_path"
                        )/$(basename "$pia_source_path")"
                    fi
                else
                    bl.logging.critical \
                        "Given argument: \"$1\" is not available." '\n'
                    bl.logging.plain "$(pia.get_help_message "$0")"
                fi
                shift
        esac
    done
    if \
        [[ ! "$pia_source_path" ]] || \
        [[ ! "$pia_target_path" ]]
    then
        bl.logging.critical \
            You have to provide source and target file path. $'\n'
        bl.logging.plain "$(pia.get_help_message "$0")"
        return 1
    fi
}
## endregion
## region helper
alias pia.remaster_iso=pia_remaster_iso
pia_remaster_iso() {
    local -r __documentation__='
        Remasters given iso into new iso. If new systemd programs are used (if
        first argument is "true") they could have problems in change root
        environment without and exclusive dbus connection.
    '
    bl.logging.info \
        "Mount \"$pia_source_path\" to \"$pia_mountpoint_path\"."
    mount \
        -t iso9660 \
        -o loop \
        "$pia_source_path" \
        "$pia_target_path"
    bl.logging.info \
        "Copy content in \"$pia_mountpoint_path\" to \"$pia_temporary_remastering_path\"."
    cp --archiv "${pia_mountpoint_path}/"* "$pia_temporary_remastering_path"
    local path
    local -i return_code=0
    for path in "${pia_relative_paths_to_squash_filesystem[@]}"; do
        bl.logging.info "Extract squash file system in \"${pia_temporary_remastering_path}/$path\" to \"${pia_temporary_remastering_path}\"."
        unsquashfs \
            -d "${pia_temporary_filesystem_remastering_path}" \
            "${pia_temporary_remastering_path}/${path}"
        rm --force "${pia_temporary_remastering_path}/${path}"
        bl.logging.info "Mount root file system in \"${pia_temporary_filesystem_remastering_path}\" to \"${pia_temporary_root_filesystem_remastering_path}\"."
        mount \
            "${pia_temporary_filesystem_remastering_path}/"* \
            "$_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH"
        bl.logging.info "Copy \"$(
            dirname "$(readlink --canonicalize "$0")"
        )/$pia_relative_source_file_path\" to \"${pia_temporary_root_filesystem_remastering_path}/${pia_relative_target_file_path}\"."
        cp \
            "$(dirname "$(readlink --canonicalize "$0")")/$_RELATIVE_SOURCE_FILE_PATH" \
            "${pia_temporary_root_filesystem_remastering_path}/${pia_relative_target_file_path}"
        bl.logging.info "Set key map to \"$pia_keyboard_layout\"."
        if [ "$1" = true ]; then
            arch-chroot \
                "$pia_temporary_root_filesystem_remastering_path" \
                localectl set-keymap "$pia_keyboard_layout"
            arch-chroot \
                "$pia_temporary_root_filesystem_remastering_path" \
                set-locale LANG=en_US.utf8
        else
            bl.logging.plain \
                "$pia_key_map_configuration_file_content" \
                    1>"${pia_temporary_root_filesystem_remastering_path}/etc/vconsole.conf"
        fi
        bl.logging.info Set root symbolic link for root user.
        local file_name
        for file_name in .bashrc .cshrc .kshrc .zshrc; do
            if [ -f "${pia_temporary_root_filesystem_remastering_path}/root/$file_name" ]; then
                bl.logging.plain \
                    "$pia_bashrc_code" \
                        1>>"${pia_temporary_root_filesystem_remastering_path}/root/$file_name"
            else
                bl.logging.plain \
                    "$pia_bashrc_code" \
                        1>"${pia_temporary_root_filesystem_remastering_path}/root/$file_name"
            fi
        done
        bl.logging.info "Unmount \"$pia_temporary_root_filesystem_remastering_path\"."
        umount "$pia_temporary_root_filesystem_remastering_path"
        bl.logging.info "Make new squash file system from \"${pia_temporary_remastering_path}\" to \"${pia_temporary_remastering_path}/${path}\"."
        mksquashfs \
            "${pia_temporary_filesystem_remastering_path}" \
            "${pia_temporary_remastering_path}/${path}" \
            -noappend \
            -comp \
            "$pia_squash_filesystem_compressor"
        rm \
            --force \
            --recursive \
            "${pia_temporary_filesystem_remastering_path}"
        return_code=$?
        if (( return_code != 0 )); then
            bl.logging.info "Unmount \"$pia_mountpoint_path\"."
            umount "$pia_mountpoint_path"
            return $?
        fi
    done
    local -r volume_id="$(
        isoinfo -i "$pia_source_path" -d | \
            command grep --extended-regexp 'Volume id:' | \
                command grep --extended-regexp --only-matching '[^ ]+$'
    )"
    bl.logging.info "Create new iso file from \"$pia_temporary_remastering_path\" in \"$pia_target_path\" with old detected volume id \"$volume_id\"."
    pushd "${pia_mountpoint_path}" && \
    genisoimage \
        -boot-info-table \
        -boot-load-size 4 \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -full-iso9660-filenames \
        -joliet \
        -no-emul-boot \
        -output "$pia_target_path" \
        -rational-rock \
        -verbose \
        --volid "$volume_id" \
        "$pia_temporary_remastering_path"
    popd && \
    bl.logging.info "Unmount \"$pia_mountpoint_path\"."
    umount "$pia_mountpoint_path"
}
alias pia.tidy_up=pia_tidy_up
pia_tidy_up() {
    local -r __documentation__='
        Removes temporary created files.
    '
    bl.logging.info \
        "Remove temporary created location \"$pia_mountpoint_path\"."
    rm \
        --force \
        --recursive \
        "$pia_mountpoint_path"
    bl.logging.info \
        "Remove temporary created location \"$pia_temporary_remastering_path\"."
    rm \
        --force \
        --recursive \
        "$pia_temporary_remastering_path"
    bl.logging.info \
        "Remove temporary created location \"$pia_temporary_filesystem_remastering_path\"."
    rm \
        --force \
        --recursive \
        "$pia_temporary_filesystem_remastering_path"
    bl.logging.info \
        "Remove temporary created location \"$pia_temporary_root_filesystem_remastering_path\"."
    rm \
        --force \
        --recursive \
        "$pia_temporary_root_filesystem_remastering_path"
}
## endregion
## region controller
alias pia.main=pia_main
pia_main() {
    local -r __documentation__='
        Main injected point for this module.

        >>> pia.main --help
        +bl.doctest.contains
        +bl.doctest.multiline_ellipsis
        ...
        Usage: pack-into-archiso /path/to/archiso/file.iso /path/to/newly/packe
        ...
    '
    pia.commandline_interface "$@" || \
        return $?
    # Switch user if necessary and possible.
    if [[ "$USER" != root ]] && command grep root /etc/passwd &>/dev/null; then
        sudo -u root "$0" "$@"
        return $?
    fi
    pia.remaster_iso || \
        bl.logging.critical Remastering given iso failed.
    pia.tidy_up || \
        bl.logging.critical Tidying up failed.
    bl.logging.info
        "Remastering given image \"$pia_source_path\" to \"$pia_target_path\" has successfully finished."
}
## endregion
# endregion
if bl.tools.is_main; then
    pia.main "$@"
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
