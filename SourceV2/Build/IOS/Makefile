ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
V2_BUILD_ID ?= gate2c-live-relationships-20260818.2
V2_SOURCE_REVISION ?= unavailable
V2_CFLAGS ?= -fobjc-arc -fno-modules -Wall -Wextra -Wpedantic -Werror
V2_REPOSITORY_ROOT := $(abspath ../../..)
V2_SOURCE_ROOT := $(abspath ../..)
V2_CCFLAGS ?= -std=c++20 -fno-rtti -fno-modules -fno-cxx-modules -Wall -Wextra -Wpedantic -Werror -I$(V2_REPOSITORY_ROOT)

DEBUG = 0
FINALPACKAGE = 1

THEOS_PACKAGE_DIR := $(abspath ../../../packages/v2)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ServerHostV2

ServerHostV2_LIBRARIES = substrate
ServerHostV2_FRAMEWORKS = UIKit Foundation QuartzCore Metal MetalKit
ServerHostV2_CFLAGS = $(V2_CFLAGS) \
    -DSERVERHOST_V2_BUILD_ID='"$(V2_BUILD_ID)"' \
    -DSERVERHOST_V2_SOURCE_REVISION='"$(V2_SOURCE_REVISION)"'
ServerHostV2_CCFLAGS = $(V2_CCFLAGS) \
    -DSERVERHOST_V2_BUILD_ID='"$(V2_BUILD_ID)"' \
    -DSERVERHOST_V2_SOURCE_REVISION='"$(V2_SOURCE_REVISION)"'

ServerHostV2_FILES = \
    $(V2_SOURCE_ROOT)/Bootstrap/V2Entry.mm \
    $(V2_SOURCE_ROOT)/Bootstrap/InertInitialization.cpp \
    $(V2_SOURCE_ROOT)/Bootstrap/LegacyRuntimeGuard.cpp \
    $(V2_SOURCE_ROOT)/Diagnostics/Logger.cpp \
    $(V2_SOURCE_ROOT)/Diagnostics/DiagnosticSnapshot.cpp \
    $(V2_SOURCE_ROOT)/Diagnostics/ContractCapture.mm \
    $(V2_SOURCE_ROOT)/UI/DiagnosticPresentationModel.cpp \
    $(V2_SOURCE_ROOT)/UI/PresentationStateMachine.cpp \
    $(V2_SOURCE_ROOT)/UI/DiagnosticUIBootstrap.mm \
    $(V2_SOURCE_ROOT)/UE/String.cpp \
    $(V2_SOURCE_ROOT)/UE/Name.cpp \
    $(V2_SOURCE_ROOT)/UE/ObjectArray.cpp \
    $(V2_SOURCE_ROOT)/UE/Reflection.cpp \
    $(V2_SOURCE_ROOT)/Model/Engine/LiveRelationships.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Platform/MachOImageView.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Platform/MemorySource.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Platform/LoadedImageCatalog.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Platform/ImageIdentityResolver.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Platform/ExactProfileSelector.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Platform/CheckedMemoryReader.cpp \
    $(V2_SOURCE_ROOT)/Bindings/UE/ReadOnlySnapshotCapture.cpp \
    $(V2_SOURCE_ROOT)/Bindings/UE/WorldRelationshipCapture.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Validation/ProfileValidator.cpp \
    $(V2_SOURCE_ROOT)/Tests/Static/LayoutTests.cpp \
    $(V2_REPOSITORY_ROOT)/ImGui/imgui.cpp \
    $(V2_REPOSITORY_ROOT)/ImGui/imgui_draw.cpp \
    $(V2_REPOSITORY_ROOT)/ImGui/imgui_tables.cpp \
    $(V2_REPOSITORY_ROOT)/ImGui/imgui_widgets.cpp \
    $(V2_REPOSITORY_ROOT)/ImGui/imgui_impl_metal.mm

include $(THEOS_MAKE_PATH)/tweak.mk
