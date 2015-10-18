UBOOT_BIN_DIR := $(UBOOT_SRC)/sd_fuse

ADDITIONAL_PACKAGES := ssh,vim,ntpdate,usbmount
CORE_PACKAGES := ca-certificates,initramfs-tools,flash-kernel,locales,sudo

debootstrap-stage1 := rootfs/debootstrap/debootstrap
debootstrap-stage2 := rootfs/var/log/bootstrap.log
qemu-arm-static := rootfs/usr/bin/qemu-arm-static
rootfs-base := $(debootstrap-stage2) install-core-packages configure-locale configure-timezone

# This rule works without the rootfs directory even existing
.PHONY: clean-rootfs
clean-rootfs: | has_root
	if mountpoint -q rootfs/proc ; then umount rootfs/proc ; fi
	if mountpoint -q rootfs/sys ; then umount rootfs/sys ; fi
	if mountpoint -q rootfs/dev ; then umount rootfs/dev ; fi
	rm -rf rootfs/*

.PHONY: distclean-rootfs
distclean-rootfs: clean-rootfs | has_root
	rm -rf $(ROOTFS_DIR)

# Don't depend on clean-rootfs here because we *only* want to
# clean if we are debootstrapping
.INTERMEDIATE: $(debootstrap-stage1)
.PRECIOUS: $(debootstrap-stage1)
$(debootstrap-stage1): | has_root
	if mountpoint -q rootfs/proc ; then umount rootfs/proc ; fi
	if mountpoint -q rootfs/sys ; then umount rootfs/sys ; fi
	if mountpoint -q rootfs/dev ; then umount rootfs/dev ; fi
	rm -rf rootfs/*
	mkdir -p rootfs
	debootstrap --foreign --no-check-gpg --include=debian-archive-keyring --arch=$(DEBIAN_ARCH) $(DEBIAN_SUITE) rootfs $(DEBIAN_MIRROR)

$(debootstrap-stage2): $(debootstrap-stage1) | has_root $(qemu-arm-static)
	LC_ALL=C chroot rootfs /debootstrap/debootstrap --second-stage

$(qemu-arm-static): $(shell which qemu-arm-static) | has_root $(debootstrap-stage1)
	mkdir -p $(@D)
	cp -a $$(which qemu-arm-static) $@

rootfs/usr/sbin/policy-rc.d: | has_root $(debootstrap-stage1)
	#TODO: this has to be reverted at some point!
	mkdir -p $(@D)
	printf "#!/bin/sh\nexit 101" > $@
	chmod +x $@

.PHONY: update-apt
update-apt: | has_root $(qemu-arm-static)
	sem --fg --id dpkg LC_ALL=C chroot rootfs apt-get update

.PHONY: install-core-packages
install-core-packages: update-apt | has_root $(qemu-arm-static)
	sem --fg --id dpkg LC_ALL=C chroot rootfs apt-get install $(CORE_PACKAGES)

.PHONY: install-extra-packages
install-extra-packages: update-apt | has_root $(qemu-arm-static)
	sem --fg --id dpkg LC_ALL=C chroot rootfs apt-get install $(ADDITIONAL_PACKAGES)

.PHONY: install-user
install-user: $(debootstrap-stage2) | has_root install-core-packages $(qemu-arm-static)
	LC_ALL=C chroot $(ROOTFS_DIR) passwd --lock --delete root
	LC_ALL=C chroot $(ROOTFS_DIR) adduser --gecos "" --disabled-password $(USERNAME)
	LC_ALL=C chroot $(ROOTFS_DIR) adduser $(USERNAME) sudo
	echo $(USERNAME):$(PASSWORD) | LC_ALL=C chroot $(ROOTFS_DIR) chpasswd

.PHONY: configure-locale
configure-locale: $(debootstrap-stage2) | has_root install-core-packages $(qemu-arm-static)
	sed -s 's/^# *\(\($(subst $(space),\|,$(LOCALES))\).*\)/\1/' -i $(ROOTFS_DIR)/etc/locale.gen
	sem --fg --id dpkg LC_ALL=C chroot $(ROOTFS_DIR) dpkg-reconfigure -f noninteractive locales

.PHONY: configure-timezone
configure-timezone: $(debootstrap-stage2) | has_root install-core-packages $(qemu-arm-static)
	echo $(TIMEZONE) > $(ROOTFS_DIR)/etc/timezone
	sem --fg --id dpkg LC_ALL=C chroot $(ROOTFS_DIR) dpkg-reconfigure -f noninteractive tzdata

define _interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
endef
$(call declare,rootfs/etc/network/interfaces,interfaces)

.PHONY: rootfs/etc/network/interfaces
rootfs/etc/network/interfaces: | has_root
	mkdir -p $(@D)
	echo $$interfaces > $@

#$(ROOTFS_DIR): $(ROOTFS_DIR).base/.stamp has_root
#	cd files/common && find . -type f ! -name '*~' -exec cp --preserve=mode,timestamps --parents \{\} ../../$@ \;
#	[ -d files/$(DEBIAN_SUITE) ] && cd files/$(DEBIAN_SUITE) && mkdir -p ../../$@/$(DEBIAN_SUITE) && find . -type f ! -name '*~' -exec cp --preserve=mode,timestamps --parents \{\} ../../$@ \;
#	mount -o bind /proc $@/proc
#	mount -o bind /sys $@/sys
#	mount -o bind /dev $@/dev
#	cp postinstall $@
#	if [ -d "postinst" ]; then cp -r postinst $@ ; fi
#	LC_ALL=C chroot $@ /bin/bash -c "/postinstall $(DEBIAN_SUITE) $(DEBIAN_MIRROR)"
#	for i in patches/*.patch ; do patch -p0 -d $@ < $$i ; done
#	if [ -d patches/$(DEBIAN_SUITE) ]; then for i in patches/$(DEBIAN_SUITE)/*.patch; do patch -p0 -d $@ < $$i ; done fi
#	umount $@/proc
#	umount $@/sys
#	umount $@/dev
#	rm $@/postinstall
#	rm -rf $@/postinst/
#	#rm $@/usr/bin/qemu-arm-static
#	touch $@

define _fk_db
# To override fields include the Machine field and the fields you wish to
# override.
#
# e.g. to override Boot-Device on the Dreamplug to sdb rather than sda
#
#Machine: Globalscale Technologies Dreamplug
#Boot-Device: /dev/sdb1


Machine: Hardkernel Odroid C1
U-Boot-Kernel-Address: 0
U-Boot-Initrd-Address: 0
DTB-Id: meson8b_odroidc.dtb
Boot-Kernel-Path: /boot/u-boot/uImage
Boot-Initrd-Path: /boot/u-boot/uInitrd
Boot-DTB-Path: /boot/u-boot/meson8b_odroidc.dtb
endef
$(call declare,kernel-install,fk_db)

.PHONY: kernel-install
kernel-install: $(debootstrap-stage2) $(call PACKAGES) | has_root install-core-packages $(qemu-arm-static)
	mount -o bind /dev $(ROOTFS_DIR)/dev
	mount -o bind /proc $(ROOTFS_DIR)/proc
	mkdir -p $(ROOTFS_DIR)/etc/flash-kernel
	mkdir -p $(ROOTFS_DIR)/boot/u-boot
	echo $$fk_db > $(ROOTFS_DIR)/etc/flash-kernel/db
	echo "Hardkernel Odroid C1" > $(ROOTFS_DIR)/etc/flash-kernel/machine
	cp $(call PACKAGES) $(ROOTFS_DIR)/tmp
	LC_ALL=C chroot $(ROOTFS_DIR) dpkg -i $(addprefix /tmp/,$(call PACKAGES))
	umount $(ROOTFS_DIR)/proc
	umount $(ROOTFS_DIR)/dev

#$(RAMDISK_FILE): $(ROOTFS_DIR)
#	mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d $(ROOTFS_DIR)/boot/initrd.img-* uInitrd

#$(IMAGE_FILE): $(ROOTFS_DIR) kernel-install $(RAMDISK_FILE)
#	if test -f "$@.tmp"; then rm "$@.tmp" ; fi
#	./createimg $@.tmp $(BOOT_MB) $(ROOT_MB) $(BOOT_DIR) $(ROOTFS_DIR) $(UBOOT_BIN_DIR) $(RAMDISK_FILE) "$(ROOT_DEV)"
#	mv $@.tmp $@
#	touch $@



rootfs-odroid: $(rootfs-base) install-extra-packages install-user install-kernel

