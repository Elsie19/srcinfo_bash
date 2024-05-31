#!/bin/bash
# @file srcinfo.sh
# @brief A library for parsing SRCINFO into native bash dictionaries.
# @description
#   This library is used for parsing SRCINFO into native bash dictionaries.
#   Since Bash as of now does not have multidimensional arrays, srcinfo_bash
#   takes a lot of liberties with creating arrays, and tries its hardest to make
#   them easy to access.

# @description Split a key value pair into an associated array.
#
# @example
#   declare -A out
#   srcinfo.parse_key_val 'foo = bar' out
#
# @arg $1 string Key value assignment
# @arg $2 string Name of associated array
function srcinfo.parse_key_val() {
    local key value input="${1}"
    declare -n out_array="${2}"
    key="${input%%=*}"
    value="${input#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    # shellcheck disable=SC2034
    out_array=([key]="${key}" [value]="${value}")
}

function srcinfo._basic_check() {
    [[ "${1}" == *"="* ]]
}

# @description Create array based on input
#
# @example
#   srcinfo._create_array pkgbase var_name var_prefix
#
# @arg $1 string (optional) The pkgbase of the section
# @arg $2 string The variable name
# @arg $3 string (optional) The variable prefix
#
# @stdout Name of array created.
function srcinfo._create_array() {
    local pkgbase="${1}" var_name="${2}" var_pref="${3}"
    if [[ -n "${pkgbase}" ]]; then
        if ! [[ -v "${pkgbase}_${var_pref}_${var_name}" ]]; then
            declare -ag "${pkgbase}_${var_pref}_${var_name}"
            echo "${pkgbase}_${var_pref}_${var_name}"
        else
            echo "${pkgbase}_${var_pref}_${var_name}"
        fi
    else
        if ! [[ -v "${var_pref}_${var_name}" ]]; then
            declare -ag "${var_pref}_${var_name}"
            echo "${var_pref}_${var_name}"
        else
            echo "${var_pref}_${var_name}"
        fi
    fi
}

# @description Promote array to variable
#
# @example
#   foo=('bar')
#   srcinfo._promote_to_variable foo
#
# @arg $1 string Name of array to promote
function srcinfo._promote_to_variable() {
    local var_name="${1}" key value
    key="${var_name}"
    value="${!var_name[0]}"
    unset "${var_name}"
    declare -g "${key}=${value}"
}

function srcinfo.parse() {
    # We need this for trimming whitespace without external tools.
    shopt -s extglob
    local OPTION OPTIND pacstall_compat=false srcinfo_file var_prefix pkgbase temp_array ref total_list loop part ctr i
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
        # Trim leading whitespace.
        line="${line##+([[:space:]])}"
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
        # Define pkgbase first, it must be the first thing listed
        if [[ -z "${pkgbase}" ]]; then
            # Do we have pkgbase first?
            if [[ "${temp_line[key]}" == "pkgbase" ]]; then
                pkgbase="${temp_line[value]}"
            # Ok if not, did we not pass pacstall_compat?
            elif [[ "${pacstall_compat}" == false ]]; then
                return 6
            fi
        elif [[ "${temp_line[key]}" == *"pkgname" ]]; then
            # Bash can't have dashes in variable names
            pkgbase="${temp_line[value]//-/_}"
        fi
        # Next we need to parse out individual keys.
        # So the strategy is to create arrays of every key and at the end,
        # we can promote array.len() == 1 to variables instead. After that we
        # can work back upwards.
        temp_array="$(srcinfo._create_array "${pkgbase}" "${temp_line[key]}" "${var_prefix}")"
        declare -n ref="${temp_array}"
        ref+=("${temp_line[value]}")
        total_list+=("${temp_array}")
    done < "${srcinfo_file}"
    if [[ "${pacstall_compat}" == false ]]; then
        declare -Ag "${var_prefix:+${var_prefix}_}access_pkgbase"
        for loop in "${total_list[@]}"; do
            declare -n part="${loop}"
            # Are we at a new pkgname (pkgbase)?
            if [[ "${loop}" == *"pkgname" ]]; then
                declare -n var_name="${var_prefix:+${var_prefix}_}access_pkgbase"
                for i in "${!part[@]}"; do
                    # Create our inner part
                    declare -Ag "${var_prefix:+${var_prefix}_}${part[$i]//-/_}_inner"
                    # Declare that relationship
                    var_name["${var_prefix:+${var_prefix}_}${part[$i]//-/_}"]="${var_prefix:+${var_prefix}_}${part[$i]//-/_}_inner"
                done
                continue
            fi
            # Alright now that we're here, we can start filling stuff up.
        done
        declare -p "${var_prefix:+${var_prefix}_}access_pkgbase"
    fi
    declare -p total_list
}
