#!/bin/bash

function srcinfo.parse_key_val() {
    local key value split=() input="${1}"
    declare -n out_array="${2}"
    split=(${input/=/ })
    out_array=([key]="${split[0]}" [value]="${split[1]}")
}

function srcinfo._basic_check() {
    [[ "${1}" == *"="* ]]
}

function srcinfo.parse() {
    local OPTION OPTIND pacstall_compat=false srcinfo_file var_prefix
    while getopts 'p' OPTION; do
        case "${OPTION}" in
            p) pacstall_compat=true ;;
            ?) echo "Usage: ${FUNCNAME[0]} [-p] SRCINFO [var_prefix]" >&2 && return 2 ;;
        esac
    done
    shift $((OPTIND - 1))
    srcinfo_file="${1:?No SRCINFO passed to srcinfo.parse}"
    [[ -n "${2}" ]] && var_prefix="${2}"
    [[ ! -s "${srcinfo_file}" ]] && return 5
    while IFS= read -r line; do
        # Skip blank lines
        [[ -z "${line}" ]] && continue
        declare -A temp_line
        if ! srcinfo._basic_check "${line}"; then
            echo "Could not parse line: '${line}'" >&2
            return 3
        fi
        srcinfo.parse_key_val "${line}" temp_line
        if [[ -z "${temp_line[value]}" ]]; then
            echo "Empty value for: '${line}'" >&2
            return 4
        fi
    done < "${srcinfo_file}"
}
