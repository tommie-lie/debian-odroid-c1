UBOOT_BIN_DIR := $(UBOOT_SRC)/sd_fuse

.PHONY: clean
roots-clean: delete-rootfs
	rm -rf $(wildcard $(IMAGE_FILE) $(IMAGE_FILE).tmp)

.PHONY: distclean
rootfs-distclean: delete-rootfs
	rm -rf $(wildcard $(ROOTFS_DIR).base $(ROOTFS_DIR).base.tmp)

.PHONY: delete-rootfs
delete-rootfs:
	if mountpoint -q $(ROOTFS_DIR)/proc ; then umount $(ROOTFS_DIR)/proc ; fi
	if mountpoint -q $(ROOTFS_DIR)/sys ; then umount $(ROOTFS_DIR)/sys ; fi
	if mountpoint -q $(ROOTFS_DIR)/dev ; then umount $(ROOTFS_DIR)/dev ; fi
	rm -rf $(wildcard $(ROOTFS_DIR) uInitrd)
	
.PHONY: rootfs-build
rootfs-build: $(IMAGE_FILE)

$(ROOTFS_DIR).base/.stamp:
	rm -rf "$(@D)"
	mkdir -p $(@D)
	debootstrap --foreign --no-check-gpg --include=ca-certificates,ssh,vim,locales,ntpdate,usbmount,initramfs-tools,debian-archive-keyring --arch=$(DEBIAN_ARCH) $(DEBIAN_SUITE) $(@D) $(DEBIAN_MIRROR)
	cp $$(which qemu-arm-static) $(@D)/usr/bin
	chroot $(@D) /debootstrap/debootstrap --second-stage
	chroot $(@D) apt-get update
	touch $@

.PHONY: $(ROOTFS_DIR)
$(ROOTFS_DIR): $(ROOTFS_DIR).base/.stamp
	cp -a $(ROOTFS_DIR).base -T $@
	cd files/common && find . -type f ! -name '*~' -exec cp --preserve=mode,timestamps --parents \{\} ../../$@ \;
	[ -d files/$(DEBIAN_SUITE) ] && cd files/$(DEBIAN_SUITE) && mkdir -p ../../$@/$(DEBIAN_SUITE) && find . -type f ! -name '*~' -exec cp --preserve=mode,timestamps --parents \{\} ../../$@ \;
	mount -o bind /proc $@/proc
	mount -o bind /sys $@/sys
	mount -o bind /dev $@/dev
	cp postinstall $@
	if [ -d "postinst" ]; then cp -r postinst $@ ; fi
	chroot $@ /bin/bash -c "/postinstall $(DEBIAN_SUITE) $(DEBIAN_MIRROR)"
	for i in patches/*.patch ; do patch -p0 -d $@ < $$i ; done
	if [ -d patches/$(DEBIAN_SUITE) ]; then for i in patches/$(DEBIAN_SUITE)/*.patch; do patch -p0 -d $@ < $$i ; done fi
	umount $@/proc
	umount $@/sys
	umount $@/dev
	rm $@/postinstall
	rm -rf $@/postinst/
	#rm $@/usr/bin/qemu-arm-static
	touch $@

.PHONY: kernel-install
kernel-install: $(ROOTFS_DIR) $(call PACKAGES)
	cp $(call PACKAGES) $(ROOTFS_DIR)/tmp
	mkdir -p $(ROOTFS_DIR)/boot/u-boot
	chroot $(ROOTFS_DIR) apt-get install --yes flash-kernel
	cp --preserve=mode,timestamps files/common/etc/flash-kernel/machine $(ROOTFS_DIR)/etc/flash-kernel/machine
	cp --preserve=mode,timestamps files/common/etc/flash-kernel/db $(ROOTFS_DIR)/etc/flash-kernel/db
	chroot $(ROOTFS_DIR) /bin/bash -c "dpkg -i $(addprefix /tmp/,$(call PACKAGES))"

$(RAMDISK_FILE): $(ROOTFS_DIR)
	mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d $(ROOTFS_DIR)/boot/initrd.img-* uInitrd

$(IMAGE_FILE): $(ROOTFS_DIR) kernel-install $(RAMDISK_FILE)
	if test -f "$@.tmp"; then rm "$@.tmp" ; fi
	./createimg $@.tmp $(BOOT_MB) $(ROOT_MB) $(BOOT_DIR) $(ROOTFS_DIR) $(UBOOT_BIN_DIR) $(RAMDISK_FILE) "$(ROOT_DEV)"
	mv $@.tmp $@
	touch $@

