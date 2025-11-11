GIT_LAST_COMMIT := $(shell git describe --tags --always | sed 's/-/+/' | sed 's/^v//')
FLUTTER ?= flutter

ifneq ($(DRONE_BUILD_NUMBER),)
	VERSION ?= $(DRONE_BUILD_NUMBER)
else
	VERSION ?= 1
endif

.PHONY: test
test: l10n
	$(FLUTTER) test

.PHONY: build-all
build-all: build-release build-debug build-profile

.PHONY: build-release
build-release: l10n
	$(FLUTTER) build apk --release --build-number=$(VERSION) --flavor production

.PHONY: build-debug
build-debug: l10n
	$(FLUTTER) build apk --debug --build-number=$(VERSION) --flavor unsigned

.PHONY: build-profile
build-profile: l10n
	$(FLUTTER) build apk --profile --build-number=$(VERSION) --flavor unsigned

.PHONY: build-ios
build-ios: l10n
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

.PHONY: l10n
l10n:
	$(FLUTTER) gen-l10n

.PHONY: check-l10n
check-l10n: l10n
	@if [ -s lib/l10n/untranslated_messages.json ]; then echo "Untranslated strings found:" && cat lib/l10n/untranslated_messages.json && exit 1; fi