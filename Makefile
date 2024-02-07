.PHONY: test

test:
	cd test && ./test-depot.sh

clean:
	rm -vf *~ test/*~
