#!/bin/bash
# Download Python package source from PyPI
# Usage: download_pypi_source.sh <package_name> <version> <output_dir> [output_filename]

download_pypi_source() {
	local _pkg_name="$1"
	local _version="$2"
	local _output_dir="$3"
	local _output_filename="${4:-${_pkg_name}-${_version}.tar.gz}"
	
	if [ -z "$_pkg_name" ] || [ -z "$_version" ] || [ -z "$_output_dir" ]; then
		echo "Usage: download_pypi_source <package_name> <version> <output_dir> [output_filename]" >&2
		return 1
	fi
	
	mkdir -p "$_output_dir"
	
	# Try to get source URL from PyPI JSON API
	echo "Fetching source URL from PyPI for ${_pkg_name} ${_version}..."
	local _pypi_json=$(curl -s "https://pypi.org/pypi/${_pkg_name}/json" 2>/dev/null)
	
	if [ -n "$_pypi_json" ]; then
		# Extract source distribution URL
		local _source_url=$(echo "$_pypi_json" | python3 -c "
import sys, json
try:
	data = json.load(sys.stdin)
	urls = [f['url'] for f in data['urls'] if f['packagetype'] == 'sdist' and data['info']['version'] == '${_version}']
	if urls:
		print(urls[0])
except:
	pass
" 2>/dev/null)
		
		if [ -n "$_source_url" ]; then
			echo "Downloading from: $_source_url"
			wget -q "$_source_url" -O "$_output_dir/$_output_filename"
			if [ $? -eq 0 ]; then
				echo "Downloaded: $_output_filename"
				return 0
			fi
		fi
	fi
	
	# Fallback: try standard PyPI URL pattern
	local _fallback_url="https://files.pythonhosted.org/packages/source/${_pkg_name:0:1}/${_pkg_name}/${_pkg_name}-${_version}.tar.gz"
	echo "Trying fallback URL: $_fallback_url"
	wget -q "$_fallback_url" -O "$_output_dir/$_output_filename"
	
	if [ $? -eq 0 ]; then
		echo "Downloaded: $_output_filename"
		return 0
	fi
	
	echo "Error: Failed to download ${_pkg_name} ${_version} source" >&2
	return 1
}

# If script is run directly (for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	download_pypi_source "$@"
fi

