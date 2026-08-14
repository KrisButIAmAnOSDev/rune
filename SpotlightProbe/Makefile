export THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
SDKVERSION = 16.5
SYSROOT = $(THEOS)/sdks/iPhoneOS16.5.sdk

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = spotlightprobe
spotlightprobe_FILES = SpotlightProbe.x
spotlightprobe_CFLAGS = -fobjc-arc
spotlightprobe_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
