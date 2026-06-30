GIT_LAST_COMMIT := $(shell git describe --tags --always | sed 's/-/+/' | sed 's/^v//')
FLUTTER ?= flutter

ifneq ($(DRONE_BUILD_NUMBER),)
	VERSION ?= $(DRONE_BUILD_NUMBER)
else
	VERSION ?= 1
endif

.PHONY: test
test:
	$(FLUTTER) test

.PHONY: build-all
build-all: build-release build-debug build-profile

.PHONY: build-release
build-release:
	$(FLUTTER) build apk --release --build-number=$(VERSION) --flavor production

.PHONY: build-debug
build-debug:
	$(FLUTTER) build apk --debug --build-number=$(VERSION) --flavor unsigned

.PHONY: build-profile
build-profile:
	$(FLUTTER) build apk --profile --build-number=$(VERSION) --flavor unsigned

.PHONY: build-ios
build-ios:
	$(FLUTTER) build ios --release --build-number=$(VERSION) --no-codesign

.PHONY: format
format:
	$(FLUTTER) format lib

.PHONY: format-check
format-check:
	@diff=$$(flutter format -n lib); \
	if [ -n "$$diff" ]; then \
		echo "The following files are not formatted correctly:"; \
		echo "$${diff}"; \
		echo "Please run 'make format' and commit the result."; \
		exit 1; \
	fi;