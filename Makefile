ARCHS = arm64
TARGET = iphone:clang:16.5:15.0

DEBUG = 1
FINALPACKAGE = 0
SERVERHOST_DEVELOPER_UI ?= 0
SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK ?= 0
SERVERHOST_LIFECYCLE_AUTOSAVE ?= 0
SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE ?= 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ServerHost

ServerHost_FRAMEWORKS = UIKit Metal MetalKit Foundation QuartzCore CoreGraphics
ServerHost_LIBRARIES = substrate
ServerHost_CFLAGS = -fobjc-arc -fno-modules -Wall -Wextra -Wno-unused-parameter
ServerHost_CCFLAGS = -std=c++20 -fno-rtti -fno-modules -fno-cxx-modules -Wall -Wextra -Wno-unused-parameter -DSERVERHOST_DEVELOPER_UI=$(SERVERHOST_DEVELOPER_UI) -DSERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK=$(SERVERHOST_EXPERIMENTAL_POSTLOGIN_HOOK) -DSERVERHOST_LIFECYCLE_AUTOSAVE=$(SERVERHOST_LIFECYCLE_AUTOSAVE) -DSERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE=$(SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE)

IMGUI_FILES = \
    ImGui/imgui.cpp \
    ImGui/imgui_draw.cpp \
    ImGui/imgui_tables.cpp \
    ImGui/imgui_widgets.cpp \
    ImGui/imgui_impl_metal.mm

SERVER_FILES = \
    Menu/HostMenu.mm \
    MenuLoad/OverlayView.mm \
    MenuLoad/MenuBootstrap.mm \
    Source/Hosting/HostingRuntime.mm \
    Source/UnrealEngine/ScriptCore.mm \
    Source/Libraries/CGuardMemory/CGPMemory.cpp \
    Source/Libraries/HardwareBreakpointHook/HardwareBreakpointHook.c \
    Source/Libraries/HardwareBreakpointHook/mach_excServer.c

ServerHost_FILES = $(IMGUI_FILES) $(SERVER_FILES)

include $(THEOS_MAKE_PATH)/tweak.mk
