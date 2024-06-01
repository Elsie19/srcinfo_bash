#!/usr/bin/env bash
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
        if ! [[ -v "${var_pref}_${pkgbase}_array_${var_name}" ]]; then
            declare -ag "${var_pref}_${pkgbase}_array_${var_name}"
            echo "${var_pref}_${pkgbase}_array_${var_name}"
        else
            echo "${var_pref}_${pkgbase}_array_${var_name}"
        fi
    else
        if ! [[ -v "${var_pref}_array_${var_name}" ]]; then
            declare -ag "${var_pref}_array_${var_name}"
            echo "${var_pref}_array_${var_name}"
        else
            echo "${var_pref}_array_${var_name}"
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
            ?) echo "Usage: ${FUNCNAME[0]} [-p] .SRCINFO var_prefix" >&2 && return 2 ;;
        esac
    done
    shift $((OPTIND - 1))
    srcinfo_file="${1:?No .SRCINFO passed to srcinfo.parse}"
    var_prefix="${2:?Variable prefix not passed to srcinfo.parse}"
    srcinfo.cleanup "${var_prefix}"
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
            else
                return 6
            fi
        elif [[ ${temp_line[key]} == *"pkgbase" ]]; then
            pkgbase="${temp_line[value]//-/_}"
        elif [[ ${temp_line[key]} == *"pkgname" ]]; then
            # Bash can't have dashes in variable names
            pkgbase="${temp_line[value]//-/_}"
        fi
        export print_pkgbase="${pkgbase}"
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
    declare -Ag "${var_prefix}_access"
    for loop in "${total_list[@]}"; do
        declare -n part="${loop}"
        # Are we at a new pkgname (pkgbase)?
        if [[ ${loop} == *"pkgname" ]]; then
            declare -n var_name="${var_prefix}_access"
            for i in "${!part[@]}"; do
                # Create our inner part
                declare -Ag "${var_prefix}_${part[$i]//-/_}"
                # Declare that relationship
                var_name["${var_prefix}_${part[$i]//-/_}"]="${var_prefix}_${part[$i]//-/_}"
            done
        fi
    done
    for part_two in "${total_list[@]}"; do
        # We already dealt with these
        [[ ${part_two} == *"_array_pkgbase" ]] && continue
        # Now we need to go and check every loop over, and parse it out so we get something like ("prefix", "key"), so we can then work with that.
        # But first actually we should promote single element arrays to variables
        declare -n referoo="${part_two}"
        if (("${#referoo[@]}" == 1)); then
            srcinfo._promote_to_variable "${part_two}"
        fi
        mapfile -t split_up <<< "${part_two/_array_/$'\n'}"
        declare -n boob="${split_up[0]}"

        # So now we need to check if the thing we're trying to insert is a variable,
        # or an array.
        if [[ "$(declare -p -- "${part_two}")" == "declare -a "* ]]; then
            declare -ga "${part_two}"
            boob[${split_up[1]}]="${part_two}"
        else
            # shellcheck disable=SC2004
            # shellcheck disable=SC2034
            boob[${split_up[1]}]="${!part_two}"
        fi
    done
}

function srcinfo.cleanup() {
    local var_prefix="${1:?No var_prefix passed to srcinfo.cleanup}" i z
    local main_loop_template="${var_prefix}_access"
    declare -n main_loop="${main_loop_template}"
    for i in "${main_loop[@]}"; do
        declare -n big_balls="${i}"
        for z in "${big_balls[@]}"; do
            unset "${var_prefix}_array_${z}"
        done
        unset big_balls
    done
    unset "${var_prefix}_access"
    # So now lets clean the stragglers that we can't reasonably infer
    for i in $(compgen -v); do
        if [[ ${i} == "${var_prefix}_"* ]] && [[ ${i} == *"_array_"* ]]; then
            unset "${i}"
        fi
    done
}

# @description Parse a specific variable from .SRCINFO
#
# @example
#   srcinfo.print_var .SRCINFO source
#
# @arg $1 string .SRCINFO file path
# @arg $2 string Variable or Array to print
function srcinfo.print_var() {
    local srcinfo_file="${1}" found="${2}" var_prefix="findvar" output var print_pkgbase
    srcinfo.parse -p "${srcinfo_file}" "${var_prefix}"
    output="${var_prefix}_${print_pkgbase}_array_${found}[@]"
    if [[ -n ${!output} ]]; then
        printf "%s\n" "${!output}"
    else
        return 1
    fi
}
