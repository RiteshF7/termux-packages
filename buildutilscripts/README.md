# Build Utility Scripts

This directory contains reusable utility scripts for building Python wheels for Android using the Termux build system.

## Scripts

### `setup_android_env.sh`
Sets up Android SDK and NDK environment variables.

**Functions:**
- `setup_android_sdk_ndk()` - Finds and sets up Android SDK and NDK paths
- `setup_termux_build_env()` - Sets up minimal Termux-like environment variables for standalone builds

**Usage:**
```bash
source setup_android_env.sh
setup_android_sdk_ndk
setup_termux_build_env
```

### `setup_ndk_toolchain.sh`
Configures NDK toolchain for cross-compilation.

**Functions:**
- `setup_ndk_toolchain()` - Sets up CC, CXX, AR, and other compiler tools based on TERMUX_ARCH

**Usage:**
```bash
source setup_ndk_toolchain.sh
setup_ndk_toolchain
```

### `setup_android_compiler_flags.sh`
Sets up Android compiler flags (CFLAGS, CXXFLAGS, LDFLAGS) for cross-compilation.

**Functions:**
- `setup_android_compiler_flags()` - Sets up compiler flags based on TERMUX_ARCH and ANDROID_API_LEVEL

**Usage:**
```bash
source setup_android_compiler_flags.sh
setup_android_compiler_flags
```

**Note:** Requires `setup_ndk_toolchain()` to be called first to set SYSROOT.

### `create_meson_cross_file.sh`
Creates a meson cross-compilation file for Android builds.

**Functions:**
- `create_meson_cross_file <output_file>` - Creates meson cross file with Android toolchain configuration

**Usage:**
```bash
source create_meson_cross_file.sh
create_meson_cross_file "$TERMUX_PKG_SRCDIR/meson-cross.ini"
```

**Note:** Requires `setup_ndk_toolchain()` and `setup_android_compiler_flags()` to be called first.

### `install_python_deps.sh`
Installs Python dependencies for build process.

**Functions:**
- `install_python_package <package>` - Installs a single Python package if not already available
- `install_python_deps <dep1> [dep2] ... [depN]` - Installs multiple Python dependencies

**Usage:**
```bash
source install_python_deps.sh
install_python_package "numpy"
install_python_deps "joblib>=1.3.0" "threadpoolctl>=3.2.0"
```

### `download_pypi_source.sh`
Downloads Python package source from PyPI.

**Functions:**
- `download_pypi_source <package_name> <version> <output_dir> [output_filename]` - Downloads source tarball from PyPI

**Usage:**
```bash
source download_pypi_source.sh
download_pypi_source "orjson" "3.11.5" "/tmp/source" "orjson-3.11.5.tar.gz"
```

### `create_stub_libs.sh`
Creates stub libraries for cross-compilation when actual libraries are only available at runtime.

**Functions:**
- `create_stub_libs <lib_name> [additional_libs...]` - Creates stub .so files
- `cleanup_stub_libs()` - Removes stub library directory

**Usage:**
```bash
source create_stub_libs.sh
create_stub_libs "python3.12" "unwind"
# ... build process ...
cleanup_stub_libs
```

### `setup_rust_android.sh`
Sets up Rust for Android cross-compilation.

**Functions:**
- `setup_rust_android()` - Configures Rust target and Cargo for Android
- `setup_pyo3_cross()` - Configures PyO3 for cross-compilation (allows undefined symbols)

**Usage:**
```bash
source setup_rust_android.sh
setup_rust_android
setup_pyo3_cross
```

### `copy_wheel_to_output.sh`
Copies built wheel files to the output directory.

**Functions:**
- `copy_wheel_to_output <package_name> <version> <source_dir> [wheels_dir]` - Finds and copies wheel files

**Usage:**
```bash
source copy_wheel_to_output.sh
copy_wheel_to_output "orjson" "3.11.5" "$TERMUX_PKG_SRCDIR"
```

## Example Usage in build.sh

```bash
#!/bin/bash
set -e

# Source utility scripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDUTIL_DIR="$(cd "$SCRIPT_DIR/../../buildutilscripts" && pwd)"
source "$BUILDUTIL_DIR/setup_android_env.sh"
source "$BUILDUTIL_DIR/setup_ndk_toolchain.sh"
source "$BUILDUTIL_DIR/download_pypi_source.sh"
source "$BUILDUTIL_DIR/copy_wheel_to_output.sh"

# Standalone execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    setup_android_sdk_ndk || exit 1
    setup_termux_build_env
    
    # Download source
    download_pypi_source "package-name" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
    
    # Build steps...
    
    # Copy wheel
    copy_wheel_to_output "package_name" "$TERMUX_PKG_VERSION" "$TERMUX_PKG_SRCDIR"
fi
```

## Notes

- All scripts are designed to be sourced (not executed directly) when used in build.sh files
- Scripts can also be run directly for testing purposes
- Scripts handle both standalone execution and integration with Termux build system
- Environment variables like `TERMUX_ARCH`, `TERMUX_PYTHON_VERSION`, `NDK`, etc. should be set before calling utility functions

