#include "SourceV2/UI/PresentationStateMachine.hpp"

#include <algorithm>

namespace serverhost::v2::ui {
namespace {

constexpr std::size_t kMinimumEventCapacity = 1;
constexpr std::size_t kMaximumEventDetailLength = 96;

std::string BoundedDetail(std::string_view detail) {
    const std::size_t length = std::min(detail.size(), kMaximumEventDetailLength);
    return std::string(detail.substr(0, length));
}

}  // namespace

const char* PresentationStateName(PresentationState state) noexcept {
    switch (state) {
        case PresentationState::Detached: return "Detached";
        case PresentationState::AttachedClosed: return "AttachedClosed";
        case PresentationState::OpenRequested: return "OpenRequested";
        case PresentationState::FirstFramePresented: return "FirstFramePresented";
        case PresentationState::Open: return "Open";
        case PresentationState::Closing: return "Closing";
        case PresentationState::FailedWithVisibleFallback:
            return "FailedWithVisibleFallback";
    }
    return "Unknown";
}

const char* PresentationEventKindName(PresentationEventKind kind) noexcept {
    switch (kind) {
        case PresentationEventKind::Attached: return "attached";
        case PresentationEventKind::OpenRequested: return "open-requested";
        case PresentationEventKind::FirstFrameEntered: return "first-frame-entered";
        case PresentationEventKind::FirstFramePresented: return "first-frame-presented";
        case PresentationEventKind::OpenConfirmed: return "open-confirmed";
        case PresentationEventKind::CloseRequested: return "close-requested";
        case PresentationEventKind::CloseCompleted: return "close-completed";
        case PresentationEventKind::Detached: return "detached";
        case PresentationEventKind::VisibleFallback: return "visible-fallback";
        case PresentationEventKind::RejectedTransition: return "rejected-transition";
    }
    return "unknown";
}

PresentationStateMachine::PresentationStateMachine(
    std::size_t eventCapacity, std::uint64_t firstFrameTimeoutMilliseconds)
    : eventCapacity_(std::max(eventCapacity, kMinimumEventCapacity)),
      firstFrameTimeoutMilliseconds_(std::max<std::uint64_t>(
          firstFrameTimeoutMilliseconds, 1)) {}

PresentationState PresentationStateMachine::State() const noexcept {
    return state_;
}

bool PresentationStateMachine::Attach() {
    return Transition(PresentationState::Detached,
                      PresentationState::AttachedClosed,
                      PresentationEventKind::Attached,
                      "overlay hierarchy attached");
}

bool PresentationStateMachine::RequestOpen() {
    failureStage_.clear();
    return Transition(PresentationState::AttachedClosed,
                      PresentationState::OpenRequested,
                      PresentationEventKind::OpenRequested,
                      "open requested");
}

void PresentationStateMachine::NoteFirstFrameEntered() {
    if (state_ == PresentationState::OpenRequested) {
        Record(PresentationEventKind::FirstFrameEntered, "first frame entered");
        return;
    }
    Record(PresentationEventKind::RejectedTransition,
           "first frame entered outside OpenRequested");
}

bool PresentationStateMachine::MarkFirstFramePresented() {
    return Transition(PresentationState::OpenRequested,
                      PresentationState::FirstFramePresented,
                      PresentationEventKind::FirstFramePresented,
                      "ImGui frame rendered and submitted");
}

bool PresentationStateMachine::ConfirmOpen() {
    return Transition(PresentationState::FirstFramePresented,
                      PresentationState::Open,
                      PresentationEventKind::OpenConfirmed,
                      "continuous UI rendering enabled while open");
}

bool PresentationStateMachine::RequestClose() {
    if (state_ != PresentationState::OpenRequested
        && state_ != PresentationState::FirstFramePresented
        && state_ != PresentationState::Open
        && state_ != PresentationState::FailedWithVisibleFallback) {
        Record(PresentationEventKind::RejectedTransition,
               "close requested outside an open/fallback state");
        return false;
    }
    state_ = PresentationState::Closing;
    Record(PresentationEventKind::CloseRequested, "close requested");
    return true;
}

bool PresentationStateMachine::CompleteClose() {
    return Transition(PresentationState::Closing,
                      PresentationState::AttachedClosed,
                      PresentationEventKind::CloseCompleted,
                      "close completed; renderer stopped");
}

bool PresentationStateMachine::Detach() {
    if (state_ == PresentationState::Detached) {
        Record(PresentationEventKind::RejectedTransition, "already detached");
        return false;
    }
    state_ = PresentationState::Detached;
    Record(PresentationEventKind::Detached, "overlay hierarchy detached");
    return true;
}

bool PresentationStateMachine::FailWithVisibleFallback(std::string_view stage) {
    if (!IsAwaitingFirstFrame()) {
        Record(PresentationEventKind::RejectedTransition,
               "visible fallback requested outside first-frame wait");
        return false;
    }
    failureStage_ = BoundedDetail(stage.empty() ? "unknown-presentation-stage" : stage);
    state_ = PresentationState::FailedWithVisibleFallback;
    Record(PresentationEventKind::VisibleFallback, failureStage_);
    return true;
}

bool PresentationStateMachine::IsAwaitingFirstFrame() const noexcept {
    return state_ == PresentationState::OpenRequested
        || state_ == PresentationState::FirstFramePresented;
}

bool PresentationStateMachine::ShouldPresentFirstFrameFallback(
    std::uint64_t elapsedMilliseconds) const noexcept {
    return IsAwaitingFirstFrame()
        && elapsedMilliseconds >= firstFrameTimeoutMilliseconds_;
}

std::uint64_t PresentationStateMachine::FirstFrameTimeoutMilliseconds() const noexcept {
    return firstFrameTimeoutMilliseconds_;
}

const std::string& PresentationStateMachine::FailureStage() const noexcept {
    return failureStage_;
}

PresentationEventSnapshot PresentationStateMachine::Events() const {
    return PresentationEventSnapshot{
        .entries = std::vector<PresentationEvent>(events_.begin(), events_.end()),
        .capacity = eventCapacity_,
        .dropped = dropped_,
    };
}

bool PresentationStateMachine::Transition(PresentationState expected,
                                          PresentationState next,
                                          PresentationEventKind event,
                                          std::string_view detail) {
    if (state_ != expected) {
        Record(PresentationEventKind::RejectedTransition, detail);
        return false;
    }
    state_ = next;
    Record(event, detail);
    return true;
}

void PresentationStateMachine::Record(PresentationEventKind kind, std::string_view detail) {
    if (events_.size() == eventCapacity_) {
        events_.pop_front();
        ++dropped_;
    }
    events_.push_back(PresentationEvent{
        .sequence = nextSequence_++,
        .kind = kind,
        .state = state_,
        .detail = BoundedDetail(detail),
    });
}

}  // namespace serverhost::v2::ui
