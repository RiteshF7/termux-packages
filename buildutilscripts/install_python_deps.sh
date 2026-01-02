#!/bin/bash
# Install Python dependencies for build
# Usage: install_python_deps <dep1> [dep2] ... [depN]

install_python_deps() {
	local _deps=("$@")
	
	if [ ${#_deps[@]} -eq 0 ]; then
		return 0
	fi
	
	for _dep in "${_deps[@]}"; do
		# Extract package name (remove version specifiers)
		local _dep_name=$(echo "$_dep" | sed 's/[<>=!].*//')
		
		# Check if already installed
		if python3 -c "import $_dep_name" 2>/dev/null; then
			continue
		fi
		
		# Try to install
		echo "Installing $_dep..."
		pip install "$_dep" --break-system-packages --user --quiet 2>/dev/null || \
		pip install "$_dep" --user --quiet 2>/dev/null || \
		pip install "$_dep" --quiet 2>/dev/null || true
	done
	
	return 0
}

# Install a single Python package if not available
install_python_package() {
	local _package="$1"
	
	if [ -z "$_package" ]; then
		echo "Usage: install_python_package <package>" >&2
		return 1
	fi
	
	local _package_name=$(echo "$_package" | sed 's/[<>=!].*//')
	
	if python3 -c "import $_package_name" 2>/dev/null; then
		return 0
	fi
	
	echo "Installing $_package..."
	pip install "$_package" --break-system-packages --user --quiet 2>/dev/null || \
	pip install "$_package" --user --quiet 2>/dev/null || \
	pip install "$_package" --quiet 2>/dev/null || true
	
	return 0
}

