ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
V2_BUILD_ID ?= gate1-foundation-20260818.3
V2_CFLAGS ?= -fno-modules -Wall -Wextra -Wpedantic -Werror
V2_REPOSITORY_ROOT := $(abspath ../../..)
V2_SOURCE_ROOT := $(abspath ../..)
V2_CCFLAGS ?= -std=c++20 -fno-rtti -fno-modules -fno-cxx-modules -Wall -Wextra -Wpedantic -Werror -I$(V2_REPOSITORY_ROOT)

DEBUG = 0
FINALPACKAGE = 1

THEOS_PACKAGE_DIR := $(abspath ../../../packages/v2)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ServerHostV2

ServerHostV2_LIBRARIES = substrate
ServerHostV2_CFLAGS = $(V2_CFLAGS) -DSERVERHOST_V2_BUILD_ID='"$(V2_BUILD_ID)"'
ServerHostV2_CCFLAGS = $(V2_CCFLAGS) -DSERVERHOST_V2_BUILD_ID='"$(V2_BUILD_ID)"'

ServerHostV2_FILES = \
    $(V2_SOURCE_ROOT)/Bootstrap/V2Entry.mm \
    $(V2_SOURCE_ROOT)/Bootstrap/InertInitialization.cpp \
    $(V2_SOURCE_ROOT)/Bootstrap/LegacyRuntimeGuard.cpp \
    $(V2_SOURCE_ROOT)/UE/String.cpp \
    $(V2_SOURCE_ROOT)/UE/Name.cpp \
    $(V2_SOURCE_ROOT)/UE/ObjectArray.cpp \
    $(V2_SOURCE_ROOT)/UE/Reflection.cpp \
    $(V2_SOURCE_ROOT)/Bindings/Validation/ProfileValidator.cpp \
    $(V2_SOURCE_ROOT)/Tests/Static/LayoutTests.cpp

include $(THEOS_MAKE_PATH)/tweak.mk
