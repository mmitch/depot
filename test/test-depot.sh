#!/bin/bash
set -e

ok=0
fail=0

run_test() {
    local name="$1"

    echo
    echo "testing $name:"

    if diff -Narup "$name".expected <(../depot.pl "$name".input); then
	echo "test OK"
	ok=$((ok + 1))
    else
	echo "test FAILED"
	fail=$((fail + 1))
    fi
}

print_stats() {
    echo
    printf "%d OK, %d FAILED\n" $ok $fail
    
    if [ $fail -gt 0 ]; then
	exit 1
    fi
    exit 0
}

trap print_stats EXIT

run_test test-1-basic
