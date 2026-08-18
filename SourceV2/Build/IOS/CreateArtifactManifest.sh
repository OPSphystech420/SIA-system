#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    echo "usage: CreateArtifactManifest.sh PACKAGE_PATH BUILD_ID SOURCE_REVISION DSYM_PATH" >&2
    exit 2
fi

: "${V2_HOST_CPPFLAGS:?missing V2_HOST_CPPFLAGS}"
: "${V2_HOST_CXXFLAGS:?missing V2_HOST_CXXFLAGS}"
: "${V2_HOST_LDFLAGS:=}"
: "${V2_IOS_TARGET:?missing V2_IOS_TARGET}"
: "${V2_IOS_ARCHS:?missing V2_IOS_ARCHS}"
: "${V2_IOS_CFLAGS:?missing V2_IOS_CFLAGS}"
: "${V2_IOS_CCFLAGS:?missing V2_IOS_CCFLAGS}"
: "${V2_SOURCE_TREE_STATE:?missing V2_SOURCE_TREE_STATE}"

package_path=$1
build_id=$2
source_revision=$3
dsym_source=$4
if [ ! -f "$package_path" ] || [ "$source_revision" = unavailable ]; then
    echo "injection artifact requires an existing package and Git revision" >&2
    exit 1
fi
if [ "$V2_SOURCE_TREE_STATE" != clean ]; then
    echo "injection artifact requires a clean committed source tree" >&2
    exit 1
fi
if [ ! -d "$dsym_source" ]; then
    echo "dSYM does not exist: $dsym_source" >&2
    exit 1
fi

package_dir=$(cd "$(dirname "$package_path")" && pwd)
package_path="$package_dir/$(basename "$package_path")"
dsym_dir=$(cd "$(dirname "$dsym_source")" && pwd)
dsym_source="$dsym_dir/$(basename "$dsym_source")"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/serverhost-v2-injection.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

(
    cd "$work_dir"
    ar -x "$package_path"
)
data_archive=$(find "$work_dir" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)
control_archive=$(find "$work_dir" -maxdepth 1 -type f -name 'control.tar.*' -print -quit)
test -n "$data_archive"
test -n "$control_archive"
mkdir -p "$work_dir/data" "$work_dir/control"
tar -xf "$data_archive" -C "$work_dir/data"
tar -xf "$control_archive" -C "$work_dir/control"

packaged_dylib="$work_dir/data/Library/MobileSubstrate/DynamicLibraries/ServerHostV2.dylib"
test -f "$packaged_dylib"

package_sha=$(shasum -a 256 "$package_path" | awk '{print $1}')
dylib_sha=$(shasum -a 256 "$packaged_dylib" | awk '{print $1}')
package_id=$(sed -n 's/^Package: //p' "$work_dir/control/control")
package_version=$(sed -n 's/^Version: //p' "$work_dir/control/control")
dylib_uuid=$(dwarfdump --uuid "$packaged_dylib" | sed -n '1s/^UUID: \([0-9A-Fa-f-]*\).*/\1/p')
dsym_uuid=$(dwarfdump --uuid "$dsym_source" | sed -n '1s/^UUID: \([0-9A-Fa-f-]*\).*/\1/p')
test -n "$dylib_uuid"
test -n "$dsym_uuid"
if [ "$dylib_uuid" != "$dsym_uuid" ]; then
    echo "dylib/dSYM UUID mismatch: $dylib_uuid != $dsym_uuid" >&2
    exit 1
fi

injection_parent="$package_dir/injection"
injection_dir="$injection_parent/$build_id"
if [ -e "$injection_dir" ]; then
    echo "immutable injection artifact already exists: $injection_dir" >&2
    exit 1
fi

stage_dir="$work_dir/stage/$build_id"
mkdir -p "$stage_dir"
cp "$packaged_dylib" "$stage_dir/ServerHostV2.dylib"
cp -R "$dsym_source" "$stage_dir/ServerHostV2.dylib.dSYM"
cmp -s "$packaged_dylib" "$stage_dir/ServerHostV2.dylib"
dsym_dwarf="$stage_dir/ServerHostV2.dylib.dSYM/Contents/Resources/DWARF/ServerHostV2.dylib"
test -f "$dsym_dwarf"
dsym_sha=$(shasum -a 256 "$dsym_dwarf" | awk '{print $1}')

manifest="$stage_dir/manifest.txt"
{
    echo 'format=serverhost-v2-injection-manifest-v3'
    echo 'artifact_role=sideloadly-input-before-resigning'
    printf 'build_id=%s\n' "$build_id"
    printf 'git_revision=%s\n' "$source_revision"
    printf 'source_tree_state=%s\n' "$V2_SOURCE_TREE_STATE"
    printf 'package_id=%s\n' "$package_id"
    printf 'package_version=%s\n' "$package_version"
    printf 'package_path=%s\n' "$package_path"
    printf 'package_sha256=%s\n' "$package_sha"
    printf 'dylib_path=%s/ServerHostV2.dylib\n' "$injection_dir"
    printf 'dylib_sha256=%s\n' "$dylib_sha"
    printf 'macho_uuid=%s\n' "$dylib_uuid"
    printf 'dsym_path=%s/ServerHostV2.dylib.dSYM\n' "$injection_dir"
    printf 'dsym_uuid=%s\n' "$dsym_uuid"
    printf 'dsym_dwarf_sha256=%s\n' "$dsym_sha"
    echo 'target_profile=ios-shootergame-1.10280-exact-e52a980c'
    echo 'target_product=ShooterGame'
    echo 'target_architecture=arm64'
    echo 'target_lc_uuid=E52A980C-9C36-34C7-84B0-DD6E846328DC'
    echo 'target_text_section=__TEXT,__text'
    echo 'target_text_file_offset=0x4000'
    echo 'target_text_size=0x448B030'
    echo 'target_text_sha256=8bfc1fd248a5bf2fc589b85de0afccb57fe872789dff1b0e8c0d7b3db591bcf8'
    echo 'target_stable_prefix_size=0x59DC000'
    echo 'runtime_capabilities=scans_started=0,hooks=0,engine_calls=0,mutation=0'
    printf 'host_cppflags=%s\n' "$V2_HOST_CPPFLAGS"
    printf 'host_cxxflags=%s\n' "$V2_HOST_CXXFLAGS"
    printf 'host_ldflags=%s\n' "$V2_HOST_LDFLAGS"
    printf 'ios_target=%s\n' "$V2_IOS_TARGET"
    printf 'ios_archs=%s\n' "$V2_IOS_ARCHS"
    printf 'ios_cflags=%s\n' "$V2_IOS_CFLAGS"
    printf 'ios_ccflags=%s\n' "$V2_IOS_CCFLAGS"
    echo 'sideloadly_note=manifest identifies the input dylib before any Sideloadly re-signing'
} >"$manifest"

chmod 0444 "$manifest"
mkdir -p "$injection_parent"
mv "$stage_dir" "$injection_dir"

echo "injection_dylib=$injection_dir/ServerHostV2.dylib"
echo "dylib_sha256=$dylib_sha"
echo "macho_uuid=$dylib_uuid"
echo "dsym=$injection_dir/ServerHostV2.dylib.dSYM"
echo "dsym_uuid=$dsym_uuid"
echo "injection_manifest=$injection_dir/manifest.txt"
echo "manifest_sha256=$(shasum -a 256 "$injection_dir/manifest.txt" | awk '{print $1}')"
