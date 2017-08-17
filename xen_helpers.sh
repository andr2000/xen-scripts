#!/bin/bash

_xen_load_config()
{
	local config_file="${_XEN_CONFIG}"

	if [ "${config_file}" == "" ] ; then
		config_file="xen_helpers.conf"
		export _XEN_CONFIG_PATH="${PWD}/${config_file}"
	fi

	if [ ! -f "${config_file}" ] ; then
		config_file="${BASH_SOURCE/xen_helpers.sh/xen_helpers.conf}"
		export _XEN_CONFIG_PATH="${config_file}"
	fi

	if [ -f "${config_file}" ] ; then
		source "${config_file}"
	else
		echo touch "${config_file}"
	fi

	complete -o nospace -F _xen_cda_completion cda
	complete -o nospace -F _xen_cda_completion cda_save
	complete -o nospace -F _xen_pvr_completion xen_pvr_make

	# Load defaults
	export XEN_SHELL_REUSE=${XEN_SHELL_REUSE:-0}
	export XEN_BUILD_JOBS=${XEN_BUILD_JOBS:-1}
}

_xen_set_config()
{
	local config_file="${_XEN_CONFIG_PATH}"
	local key=$1
	local value=$2

	local exists=`grep "^export.*${key}.*=" "${config_file}"`
	if [ "${exists}" == "" ] ; then
		echo "export ${key}=" >> "${config_file}"
	fi
	sed -i "s%\(${key} *= *\).*%\1${value}%" "${config_file}"
}
_xen_initialize()
{
	export _XEN_CONFIG="$1"

	_xen_load_config

	if [ "${XEN_SHELL_REUSE}" != "1" ] ; then
		_XEN_INIT=ENV bash --rcfile $(readlink -f "${BASH_SOURCE}")
	else
		_xen_initialize_environment
	fi
}

_xen_initialize_sysroot()
{
	local environment="${XEN_SYSROOT_DIR}/environment-setup-aarch64-poky-linux"

	if [ -f "${environment}" ] ; then
		source "${environment}"
	else
		echo "WARNING: SYSROOT environment '${environment}' is not found"
		exit 1
	fi

	_xen_export_make_jobs

	unset CFLAGS
	unset LDFLAGS
	export XEN_OS="Linux"
	export XEN_COMPILE_ARCH="x86_64"
	export XEN_TARGET_ARCH="arm64"
	export XEN_CONFIG_EXPERT=y
	export MAKELEVEL=0
	export LC_ALL=C
}

_xen_initialize_shell()
{
	if [ -f /etc/bash.bashrc ] ; then
		source /etc/bash.bashrc
	fi

	if [ -f ${HOME}/.bashrc ] ; then
		source ${HOME}/.bashrc
	fi

	# Have to load config second time in case if some exports did not survive sudo and bash restart
	_xen_load_config

}

_xen_bash_prompt()
{
	export _XEN_ORIGINAL_PS1="${_XEN_ORIGINAL_PS1:-${PS1}}"
	export _XEN_SETUP_ID_PREFIX="\[\033[01;32m\][${XEN_SETUP_ID}-${XEN_SETUP_ID_EXT}"
	export _XEN_SETUP_ID_SUFFIX="\[\033[01;32m\]]\[\033[00m\]:"
	export PS1="${_XEN_SETUP_ID_PREFIX}${_XEN_SETUP_ID_SUFFIX}${_XEN_ORIGINAL_PS1}"
}

_xen_initialize_environment()
{
	if [ "${XEN_SHELL_REUSE}" != "1" ] ; then
		_xen_initialize_shell
	fi

	# Build
	if [ "${_XEN_INIT}" == "MENUCONFIG" ] ; then
		export XEN_SETUP_ID=config
		bind '"\e[A"':history-search-backward
		bind '"\e[B"':history-search-forward
	else
		export XEN_SETUP_ID=sysroot
		_xen_initialize_sysroot
	fi


	# update bash prompt
	_xen_bash_prompt

	export _XEN_INIT="DONE"
}

_xen_check_list()
{
	if [ "$(echo "$1" | grep -P "^($2)$")" != "" ] ; then
		echo found
	fi
}

_xen_parse_command_line()
{
	local name=$1
	local options=$2
	shift 2

	local parameters=""

	if ! parameters=$(getopt -n ${name} -a -l "${options}" -l "help" -o "h" -- "$@") ; then
		xen_man ${name}
		return 1
	fi

	eval "set -- ${parameters}"

	local non_option=""

	while [ $# -gt 0 ] ; do
		if [[ "$1" == "-h" || "$1" == "--help" ]] ; then
			xen_man ${name}
			return 1
		fi

		if [[ "$1" == "--" ]] ; then
			if [ ${arg_non_option+defined} ] ; then
				arg_non_option=()
				non_option="true"
				shift
				continue
			else
				return 0
			fi
		fi

		if [[ "${non_option}" == "true" ]] ; then
			arg_non_option=("${arg_non_option[@]}" "$1")
		else
			local option=$(echo "$1" | sed -re "s/^-+//")
			local argument=$(echo "${options}" | sed -re "s/.*${option}(:?).*/arg\1/")
			local variable=$(echo "${option}" | sed -re "s/\w/arg_\0/; s/-/_/g")

			case "${argument}" in
				arg) eval "$variable=1" ;;
				arg:) eval "$variable=\"$2\"" ; shift ;;
				*) xen_man ${name} ; return 1 ;;
			esac
		fi

		shift
	done
}

_xen_export_make_jobs()
{
	export MAKE_JOBS=""

	if [ "${XEN_BUILD_JOBS}" == "MAX" ] ; then
		export MAKE_JOBS=-j
	elif [ "${XEN_BUILD_JOBS}" -gt 1 ] ; then
		export MAKE_JOBS=-j${XEN_BUILD_JOBS}
	fi
}

_xen_save_path()
{
	pushd "$1" > /dev/null
}

_xen_restore_path()
{
	popd > /dev/null
}

_xen_cd_completion()
{
	COMPREPLY=()

	local current="${COMP_WORDS[COMP_CWORD]}"

	if [[ ${COMP_CWORD} == 1 ]] ; then
		local bookmarks=($(compgen -W "$1" -- ${current}))
		local files=($(compgen -d -- "$2/${current}"))
		local directories=()
		local file

		for file in "${files[@]}" ; do
			if [ -d "${file}" ] ; then
				directories+=("${file#$2/}/")
			fi
		done

		COMPREPLY=("${bookmarks[@]}" "${directories[@]}")
	fi
}

_xen_cda_completion()
{
	_xen_cd_completion "xen dom0 domu domd rootfs0 rootfsu pvr_km pvr_um pvr_meta tftp" ""
}

_xen_pvr_completion()
{
	_xen_cd_completion "dom0 domu domd h3 m3" ""
}

cd() {
	builtin cd "$@" || return
	export XEN_SETUP_ID_EXT=""
	[ "$OLDPWD" = "$PWD" ] || case $PWD in
		"${XEN_DIR}")
			export XEN_SETUP_ID_EXT="xen"
		;;
		"${XEN_DIR_KERNEL_DOM0}")
			export XEN_SETUP_ID_EXT="dom0"
		;;
		"${XEN_DIR_KERNEL_DOMU}")
			export XEN_SETUP_ID_EXT="domu"
		;;
		"${XEN_DIR_ROOTFS_DOM0}")
			export XEN_SETUP_ID_EXT="rootfs0"
		;;
		"${XEN_DIR_ROOTFS_DOMU}")
			export XEN_SETUP_ID_EXT="rootfsu"
		;;
		"${XEN_DIR_PVR_KM}")
			export XEN_SETUP_ID_EXT="pvr_km"
		;;
		"${XEN_DIR_PVR_UM}")
			export XEN_SETUP_ID_EXT="pvr_um"
		;;
		"${XEN_DIR_PVR_META}")
			export XEN_SETUP_ID_EXT="pvr_meta"
		;;
		"${XEN_DIR_TFTP}")
			export XEN_SETUP_ID_EXT="tftp"
		;;
	esac
	_xen_bash_prompt
}

cda()
{
	if [ "$1" == "" ] ; then
		cd ${XEN_DIR}
		return
	fi

	case "$1" in
		xen)
			cd "${XEN_DIR}"
		;;
		dom0)
			cd "${XEN_DIR_KERNEL_DOM0}"
		;;
		domd)
			cd "${XEN_DIR_KERNEL_DOMD}"
		;;
		domu)
			cd "${XEN_DIR_KERNEL_DOMU}"
		;;
		rootfs0)
			cd "${XEN_DIR_ROOTFS_DOM0}"
		;;
		rootfsu)
			cd "${XEN_DIR_ROOTFS_DOMU}"
		;;
		pvr_km)
			cd "${XEN_DIR_PVR_KM}"
		;;
		pvr_um)
			cd "${XEN_DIR_PVR_UM}"
		;;
		pvr_meta)
			cd "${XEN_DIR_PVR_META}"
		;;
		tftp)
			cd "${XEN_DIR_TFTP}"
		;;
		*)
		;;
	esac
}

cda_save()
{
	if [ "$1" == "" ] ; then
		return
	fi

	case "$1" in
		xen)
			_xen_set_config XEN_DIR ${PWD}
			export XEN_DIR=${PWD}
		;;
		dom0)
			_xen_set_config XEN_DIR_KERNEL_DOM0 ${PWD}
			export XEN_DIR_KERNEL_DOM0=${PWD}
		;;
		domd)
			_xen_set_config XEN_DIR_KERNEL_DOMD ${PWD}
			export XEN_DIR_KERNEL_DOMD=${PWD}
		;;
		domu)
			_xen_set_config XEN_DIR_KERNEL_DOMU ${PWD}
			export XEN_DIR_KERNEL_DOMU=${PWD}
		;;
		rootfs0)
			_xen_set_config XEN_DIR_ROOTFS_DOM0 ${PWD}
			export XEN_DIR_ROOTFS_DOM0=${PWD}
		;;
		rootfsu)
			_xen_set_config XEN_DIR_ROOTFS_DOMU ${PWD}
			export XEN_DIR_ROOTFS_DOMU=${PWD}
		;;
		pvr_km)
			_xen_set_config XEN_DIR_PVR_KM ${PWD}
			export XEN_DIR_PVR_KM=${PWD}
		;;
		pvr_um)
			_xen_set_config XEN_DIR_PVR_UM ${PWD}
			export XEN_DIR_PVR_UM=${PWD}
		;;
		pvr_meta)
			_xen_set_config XEN_DIR_PVR_META ${PWD}
			export XEN_DIR_PVR_META=${PWD}
		;;
		tftp)
			_xen_set_config XEN_DIR_TFTP ${PWD}
			export XEN_DIR_TFTP=${PWD}
		;;
		*)
		;;
	esac
}

_xen_kernel_config()
{
	_xen_initialize_environment
}

xen_kernel_config()
{
	env -i TERM="xterm" PATH=${PATH} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} \
		_XEN_INIT=MENUCONFIG XEN_SHELL_REUSE=1 \
		bash --rcfile $(readlink -f "${BASH_SOURCE}")
}

_xen_select_rootfs()
{
	case $PWD in
		"${XEN_DIR_KERNEL_DOM0}")
			export XEN_DIR_ROOTFS=${XEN_DIR_ROOTFS_DOM0}
		;;
		"${XEN_DIR_KERNEL_DOMD}")
			export XEN_DIR_ROOTFS=${XEN_DIR_ROOTFS_DOMD}
		;;
		"${XEN_DIR_KERNEL_DOMU}")
			export XEN_DIR_ROOTFS=${XEN_DIR_ROOTFS_DOMU}
		;;
		*)
			export XEN_DIR_ROOTFS="/tmp/"
			echo "WARNING!!! Installing into ${XEN_DIR_ROOTFS}"
		;;
	esac

}

_xen_kernel_install()
{
	local kernel=$1
	shift 1

	case "$kernel" in
		domu)
			# always install into Dom0's root fs so these are reachable by Dom0
			if [ "$XEN_DIR_ROOTFS_DOM0" == "" ] ; then
				echo "ERROR: Install path is not set: dom0 root fs"
				return 1
			fi
			KERNEL_INSTALL_PATH="${XEN_DIR_ROOTFS_DOM0}/boot"
		;;
		*)
			if [ "$XEN_DIR_TFTP" == "" ] ; then
				echo "ERROR: Install path is not set: tftp"
				return 1
			fi
			KERNEL_INSTALL_PATH="${XEN_DIR_TFTP}"
		;;
	esac

	sudo -E PATH=$PATH INSTALL_PATH=${KERNEL_INSTALL_PATH} make V=${MAKELEVEL} install
	sudo -E PATH=$PATH INSTALL_PATH=${KERNEL_INSTALL_PATH} make V=${MAKELEVEL} dtbs_install
	# Read KERNELRELEASE from include/config/kernel.release (if it exists)
	KERNELRELEASE=`cat include/config/kernel.release 2> /dev/null`
	if [[ ! -z $KERNELRELEASE ]] ; then
		pushd . > /dev/null
		cd ${KERNEL_INSTALL_PATH}
		sudo rm Image || true
		sudo ln -s "vmlinuz-${KERNELRELEASE}" Image
		popd > /dev/null
	fi
}

_xen_kernel_install_modules()
{
	_xen_select_rootfs

	if [ "$XEN_DIR_ROOTFS" == "" ] ; then
		echo "ERROR: Install path is $XEN_DIR_ROOTFS"
		return
	fi

	# INSTALL_MOD_STRIP=1 for stripping the modules
	sudo -E PATH=$PATH INSTALL_MOD_PATH=${XEN_DIR_ROOTFS}/ V=${MAKELEVEL} make V=${MAKELEVEL} \
		INSTALL_MOD_STRIP=1 modules_install
}

xen_kernel_install()
{
	_xen_kernel_install $1 && _xen_kernel_install_modules
}

xen_kernel_install_no_modules()
{
        _xen_kernel_install $1
}

_xen_pvr_make()
{
	local kernel=$1
	shift 1

	case "$kernel" in
		dom0)
			export PVR_KERNEL_DIR=${XEN_DIR_KERNEL_DOM0}
			export PVR_DISCIMAGE=${XEN_DIR_ROOTFS_DOM0}
		;;
		domd)
			export PVR_KERNEL_DIR=${XEN_DIR_KERNEL_DOMD}
			export PVR_DISCIMAGE=${XEN_DIR_ROOTFS_DOMD}
		;;
		domu)
			export PVR_KERNEL_DIR=${XEN_DIR_KERNEL_DOMU}
			export PVR_DISCIMAGE=${XEN_DIR_ROOTFS_DOMU}
		;;
		*)
			echo "$(tput setaf 1)ERROR: domX must be supplied as argument"
			return 1
		;;
	esac

	case "$1" in
		h3)
			export PVR_FLAVOR="r8a7795_linux"
			shift 1
			case "$1" in
				guest)
					export PVR_VIRT_OPS="SUPPORT_PVRSRV_GPUVIRT=1 PVRSRV_GPUVIRT_GUESTDRV=1"
					echo "Using r8a7795_linux to build guest driver"
					shift 1
				;;
				host)
					export PVR_VIRT_OPS="SUPPORT_PVRSRV_GPUVIRT=1 PVRSRV_GPUVIRT_NUM_OSID=2"
					echo "Using r8a7795_linux to build host driver"
					shift 1
				;;
				"")
				;;
				*)
					echo "Unknown virtualization flavor ${1}, use guest/host to change"
					return 1
				;;
			esac
		;;
		m3)
			export PVR_FLAVOR="r8a7796_linux"
			shift 1
			case "$1" in
				guest)
					export PVR_VIRT_OPS="SUPPORT_PVRSRV_GPUVIRT=1 PVRSRV_GPUVIRT_GUESTDRV=1"
					echo "Using r8a7796_linux to build guest driver"
					shift 1
				;;
				host)
					export PVR_VIRT_OPS="SUPPORT_PVRSRV_GPUVIRT=1 PVRSRV_GPUVIRT_NUM_OSID=2"
					echo "Using r8a7796_linux to build host driver"
					shift 1
				;;
				"")
				;;
				*)
					echo "Unknown virtualization flavor ${1}, use guest/host to change"
					return 1
				;;
			esac
		;;
		*)
			echo "Using r8a7796_linux, use m3/h3 argument to change"
			export PVR_FLAVOR="r8a7796_linux"
		;;
	esac

	local SUFFIX="KERNELDIR=$PVR_KERNEL_DIR DISCIMAGE=$PVR_DISCIMAGE PVR_BUILD_DIR=$PVR_FLAVOR METAG_INST_ROOT=$XEN_DIR_PVR_META $PVR_VIRT_OPS"
	make ${SUFFIX} ${MAKE_JOBS} V=${MAKELEVEL} $@
}

xen_pvr_make()
{
	_xen_pvr_make $@ || return
}

xen_pvr_install()
{
	_xen_pvr_make $@ || return

	local SUFFIX="KERNELDIR=$PVR_KERNEL_DIR DISCIMAGE=$PVR_DISCIMAGE PVR_BUILD_DIR=$PVR_FLAVOR"
	sudo -E PATH=$PATH make ${SUFFIX} ${MAKE_JOBS} V=${MAKELEVEL} install
}
xen_config()
{
	if [ "1" = "1" ]; then
		echo "XSM_ENABLE := y" > .config
		echo "CONFIG_HAS_SCIF := y" >> .config
		echo "CONFIG_EARLY_PRINTK := salvator" >> .config
		echo "CONFIG_QEMU_XEN := n" >> .config
		echo "CONFIG_DEBUG := y" >> .config
	fi
	if [ "1" = "0" ]; then
		#fixup AS/CC/CCP/etc variable within StdGNU.mk
		for i in LD CC CPP CXX; do
			sed -i "s/^\($i\s\s*\).*=/\1?=/" config/StdGNU.mk
		done
		#fixup environment passing in some makefiles
		sed -i 's#\(\w*\)=\(\$.\w*.\)#\1="\2"#' tools/firmware/Makefile
		#libsystemd-daemon -> libsystemd for newer systemd versions
		sed -i 's#libsystemd-daemon#libsystemd#' tools/configure
	fi
	./configure ${CONFIGURE_FLAGS} --prefix=/usr --exec_prefix=/usr --bindir=/usr/bin \
		--sbindir=/usr/sbin --libexecdir=/usr/lib --datadir=/usr/share \
		--sysconfdir=/etc --sharedstatedir=/com --localstatedir=/var \
		--libdir=/usr/lib --includedir=/usr/include --oldincludedir=/usr/include \
		--infodir=/usr/share/info --mandir=/usr/share/man --disable-silent-rules \
		--disable-dependency-tracking --exec-prefix=/usr --prefix=/usr \
		--with-systemd=/lib/systemd/system --with-systemd-modules-load=/lib/systemd/modules-load.d \
		--disable-stubdom --disable-ioemu-stubdom --disable-pv-grub --disable-xenstore-stubdom \
		--disable-rombios --disable-ocamltools --with-initddir=/etc/init.d \
		--with-sysconfig-leaf-dir=default --with-system-qemu=/usr/bin/qemu-system-i386 \
		--disable-qemu-traditional --enable-nls --disable-seabios --disable-sdl \
		--enable-systemd --enable-xsmpolicy --disable-docs --with-sysroot=${SDKTARGETSYSROOT}
}

xen_compile()
{
	local SUFFIX="CONFIG_HAS_SCIF=y CONFIG_EARLY_PRINTK=salvator CONFIG_QEMU_XEN=n debug=n DESTDIR=${PWD}/dist"

	make ${SUFFIX} ${MAKE_JOBS} V=${MAKELEVEL} install || echo "$(tput setaf 1)ERRORS: build failed"
	if [ -f dist/boot/xen ]; then
		mkimage -A arm64 -C none -T kernel -a 0x78080000 -e 0x78080000 -n "XEN" -d dist/boot/xen dist/boot/xen-uImage
	fi
}

xen_make()
{
	local SUFFIX="CONFIG_HAS_SCIF=y CONFIG_EARLY_PRINTK=salvator CONFIG_QEMU_XEN=n debug=n DESTDIR=${PWD}/dist"

	make ${SUFFIX} ${MAKE_JOBS} V=${MAKELEVEL} $@
}


xen_install()
{
	sudo -E bash -c "cp -rfv dist/* ${XEN_DIR_ROOTFS_DOM0}"
}

xen_install_boot()
{
	cp -vf dist/boot/* ${XEN_DIR_TFTP}
}

xen_cscope()
{
	echo "[GEN]	cscope"
	find . -name "*.[chS]" -type f | grep -v x86  > cscope.files
	cscope -bq
}

xen_man()
{
	case "$1" in
		xen_config)
			echo "xen_config -- configure Xen build"
			;;
		xen_compile)
			echo "xen_compile -- build Xen, the tools and install"
			;;
		xen_cscope)
			echo "xen_cscope -- generate cscope database for XEN"
			;;
		xen_make)
			echo "xen_make -- run make w/ parameters provided as args"
			;;
		xen_pvr_make)
			echo "xen_pvr_make -- run make w/ parameters provided as args for PVR KM/UM"
			echo "  Arguments:"
			echo "    [dom0|domu]  - domain to build for"
			echo "    [m3|h3]      - platform to build for"
			echo "    [guest|host] - optional, build with virtualization support"
			;;
		xen_install)
			echo "xen_install -- install Xen"
			;;
		xen_install_boot)
			echo "xen_install_boot -- install boot images to TFTP dir"
			;;
		xen_kernel_config)
			echo "xen_kernel_config -- run environment for kernel config"
			;;
		xen_kernel_install)
			echo "xen_kernel_install -- install kernel, dtbs and modules"
			echo "  Options:"
			echo "    <domu>  - install domu kernel/modules into dom0's root fs"
			;;
		xen_kernel_install_no_modules)
			echo "xen_kernel_install_no_modules -- install kernel and dtbs, NO modules"
			echo "  Options:"
			echo "    <domu>  - install domu kernel/modules into dom0's root fs"
			;;
		xen_helpers)
			echo "xen_helpers"
			echo
			echo "  The script provides a shell environment with a number of convenience functions that"
			echo "  simplify XEN development. To initialize the environment run or source the script."
			echo
			echo "  Options:"
			echo "    --config <path> -- path to the configuration file. By default the script looks for"
			echo "                       xen_helpers.conf in the same directory as the script itself."
			;;
		cda)
			echo "cda -- go to work directories"
			echo "  When executed without parameter, changes working directory to the root of XEN tree."
			echo "  Goes to one of pre-defined locations if bookmark name is passed."
			echo
			echo "  Bookmarks:"
			echo "    xen     -- Xen root"
			echo "    dom0    -- Dom0 kernel"
			echo "    domd    -- DomD kernel"
			echo "    domu    -- DomU kernel"
			echo "    rootfs0 -- Dom0 root filesystem"
			echo "    pvr_km  -- PVR KM"
			echo "    tftp    -- TFTP server root"
			;;
		cda_save)
			echo "cda_save -- save work directories paths for use with cda"
			echo
			echo "  Bookmarks:"
			echo "    same as for cda"
			;;


		*)
			echo "Below is the list of available helper functions. To get detailed help"
			echo "for a particular function run:"
			echo
			echo "    xen_man <function_name>"
			echo
			echo "Functions:"
			echo "  xen_kernel_menuconfig  -- make menuconfig for Dom0 or DomU kernel"
			;;
	esac

	echo
}

arg_config=""

_xen_parse_command_line "xen_helpers" "config:" "$@" || exit 1

if [ "${_XEN_INIT}" == "" ] ; then
	_xen_initialize "${arg_config}"
elif [ "${_XEN_INIT}" == "MENUCONFIG" ] ; then
	_xen_kernel_config
elif [ "${_XEN_INIT}" == "ENV" ] ; then
	_xen_initialize_environment
elif [ "${_XEN_INIT}" == "DONE" ] ; then
	echo "ERROR: The helpers are already initialized"
fi
