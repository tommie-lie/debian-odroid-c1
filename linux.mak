include common.mk

export ARCH := arm
export CROSS_COMPILE := $(LINUX_TC_PREFIX)

.PHONY: all
all: build

.PHONY: clean
clean:
	if test -d "$(LINUX_SRC)"; then $(MAKE) -C $(LINUX_SRC) clean ; fi
	rm -f linux-deb-pkg
	rm -f linux-image*_armhf.deb
	rm -f linux-firmware-image*_armhf.deb
	rm -f linux-headers*_armhf.deb
	rm -f linux-libc-dev*_armhf.deb

.PHONY: distclean
distclean:
	rm -rf $(wildcard $(LINUX_SRC))

.PHONY: build
build: linux-deb-pkg

linux-deb-pkg: $(LINUX_SRC) $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC) KBUILD_DEBARCH=armhf deb-pkg
	touch $@

$(LINUX_SRC):
	git clone --depth=1 $(LINUX_REPO) -b $(LINUX_BRANCH) $(LINUX_SRC)
	cd $(LINUX_SRC) ; \
	QUILT_PATCHES=../kpatches quilt push -a ; [ $$? -eq 0 -o $$? -eq 2 ]

$(LINUX_SRC)/.config: | $(LINUX_SRC)
	$(MAKE) -C $(LINUX_SRC) odroidc_defconfig

