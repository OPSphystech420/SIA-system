#include "SourceV2/Tests/TestHarness.hpp"

#include "SourceV2/UI/PresentationStateMachine.hpp"

#include <string>

namespace serverhost::v2::tests {

void RunPresentationStateMachineTests(TestContext& context) {
    using ui::PresentationEventKind;
    using ui::PresentationState;
    using ui::PresentationStateMachine;

    PresentationStateMachine model(16, 750);
    V2_EXPECT(context, model.State() == PresentationState::Detached);
    V2_EXPECT(context, model.Attach());
    V2_EXPECT(context, model.State() == PresentationState::AttachedClosed);
    V2_EXPECT(context, model.RequestOpen());
    V2_EXPECT(context, model.State() == PresentationState::OpenRequested);
    V2_EXPECT(context, !model.ShouldPresentFirstFrameFallback(749));
    V2_EXPECT(context, model.ShouldPresentFirstFrameFallback(750));
    model.NoteFirstFrameEntered();
    V2_EXPECT(context, model.MarkFirstFramePresented());
    V2_EXPECT(context, model.State() == PresentationState::FirstFramePresented);
    V2_EXPECT(context, model.ConfirmOpen());
    V2_EXPECT(context, model.State() == PresentationState::Open);
    V2_EXPECT(context, !model.ShouldPresentFirstFrameFallback(5000));
    V2_EXPECT(context, model.RequestClose());
    V2_EXPECT(context, model.State() == PresentationState::Closing);
    V2_EXPECT(context, model.CompleteClose());
    V2_EXPECT(context, model.State() == PresentationState::AttachedClosed);

    const ui::PresentationEventSnapshot successfulEvents = model.Events();
    V2_EXPECT(context, successfulEvents.entries.size() == 7);
    V2_EXPECT(context, successfulEvents.entries[0].kind == PresentationEventKind::Attached);
    V2_EXPECT(context,
              successfulEvents.entries[2].kind == PresentationEventKind::FirstFrameEntered);
    V2_EXPECT(context,
              successfulEvents.entries[3].state == PresentationState::FirstFramePresented);
    V2_EXPECT(context,
              successfulEvents.entries.back().state == PresentationState::AttachedClosed);

    PresentationStateMachine fallback(8, 500);
    V2_EXPECT(context, fallback.Attach());
    V2_EXPECT(context, fallback.RequestOpen());
    V2_EXPECT(context, fallback.ShouldPresentFirstFrameFallback(500));
    V2_EXPECT(context, fallback.FailWithVisibleFallback("metal-drawable-unavailable"));
    V2_EXPECT(context, fallback.State() == PresentationState::FailedWithVisibleFallback);
    V2_EXPECT(context, fallback.FailureStage() == "metal-drawable-unavailable");
    V2_EXPECT(context, fallback.RequestClose());
    V2_EXPECT(context, fallback.CompleteClose());
    V2_EXPECT(context, fallback.State() == PresentationState::AttachedClosed);

    PresentationStateMachine rejected(4, 100);
    V2_EXPECT(context, !rejected.RequestOpen());
    V2_EXPECT(context, !rejected.MarkFirstFramePresented());
    V2_EXPECT(context, !rejected.FailWithVisibleFallback("invalid"));
    V2_EXPECT(context, rejected.State() == PresentationState::Detached);
    V2_EXPECT(context, rejected.Events().entries.size() == 3);

    PresentationStateMachine bounded(3, 100);
    V2_EXPECT(context, bounded.Attach());
    V2_EXPECT(context, bounded.RequestOpen());
    bounded.NoteFirstFrameEntered();
    V2_EXPECT(context, bounded.MarkFirstFramePresented());
    V2_EXPECT(context, bounded.ConfirmOpen());
    const ui::PresentationEventSnapshot boundedEvents = bounded.Events();
    V2_EXPECT(context, boundedEvents.capacity == 3);
    V2_EXPECT(context, boundedEvents.entries.size() == 3);
    V2_EXPECT(context, boundedEvents.dropped == 2);
    V2_EXPECT(context, boundedEvents.entries.front().sequence == 3);
    V2_EXPECT(context, boundedEvents.entries.back().kind == PresentationEventKind::OpenConfirmed);

    PresentationStateMachine detached(4, 100);
    V2_EXPECT(context, detached.Attach());
    V2_EXPECT(context, detached.Detach());
    V2_EXPECT(context, detached.State() == PresentationState::Detached);
}

}  // namespace serverhost::v2::tests
