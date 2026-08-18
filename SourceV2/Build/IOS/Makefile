ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
V2_BUILD_ID ?= gate1-foundation-20260818.2
V2_CFLAGS ?= -fno-modules -Wall -Wextra -Wpedantic -Werror
V2_CCFLAGS ?= -std=c++20 -fno-rtti -fno-modules -fno-cxx-modules -Wall -Wextra -Wpedantic -Werror -I$(THEOS_PROJECT_DIR)/../../..

DEBUG = 0
FINALPACKAGE = 1

THEOS_PACKAGE_DIR := $(abspath ../../../packages/v2)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ServerHostV2

ServerHostV2_LIBRARIES = substrate
ServerHostV2_CFLAGS = $(V2_CFLAGS) -DSERVERHOST_V2_BUILD_ID='"$(V2_BUILD_ID)"'
ServerHostV2_CCFLAGS = $(V2_CCFLAGS) -DSERVERHOST_V2_BUILD_ID='"$(V2_BUILD_ID)"'

ServerHostV2_FILES = \
    ../../Bootstrap/V2Entry.mm \
    ../../Bootstrap/InertInitialization.cpp \
    ../../Bootstrap/LegacyRuntimeGuard.cpp \
    ../../UE/String.cpp \
    ../../UE/Name.cpp \
    ../../UE/ObjectArray.cpp \
    ../../UE/Reflection.cpp \
    ../../Bindings/Validation/ProfileValidator.cpp \
    ../../Tests/Static/LayoutTests.cpp

include $(THEOS_MAKE_PATH)/tweak.mk
