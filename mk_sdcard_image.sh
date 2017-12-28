#!/bin/bash


MOUNT_POINT="/tmp/mntpoint"

usage()
{
	echo "`basename "$0"` <image-folder> <image-file> [image-size-gb]"
	echo "	image-folder	Base daily build folder where artifacts live"
	echo "	image-file	Output image file, can be a physical device"
	echo "	image-size	Optional, image size in GB"

	exit 1
}

inflate_image()
{
	local dev=$1
	local size_gb=$2
	if  [ -b "$dev" ] ; then
		echo "Using physical block device $dev"
		return 0
	fi

	echo "Inflating image file at $dev of size ${size_gb}GB"
	local inflate=1
	if [ -e $1 ] ; then
		echo ""
		read -r -p "File $dev exists, remove it? [y/N]:" yesno
		case "$yesno" in
		[yY])
			rm -f $dev || exit 1
		;;
		*)
			echo "Reusing existing image file"
			inflate=0
		;;
		esac
	fi
	if [[ $inflate == 1 ]] ; then
		dd if=/dev/zero of=$dev bs=1M count=$(($size_gb*1024)) || exit 1
	fi
}

partition_image()
{
	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $1
		o # clear the in memory partition table
		n # new partition: Dom0 - 256M, ext4 primary
			p # primary partition
				# partition number
				# default - start at beginning of disk
				+256M
		n # new partition: DomD - 2G, ext4 primary
			p # primary partition
				# partition number
				# default - start at beginning of disk
				+2G
		n # new partition: DomF - 1GB, ext4 primary
			p # primary partition
				# partion number
				# default, start immediately after preceding partition
				+1G
		n # new partition: DomA - rest of the disk, ext4 primary
			e # extended partition: DomA system image, ext4
				# partition number
				# default, start immediately after preceding partition
				# default, extend partition to end of disk
			n # new logical partition - system
				# default, start immediately after preceding partition
				+2G
			n # new logical partition - vendor
				# default, start immediately after preceding partition
				+256M
			n # new logical partition - misc
				# default, start immediately after preceding partition
				+1M
			n # new logical partition - userdata
				# default, start immediately after preceding partition
				# default, extend partition to end of disk
		p # print the in-memory partition table
		w # write the partition table
		q # and we're done
EOF
	sudo partprobe
}

mkfs_image_one()
{
	local loop_base=$1
	local part=$2
	local label=$3
	local loop_dev="${loop_base}p${part}"

	sudo mkfs.ext4 -F $loop_dev -L $label
}

label_one()
{
	local loop_base=$1
	local part=$2
	local label=$3
	local loop_dev="${loop_base}p${part}"

	sudo e2label $loop_dev $label
}

mkfs_image()
{
	local img_output_file=$1
	local loop_dev=$2

	sudo losetup -P $loop_dev $img_output_file
	echo "Making ext4 filesystem for Dom0"
	mkfs_image_one $loop_dev 1 boot
	echo "Making ext4 filesystem for DomD"
	mkfs_image_one $loop_dev 2 domd
	echo "Making ext4 filesystem for DomF"
	mkfs_image_one $loop_dev 3 domf
	echo "Making ext4 filesystem for DomA/userdata"
	mkfs_image_one $loop_dev 8 doma_user
	sudo losetup -d $loop_dev
}

mount_part()
{
	local loop_base=$1
	local img_output_file=$2
	local part=$3
	local mntpoint=$4
	local loop_dev=${loop_base}p${part}

	sudo losetup -P $loop_base $img_output_file

	mkdir -p "${mntpoint}" || true
	sudo mount $loop_dev "${mntpoint}"
}

umount_part()
{
	local loop_base=$1
	local part=$2
	local loop_dev=${loop_base}p${part}

	sudo umount $loop_dev
	sudo losetup -d $loop_base
}

unpack_dom0()
{
	local db_base_folder=$1
	local loop_base=$2
	local img_output_file=$3
	local part=$4

	local dom0_name=`ls $db_base_folder | grep dom0`
	local dom0_root=$db_base_folder/$dom0_name

	local domd_name=`ls $db_base_folder | grep domd`
	local domd_root=$db_base_folder/$domd_name

	local Image=`find $dom0_root -name Image`
	local uInitramfs=`find $dom0_root -name uInitramfs`
	local dom0dtb=`find $domd_root -name dom0.dtb`
	local xenpolicy=`find $domd_root -name xenpolicy`
	local xenuImage=`find $domd_root -name xen-uImage`

	echo "Dom0 kernel image is at $Image"
	echo "Dom0 initramfs is at $uInitramfs"
	echo "Dom0 device tree is at $dom0dtb"
	echo "Xen policy is at $xenpolicy"
	echo "Xen image is at $xenuImage"

	mount_part $loop_base $img_output_file $part $MOUNT_POINT

	sudo mkdir "${MOUNT_POINT}/boot" || true

	for f in $Image $uInitramfs $dom0dtb $xenpolicy $xenuImage ; do
		sudo cp -L $f "${MOUNT_POINT}/boot/"
	done

	umount_part $loop_base $part
}

unpack_dom_from_tar()
{
	local db_base_folder=$1
	local loop_base=$2
	local img_output_file=$3
	local part=$4
	local domain=$5
	local loop_dev=${loop_base}p${part}

	local dom_name=`ls $db_base_folder | grep $domain`
	local dom_root=$db_base_folder/$dom_name
	# take the latest - useful if making image from local build
	local rootfs=`find $dom_root -name "*rootfs.tar.xz" | xargs ls -t | head -1`

	echo "Root filesystem is at $rootfs"

	mount_part $loop_base $img_output_file $part $MOUNT_POINT

	sudo tar -xf $rootfs -C "${MOUNT_POINT}"

	umount_part $loop_base $part
}

unpack_doma()
{
	local db_base_folder=$1
	local loop_base=$2
	local img_output_file=$3
	local part_system=$4
	local part_vendor=$5
	local part_misc=$6
	local raw_system="/tmp/system.raw"
	local raw_vendor="/tmp/vendor.raw"

	local doma_name=`ls $db_base_folder | grep android`
	local doma_root=$db_base_folder/$doma_name
	local system=`find $doma_root -name "system.img"`
	local vendor=`find $doma_root -name "vendor.img"`

	echo "DomA system image is at $system"
	echo "DomA vendor image is at $vendor"

	sudo losetup -P $loop_base $img_output_file

	simg2img $system $raw_system
	simg2img $vendor $raw_vendor

	sudo dd if=$raw_system of=${loop_base}p${part_system} bs=1M
	sudo dd if=$raw_vendor of=${loop_base}p${part_vendor} bs=1M
	sudo dd if=/dev/zero of=${loop_base}p${part_misc}

	rm -f $raw_system $raw_vendor

	label_one ${loop_base} ${part_system} doma_sys

	sudo losetup -d $loop_base
}

unpack_image()
{
	local db_base_folder=$1
	local loop_dev=$2
	local img_output_file=$3

	unpack_dom0 $db_base_folder $loop_dev $img_output_file 1
	unpack_dom_from_tar $db_base_folder $loop_dev $img_output_file 2 domd
	unpack_dom_from_tar $db_base_folder $loop_dev $img_output_file 3 fusion
	unpack_doma $db_base_folder $loop_dev $img_output_file 5 6 7
}

make_image()
{
	local db_base_folder=$1
	local img_output_file=$2
	local image_sg_gb=${3:-16}
	local loop_dev="/dev/loop0"

	echo "Preparing image at ${img_output_file}"
	sudo umount -f ${img_output_file}*
	inflate_image $img_output_file $image_sg_gb
	partition_image $img_output_file
	mkfs_image $img_output_file $loop_dev
	unpack_image $db_base_folder $loop_dev $img_output_file
}

if [ "$#" -lt "2" ] ; then
    usage
fi


make_image $@

