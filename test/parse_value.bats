setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../src:$PATH"
    source srcinfo.sh
}

@test "Clustered (a=b)" {
    test_out=()
    srcinfo.parse_key_val "a=b" test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="b")' "$(declare -p test_out)"
}

@test "Doubled (a==b)" {
    test_out=()
    srcinfo.parse_key_val "a==b" test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="=b")' "$(declare -p test_out)"
}

@test "Spaced Right (a= b)" {
    test_out=()
    srcinfo.parse_key_val "a= b" test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="b")' "$(declare -p test_out)"
}

@test "Spaced Left (a =b)" {
    test_out=()
    srcinfo.parse_key_val "a =b" test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="b")' "$(declare -p test_out)"
}

@test "Spaced Both (a = b)" {
    test_out=()
    srcinfo.parse_key_val "a = b" test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="b")' "$(declare -p test_out)"
}

@test "Spaced Both with padding ( a = b )" {
    test_out=()
    srcinfo.parse_key_val " a = b " test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="b")' "$(declare -p test_out)"
}

@test "Spaced Both with tab padding (   a = b   )" {
    test_out=()
    srcinfo.parse_key_val " a = b   " test_out
    assert_equal 'declare -a test_out=([0]="a" [1]="b")' "$(declare -p test_out)"
}

@test "No Right (a=)" {
    test_out=()
    srcinfo.parse_key_val "a=" test_out
    assert_equal 'declare -a test_out=([0]="a")' "$(declare -p test_out)"
}

@test "Padding left and right of key ( a =)" {
    test_out=()
    srcinfo.parse_key_val " a =" test_out
    assert_equal 'declare -a test_out=([0]="a")' "$(declare -p test_out)"
}
