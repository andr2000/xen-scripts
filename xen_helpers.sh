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

_xen_initialize_environment()
{
	if [ "${XEN_SHELL_REUSE}" != "1" ] ; then
		_xen_initialize_shell
	fi

	# Build
	export XEN_SETUP_ID=sysroot
	_xen_initialize_sysroot

	# bash prompt
	export _XEN_ORIGINAL_PS1="${_XEN_ORIGINAL_PS1:-${PS1}}"
	export _XEN_SETUP_ID_PREFIX="\[\033[01;32m\][${XEN_SETUP_ID}"
	export _XEN_SETUP_ID_SUFFIX="\[\033[01;32m\]]\[\033[00m\]:"
	export PS1="${_XEN_SETUP_ID_PREFIX}${_XEN_SETUP_ID_SUFFIX}${_XEN_ORIGINAL_PS1}"

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
	_xen_cd_completion "xen dom0 domu domd rootfs" ""
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
			cd "${XEN_KERNEL_DOM0_DIR}"
		;;
		domd)
			cd "${XEN_KERNEL_DOMD_DIR}"
		;;
		domu)
			cd "${XEN_KERNEL_DOMU_DIR}"
		;;
		rootfs)
			cd "${XEN_ROOTFS_DOM0_DIR}"
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
			_xen_set_config XEN_KERNEL_DOM0_DIR ${PWD}
			export XEN_KERNEL_DOM0_DIR=${PWD}
		;;
		domd)
			_xen_set_config XEN_KERNEL_DOMD_DIR ${PWD}
			export XEN_KERNEL_DOMD_DIR=${PWD}
		;;
		domu)
			_xen_set_config XEN_KERNEL_DOMU_DIR ${PWD}
			export XEN_KERNEL_DOMU_DIR=${PWD}
		;;
		rootfs)
			_xen_set_config XEN_ROOTFS_DOM0_DIR ${PWD}
			export XEN_ROOTFS_DOM0_DIR=${PWD}
		;;
		*)
		;;
	esac
}

_xen_menuconfig()
{
	ARCH=arm64 make menuconfig
	exit 0
}

xen_kernel_menuconfig()
{(
	env -i TERM="xterm" PATH=${PATH} _XEN_INIT="MCONFIG" bash --rcfile $(readlink -f "${BASH_SOURCE}")
)}

xen_config()
{
	_xen_save_path .
	[[ ! -z $XEN_DIR ]] && cd ${XEN_DIR}

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
	_xen_restore_path
}

xen_compile()
{
	_xen_save_path .
	[[ ! -z ${XEN_DIR} ]] && cd ${XEN_DIR}
	local SUFFIX="CONFIG_HAS_SCIF=y CONFIG_EARLY_PRINTK=salvator CONFIG_QEMU_XEN=n debug=n DESTDIR=${PWD}/dist"

	make ${SUFFIX} ${MAKE_JOBS} install
	if [ -f dist/boot/xen ]; then
		mkimage -A arm64 -C none -T kernel -a 0x78080000 -e 0x78080000 -n "XEN" -d dist/boot/xen dist/boot/xen-uImage
	fi
	_xen_restore_path
}

xen_install()
{
	_xen_save_path .
	[[ ! -z ${XEN_DIR} ]] && cd ${XEN_DIR}

	sudo -E bash -c "cp -rfv dist/* ${XEN_ROOTFS_DOM0_DIR}"
	_xen_restore_path
}

xen_man()
{
	case "$1" in
		xen_config)
			echo "xen_config -- configure Xen build"
			;;
		xen_compile)
			echo "xen_compile -- build Xen"
			;;
		xen_install)
			echo "xen_install -- install Xen"
			;;
		xen_kernel_menuconfig)
			echo "xen_kernel_menuconfig -- make kernel config"
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
			echo "    xen    -- Xen root"
			echo "    dom0   -- Dom0 kernel"
			echo "    domd   -- DomD kernel"
			echo "    domu   -- DomU kernel"
			echo "    rootfs -- Dom0 root filesystem"
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
elif [ "${_XEN_INIT}" == "ENV" ] ; then
	_xen_initialize_environment
elif [ "${_XEN_INIT}" == "DONE" ] ; then
	echo "ERROR: The helpers are already initialized"
fi
