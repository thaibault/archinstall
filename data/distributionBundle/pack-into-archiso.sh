#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]tsickert.com) 16.12.2012

# License
# -------

# This library written by Torben Sickert stands under a creative commons naming
# 4.0 international license.
# See https://creativecommons.org/licenses/by/4.0/deed.de
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
# NOTE: Shortens this module's scope to "pia_*" and "PIA_*" names.
BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^pack\.into\.archiso$/pia/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^PACK_INTO_ARCHISO$/PIA/')
bl.module.import bashlink.logging
bl.module.import bashlink.tools
# endregion
# region variables
declare -gr PIA__DOCUMENTATION__='
    This module modifies a given arch linux iso image.

    Packs archinstall into the live system of the given archiso image.

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
    grep
    mktemp
    libisoburn
    readlink
    rm
    sed
    squashfs-tools
)
declare -agr PIA__OPTIONAL_DEPENDENCIES__=(
    'sudo: Perform action as another user.'
)
## region commandline arguments
declare -g PIA_SQUASH_FILESYSTEM_COMPRESSOR=gzip
declare -g PIA_KEYBOARD_LAYOUT=de-latin1
declare -g PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT="KEYMAP=${PIA_KEYBOARD_LAYOUT}"$'\nFONT=Lat2-Terminus16\nFONT_MAP='
## endregion
declare -g PIA_SOURCE_PATH=''
declare -g PIA_TARGET_PATH=''
declare -g PIA_TEMPORARY_REMASTERING_PATH="$(mktemp --directory)"
declare -g PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH="$(
    mktemp --directory
)"
declare -g PIA_RELATIVE_SQUASH_FILESYSTEM_PATH=arch/x86_64/airootfs.sfs
declare -g PIA_RELATIVE_SOURCE_FILE_PATH=archinstall.sh
declare -g PIA_RELATIVE_TARGET_FILE_PATH=usr/bin/
declare -g PIA_SHELL_CONFIGURATION=$'\nalias install=archinstall.sh\nalias getInstallScript='"'curl --output archinstall.sh https://raw.githubusercontent.com/thaibault/archinstall/main/archinstall.sh && chmod +x archinstall.sh'"

BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^pack\.into\.archiso([._][a-zA-Z_-]+)?$/pia\1/')
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

        >>> pia.commandline_interface source.iso target.iso \
        >>>     --keyboard-layout us --squash-filesystem-compressor xz
        >>> echo "$PIA_SOURCE_PATH $PIA_TARGET_PATH"
        >>> echo "$PIA_KEYBOARD_LAYOUT $PIA_SQUASH_FILESYSTEM_COMPRESSOR"
        >>> echo "$PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT" | head --lines 1
        source.iso target.iso
        us xz
        KEYMAP=us

        >>> local target_path="$(pia_bl_doctest_mktemp --directory)"
        >>> pia.commandline_interface path/to/source.iso "$target_path"
        >>> [ "$PIA_TARGET_PATH" = \
        >>>     "$(readlink --canonicalize "$target_path")/source.iso" ] && \
        >>>         echo yes
        yes
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
                # NOTE: Keep the key map configuration in sync.
                PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT="$(
                    echo "$PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT" | \
                        command sed "s/^KEYMAP=.*$/KEYMAP=${1}/"
                )"
                shift
                ;;
            -m|--key-map-configuration)
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
        Remasters given iso into new iso: Adds archinstall (and bashlink if
        available) to the live root file system, configures its keyboard
        layout and replays the original boot configuration.
    '
    local -r source_directory_path="$(
        dirname "$(readlink --canonicalize "$0")"
    )"
    local -r squash_file_system_path="${PIA_TEMPORARY_REMASTERING_PATH}/airootfs.sfs"
    local -r checksum_file_path="${PIA_TEMPORARY_REMASTERING_PATH}/airootfs.sha512"
    local -r root_path="$PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH"
    bl.logging.info \
        "Extract \"/${PIA_RELATIVE_SQUASH_FILESYSTEM_PATH}\" from \"${PIA_SOURCE_PATH}\"."
    xorriso \
        -osirrox on \
        -indev "$PIA_SOURCE_PATH" \
        -extract \
            "/$PIA_RELATIVE_SQUASH_FILESYSTEM_PATH" \
            "$squash_file_system_path" \
                2>/dev/null || \
                    return $?
    bl.logging.info "Unpack root file system to \"${root_path}\"."
    rm --force --recursive "$root_path"
    unsquashfs -quiet -dest "$root_path" "$squash_file_system_path" \
        1>/dev/null || \
            return $?
    bl.logging.info \
        "Copy \"${PIA_RELATIVE_SOURCE_FILE_PATH}\" to \"/${PIA_RELATIVE_TARGET_FILE_PATH}\"."
    install \
        -D \
        --mode 755 \
        "${source_directory_path}/${PIA_RELATIVE_SOURCE_FILE_PATH}" \
        "${root_path}/${PIA_RELATIVE_TARGET_FILE_PATH}${PIA_RELATIVE_SOURCE_FILE_PATH}"
    local bashlink_path
    for bashlink_path in \
        "${source_directory_path}/node_modules/bashlink" \
        /usr/lib/bashlink
    do
        if [ -f "${bashlink_path}/module.sh" ]; then
            bl.logging.info \
                "Copy bashlink from \"${bashlink_path}\" to provide it offline."
            mkdir --parents "${root_path}/usr/lib/bashlink"
            cp \
                --dereference \
                --recursive \
                "${bashlink_path}/"* \
                "${root_path}/usr/lib/bashlink/"
            break
        fi
    done
    bl.logging.info "Set key map to \"$PIA_KEYBOARD_LAYOUT\"."
    echo -e "$PIA_KEY_MAP_CONFIGURATION_FILE_CONTENT" \
        1>"${root_path}/etc/vconsole.conf"
    bl.logging.info Register shortcuts for root user.
    local file_name
    for file_name in .bashrc .zshrc; do
        echo "$PIA_SHELL_CONFIGURATION" \
            1>>"${root_path}/root/$file_name"
    done
    bl.logging.info Pack new root file system.
    mksquashfs \
        "$root_path" \
        "$squash_file_system_path" \
        -noappend \
        -comp "$PIA_SQUASH_FILESYSTEM_COMPRESSOR" \
            1>/dev/null || \
                return $?
    (
        cd "$PIA_TEMPORARY_REMASTERING_PATH" && \
        sha512sum airootfs.sfs 1>"$checksum_file_path"
    )
    # NOTE: Archiso finds its boot medium via the volume date as uuid.
    local -r volume_date="$(
        xorriso -indev "$PIA_SOURCE_PATH" -pvd_info 2>/dev/null | \
            command sed \
                --quiet \
                --regexp-extended \
                's/^Modif\. Time *: *([0-9]{16}).*$/\1/p'
    )"
    bl.logging.info \
        "Create new iso file \"${PIA_TARGET_PATH}\" with original boot configuration and volume date \"${volume_date}\"."
    rm --force "$PIA_TARGET_PATH"
    xorriso \
        -indev "$PIA_SOURCE_PATH" \
        -outdev "$PIA_TARGET_PATH" \
        -map \
            "$squash_file_system_path" \
            "/$PIA_RELATIVE_SQUASH_FILESYSTEM_PATH" \
        -map \
            "$checksum_file_path" \
            "/${PIA_RELATIVE_SQUASH_FILESYSTEM_PATH%.sfs}.sha512" \
        -rm_r "/${PIA_RELATIVE_SQUASH_FILESYSTEM_PATH}.cms.sig" -- \
        -volume_date uuid "$volume_date" \
        -boot_image any replay \
            2>/dev/null
}
alias pia.tidy_up=pia_tidy_up
pia_tidy_up() {
    local -r __documentation__='
        Removes temporary created files.

        >>> local PIA_TEMPORARY_REMASTERING_PATH="$(
        >>>     pia_bl_doctest_mktemp --directory)"
        >>> local PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH="$(
        >>>     pia_bl_doctest_mktemp --directory)"
        >>> touch "${PIA_TEMPORARY_REMASTERING_PATH}/file"
        >>> pia.tidy_up
        >>> ls --directory \
        >>>     "$PIA_TEMPORARY_REMASTERING_PATH" \
        >>>     "$PIA_TEMPORARY_ROOT_FILESYSTEM_REMASTERING_PATH" \
        >>>         2>/dev/null
        >>> echo $?
        2
    '
    bl.logging.info \
        "Remove temporary created location \"${PIA_TEMPORARY_REMASTERING_PATH}\"."
    rm \
        --force \
        --recursive \
        "$PIA_TEMPORARY_REMASTERING_PATH"
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
    if (( UID != 0 )) && command grep root /etc/passwd &>/dev/null; then
        sudo -u root "$0" "$@"
        return $?
    fi
    pia.remaster_iso || \
        bl.logging.critical Remastering given iso failed.
    pia.tidy_up || \
        bl.logging.critical Tidying up failed.
    bl.logging.info \
        "Remastering given image \"${PIA_SOURCE_PATH}\" to \"${PIA_TARGET_PATH}\" has successfully finished."
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
