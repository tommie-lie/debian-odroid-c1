#
# You need the following packages installed:
#   sudo apt-get install build-essential wget git lzop u-boot-tools binfmt-support qemu qemu-user-static debootstrap parted
#
# If you are running 64 bit Ubuntu, you might need to run the following 
# commands to be able to launch the 32 bit toolchain:
#
#    sudo dpkg --add-architecture i386
#    sudo apt-get update
#    sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1
#

.DEFAULT_GOAL: all

include common.mk
include uboot.mk
include linux.mk
include rootfs.mk



.PHONY: all
all: build

# Build steps
BUILD_STEPS := uboot linux rootfs

# Prerequesites for each build step
rootfs-pr: build-uboot build-linux
uboot-pr:
linux-pr:

# Build step rule template
define BUILDSTEP_TEMPLATE
.PHONY: build-$(1) clean-$(1) distclean-$(1) $$($(1)-pr)
build-$(1): $(1)-pr $(1)-build

clean-$(1): $(1)-clean

distclean-$(1): $(1)-distclean

endef

$(foreach step,$(BUILD_STEPS),$(eval $(call BUILDSTEP_TEMPLATE,$(step))))

.PHONY: build
build: $(addprefix build-,$(BUILD_STEPS))

.PHONY: clean
clean: $(addprefix clean-,$(BUILD_STEPS))

.PHONY: distclean
distclean: $(addprefix distclean-,$(BUILD_STEPS))

