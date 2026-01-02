#!/bin/bash
# Create meson cross-compilation file for Android
# Usage: create_meson_cross_file <output_file>

create_meson_cross_file() {
	local _output_file="$1"
	
	if [ -z "$_output_file" ]; then
		echo "Usage: create_meson_cross_file <output_file>" >&2
		return 1
	fi
	
	if [ -z "$CC" ] || [ -z "$CXX" ] || [ -z "$AR" ]; then
		echo "Error: CC, CXX, AR not set. Run setup_ndk_toolchain.sh first" >&2
		return 1
	fi
	
	local _arch="${TERMUX_ARCH:-x86_64}"
	local _cpu_family=""
	local _cpu=""
	
	# Map Termux arch to meson arch
	case "$_arch" in
		aarch64)
			_cpu_family="aarch64"
			_cpu="aarch64"
			;;
		arm)
			_cpu_family="arm"
			_cpu="armv7"
			;;
		i686)
			_cpu_family="x86"
			_cpu="i686"
			;;
		x86_64)
			_cpu_family="x86_64"
			_cpu="x86_64"
			;;
		*)
			echo "Error: Unsupported architecture: $_arch" >&2
			return 1
			;;
	esac
	
	# Create meson cross file
	cat > "$_output_file" << EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '${STRIP:-${AR%/*}/llvm-strip}'

[host_machine]
system = 'android'
cpu_family = '$_cpu_family'
cpu = '$_cpu'
endian = 'little'

[properties]
c_args = ['${CFLAGS}']
cpp_args = ['${CXXFLAGS}']
c_link_args = ['${LDFLAGS}']
cpp_link_args = ['${LDFLAGS}']
EOF
	
	export MESON_CROSS_FILE="$_output_file"
	return 0
}

