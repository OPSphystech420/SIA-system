V2_CXX ?= clang++
V2_SANITIZERS ?= 0
V2_BUILD_ID ?= gate2c-live-relationships-20260818.3
V2_PACKAGE_VERSION := 0.4.2~gate2c.20260818.3

V2_ARTIFACT_ROOT ?= .artifacts/v2
ifeq ($(V2_SANITIZERS),1)
V2_BUILD_DIR := $(V2_ARTIFACT_ROOT)/host-sanitized
else
V2_BUILD_DIR := $(V2_ARTIFACT_ROOT)/host
endif
V2_TEST_BIN := $(V2_BUILD_DIR)/serverhost_v2_core_tests

V2_CPPFLAGS := -I.
V2_CXXFLAGS := -std=c++20 -O1 -g -Wall -Wextra -Wpedantic -Werror -MMD -MP
V2_LDFLAGS :=

ifeq ($(V2_SANITIZERS),1)
V2_CXXFLAGS += -fsanitize=address,undefined -fno-omit-frame-pointer
V2_LDFLAGS += -fsanitize=address,undefined
endif

V2_PRODUCTION_SOURCES := \
    SourceV2/UE/String.cpp \
    SourceV2/UE/Name.cpp \
    SourceV2/UE/ObjectArray.cpp \
    SourceV2/UE/Reflection.cpp \
    SourceV2/Model/Engine/LiveRelationships.cpp \
    SourceV2/Diagnostics/Logger.cpp \
    SourceV2/Diagnostics/DiagnosticSnapshot.cpp \
    SourceV2/UI/DiagnosticPresentationModel.cpp \
    SourceV2/UI/PresentationStateMachine.cpp \
    SourceV2/Bindings/Platform/MachOImageView.cpp \
    SourceV2/Bindings/Platform/MemorySource.cpp \
    SourceV2/Bindings/Platform/LoadedImageCatalog.cpp \
    SourceV2/Bindings/Platform/ImageIdentityResolver.cpp \
    SourceV2/Bindings/Platform/ExactProfileSelector.cpp \
    SourceV2/Bindings/Platform/CheckedMemoryReader.cpp \
    SourceV2/Bindings/UE/ReadOnlySnapshotCapture.cpp \
    SourceV2/Bindings/UE/WorldRelationshipCapture.cpp \
    SourceV2/Bindings/Validation/ProfileValidator.cpp \
    SourceV2/Bootstrap/InertInitialization.cpp \
    SourceV2/Bootstrap/LegacyRuntimeGuard.cpp

V2_TEST_SOURCES := \
    SourceV2/Tests/TestMain.cpp \
    SourceV2/Tests/Static/LayoutTests.cpp \
    SourceV2/Tests/Unit/ContainerStringTests.cpp \
    SourceV2/Tests/Unit/NameTests.cpp \
    SourceV2/Tests/Unit/ObjectIdentityTests.cpp \
    SourceV2/Tests/Unit/ReflectionTests.cpp \
    SourceV2/Tests/Unit/ProfileInitializationTests.cpp \
    SourceV2/Tests/Unit/LegacyRuntimeGuardTests.cpp \
    SourceV2/Tests/Unit/DiagnosticsTests.cpp \
    SourceV2/Tests/Unit/PlatformBoundaryTests.cpp \
    SourceV2/Tests/Unit/ReadOnlySnapshotCaptureTests.cpp \
    SourceV2/Tests/Unit/PresentationStateMachineTests.cpp

V2_SOURCES := $(V2_PRODUCTION_SOURCES) $(V2_TEST_SOURCES)
V2_OBJECTS := $(patsubst %.cpp,$(V2_BUILD_DIR)/%.o,$(V2_SOURCES))
V2_DEPFILES := $(V2_OBJECTS:.o=.d)

V2_IOS_PACKAGE_PROJECT := SourceV2/Build/IOS
V2_IOS_BUILD_DIR := $(abspath $(V2_ARTIFACT_ROOT)/ios)
V2_PACKAGE_PATH := packages/v2/com.mhga.serverhost.v2_$(V2_PACKAGE_VERSION)_iphoneos-arm.deb
V2_INJECTION_DIR := packages/v2/injection/$(V2_BUILD_ID)
V2_INJECTION_DYLIB := $(V2_INJECTION_DIR)/ServerHostV2.dylib
V2_INJECTION_DSYM := $(V2_INJECTION_DIR)/ServerHostV2.dylib.dSYM
V2_INJECTION_MANIFEST := $(V2_INJECTION_DIR)/manifest.txt
V2_BUILD_DSYM := $(V2_IOS_BUILD_DIR)/theos/obj/arm64/ServerHostV2.dylib.dSYM
V2_IOS_TARGET := iphone:clang:16.5:15.0
V2_IOS_ARCHS := arm64
V2_IOS_CFLAGS := -fobjc-arc -fno-modules -Wall -Wextra -Wpedantic -Werror
V2_IOS_CCFLAGS := -std=c++20 -fno-rtti -fno-modules -fno-cxx-modules -Wall -Wextra -Wpedantic -Werror -I$(abspath .)
V2_SOURCE_REVISION := $(shell git rev-parse HEAD 2>/dev/null || printf unavailable)
V2_SOURCE_TREE_STATE := $(shell if git diff --quiet && git diff --cached --quiet && test -z "$$(git ls-files --others --exclude-standard)"; then printf clean; else printf modified; fi)

.PHONY: all serverhost_v2_core_tests test audit boundary-audit \
    check-source-revision ios-package ios-package-inspect artifact-manifest injection-audit \
    ios-package-clean clean

all: serverhost_v2_core_tests

serverhost_v2_core_tests: $(V2_TEST_BIN)

$(V2_TEST_BIN): $(V2_OBJECTS)
	@mkdir -p $(@D)
	$(V2_CXX) $(V2_LDFLAGS) $^ -o $@

$(V2_BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(@D)
	$(V2_CXX) $(V2_CPPFLAGS) $(V2_CXXFLAGS) -MF $(@:.o=.d) -c $< -o $@

-include $(V2_DEPFILES)

test: serverhost_v2_core_tests
	$(V2_TEST_BIN)

boundary-audit:
	sh SourceV2/Tests/Static/BoundaryAudit.sh

audit: boundary-audit

check-source-revision:
	@test "$(V2_SOURCE_REVISION)" != unavailable || { echo "V2 packaging requires the Server-Host git baseline" >&2; exit 1; }
	@test "$(V2_SOURCE_TREE_STATE)" = clean || { echo "V2 packaging requires a clean committed source tree" >&2; exit 1; }
	@echo "source_revision=$(V2_SOURCE_REVISION) source_tree_state=$(V2_SOURCE_TREE_STATE)"

ios-package: test boundary-audit check-source-revision
	$(MAKE) -C $(V2_IOS_PACKAGE_PROJECT) \
		THEOS_BUILD_DIR="$(V2_IOS_BUILD_DIR)" \
		_THEOS_LOCAL_DATA_DIR="$(V2_IOS_BUILD_DIR)/theos" \
		V2_BUILD_ID="$(V2_BUILD_ID)" \
		V2_SOURCE_REVISION="$(V2_SOURCE_REVISION)" \
		V2_CFLAGS="$(V2_IOS_CFLAGS)" \
		V2_CCFLAGS="$(V2_IOS_CCFLAGS)" package
	@test -f "$(V2_PACKAGE_PATH)" || { echo "expected V2 package was not created: $(V2_PACKAGE_PATH)" >&2; exit 1; }
	$(MAKE) -f SourceV2.mk ios-package-inspect artifact-manifest injection-audit

ios-package-inspect:
	sh SourceV2/Build/IOS/InspectPackage.sh \
		"$(V2_PACKAGE_PATH)" "$(V2_BUILD_ID)" "$(V2_PACKAGE_VERSION)"

artifact-manifest:
	V2_HOST_CPPFLAGS='$(V2_CPPFLAGS)' \
	V2_HOST_CXXFLAGS='$(V2_CXXFLAGS)' \
	V2_HOST_LDFLAGS='$(V2_LDFLAGS)' \
	V2_IOS_TARGET='$(V2_IOS_TARGET)' \
	V2_IOS_ARCHS='$(V2_IOS_ARCHS)' \
	V2_IOS_CFLAGS='$(V2_IOS_CFLAGS)' \
	V2_IOS_CCFLAGS='$(V2_IOS_CCFLAGS) -DSERVERHOST_V2_BUILD_ID="$(V2_BUILD_ID)" -DSERVERHOST_V2_SOURCE_REVISION="$(V2_SOURCE_REVISION)"' \
	V2_SOURCE_TREE_STATE='$(V2_SOURCE_TREE_STATE)' \
	sh SourceV2/Build/IOS/CreateArtifactManifest.sh \
		"$(V2_PACKAGE_PATH)" "$(V2_BUILD_ID)" "$(V2_SOURCE_REVISION)" "$(V2_BUILD_DSYM)"

injection-audit:
	sh SourceV2/Build/IOS/InspectInjectionArtifact.sh \
		"$(V2_INJECTION_DYLIB)" "$(V2_INJECTION_DSYM)" "$(V2_BUILD_ID)"

ios-package-clean:
	$(MAKE) -C $(V2_IOS_PACKAGE_PROJECT) \
		THEOS_BUILD_DIR="$(V2_IOS_BUILD_DIR)" \
		_THEOS_LOCAL_DATA_DIR="$(V2_IOS_BUILD_DIR)/theos" clean

clean:
	rm -rf "$(V2_BUILD_DIR)"
