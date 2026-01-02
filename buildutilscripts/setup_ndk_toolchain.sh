#!/bin/bash
# Setup NDK toolchain for cross-compilation
# Usage: source setup_ndk_toolchain.sh

setup_ndk_toolchain() {
	if [ -z "$NDK" ]; then
		echo "Error: NDK not set. Run setup_android_env.sh first" >&2
		return 1
	fi
	
	local _toolchain_base="$NDK/toolchains/llvm/prebuilt"
	local _toolchain_dir="linux-x86_64"
	if [ ! -d "$_toolchain_base/$_toolchain_dir" ]; then
		_toolchain_dir="linux-x86"
	fi
	
	if [ ! -d "$_toolchain_base/$_toolchain_dir" ]; then
		echo "Error: Could not find NDK toolchain in $_toolchain_base" >&2
		return 1
	fi
	
	# Set architecture-specific compiler
	local _arch="${TERMUX_ARCH:-x86_64}"
	local _api_level="${ANDROID_API_LEVEL:-30}"
	
	case "$_arch" in
		aarch64)
			export CC="$_toolchain_base/$_toolchain_dir/bin/aarch64-linux-android${_api_level}-clang"
			export CXX="$_toolchain_base/$_toolchain_dir/bin/aarch64-linux-android${_api_level}-clang++"
			;;
		arm)
			export CC="$_toolchain_base/$_toolchain_dir/bin/armv7a-linux-androideabi${_api_level}-clang"
			export CXX="$_toolchain_base/$_toolchain_dir/bin/armv7a-linux-androideabi${_api_level}-clang++"
			;;
		i686)
			export CC="$_toolchain_base/$_toolchain_dir/bin/i686-linux-android${_api_level}-clang"
			export CXX="$_toolchain_base/$_toolchain_dir/bin/i686-linux-android${_api_level}-clang++"
			;;
		x86_64)
			export CC="$_toolchain_base/$_toolchain_dir/bin/x86_64-linux-android${_api_level}-clang"
			export CXX="$_toolchain_base/$_toolchain_dir/bin/x86_64-linux-android${_api_level}-clang++"
			;;
		*)
			echo "Error: Unsupported architecture: $_arch" >&2
			return 1
			;;
	esac
	
	export AR="$_toolchain_base/$_toolchain_dir/bin/llvm-ar"
	export STRIP="$_toolchain_base/$_toolchain_dir/bin/llvm-strip"
	export RANLIB="$_toolchain_base/$_toolchain_dir/bin/llvm-ranlib"
	
	# Set sysroot
	export SYSROOT="$NDK/toolchains/llvm/prebuilt/$_toolchain_dir/sysroot"
	export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
	export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig"
	
	return 0
}

