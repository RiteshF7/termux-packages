#!/bin/bash
# Build orjson wheel for Android x86_64
# Can be run standalone or sourced by Termux build system

set -e

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDUTIL_DIR="$(cd "$SCRIPT_DIR/../../buildutilscripts" && pwd)"
source "$BUILDUTIL_DIR/setup_android_env.sh"
source "$BUILDUTIL_DIR/setup_ndk_toolchain.sh"
source "$BUILDUTIL_DIR/create_stub_libs.sh"
source "$BUILDUTIL_DIR/setup_rust_android.sh"
source "$BUILDUTIL_DIR/download_pypi_source.sh"
source "$BUILDUTIL_DIR/copy_wheel_to_output.sh"

TERMUX_PKG_HOMEPAGE=https://github.com/ijl/orjson
TERMUX_PKG_DESCRIPTION="Fast, correct Python JSON library supporting dataclasses, datetimes, and numpy"
TERMUX_PKG_LICENSE="Apache-2.0 OR MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="3.11.5"
TERMUX_PKG_SRCURL=https://files.pythonhosted.org/packages/source/o/orjson/orjson-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=""
TERMUX_PKG_DEPENDS="python, libc++"
TERMUX_PKG_BUILD_DEPENDS="rust"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_PLATFORM_INDEPENDENT=false
TERMUX_PKG_PYTHON_COMMON_DEPS="maturin, build, wheel, setuptools"
TERMUX_PKG_AUTO_UPDATE=true

termux_step_pre_configure() {
	# Setup Rust for Android
	if ! type termux_setup_rust &>/dev/null; then
		setup_rust_android
	else
		termux_setup_rust
		# Ensure CARGO_TARGET_NAME is set
		if [ -z "$CARGO_TARGET_NAME" ]; then
			setup_rust_android
		fi
	fi
	
	# Ensure maturin is available
	if ! command -v maturin >/dev/null 2>&1; then
		pip install maturin --break-system-packages 2>/dev/null || pip install maturin
	fi
	
	# Setup NDK toolchain if not already set
	if [ -z "$CC" ] && [ -n "$NDK" ]; then
		setup_ndk_toolchain
	fi
	
	# Setup Rust/Cargo config
	setup_rust_android
	
	# Check for cross-compilation Python library
	local _cross_python_lib="$HOME/.termux-build/python${TERMUX_PYTHON_VERSION}-crossenv-prefix-bionic-${TERMUX_ARCH}/cross/lib"
	
	# Create stub libraries for Python and unwind if cross-compilation Python lib not found
	# PyO3 requires these libraries but they'll be available at runtime on Android
	if [ ! -f "$_cross_python_lib/libpython${TERMUX_PYTHON_VERSION}.so" ] && [ -n "$CC" ]; then
		create_stub_libs "python${TERMUX_PYTHON_VERSION}" "unwind"
	fi
	
	# Configure pyo3 to use the correct Python library for cross-compilation
	if [ -d "$_cross_python_lib" ] && [ -f "$_cross_python_lib/libpython${TERMUX_PYTHON_VERSION}.so" ]; then
		export LIBRARY_PATH="$_cross_python_lib:${LIBRARY_PATH:-}"
		export PYO3_PYTHON_LIB_DIR="$_cross_python_lib"
	else
		# For cross-compilation, maturin will handle Python linking
		# Just ensure we don't try to link against host Python
		unset PYO3_PYTHON_LIB_DIR
	fi
	
	# Setup PyO3 cross-compilation flags
	setup_pyo3_cross
}

termux_step_make() {
	# Build wheel using maturin directly
	# CARGO_TARGET_NAME is set by setup_rust_android
	# Maturin requires interpreter name (not path) when cross-compiling
	local _cross_python_dir="$HOME/.termux-build/python${TERMUX_PYTHON_VERSION}-crossenv-prefix-bionic-${TERMUX_ARCH}/cross/bin"
	if [ -d "$_cross_python_dir" ]; then
		export PATH="$_cross_python_dir:$PATH"
	fi
	
	# --skip-auditwheel workaround for Maturin error
	maturin build --release --target "$CARGO_TARGET_NAME" --out dist --interpreter "python${TERMUX_PYTHON_VERSION}" --skip-auditwheel
}

termux_step_post_make() {
	# Cleanup stub libraries if created
	cleanup_stub_libs
}

termux_step_make_install() {
	local _pyver="${TERMUX_PYTHON_VERSION//./}"
	local _arch="${TERMUX_ARCH}"
	# Map Termux arch to wheel arch
	case "$TERMUX_ARCH" in
		aarch64) _arch="aarch64" ;;
		arm) _arch="armv7" ;;
		i686) _arch="i686" ;;
		x86_64) _arch="x86_64" ;;
	esac
	
	local _wheel="orjson-${TERMUX_PKG_VERSION}-cp${_pyver}-cp${_pyver}-linux_${_arch}.whl"
	
	# Use cross-compilation Python's pip if available
	local _cross_python_dir="$HOME/.termux-build/python${TERMUX_PYTHON_VERSION}-crossenv-prefix-bionic-${TERMUX_ARCH}/cross/bin"
	local _pip_cmd="pip"
	if [ -d "$_cross_python_dir" ] && [ -f "$_cross_python_dir/pip${TERMUX_PYTHON_VERSION}" ]; then
		_pip_cmd="$_cross_python_dir/pip${TERMUX_PYTHON_VERSION}"
	fi
	
	# Try to find the built wheel
	if [ -f "$TERMUX_PKG_SRCDIR/dist/${_wheel}" ]; then
		$_pip_cmd install --no-deps --prefix="$TERMUX_PREFIX" --force-reinstall "$TERMUX_PKG_SRCDIR/dist/${_wheel}" || \
		termux_extract_wheel_and_install "$TERMUX_PKG_SRCDIR/dist/${_wheel}"
	elif [ -f "$TERMUX_PKG_SRCDIR/dist/orjson-${TERMUX_PKG_VERSION}"*.whl ]; then
		local _found_wheel=$(ls "$TERMUX_PKG_SRCDIR/dist/orjson-${TERMUX_PKG_VERSION}"*.whl | head -1)
		$_pip_cmd install --no-deps --prefix="$TERMUX_PREFIX" --force-reinstall "$_found_wheel" || \
		termux_extract_wheel_and_install "$_found_wheel"
	else
		local _found_wheel=$(ls "$TERMUX_PKG_SRCDIR/dist/orjson"*.whl | head -1)
		$_pip_cmd install --no-deps --prefix="$TERMUX_PREFIX" --force-reinstall "$_found_wheel" || \
		termux_extract_wheel_and_install "$_found_wheel"
	fi
}

# Helper function to manually extract and install wheel when pip rejects it
termux_extract_wheel_and_install() {
	local _wheel="$1"
	local _tmpdir=$(mktemp -d)
	
	# Extract wheel (wheels are zip files)
	unzip -q "$_wheel" -d "$_tmpdir"
	
	# Install metadata and data files
	if [ -d "$_tmpdir/orjson" ]; then
		mkdir -p "$TERMUX_PREFIX/lib/python${TERMUX_PYTHON_VERSION}/site-packages"
		cp -r "$_tmpdir/orjson" "$TERMUX_PREFIX/lib/python${TERMUX_PYTHON_VERSION}/site-packages/"
	fi
	
	# Install .dist-info
	if [ -d "$_tmpdir"/*.dist-info ]; then
		cp -r "$_tmpdir"/*.dist-info "$TERMUX_PREFIX/lib/python${TERMUX_PYTHON_VERSION}/site-packages/"
	fi
	
	rm -rf "$_tmpdir"
}

# Standalone execution - if script is run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	# Setup Android environment
	setup_android_sdk_ndk || exit 1
	
	# Setup Termux build environment
	setup_termux_build_env
	
	echo "Building orjson using Termux build.sh"
	echo "SDK: $ANDROID_SDK"
	echo "NDK: $NDK"
	echo "Architecture: $TERMUX_ARCH"
	echo "Python: $TERMUX_PYTHON_VERSION"
	echo ""
	
	# Download source
	echo "Downloading orjson source..."
	cd "$TERMUX_PKG_SRCDIR"
	download_pypi_source "orjson" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR" "orjson-${TERMUX_PKG_VERSION}.tar.gz" || exit 1
	tar -xzf "orjson-${TERMUX_PKG_VERSION}.tar.gz" --strip-components=1
	
	# Run build steps
	termux_step_pre_configure
	termux_step_make
	termux_step_post_make
	
	# Copy wheel to output
	copy_wheel_to_output "orjson" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
	
	# Cleanup
	rm -rf "$TERMUX_PKG_SRCDIR" "$TERMUX_PKG_MASSAGEDIR"
fi
