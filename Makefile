.PHONY: all build test test_linux shell_linux 

all: build

build:
	swift build

swifttestflags := --enable-test-discovery --enable-code-coverage

test:
	swift test ${swifttestflags} ${libsass4flags}

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name SourceMapper --rm swift:5.3 make test

shell_linux:
	docker run -it -v `pwd`:`pwd` -w `pwd` --name SourceMapper --rm swift:5.3 /bin/bash
