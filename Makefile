export THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
SDKVERSION = 16.5

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = rune
APPLICATION_NAME = Rune

rune_FILES = Tweak.x
rune_CFLAGS = -fobjc-arc
rune_FRAMEWORKS = UIKit

Rune_FILES = App.xm
Rune_CFLAGS = -fobjc-arc
Rune_FRAMEWORKS = UIKit
Rune_CODESIGN_FLAGS = -Sentitlements.plist
Rune_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/application.mk
