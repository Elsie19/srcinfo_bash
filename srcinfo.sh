#!/bin/bash

function srcinfo.parse_key_val() {
    local key value input="${1}"
    declare -n out_array="${2}"
    out_array=(${input/=/ })
}
