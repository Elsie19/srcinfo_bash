setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../src:$PATH"
    source srcinfo.sh
}

@test "Run entire script" {
    srcinfo.parse test/SRCINFO_paru foo
    for i in "${!foo_access_pkgbase[@]}"; do
        pkgbase="${foo_access_pkgbase[$i]}"
        declare -n foo="${pkgbase}"
        assert_equal "${foo[backup]}" "etc/paru.conf"
    done
}

@test "Run entire script with '-p'" {
    srcinfo.parse -p test/SRCINFO_amfora-bin foo
}
