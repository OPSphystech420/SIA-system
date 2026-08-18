#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "usage: InspectInjectionArtifact.sh DYLIB_PATH DSYM_PATH EXPECTED_BUILD_ID" >&2
    exit 2
fi

dylib=$1
dsym=$2
expected_build_id=$3
test -f "$dylib"
test -d "$dsym"
test "$(lipo -archs "$dylib")" = arm64
file "$dylib" | rg -q 'Mach-O 64-bit dynamically linked shared library arm64'

dylib_uuid=$(dwarfdump --uuid "$dylib" | sed -n '1s/^UUID: \([0-9A-Fa-f-]*\).*/\1/p')
dsym_uuid=$(dwarfdump --uuid "$dsym" | sed -n '1s/^UUID: \([0-9A-Fa-f-]*\).*/\1/p')
test -n "$dylib_uuid"
test "$dylib_uuid" = "$dsym_uuid"
strings "$dylib" | rg -Fq "$expected_build_id"

banned='HostingRuntime|HostService|ClientService|PlayerJoinService|RouteHostedPostLogin|ProcessEvent|GetNetMode|SetClientTravel|RequestHost|RequestJoin|RequestSaveWorld|RequestBroadcast|RequestKick|ExecuteHost|ExecuteJoin|RecoverRemotePlayerUI|ServerHostMenuBootstrap|ServerHostOverlayView'
if strings "$dylib" | rg -n "$banned"; then
    echo "injectable dylib contains a Legacy/gameplay string" >&2
    exit 1
fi
if nm -gj "$dylib" | c++filt | rg -n "$banned"; then
    echo "injectable dylib contains a Legacy/gameplay symbol" >&2
    exit 1
fi
if otool -L "$dylib" | rg -q '/ServerHost\.dylib'; then
    echo "injectable dylib links the Legacy runtime" >&2
    exit 1
fi

# Foundation/UIKit may emit a direct CoreFoundation load command even though
# the V2 target declares only the five reviewed Apple frameworks.
frameworks=$(otool -L "$dylib" \
    | sed -n 's|.*/System/Library/Frameworks/\([^/]*\)\.framework/.*|\1|p' \
    | LC_ALL=C sort -u)
for framework in $frameworks; do
    case "$framework" in
        CoreFoundation|Foundation|Metal|MetalKit|QuartzCore|UIKit) ;;
        *)
            echo "unexpected directly linked framework: $framework" >&2
            exit 1
            ;;
    esac
done

echo "injection artifact inspection: PASS"
echo "dylib=$dylib"
echo "dylib_sha256=$(shasum -a 256 "$dylib" | awk '{print $1}')"
echo "macho_uuid=$dylib_uuid"
echo "dsym=$dsym"
echo "dsym_uuid=$dsym_uuid"
