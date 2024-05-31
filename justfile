default: test

test:
    ./test/bats/bin/bats test/*.bats

docs:
    shdoc < src/srcinfo.sh > doc.md
