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

expect_success test-01-basic
expect_error   test-02-undefined-fund   "unknown fund \`missing_fund'"
expect_error   test-03-empty-file       "no funds found"
expect_error   test-04-file-not-found   "can't open \`test-04-file-not-found.input'"
expect_error   test-05-unknown-line     "unparseable line \`some random unparseable line'"
expect_error   test-06-backwards-date   "date \`23.11.1962' must be later than previous date"
expect_success test-07-default-mode     '-default'
expect_success test-08-verbose-mode     '-verbose'
expect_error   test-09-duplicate-fund   "duplicate fund \`fund_A'"
expect_success test-10-rename-fund
expect_error   test-11-rename-missing   "rename: fund \`fund_A' does not exist"
expect_error   test-12-rename-duplicate "rename: fund \`fund_Z' already exists"
expect_error   test-13-rename-old-gone  "unknown fund \`fund_A'"
