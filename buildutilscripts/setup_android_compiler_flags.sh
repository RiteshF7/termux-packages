#!/bin/bash
# Setup Android compiler flags for cross-compilation
# Usage: source setup_android_compiler_flags.sh

setup_android_compiler_flags() {
	local _api_level="${ANDROID_API_LEVEL:-30}"
	local _arch="${TERMUX_ARCH:-x86_64}"
	local _sysroot="${SYSROOT}"
	
	if [ -z "$_sysroot" ]; then
		echo "Error: SYSROOT not set. Run setup_ndk_toolchain.sh first" >&2
		return 1
	fi
	
	# Map architecture to target triple and library path
	local _target_triple=""
	local _lib_path=""
	case "$_arch" in
		aarch64)
			_target_triple="aarch64-linux-android${_api_level}"
			_lib_path="aarch64-linux-android"
			;;
		arm)
			_target_triple="armv7a-linux-androideabi${_api_level}"
			_lib_path="armv7a-linux-androideabi"
			;;
		i686)
			_target_triple="i686-linux-android${_api_level}"
			_lib_path="i686-linux-android"
			;;
		x86_64)
			_target_triple="x86_64-linux-android${_api_level}"
			_lib_path="x86_64-linux-android"
			;;
		*)
			echo "Error: Unsupported architecture: $_arch" >&2
			return 1
			;;
	esac
	
	# Set compiler flags
	export CFLAGS="-U__ANDROID_API__ -D__ANDROID_API__=${_api_level} --sysroot=$_sysroot -fPIC -target $_target_triple"
	export CXXFLAGS="$CFLAGS"
	export LDFLAGS="--sysroot=$_sysroot -llog -L$_sysroot/usr/lib/$_lib_path/${_api_level} -fuse-ld=lld -target $_target_triple"
	
	return 0
}

