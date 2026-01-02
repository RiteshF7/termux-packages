#!/bin/bash
# Build scikit-learn wheel for Android x86_64
# Can be run standalone or sourced by Termux build system

set -e

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDUTIL_DIR="$(cd "$SCRIPT_DIR/../../buildutilscripts" && pwd)"
source "$BUILDUTIL_DIR/setup_android_env.sh"
source "$BUILDUTIL_DIR/setup_ndk_toolchain.sh"
source "$BUILDUTIL_DIR/setup_android_compiler_flags.sh"
source "$BUILDUTIL_DIR/create_meson_cross_file.sh"
source "$BUILDUTIL_DIR/install_python_deps.sh"
source "$BUILDUTIL_DIR/download_pypi_source.sh"
source "$BUILDUTIL_DIR/copy_wheel_to_output.sh"

TERMUX_PKG_HOMEPAGE=https://scikit-learn.org/
TERMUX_PKG_DESCRIPTION="Machine learning library for Python"
TERMUX_PKG_LICENSE="BSD 3-Clause"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.8.0"
TERMUX_PKG_SRCURL=https://files.pythonhosted.org/packages/source/s/scikit-learn/scikit-learn-${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=""
TERMUX_PKG_DEPENDS="python, numpy, scipy, libc++"
TERMUX_PKG_BUILD_DEPENDS="meson-python, build, wheel, setuptools"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_PLATFORM_INDEPENDENT=false
TERMUX_PKG_PYTHON_COMMON_DEPS="meson-python<0.19.0,>=0.16.0, joblib>=1.3.0, threadpoolctl>=3.2.0"
TERMUX_PKG_AUTO_UPDATE=true

termux_step_pre_configure() {
	# Setup NDK toolchain FIRST (before installing Python packages)
	if [ -z "$CC" ] && [ -n "$NDK" ]; then
		setup_ndk_toolchain
		setup_android_compiler_flags
		
		# Create meson cross file for Android
		local _meson_cross_file="$TERMUX_PKG_SRCDIR/meson-cross.ini"
		create_meson_cross_file "$_meson_cross_file"
	fi
	
	# Check and install required build dependencies (numpy, scipy) - needed before building
	# Use system Python (not cross-compiled) for installing build dependencies
	unset _PYTHON_SYSCONFIGDATA_NAME
	
	# Define wheels directory (can be set via environment variable)
	local WHEELS_DIR="${WHEELS_DIR:-$HOME/wheels}"
	
	# Check for numpy: installed -> wheel -> install from source
	if python3 -c "import numpy; print(f'numpy version: {numpy.__version__}')" 2>/dev/null; then
		echo "numpy is already installed, skipping installation"
	elif [ -n "$(find "$WHEELS_DIR" -name "numpy-*.whl" 2>/dev/null | head -1)" ]; then
		local NUMPY_WHEEL=$(find "$WHEELS_DIR" -name "numpy-*.whl" | head -1)
		echo "Installing numpy from wheel: $(basename "$NUMPY_WHEEL")"
		pip install "$NUMPY_WHEEL" --find-links "$WHEELS_DIR" --no-index --no-deps || { echo "ERROR: numpy wheel installation failed"; exit 1; }
		python3 -c "import numpy; print(f'numpy version: {numpy.__version__}')" || { echo "ERROR: numpy import failed"; exit 1; }
	else
		echo "Installing numpy (required for build, version <2.4.0,>=2)..."
		pip install "numpy>=2,<2.4.0" --break-system-packages --user || pip install "numpy>=2,<2.4.0" --user || pip install "numpy>=2,<2.4.0"
		python3 -c "import numpy; print(f'numpy version: {numpy.__version__}')" || { echo "ERROR: numpy installation failed"; exit 1; }
	fi
	
	# Check for scipy: installed -> wheel -> install from source
	if python3 -c "import scipy; print(f'scipy version: {scipy.__version__}')" 2>/dev/null; then
		echo "scipy is already installed, skipping installation"
	elif [ -n "$(find "$WHEELS_DIR" -name "scipy-*.whl" 2>/dev/null | head -1)" ]; then
		local SCIPY_WHEEL=$(find "$WHEELS_DIR" -name "scipy-*.whl" | head -1)
		echo "Installing scipy from wheel: $(basename "$SCIPY_WHEEL")"
		pip install "$SCIPY_WHEEL" --find-links "$WHEELS_DIR" --no-index --no-deps || { echo "ERROR: scipy wheel installation failed"; exit 1; }
		python3 -c "import scipy; print(f'scipy version: {scipy.__version__}')" || { echo "ERROR: scipy import failed"; exit 1; }
	else
		echo "Installing scipy (required for build)..."
		pip install "scipy>=1.10.0,<1.17.0" --break-system-packages --user || pip install "scipy>=1.10.0,<1.17.0" --user || pip install "scipy>=1.10.0,<1.17.0"
		python3 -c "import scipy; print(f'scipy version: {scipy.__version__}')" || { echo "ERROR: scipy installation failed"; exit 1; }
	fi
	
	install_python_deps "joblib>=1.3.0" "threadpoolctl>=3.2.0"
	
	# Fix version.py - add shebang if missing (required for meson build)
	# Reference: install_scikit_learn_standalone.py lines 244-250
	local _version_py="$TERMUX_PKG_SRCDIR/sklearn/_build_utils/version.py"
	if [ -f "$_version_py" ]; then
		local _content=$(cat "$_version_py")
		if ! echo "$_content" | head -1 | grep -q "^#!/"; then
			echo "Fixing version.py: adding shebang..."
			echo "#!/usr/bin/env python3" > "$_version_py"
			echo "$_content" >> "$_version_py"
		fi
	fi
	
	# Fix meson.build - replace version extraction with hardcoded version
	# Reference: install_scikit_learn_standalone.py lines 252-263
	local _meson_build="$TERMUX_PKG_SRCDIR/meson.build"
	if [ -f "$_meson_build" ]; then
		echo "Fixing meson.build: replacing version detection..."
		# Use sed to replace version: run_command(...) with hardcoded version
		sed -i "s/version: run_command([^)]*).stdout().strip()/version: '${TERMUX_PKG_VERSION}'/" "$_meson_build" 2>/dev/null || \
		sed -i "s/version: run_command.*/version: '${TERMUX_PKG_VERSION}',/" "$_meson_build" 2>/dev/null || \
		sed -i "s/version:.*/version: '${TERMUX_PKG_VERSION}',/" "$_meson_build" 2>/dev/null || true
	fi
}

termux_step_make() {
	# Set meson environment for cross-compilation
	if [ -n "$MESON_CROSS_FILE" ] && [ -f "$MESON_CROSS_FILE" ]; then
		export MESON_CROSS_FILE
		export MESONPY_CROSS_FILE="$MESON_CROSS_FILE"
		export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
		export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig"
		
		# Force meson to recognize cross-compilation
		# Set these to help meson detect we're cross-compiling
		export _PYTHON_HOST_PLATFORM="linux-android"
		export MACHDEP="linux"
		
		echo "Cross-compilation environment set:"
		echo "  MESON_CROSS_FILE=$MESON_CROSS_FILE"
		echo "  CC=$CC"
		echo "  CXX=$CXX"
		echo "  SYSROOT=$SYSROOT"
	fi
	
	# Build wheel using pip wheel
	# Use --no-build-isolation to use system numpy/scipy
	# Use --no-deps since we've already installed dependencies
	echo "Building wheel using pip wheel..."
	
	# Try with explicit cross file environment variable
	if [ -n "$MESON_CROSS_FILE" ] && [ -f "$MESON_CROSS_FILE" ]; then
		# Set MESONPY_CROSS_FILE which meson-python should detect
		MESONPY_CROSS_FILE="$MESON_CROSS_FILE" python3 -m pip wheel . --no-deps --no-build-isolation --wheel-dir dist || \
		python3 -m pip wheel . --no-deps --no-build-isolation --wheel-dir dist || \
		python3 -m build --wheel --outdir dist --no-isolation
	else
		python3 -m pip wheel . --no-deps --no-build-isolation --wheel-dir dist || \
		python3 -m build --wheel --outdir dist --no-isolation
	fi
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
	
	local _wheel="scikit_learn-${TERMUX_PKG_VERSION}-cp${_pyver}-cp${_pyver}-linux_${_arch}.whl"
	
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
	elif [ -f "$TERMUX_PKG_SRCDIR/dist/scikit_learn-${TERMUX_PKG_VERSION}"*.whl ]; then
		local _found_wheel=$(ls "$TERMUX_PKG_SRCDIR/dist/scikit_learn-${TERMUX_PKG_VERSION}"*.whl | head -1)
		$_pip_cmd install --no-deps --prefix="$TERMUX_PREFIX" --force-reinstall "$_found_wheel" || \
		termux_extract_wheel_and_install "$_found_wheel"
	else
		local _found_wheel=$(ls "$TERMUX_PKG_SRCDIR/dist/scikit_learn"*.whl | head -1)
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
	if [ -d "$_tmpdir/sklearn" ]; then
		mkdir -p "$TERMUX_PREFIX/lib/python${TERMUX_PYTHON_VERSION}/site-packages"
		cp -r "$_tmpdir/sklearn" "$TERMUX_PREFIX/lib/python${TERMUX_PYTHON_VERSION}/site-packages/"
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
	
	echo "Building scikit-learn using Termux build.sh"
	echo "SDK: $ANDROID_SDK"
	echo "NDK: $NDK"
	echo "Architecture: $TERMUX_ARCH"
	echo "Python: $TERMUX_PYTHON_VERSION"
	echo ""
	
	# Download source
	echo "Downloading scikit-learn source..."
	cd "$TERMUX_PKG_SRCDIR"
	download_pypi_source "scikit-learn" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR" "scikit-learn-${TERMUX_PKG_VERSION}.tar.gz" || exit 1
	tar -xzf "scikit-learn-${TERMUX_PKG_VERSION}.tar.gz" --strip-components=1
	
	# Run build steps
	termux_step_pre_configure
	termux_step_make
	
	# Copy wheel to output
	copy_wheel_to_output "scikit_learn" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
	
	# Cleanup
	rm -rf "$TERMUX_PKG_SRCDIR" "$TERMUX_PKG_MASSAGEDIR"
fi

