GIT_LAST_COMMIT := $(shell git describe --tags --always | sed 's/-/+/' | sed 's/^v//')

ifneq ($(DRONE_TAG),)
	VERSION ?= $(subst v,,$(DRONE_TAG))-$(GIT_LAST_COMMIT)
else
	ifneq ($(DRONE_BRANCH),)
		VERSION ?= $(subst release/v,,$(DRONE_BRANCH))-$(GIT_LAST_COMMIT)
	else
		VERSION ?= master-$(GIT_LAST_COMMIT)
	endif
endif

.PHONY: test
test:
	flutter test

.PHONY: build-all
build-all: build-release build-debug build-profile

.PHONY: build-release
build-release:
	flutter build apk --release --build-name=$(VERSION) --flavor main

.PHONY: build-debug
build-debug:
	flutter build apk --debug --build-name=$(VERSION) --flavor unsigned

.PHONY: build-profile
build-profile:
	flutter build apk --profile --build-name=$(VERSION) --flavor unsigned
