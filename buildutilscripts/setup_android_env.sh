#!/bin/bash
# Setup Android build environment variables
# Usage: source setup_android_env.sh

# Find Android SDK and NDK
setup_android_sdk_ndk() {
	local _default_sdk="${ANDROID_SDK:-/media/trex/92e387d0-6ebf-4985-9602-95ad507642c3/home/trex/Android/Sdk}"
	
	ANDROID_SDK="${ANDROID_SDK:-$_default_sdk}"
	
	NDK_PATH=""
	if [ -n "$NDK" ]; then
		NDK_PATH="$NDK"
	else
		for ndk_dir in "$ANDROID_SDK/ndk"/*; do
			if [ -d "$ndk_dir" ]; then
				NDK_PATH="$ndk_dir"
				break
			fi
		done
	fi
	
	if [ -z "$NDK_PATH" ]; then
		echo "Error: Could not find NDK. Set NDK environment variable or ensure NDK is in $ANDROID_SDK/ndk" >&2
		return 1
	fi
	
	export ANDROID_HOME="$ANDROID_SDK"
	export NDK="$NDK_PATH"
	export TERMUX_ARCH="${TERMUX_ARCH:-x86_64}"
	
	# Get Python version if not set
	if [ -z "$TERMUX_PYTHON_VERSION" ]; then
		TERMUX_PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
		export TERMUX_PYTHON_VERSION
	fi
	
	return 0
}

# Setup minimal Termux-like environment for standalone builds
setup_termux_build_env() {
	export TERMUX_PKG_SRCDIR="${TERMUX_PKG_SRCDIR:-$(mktemp -d)}"
	export TERMUX_PKG_BUILDDIR="${TERMUX_PKG_BUILDDIR:-$TERMUX_PKG_SRCDIR}"
	export TERMUX_PKG_MASSAGEDIR="${TERMUX_PKG_MASSAGEDIR:-$(mktemp -d)}"
	export TERMUX_PREFIX="${TERMUX_PREFIX:-$TERMUX_PKG_MASSAGEDIR/data/data/com.termux/files/usr}"
	
	mkdir -p "$TERMUX_PREFIX"
}

