#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "usage: InspectPackage.sh PACKAGE_PATH EXPECTED_BUILD_ID EXPECTED_VERSION" >&2
    exit 2
fi

package_path=$1
expected_build_id=$2
expected_version=$3
if [ ! -f "$package_path" ]; then
    echo "package does not exist: $package_path" >&2
    exit 1
fi

package_dir=$(cd "$(dirname "$package_path")" && pwd)
package_path="$package_dir/$(basename "$package_path")"
inspection_dir=$(mktemp -d "${TMPDIR:-/tmp}/serverhost-v2-package-audit.XXXXXX")
trap 'rm -rf "$inspection_dir"' EXIT HUP INT TERM

(
    cd "$inspection_dir"
    ar -x "$package_path"
)

control_archive=$(find "$inspection_dir" -maxdepth 1 -type f -name 'control.tar.*' -print -quit)
data_archive=$(find "$inspection_dir" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
if [ -z "$control_archive" ] || [ -z "$data_archive" ]; then
    echo "package is missing a control or data archive" >&2
    exit 1
fi

mkdir -p "$inspection_dir/control" "$inspection_dir/data"
tar -xf "$control_archive" -C "$inspection_dir/control"
tar -xf "$data_archive" -C "$inspection_dir/data"

control_file="$inspection_dir/control/control"
dylib="$inspection_dir/data/Library/MobileSubstrate/DynamicLibraries/ServerHostV2.dylib"
plist="$inspection_dir/data/Library/MobileSubstrate/DynamicLibraries/ServerHostV2.plist"

rg -q '^Package: com\.mhga\.serverhost\.v2$' "$control_file"
rg -q '^Conflicts: com\.mhga\.serverhost$' "$control_file"
rg -Fqx "Version: $expected_version" "$control_file"

expected_files='Library/MobileSubstrate/DynamicLibraries/ServerHostV2.dylib
Library/MobileSubstrate/DynamicLibraries/ServerHostV2.plist'
actual_files=$(find "$inspection_dir/data" -type f -print \
    | sed "s|^$inspection_dir/data/||" \
    | LC_ALL=C sort)
if [ "$actual_files" != "$expected_files" ]; then
    echo "unexpected package payload:" >&2
    printf '%s\n' "$actual_files" >&2
    exit 1
fi

test -f "$dylib"
test -f "$plist"
plutil -lint "$plist" >/dev/null
test "$(lipo -archs "$dylib")" = arm64
file "$dylib" | rg -q 'Mach-O 64-bit dynamically linked shared library arm64'

codesign -dvv "$dylib" >"$inspection_dir/codesign.txt" 2>&1 || true
rg -q 'CodeDirectory' "$inspection_dir/codesign.txt"
strings "$dylib" | rg -Fq "$expected_build_id"
strings "$dylib" | rg -Fq 'ServerHost.dylib'

banned='HostingRuntime|HostService|ClientService|PlayerJoinService|RouteHostedPostLogin|ProcessEvent|GetNetMode|SetClientTravel|RequestHost|RequestJoin|RequestSaveWorld|RequestBroadcast|RequestKick|ExecuteHost|ExecuteJoin|RecoverRemotePlayerUI|ServerHostMenuBootstrap|ServerHostOverlayView'
if strings "$dylib" | rg -n "$banned"; then
    echo "banned gameplay/Legacy runtime symbol or string found in V2 payload" >&2
    exit 1
fi
if nm -gj "$dylib" | c++filt | rg -n "$banned"; then
    echo "banned gameplay/Legacy runtime exported symbol found in V2 payload" >&2
    exit 1
fi

if find "$inspection_dir/data" -type f -print | rg -q '/ServerHost\.dylib$'; then
    echo "Legacy ServerHost.dylib was packaged with V2" >&2
    exit 1
fi

package_sha=$(shasum -a 256 "$package_path" | awk '{print $1}')
dylib_sha=$(shasum -a 256 "$dylib" | awk '{print $1}')
echo "iOS package inspection: PASS"
echo "package=$package_path"
echo "package_sha256=$package_sha"
echo "dylib_sha256=$dylib_sha"
