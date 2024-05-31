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
    [[ ${1} == *"="* ]]
}

function srcinfo._contains() {
    local -n arr_name="${1}"
    local key="${2}" z
    for z in "${arr_name[@]}"; do
        if [[ ${z} == "${key}" ]]; then
            return 0
        fi
    done
    return 1
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
    if [[ -n ${pkgbase} ]]; then
        # Yes I know this looks awful, but this is the only way I can
        # accurately (hopefully) split variables and prefixes later on.
        if ! [[ -v "${var_pref}_${pkgbase}ZZZZZ${var_name}" ]]; then
            declare -ag "${var_pref}_${pkgbase}ZZZZZ${var_name}"
            echo "${var_pref}_${pkgbase}ZZZZZ${var_name}"
        else
            echo "${var_pref}_${pkgbase}ZZZZZ${var_name}"
        fi
    else
        if ! [[ -v "${var_pref}ZZZZZ${var_name}" ]]; then
            declare -ag "${var_pref}ZZZZZ${var_name}"
            echo "${var_pref}ZZZZZ${var_name}"
        else
            echo "${var_pref}ZZZZZ${var_name}"
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
    local OPTION OPTIND pacstall_compat=false srcinfo_file var_prefix pkgbase temp_array ref total_list loop part i part_two global_pkgbase split_up
    while getopts 'p' OPTION; do
        case "${OPTION}" in
            p) pacstall_compat=true ;;
            ?) echo "Usage: ${FUNCNAME[0]} [-p] SRCINFO var_prefix" >&2 && return 2 ;;
        esac
    done
    shift $((OPTIND - 1))
    srcinfo_file="${1:?No SRCINFO passed to srcinfo.parse}"
    var_prefix="${2:?Variable prefix not passed to srcinfo.parse}"
    [[ ! -s ${srcinfo_file} ]] && return 5
    while IFS= read -r line; do
        # Skip blank lines
        [[ -z ${line} ]] && continue
        [[ ${line} =~ ^\s*#.* ]] && continue
        # Trim leading whitespace.
        line="${line##+([[:space:]])}"
        declare -A temp_line
        if ! srcinfo._basic_check "${line}"; then
            echo "Could not parse line: '${line}'" >&2
            return 3
        fi
        srcinfo.parse_key_val "${line}" temp_line
        if [[ -z ${temp_line[value]} ]]; then
            echo "Empty value for: '${line}'" >&2
            return 4
        fi
        # Define pkgbase first, it must be the first thing listed
        if [[ -z ${pkgbase} ]]; then
            # Do we have pkgbase first?
            if [[ ${temp_line[key]} == "pkgbase" ]]; then
                pkgbase="${temp_line[value]}"
                global_pkgbase="${temp_line[value]}"
            fi
        elif [[ ${temp_line[key]} == *"pkgbase" ]]; then
            pkgbase="${temp_line[value]//-/_}"
        elif [[ ${temp_line[key]} == *"pkgname" ]]; then
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
        #TODO: In the linux SRCINFO, the pkgbase pkgdesc and pkgname=linux pkgdesc
        # get merged into an array, so I suppose we need to check if both pkgbase and
        # pkgname have the same keys, and if so, use pkgname, and if not, inherit from
        # pkgbase.
        if ! srcinfo._contains total_list "${temp_array}"; then
            total_list+=("${temp_array}")
        fi
    done <<< "$(
        if [[ ${pacstall_compat} == true ]]; then
            echo "pkgbase = temporary_pacstall_pkgbase"
            cat "${srcinfo_file}"
        else
            cat "${srcinfo_file}"
        fi
    )"
    declare -Ag "${var_prefix}_access_pkgbase"
    for loop in "${total_list[@]}"; do
        declare -n part="${loop}"
        # Are we at a new pkgname (pkgbase)?
        if [[ ${loop} == *"pkgname" ]]; then
            declare -n var_name="${var_prefix}_access_pkgbase"
            for i in "${!part[@]}"; do
                # Create our inner part
                declare -Ag "${var_prefix}_${part[$i]//-/_}_inner"
                # Declare that relationship
                var_name["${var_prefix}_${part[$i]//-/_}"]="${var_prefix}_${part[$i]//-/_}_inner"
            done
        fi
    done
    for part_two in "${total_list[@]}"; do
        # We already dealt with these
        [[ ${part_two} == *"ZZZZZpkgbase" ]] && continue
        # Now we need to go and check every loop over, and parse it out so we get something like ("prefix", "key"), so we can then work with that.
        # But first actually we should promote single element arrays to variables
        declare -n referoo="${part_two}"
        if (("${#referoo[@]}" == 1)); then
            srcinfo._promote_to_variable "${part_two}"
        fi
        mapfile -t split_up <<< "${part_two/ZZZZZ/$'\n'}"
        declare -n goob="${var_prefix}_access_pkgbase[${split_up[0]}]"
        declare -n boob="${goob}"

        # So now we need to check if the thing we're trying to insert is a variable,
        # or an array.
        if [[ "$(declare -p -- "${part_two}")" == "declare -a "* ]]; then
            declare -ga "${var_prefix}_arrays_${part_two}"
            declare -n yogabbagabba="${var_prefix}_arrays_${part_two}"
            declare -n going_insane="${part_two}"
            # Honestly at this point, idk why this is needed but it won't work
            # without, so..
            # shellcheck disable=SC2034
            yogabbagabba=("${going_insane[@]}")
            # shellcheck disable=SC2004
            boob[${split_up[1]}]="SRCINFO_ARRAY_REDIRECT:${var_prefix}_arrays_${part_two}"
        else
            # shellcheck disable=SC2004
            # shellcheck disable=SC2034
            boob[${split_up[1]}]="${!part_two}"
        fi
    done
}
