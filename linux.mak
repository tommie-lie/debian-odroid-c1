include common.mk

export ARCH := arm
export CROSS_COMPILE := $(LINUX_TC_PREFIX)

UIMAGE_BIN := $(LINUX_SRC)/arch/arm/boot/uImage

.PHONY: all
all: build

.PHONY: clean
clean:
	if test -d "$(LINUX_SRC)"; then $(MAKE) -C $(LINUX_SRC) clean ; fi
	rm -rf $(wildcard $(BOOT_DIR) $(BOOT_DIR).tmp $(MODS_DIR) $(MODS_DIR).tmp)

.PHONY: distclean
distclean:
	rm -rf $(wildcard $(LINUX_SRC) $(BOOT_DIR) $(MODS_DIR) $(MODS_DIR).tmp)

.PHONY: build
build: $(BOOT_DIR) $(MODS_DIR)

$(BOOT_DIR): $(UIMAGE_BIN) $(MESON8B_ODROIDC_DTB_BIN)
	if test -d "$@.tmp"; then rm -rf "$@.tmp" ; fi
	if test -d "$@"; then rm -rf "$@" ; fi
	mkdir -p "$@.tmp"
	cp -p $(LINUX_SRC)/arch/arm/boot/uImage "$@.tmp"
	cp -p $(LINUX_SRC)/arch/arm/boot/dts/meson8b_odroidc.dtb "$@.tmp"
	mv "$@.tmp" $@
	touch $@

$(UIMAGE_BIN): $(LINUX_SRC) $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC) uImage
	$(MAKE) -C $(LINUX_SRC) dtbs
	touch $@

$(MODS_DIR): $(UIMAGE_BIN)
	if test -d "$@.tmp"; then rm -rf "$@.tmp" ; fi
	if test -d "$@"; then rm -rf "$@" ; fi
	mkdir -p "$@.tmp"
	$(MAKE) -C $(LINUX_SRC) modules
	$(MAKE) -C $(LINUX_SRC) INSTALL_MOD_PATH=$(abspath $(MODS_DIR).tmp) modules_install
	mv "$@.tmp" $@
	touch $@

$(LINUX_SRC):
	git clone --depth=1 $(LINUX_REPO) -b $(LINUX_BRANCH) $(LINUX_SRC)

$(LINUX_SRC)/.config: | $(LINUX_SRC)
	$(MAKE) -C $(LINUX_SRC) odroidc_defconfig

