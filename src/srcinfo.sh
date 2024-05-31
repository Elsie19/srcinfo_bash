#!/bin/bash

function srcinfo.parse_key_val() {
    local key value split=() input="${1}"
    declare -n out_array="${2}"
    split=(${input/=/ })
    out_array=([key]="${split[0]}" [value]="${split[1]}")
}
