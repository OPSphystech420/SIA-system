#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <string>
#include <string_view>
#include <vector>

namespace serverhost::v2::ui {

enum class PresentationState : std::uint8_t {
    Detached,
    AttachedClosed,
    OpenRequested,
    FirstFramePresented,
    Open,
    Closing,
    FailedWithVisibleFallback,
};

enum class PresentationEventKind : std::uint8_t {
    Attached,
    OpenRequested,
    FirstFrameEntered,
    FirstFramePresented,
    OpenConfirmed,
    CloseRequested,
    CloseCompleted,
    Detached,
    VisibleFallback,
    RejectedTransition,
};

struct PresentationEvent final {
    std::uint64_t sequence{};
    PresentationEventKind kind{PresentationEventKind::RejectedTransition};
    PresentationState state{PresentationState::Detached};
    std::string detail;
};

struct PresentationEventSnapshot final {
    std::vector<PresentationEvent> entries;
    std::size_t capacity{};
    std::uint64_t dropped{};
};

[[nodiscard]] const char* PresentationStateName(PresentationState state) noexcept;
[[nodiscard]] const char* PresentationEventKindName(PresentationEventKind kind) noexcept;

class PresentationStateMachine final {
public:
    explicit PresentationStateMachine(std::size_t eventCapacity = 24,
                                      std::uint64_t firstFrameTimeoutMilliseconds = 1000);

    [[nodiscard]] PresentationState State() const noexcept;
    [[nodiscard]] bool Attach();
    [[nodiscard]] bool RequestOpen();
    void NoteFirstFrameEntered();
    [[nodiscard]] bool MarkFirstFramePresented();
    [[nodiscard]] bool ConfirmOpen();
    [[nodiscard]] bool RequestClose();
    [[nodiscard]] bool CompleteClose();
    [[nodiscard]] bool Detach();
    [[nodiscard]] bool FailWithVisibleFallback(std::string_view stage);

    [[nodiscard]] bool IsAwaitingFirstFrame() const noexcept;
    [[nodiscard]] bool ShouldPresentFirstFrameFallback(
        std::uint64_t elapsedMilliseconds) const noexcept;
    [[nodiscard]] std::uint64_t FirstFrameTimeoutMilliseconds() const noexcept;
    [[nodiscard]] const std::string& FailureStage() const noexcept;
    [[nodiscard]] PresentationEventSnapshot Events() const;

private:
    [[nodiscard]] bool Transition(PresentationState expected,
                                  PresentationState next,
                                  PresentationEventKind event,
                                  std::string_view detail);
    void Record(PresentationEventKind kind, std::string_view detail);

    PresentationState state_{PresentationState::Detached};
    const std::size_t eventCapacity_;
    const std::uint64_t firstFrameTimeoutMilliseconds_;
    std::deque<PresentationEvent> events_;
    std::uint64_t nextSequence_{1};
    std::uint64_t dropped_{};
    std::string failureStage_;
};

}  // namespace serverhost::v2::ui
