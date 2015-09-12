UBOOT_BIN := $(UBOOT_SRC)/sd_fuse/uboot.bin

.PHONY: uboot-clean
uboot-clean:
	if test -d "$(UBOOT_SRC)"; then $(MAKE) -C $(UBOOT_SRC) clean ; fi

.PHONY: uboot-distclean
uboot-distclean:
	rm -rf $(UBOOT_SRC)

.PHONY: uboot-build
uboot-build: $(UBOOT_BIN)

$(UBOOT_BIN): $(UBOOT_SRC)
	$(MAKE) -C $(UBOOT_SRC) odroidc_config
	$(MAKE) -C $(UBOOT_SRC)
	touch $@

$(UBOOT_SRC):
	git clone --depth=1 $(UBOOT_REPO) -b $(UBOOT_BRANCH)

