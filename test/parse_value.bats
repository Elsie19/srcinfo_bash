setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../src:$PATH"
    source srcinfo.sh
}

@test "Clustered (a=b)" {
    declare -A test_out
    srcinfo.parse_key_val "a=b" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="b" )' "$(declare -p test_out)"
}

@test "Doubled (a==b)" {
    declare -A test_out
    srcinfo.parse_key_val "a==b" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="=b" )' "$(declare -p test_out)"
}

@test "Spaced Right (a= b)" {
    declare -A test_out
    srcinfo.parse_key_val "a= b" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="b" )' "$(declare -p test_out)"
}

@test "Spaced Left (a =b)" {
    declare -A test_out
    srcinfo.parse_key_val "a =b" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="b" )' "$(declare -p test_out)"
}

@test "Spaced Both (a = b)" {
    declare -A test_out
    srcinfo.parse_key_val "a = b" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="b" )' "$(declare -p test_out)"
}

@test "Spaced Both with padding ( a = b )" {
    declare -A test_out
    srcinfo.parse_key_val " a = b " test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="b" )' "$(declare -p test_out)"
}

@test "Spaced Both with tab padding (   a = b   )" {
    declare -A test_out
    srcinfo.parse_key_val " a = b   " test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="b" )' "$(declare -p test_out)"
}

@test "No Right (a=)" {
    declare -A test_out
    srcinfo.parse_key_val "a=" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="" )' "$(declare -p test_out)"
}

@test "Padding left and right of key ( a =)" {
    declare -A test_out
    srcinfo.parse_key_val " a =" test_out
    assert_equal 'declare -A test_out=([key]="a" [value]="" )' "$(declare -p test_out)"
}
