export THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
SDKVERSION = 16.5

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = rune
rune_FILES = Tweak.x
rune_CFLAGS = -fobjc-arc
rune_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
