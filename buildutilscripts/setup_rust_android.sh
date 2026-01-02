#!/bin/bash
# Setup Rust for Android cross-compilation
# Usage: source setup_rust_android.sh

setup_rust_android() {
	if ! command -v rustc &> /dev/null; then
		echo "Error: rustc not found. Please install Rust." >&2
		return 1
	fi
	
	local _arch="${TERMUX_ARCH:-x86_64}"
	
	# Map Termux arch to Rust target
	case "$_arch" in
		aarch64)
			export CARGO_TARGET_NAME="aarch64-linux-android"
			;;
		arm)
			export CARGO_TARGET_NAME="armv7-linux-androideabi"
			;;
		i686)
			export CARGO_TARGET_NAME="i686-linux-android"
			;;
		x86_64)
			export CARGO_TARGET_NAME="x86_64-linux-android"
			;;
		*)
			echo "Error: Unsupported architecture: $_arch" >&2
			return 1
			;;
	esac
	
	# Install Rust target if needed
	if command -v rustup &> /dev/null; then
		if ! rustup target list --installed 2>/dev/null | grep -q "$CARGO_TARGET_NAME"; then
			echo "Installing Rust target $CARGO_TARGET_NAME..."
			rustup target add "$CARGO_TARGET_NAME"
		fi
	fi
	
	# Setup Cargo config for Android if CC is set
	if [ -n "$CC" ] && [ -n "$AR" ]; then
		local _cargo_config_dir="$HOME/.cargo"
		mkdir -p "$_cargo_config_dir"
		local _cargo_config="$_cargo_config_dir/config.toml"
		
		# Check if target already configured
		if ! grep -q "\[target\.${CARGO_TARGET_NAME}\]" "$_cargo_config" 2>/dev/null; then
			cat >> "$_cargo_config" << EOF

[target.${CARGO_TARGET_NAME}]
linker = "$CC"
ar = "$AR"
EOF
		fi
	fi
	
	return 0
}

# Setup PyO3 for cross-compilation
setup_pyo3_cross() {
	# Configure PyO3 to skip Python linking (will be linked at runtime)
	export PYO3_NO_PYTHON_LINK=1
	
	# Configure Rust linker flags to allow undefined symbols
	local _env_host=$(printf "$CARGO_TARGET_NAME" | tr a-z A-Z | sed s/-/_/g)
	local _existing_flags=$(eval echo \${CARGO_TARGET_${_env_host}_RUSTFLAGS:-})
	
	# Use --allow-shlib-undefined to allow undefined Python symbols (will be resolved at runtime)
	export CARGO_TARGET_${_env_host}_RUSTFLAGS="-C link-arg=-Wl,--allow-shlib-undefined -C link-arg=-Wl,--unresolved-symbols=ignore-all ${_existing_flags}"
	export RUSTFLAGS="-C link-arg=-Wl,--allow-shlib-undefined -C link-arg=-Wl,--unresolved-symbols=ignore-all ${RUSTFLAGS:-}"
	export LDFLAGS="${LDFLAGS:-} -Wl,--allow-shlib-undefined -Wl,--unresolved-symbols=ignore-all"
}

