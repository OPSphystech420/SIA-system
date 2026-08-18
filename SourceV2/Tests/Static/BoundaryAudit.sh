#!/bin/sh
set -eu

fail_if_match() {
    description=$1
    pattern=$2
    shift 2
    if rg -n "$pattern" "$@"; then
        echo "$description" >&2
        exit 1
    fi
}

feature_dirs="SourceV2/Runtime SourceV2/Services SourceV2/UI SourceV2/Features"
existing_feature_dirs=""
for directory in $feature_dirs; do
    if [ -d "$directory" ]; then
        existing_feature_dirs="$existing_feature_dirs $directory"
    fi
done

if [ -n "$existing_feature_dirs" ]; then
    fail_if_match \
        "forbidden raw ABI access found above the low-level boundary" \
        'reinterpret_cast|ProcessEvent|#include.*Bindings/Generated|#include.*FreshSDK|\+ *0x[0-9A-Fa-f]+' \
        $existing_feature_dirs
fi

fail_if_match \
    "reinterpret_cast found outside UE, Bindings, Hooks, or tests" \
    'reinterpret_cast' SourceV2 \
    --glob '!SourceV2/UE/**' \
    --glob '!SourceV2/Bindings/**' \
    --glob '!SourceV2/Hooks/**' \
    --glob '!SourceV2/Tests/**'

fail_if_match \
    "Core must not include a higher V2 layer" \
    '#include.*SourceV2/(UE|Bindings|Bootstrap|Runtime|Services|UI|Features|Hooks|Tests|Build)/' \
    SourceV2/Core

fail_if_match \
    "UE must not include bindings, bootstrap, runtime, feature, test, or build layers" \
    '#include.*SourceV2/(Bindings|Bootstrap|Runtime|Services|UI|Features|Hooks|Tests|Build)/' \
    SourceV2/UE

fail_if_match \
    "Bindings must not include bootstrap, runtime, feature, test, or build layers" \
    '#include.*SourceV2/(Bootstrap|Runtime|Services|UI|Features|Hooks|Tests|Build)/' \
    SourceV2/Bindings

fail_if_match \
    "V2 source includes a Legacy runtime header" \
    '#include.*(Source/Hosting|Source/UnrealEngine|Menu/|MenuLoad/|Utilities/)' \
    SourceV2 --glob '!SourceV2/Tests/Static/BoundaryAudit.sh'

if [ -d SourceV2/UI ]; then
    fail_if_match \
        "SourceV2/UI must not include UE, Bindings, Hooks, Runtime, or Services" \
        '#include.*SourceV2/(UE|Bindings|Hooks|Runtime|Services|Features)/' \
        SourceV2/UI
    fail_if_match \
        "SourceV2/UI must not include Legacy Source, Menu, or MenuLoad" \
        '#include.*(Source/|MenuLoad/|Menu/)' \
        SourceV2/UI
    fail_if_match \
        "SourceV2/UI render/bootstrap code must not call runtime scheduling or engine paths" \
        'HostingRuntime|::Tick *\(|ProcessEvent|GetNetMode|SetClientTravel|RequestHost|RequestJoin|RequestSave|scheduler|resolver' \
        SourceV2/UI
fi

fail_if_match \
    "Legacy HostingRuntime is forbidden in SourceV2 production code" \
    'HostingRuntime' \
    SourceV2 --glob '*.{h,hpp,c,cpp,m,mm}' \
    --glob '!SourceV2/Build/**' --glob '!SourceV2/Tests/**'

fail_if_match \
    "a V2 source list references the Legacy runtime" \
    '(HostingRuntime|Source/Hosting|Source/UnrealEngine|Menu/HostMenu|MenuLoad/|Utilities/|ServerHost\.dylib)' \
    SourceV2.mk SourceV2/Build/IOS/Makefile

rg -Fq 'ServerHostV2_FRAMEWORKS = UIKit Foundation QuartzCore Metal MetalKit' \
    SourceV2/Build/IOS/Makefile
rg -Fq 'view.paused = !shouldRender;' SourceV2/UI/DiagnosticUIBootstrap.mm
rg -Fq 'view.enableSetNeedsDisplay = !shouldRender;' SourceV2/UI/DiagnosticUIBootstrap.mm

echo "boundary audit: PASS (regex raw-access rules and include-layer dependencies)"
echo "permitted low-level raw-access inventory:"
rg -n 'reinterpret_cast|\.data\(\) *\+' SourceV2/UE SourceV2/Bindings 2>/dev/null || true
