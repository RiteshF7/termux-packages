#!/bin/bash
# Create stub libraries for cross-compilation
# Usage: create_stub_libs <lib_name> [additional_libs...]
# Returns: path to stub lib directory in _STUB_LIB_DIR variable

create_stub_libs() {
	if [ -z "$CC" ]; then
		echo "Error: CC not set. Run setup_ndk_toolchain.sh first" >&2
		return 1
	fi
	
	local _stub_lib_dir="${TMPDIR:-/tmp}/stub-libs-$$"
	mkdir -p "$_stub_lib_dir"
	
	# Create stub.c source file
	echo "void stub() {}" > "$_stub_lib_dir/stub.c"
	
	# Create stub libraries for each requested library
	for _lib in "$@"; do
		# Remove lib prefix and .so suffix if present
		local _lib_name="${_lib#lib}"
		_lib_name="${_lib_name%.so}"
		
		$CC -shared -o "$_stub_lib_dir/lib${_lib_name}.so" "$_stub_lib_dir/stub.c" 2>/dev/null || true
	done
	
	# Add to library paths
	export LIBRARY_PATH="$_stub_lib_dir:${LIBRARY_PATH:-}"
	export LD_LIBRARY_PATH="$_stub_lib_dir:${LD_LIBRARY_PATH:-}"
	
	# Store directory for cleanup
	export _STUB_LIB_DIR="$_stub_lib_dir"
	
	return 0
}

cleanup_stub_libs() {
	if [ -n "$_STUB_LIB_DIR" ] && [ -d "$_STUB_LIB_DIR" ]; then
		rm -rf "$_STUB_LIB_DIR"
		unset _STUB_LIB_DIR
	fi
}

