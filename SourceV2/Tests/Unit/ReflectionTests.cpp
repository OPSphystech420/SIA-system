#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/UE/Reflection.hpp"

#include <string>

namespace serverhost::v2::tests {

void RunReflectionTests(TestContext& context) {
    using namespace ue;

    int functionLookups = 0;
    int classLookups = 0;
    ReflectionRegistry registry(
        7,
        [&functionLookups](const std::string& name) {
            ++functionLookups;
            return ContractResult<UFunctionDescriptor>::Success(UFunctionDescriptor{
                .identity = {11, 22, 7},
                .fullName = name,
                .functionFlags = EFunctionFlags::Native | EFunctionFlags::NetClient,
                .numParms = 1,
                .parmsSize = 8,
                .returnValueOffset = 0,
            });
        },
        [&classLookups](const std::string& name) {
            ++classLookups;
            return ContractResult<UClassDescriptor>::Success(UClassDescriptor{
                .identity = {12, 23, 7},
                .fullName = name,
                .castFlags = EClassCastFlags::Class,
                .superClass = std::nullopt,
            });
        });

    auto function = registry.FindFunction("Function ShooterGame.ShooterPC.ClientInit");
    V2_EXPECT(context, function);
    V2_EXPECT(context, registry.FindFunction("Function ShooterGame.ShooterPC.ClientInit"));
    V2_EXPECT(context, functionLookups == 1);
    V2_EXPECT(context, function.Value().Validate(
        7, EFunctionFlags::Native | EFunctionFlags::NetClient, 8, 1));
    V2_EXPECT(context, !function.Value().Validate(7, EFunctionFlags::Native, 1, 1));

    V2_EXPECT(context, registry.FindClass("Class Engine.World"));
    V2_EXPECT(context, registry.FindClass("Class Engine.World"));
    V2_EXPECT(context, classLookups == 1);

    registry.Invalidate(8);
    auto wrongGeneration = registry.FindFunction("Function ShooterGame.ShooterPC.ClientInit");
    V2_EXPECT(context, !wrongGeneration);
    V2_EXPECT(context, functionLookups == 2);

    FPropertyDescriptor validProperty{
        .field = {.name = FName{5, 0},
                  .castFlags = EClassCastFlags::Property | EClassCastFlags::BoolProperty,
                  .nextName = std::nullopt},
        .arrayDim = 1,
        .elementSize = 1,
        .propertyFlags = EPropertyFlags::None,
        .offset = 0x20,
        .boolMetadata = BoolPropertyMetadata{1, 0, 0x4, 0x4},
    };
    V2_EXPECT(context, validProperty.Validate());
    validProperty.boolMetadata->byteMask = 0x3;
    V2_EXPECT(context, !validProperty.Validate());
}

}  // namespace serverhost::v2::tests
