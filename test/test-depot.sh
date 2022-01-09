#!/bin/bash
set -e

ok=0
fail=0

start_test() {
    local name="$1"

    echo
    echo "testing $name:"
}

succeed_test() {
    echo "test OK"
    ok=$((ok + 1))
}

fail_test() {
    echo "test FAILED"
    fail=$((fail + 1))
}

expect_success() {
    local name="$1"
    shift

    start_test "$name"

    if diff -Narup "$name".expected <(../depot.pl "$@" "$name".input); then
	succeed_test
    else
	fail_test
    fi
}

expect_error() {
    local name="$1" expected_error="$2"

    start_test "$name"

    local actual_error
    if ! actual_error=$(../depot.pl "$name".input 2>&1 1>/dev/null) ; then
	if [[ $actual_error == *"$expected_error"* ]]; then
	    succeed_test
	else
	    echo "got wrong error message:"
	    diff -Narup <(echo "$expected_error") <(echo "$actual_error") || true
	    fail_test
	fi
    else
	echo "command succeeded unexpectedly"
	fail_test
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

# use standard locale for tests
export LANG=C

expect_success test-1-basic
expect_error   test-2-undefined-fund "unknown fund \`missing_fund'"
expect_error   test-3-empty-file     "no funds found"
expect_error   test-4-file-not-found "can't open \`test-4-file-not-found.input'"
expect_error   test-5-unknown-line   "unparseable line \`some random unparseable line'"
expect_error   test-6-backwards-date "date \`23.11.1962' must be later than previous date"
expect_success test-7-default-mode   '-default'
