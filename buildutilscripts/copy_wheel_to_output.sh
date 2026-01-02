#!/bin/bash
# Copy built wheel to output directory
# Usage: copy_wheel_to_output.sh <package_name> <version> <source_dir> [wheels_dir]

copy_wheel_to_output() {
	local _pkg_name="$1"
	local _version="$2"
	local _source_dir="$3"
	# Default to wheels directory in project root (two levels up from packages/)
	local _wheels_dir="${4}"
	if [ -z "$_wheels_dir" ]; then
		# Try to find wheels directory relative to project root
		local _script_dir="${SCRIPT_DIR:-$(pwd)}"
		_wheels_dir="$_script_dir/../../wheels"
		# If that doesn't exist, try termux-packages/wheels
		if [ ! -d "$_wheels_dir" ]; then
			_wheels_dir="$(dirname "$(dirname "$(dirname "$0")")")/wheels"
		fi
	fi
	
	if [ -z "$_pkg_name" ] || [ -z "$_version" ] || [ -z "$_source_dir" ]; then
		echo "Usage: copy_wheel_to_output <package_name> <version> <source_dir> [wheels_dir]" >&2
		return 1
	fi
	
	mkdir -p "$_wheels_dir"
	
	# Try to find wheel in dist directory
	if [ -d "$_source_dir/dist" ]; then
		# Try exact match first
		local _pyver="${TERMUX_PYTHON_VERSION//./}"
		local _arch="${TERMUX_ARCH:-x86_64}"
		case "$_arch" in
			aarch64) _arch="aarch64" ;;
			arm) _arch="armv7" ;;
			i686) _arch="i686" ;;
			x86_64) _arch="x86_64" ;;
		esac
		
		# Try different wheel naming patterns
		local _wheel_patterns=(
			"${_pkg_name}-${_version}-cp${_pyver}-cp${_pyver}-linux_${_arch}.whl"
			"${_pkg_name}-${_version}"*.whl
			"${_pkg_name}"*.whl
		)
		
		for _pattern in "${_wheel_patterns[@]}"; do
			if ls "$_source_dir/dist/$_pattern" 1>/dev/null 2>&1; then
				cp "$_source_dir/dist/$_pattern" "$_wheels_dir/" 2>/dev/null && break
			fi
		done
		
		# If no specific pattern matched, copy all wheels
		if [ $? -ne 0 ]; then
			cp "$_source_dir/dist"/*.whl "$_wheels_dir/" 2>/dev/null || true
		fi
	fi
	
	# Display found wheels
	echo ""
	echo "=========================================="
	echo "Build complete!"
	echo "=========================================="
	echo "Wheel location: $_wheels_dir"
	find "$_wheels_dir" -name "${_pkg_name}*.whl" -type f 2>/dev/null || true
}

# If script is run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	copy_wheel_to_output "$@"
fi

