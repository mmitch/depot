#!/bin/bash
set -e

ok=0
fail=0

expect_success() {
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

expect_error() {
    local name="$1" expected_error="$2"

    echo
    echo "testing $name:"

    local actual_error
    if ! actual_error=$(../depot.pl "$name".input 2>&1 1>/dev/null) ; then
	if [[ $actual_error == *"$expected_error"* ]]; then
	    echo "test OK"
	    ok=$((ok + 1))
	else
	    echo "got wrong error message:"
	    diff -Narup <(echo "$expected_error") <(echo "$actual_error") || true
	    echo "test FAILED"
	    fail=$((fail + 1))
	fi
    else
	echo "command succeeded unexpectedly"
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

expect_success test-1-basic
expect_error   test-2-undefined-fund "unknown fund \`missing_fund'"
expect_error   test-3-empty-file     "no funds found"
expect_error   test-4-file-not-found "can't open \`test-4-file-not-found.input'"
