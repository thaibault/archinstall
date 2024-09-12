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
declare -gr PIA__DOCUMENTATION__='
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
declare -agr PIA__DEPENDENCIES__=(
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
declare -agr PIA__OPTIONAL_DEPENDENCIES__=(
    'sudo: Perform action as another user.'
    'arch-install-scripts: Supports to perform an arch-chroot.'
)
## region commandline arguments
declare -g PIA_SQUASH_FILESYSTEM_COMPRESSOR=gzip
declare -g PIA_KEYBOARD_LAYOUT=de-latin1
declare -g PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT="KEYMAP=${PIA_KEYBOARD_LAYOUT}"$'\nFONT=Lat2-Terminus16\nFONT_MAP='
## endregion
declare -g PIA_SOURCE_PATH=''
declare -g PIA_TARGET_PATH=''
declare -g PIA_MOUNTPOINT_PATH="$(mktemp --directory)"
declare -g PIA_TEMPORARY_REMASTERING_PATH="$(mktemp --directory)"
declare -g PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH="$(
    mktemp --directory
)/mnt"
declare -g PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH="$(
    mktemp --directory
)"
declare -ag PIA_RELATIVE_PATHS_TO_SQUASH_FILESYSTEM=(
    arch/i686/root-image.fs.sfs
    arch/x86_64/root-image.fs.sfs
)
declare -g PIA_RELATIVE_SOURCE_FILE_PATH=archInstall.sh
declare -g PIA_RELATIVE_TARGET_FILE_PATH=usr/bin/
declare -g PIA_BASHRC_CODE=$'\nalias getInstallScript='"'wget https://goo.gl/bPAqXB --output-document archInstall.sh && chmod +x archInstall.sh'"$'\nalias install='"'([ -f /root/archInstall.sh ] || getInstallScript);/root/archInstall.sh'"

BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^packIntoArchiso([._][a-zA-Z_-]+)?$/pai\1/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^PACK_INTO_ARCHISO(_[a-zA-Z_-]+)?$/PIA\1/')
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

-c --squash-filesystem-compressor Defines the squash filesystem compressor. All supported compressors for "mksquashfs" are possible (default: "$PIA_SQUASH_FILESYSTEM_COMPRESSOR").

-k --keyboard-layout Defines needed key map (default: "$PIA_KEYBOARD_LAYOUT").

-m --key-map-configuration FILE_CONTENT Keyboard map configuration (default: "$PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT").
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
    echo -e "$PIA__DOCUMENTATION__"
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
                PIA_SQUASH_FILESYSTEM_COMPRESSOR="$1"
                shift
                ;;
            -k|--keyboard-layout)
                shift
                PIA_KEYBOARD_LAYOUT="$1"
                shift
                ;;
            -m|--key-map-configuation)
                shift
                PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT="$1"
                shift
                ;;

            '')
                shift
                break
                ;;
            *)
                if [[ ! "$PIA_SOURCE_PATH" ]]; then
                    PIA_SOURCE_PATH="$1"
                elif [[ ! "$PIA_TARGET_PATH" ]]; then
                    PIA_TARGET_PATH="$1"
                    if [ -d "$PIA_TARGET_PATH" ]; then
                        PIA_TARGET_PATH="$(
                            readlink \
                                --canonicalize \
                                "$PIA_TARGET_PATH"
                        )/$(basename "$PIA_SOURCE_PATH")"
                    fi
                else
                    bl.logging.critical \
                        "Given argument: \"$1\" is not available." '\n'
                    bl.logging.plain "$(pia.get_help_message "$0")"
                fi
                shift
        esac
    done
    if [[ ! "$PIA_SOURCE_PATH" ]] || [[ ! "$PIA_TARGET_PATH" ]]; then
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
        "Mount \"$PIA_SOURCE_PATH\" to \"$PIA_MOUNTPOINT_PATH\"."
    mount -t iso9660 -o loop "$PIA_SOURCE_PATH" "$PIA_TARGET_PATH"
    bl.logging.info \
        "Copy content in \"$PIA_MOUNTPOINT_PATH\" to \"$PIA_TEMPORARY_REMASTERING_PATH\"."
    cp --archiv "${PIA_MOUNTPOINT_PATH}/"* "$PIA_TEMPORARY_REMASTERING_PATH"
    local path
    local -i return_code=0
    for path in "${PIA_RELATIVE_PATHS_TO_SQUASH_FILESYSTEM[@]}"; do
        bl.logging.info "Extract squash file system in \"${PIA_TEMPORARY_REMASTERING_PATH}/${path}\" to \"${PIA_TEMPORARY_REMASTERING_PATH}\"."
        unsquashfs \
            -d "${PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH}" \
            "${PIA_TEMPORARY_REMASTERING_PATH}/${path}"
        rm --force "${PIA_TEMPORARY_REMASTERING_PATH}/${path}"
        bl.logging.info "Mount root file system in \"${PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH}\" to \"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}\"."
        mount \
            "${PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH}/"* \
            "$_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH"
        bl.logging.info "Copy \"$(
            dirname "$(readlink --canonicalize "$0")"
        )/${PIA_RELATIVE_SOURCE_FILE_PATH}\" to \"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}/${PIA_RELATIVE_TARGET_FILE_PATH}\"."
        cp \
            "$(dirname "$(readlink --canonicalize "$0")")/$_RELATIVE_SOURCE_FILE_PATH" \
            "${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}/${PIA_RELATIVE_TARGET_FILE_PATH}"
        bl.logging.info "Set key map to \"$PIA_KEYBOARD_LAYOUT\"."
        if [ "$1" = true ]; then
            arch-chroot \
                "$PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH" \
                localectl set-keymap "$PIA_KEYBOARD_LAYOUT"
            arch-chroot \
                "$PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH" \
                set-locale LANG=en_US.utf8
        else
            bl.logging.plain \
                "$PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT" \
                    1>"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}/etc/vconsole.conf"
        fi
        bl.logging.info Set root symbolic link for root user.
        local file_name
        for file_name in .bashrc .cshrc .kshrc .zshrc; do
            if [ -f "${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}/root/$file_name" ]; then
                bl.logging.plain \
                    "$PIA_BASHRC_CODE" \
                        1>>"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}/root/$file_name"
            else
                bl.logging.plain \
                    "$PIA_BASHRC_CODE" \
                        1>"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}/root/$file_name"
            fi
        done
        bl.logging.info "Unmount \"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}\"."
        umount "$PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH"
        bl.logging.info "Make new squash file system from \"${PIA_TEMPORARY_REMASTERING_PATH}\" to \"${PIA_TEMPORARY_REMASTERING_PATH}/${path}\"."
        mksquashfs \
            "${PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH}" \
            "${PIA_TEMPORARY_REMASTERING_PATH}/${path}" \
            -noappend \
            -comp \
            "$PIA_SQUASH_FILESYSTEM_COMPRESSOR"
        rm \
            --force \
            --recursive \
            "${PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH}"
        return_code=$?
        if (( return_code != 0 )); then
            bl.logging.info "Unmount \"$PIA_MOUNTPOINT_PATH\"."
            umount "$PIA_MOUNTPOINT_PATH"
            return $?
        fi
    done
    local -r volume_id="$(
        isoinfo -i "$PIA_SOURCE_PATH" -d | \
            command grep --extended-regexp 'Volume id:' | \
                command grep --extended-regexp --only-matching '[^ ]+$'
    )"
    bl.logging.info "Create new iso file from \"$PIA_TEMPORARY_REMASTERING_PATH\" in \"${PIA_TARGET_PATH}\" with old detected volume id \"${volume_id}\"."
    pushd "${PIA_MOUNTPOINT_PATH}" && \
    genisoimage \
        -boot-info-table \
        -boot-load-size 4 \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -full-iso9660-filenames \
        -joliet \
        -no-emul-boot \
        -output "$PIA_TARGET_PATH" \
        -rational-rock \
        -verbose \
        --volid "$volume_id" \
        "$PIA_TEMPORARY_REMASTERING_PATH"
    popd && \
    bl.logging.info "Unmount \"$PIA_MOUNTPOINT_PATH\"."
    umount "$PIA_MOUNTPOINT_PATH"
}
alias pia.tidy_up=pia_tidy_up
pia_tidy_up() {
    local -r __documentation__='
        Removes temporary created files.
    '
    bl.logging.info \
        "Remove temporary created location \"${PIA_MOUNTPOINT_PATH}\"."
    rm --force --recursive "$PIA_MOUNTPOINT_PATH"
    bl.logging.info \
        "Remove temporary created location \"${PIA_TEMPORARY_REMASTERING_PATH}\"."
    rm \
        --force \
        --recursive \
        "$PIA_TEMPORARY_REMASTERING_PATH"
    bl.logging.info \
        "Remove temporary created location \"${PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH}\"."
    rm \
        --force \
        --recursive \
        "$PIA_TEMPORARY_FILESYSTEM_REMASTERING_PATH"
    bl.logging.info \
        "Remove temporary created location \"${PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH}\"."
    rm \
        --force \
        --recursive \
        "$PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH"
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
        Remastering given image \""$PIA_SOURCE_PATH"\" to \
        \""$PIA_TARGET_PATH"\" has successfully finished.
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
