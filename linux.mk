export ARCH := arm
export CROSS_COMPILE := $(LINUX_TC_PREFIX)

KERNEL_VERSION = $(shell MAKEFLAGS= MFLAGS= $(MAKE) -C $(LINUX_SRC) --no-print-directory kernelversion)

KDEB_PKGVERSION = $(KERNEL_VERSION)-1

define PACKAGES
$(strip \
$(eval _a := $(KERNEL_VERSION))     \
$(eval _b := $(KDEB_PKGVERSION))    \
linux-image-$(_a)_$(_b)_armhf.deb     \
linux-headers-$(_a)_$(_b)_armhf.deb   \
linux-firmware-image_$(_b)_armhf.deb  \
linux-libc-dev_$(_b)_armhf.deb)
endef


.PHONY: linux-clean
linux-clean:
	[ -d "$(LINUX_SRC)" ] && $(MAKE) -C $(LINUX_SRC) clean
	rm -f linux-imag-*_armhf.deb
	rm -f linux-headers-*_armhf.deb
	rm -f linux-firmware-image_*_armhf.deb
	rm -f linux-libc-dev_*_armhf.deb

.PHONY: linux-distclean
linux-distclean:
	rm -rf $(LINUX_SRC)

.PHONY: linux-build
linux-build: $(LINUX_SRC)
	$(MAKE) $(call PACKAGES)

$(subst .deb,%deb,$(call PACKAGES)): $(LINUX_SRC)/Makefile $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC) KBUILD_DEBARCH=armhf deb-pkg

$(LINUX_SRC):
	git clone --depth=1 $(LINUX_REPO) -b $(LINUX_BRANCH) $(LINUX_SRC)
	cd $(LINUX_SRC) ; \
	QUILT_PATCHES=../kpatches quilt push -a ; [ $$? -eq 0 -o $$? -eq 2 ]

$(LINUX_SRC)/.config: | $(LINUX_SRC)
	$(MAKE) -C $(LINUX_SRC) odroidc_defconfig

