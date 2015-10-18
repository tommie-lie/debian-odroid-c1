comma := ,
empty :=
space := $(empty) $(empty)
define newline


endef
declare = $1: export $2 := $(subst $(newline),\n,$(_$2))


DEBIAN_SUITE ?= jessie
DEBIAN_MIRROR ?= http://http.debian.net/debian/
DEBIAN_ARCH := armhf

ifneq ($(findstring $(DIST),jessie stable),)
# ROOT_DEV is needed for jessie, it will cause boot.ini to boot from /dev/mmcblk0p2 rather than from UUID.
# For some reason, booting by UUID is broken with jessie...
ROOT_DEV := /dev/mmcblk0p2
endif

IMAGE_MB ?= 2048
BOOT_MB ?= 32
ROOT_MB=$(shell expr $(IMAGE_MB) - $(BOOT_MB))

BOOT_DIR := boot
MODS_DIR := mods
ROOTFS_DIR := rootfs
RAMDISK_FILE := uInitrd
IMAGE_FILE := sdcard-$(DEBIAN_SUITE).img

UBOOT_REPO := https://github.com/hardkernel/u-boot.git
UBOOT_BRANCH := odroidc-v2011.03
UBOOT_SRC := u-boot

LINUX_TC_PREFIX := arm-linux-gnueabihf-
LINUX_REPO := https://github.com/hardkernel/linux.git
LINUX_BRANCH := odroidc-3.10.y
LINUX_SRC := linux

TIMEZONE ?= Etc/UTC
LOCALES ?= en_US.UTF-8

USERNAME := odroid
PASSWORD := odroid
