#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "usage: CreateArtifactManifest.sh PACKAGE_PATH BUILD_ID SOURCE_REVISION" >&2
    exit 2
fi

: "${V2_HOST_CPPFLAGS:?missing V2_HOST_CPPFLAGS}"
: "${V2_HOST_CXXFLAGS:?missing V2_HOST_CXXFLAGS}"
: "${V2_HOST_LDFLAGS:=}"
: "${V2_IOS_TARGET:?missing V2_IOS_TARGET}"
: "${V2_IOS_ARCHS:?missing V2_IOS_ARCHS}"
: "${V2_IOS_CFLAGS:?missing V2_IOS_CFLAGS}"
: "${V2_IOS_CCFLAGS:?missing V2_IOS_CCFLAGS}"

package_path=$1
build_id=$2
source_revision=$3
if [ ! -f "$package_path" ] || [ "$source_revision" = unavailable ]; then
    echo "manifest requires an existing package and exact source revision" >&2
    exit 1
fi

package_dir=$(cd "$(dirname "$package_path")" && pwd)
package_path="$package_dir/$(basename "$package_path")"
manifest_work=$(mktemp -d "${TMPDIR:-/tmp}/serverhost-v2-manifest.XXXXXX")
trap 'rm -rf "$manifest_work"' EXIT HUP INT TERM

(
    cd "$manifest_work"
    ar -x "$package_path"
)
data_archive=$(find "$manifest_work" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
control_archive=$(find "$manifest_work" -maxdepth 1 -type f -name 'control.tar.*' -print -quit)
test -n "$data_archive"
test -n "$control_archive"
mkdir -p "$manifest_work/data" "$manifest_work/control"
tar -xf "$data_archive" -C "$manifest_work/data"
tar -xf "$control_archive" -C "$manifest_work/control"

dylib_relative_path=Library/MobileSubstrate/DynamicLibraries/ServerHostV2.dylib
dylib="$manifest_work/data/$dylib_relative_path"
test -f "$dylib"

package_sha=$(shasum -a 256 "$package_path" | awk '{print $1}')
dylib_sha=$(shasum -a 256 "$dylib" | awk '{print $1}')
package_id=$(sed -n 's/^Package: //p' "$manifest_work/control/control")
package_version=$(sed -n 's/^Version: //p' "$manifest_work/control/control")
manifest_path="$package_path.$package_sha.manifest"
manifest_tmp=$(mktemp "$package_dir/.serverhost-v2-manifest.XXXXXX")

{
    echo 'format=serverhost-v2-artifact-manifest-v1'
    printf 'build_id=%s\n' "$build_id"
    printf 'source_revision=%s\n' "$source_revision"
    printf 'source_tree_state=clean\n'
    printf 'package_id=%s\n' "$package_id"
    printf 'package_version=%s\n' "$package_version"
    printf 'package_path=%s\n' "$package_path"
    printf 'package_sha256=%s\n' "$package_sha"
    printf 'dylib_path=%s\n' "$dylib_relative_path"
    printf 'dylib_sha256=%s\n' "$dylib_sha"
    printf 'host_cppflags=%s\n' "$V2_HOST_CPPFLAGS"
    printf 'host_cxxflags=%s\n' "$V2_HOST_CXXFLAGS"
    printf 'host_ldflags=%s\n' "$V2_HOST_LDFLAGS"
    printf 'ios_target=%s\n' "$V2_IOS_TARGET"
    printf 'ios_archs=%s\n' "$V2_IOS_ARCHS"
    printf 'ios_cflags=%s\n' "$V2_IOS_CFLAGS"
    printf 'ios_ccflags=%s\n' "$V2_IOS_CCFLAGS"
} >"$manifest_tmp"

if [ -e "$manifest_path" ]; then
    if ! cmp -s "$manifest_tmp" "$manifest_path"; then
        echo "immutable manifest collision: $manifest_path" >&2
        rm -f "$manifest_tmp"
        exit 1
    fi
    rm -f "$manifest_tmp"
else
    chmod 0444 "$manifest_tmp"
    mv "$manifest_tmp" "$manifest_path"
fi

echo "artifact_manifest=$manifest_path"
echo "manifest_sha256=$(shasum -a 256 "$manifest_path" | awk '{print $1}')"
