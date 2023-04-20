PREFIX ?= /usr/local
RELEASE ?= release
BIN_PATH := $(shell swift build --show-bin-path -c ${RELEASE})

.PHONY: all build test test_linux shell_linux install uninstall

all: build

build:
	swift build -c ${RELEASE}

test:
	swift test --enable-code-coverage

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name SourceMapper --rm swift:5.7 swift test

shell_linux:
	docker run -it -v `pwd`:`pwd` -w `pwd` --name SourceMapper --rm swift:5.7 /bin/bash

install: build
	-mkdir -p ${PREFIX}/bin
	install ${BIN_PATH}/srcmapcat ${PREFIX}/bin

uninstall:
	rm -f ${PREFIX}/bin/srcmapcat
