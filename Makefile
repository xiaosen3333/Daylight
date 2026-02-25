PROJECT := Daylight.xcodeproj
SCHEME := Daylight
SIMULATOR ?= iPhone 16
RESOLVE_SIMULATOR := ./scripts/resolve_simulator.sh

.PHONY: lint test build ci

lint:
	swiftlint lint --strict

build:
	@set -e; \
	SIM_ID=$$($(RESOLVE_SIMULATOR) "$(PROJECT)" "$(SCHEME)" "$(SIMULATOR)"); \
	echo "Using iOS Simulator id=$$SIM_ID"; \
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination "id=$$SIM_ID" CODE_SIGNING_ALLOWED=NO build

test:
	@set -e; \
	SIM_ID=$$($(RESOLVE_SIMULATOR) "$(PROJECT)" "$(SCHEME)" "$(SIMULATOR)"); \
	echo "Using iOS Simulator id=$$SIM_ID"; \
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination "id=$$SIM_ID" CODE_SIGNING_ALLOWED=NO test

ci: lint test
