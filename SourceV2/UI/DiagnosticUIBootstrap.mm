#include "SourceV2/UI/DiagnosticUIBootstrap.hpp"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#include "ImGui/imgui.h"
#include "ImGui/imgui_impl_metal.h"
#include "SourceV2/Diagnostics/DiagnosticSnapshot.hpp"
#include "SourceV2/Diagnostics/Logger.hpp"
#include "SourceV2/UI/DiagnosticPresentationModel.hpp"
#include "SourceV2/UI/PresentationStateMachine.hpp"

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>

namespace {

constexpr NSInteger kMaximumWindowRetries = 20;
constexpr NSTimeInterval kWindowRetryInterval = 0.25;
constexpr NSUInteger kMaximumFirstFrameAttempts = 3;
constexpr NSTimeInterval kFirstFrameRetryInterval = 0.10;
constexpr std::uint64_t kFirstFrameTimeoutMilliseconds = 1000;
constexpr NSTimeInterval kDuplicateButtonActionInterval = 0.15;
constexpr NSTimeInterval kPostDragTapSuppressionInterval = 0.25;
constexpr CGFloat kDragThreshold = 6.0;
constexpr CFTimeInterval kFrameFailureLogInterval = 2.0;

using serverhost::v2::diagnostics::LogCategory;
using serverhost::v2::diagnostics::LogSeverity;

void LogUI(LogSeverity severity, const std::string& message) {
    serverhost::v2::diagnostics::ProcessLogger().Add(severity, LogCategory::UI, message);
}

std::string UTF8String(NSString* value) {
    if (!value)
        return {};
    const char* utf8 = value.UTF8String;
    return utf8 ? std::string(utf8) : std::string();
}

ImVec4 RGB(unsigned int value, float alpha = 1.0f) {
    return ImVec4(
        static_cast<float>((value >> 16) & 0xffU) / 255.0f,
        static_cast<float>((value >> 8) & 0xffU) / 255.0f,
        static_cast<float>(value & 0xffU) / 255.0f,
        alpha);
}

void ApplyDiagnosticTheme() {
    ImGui::StyleColorsDark();
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowPadding = ImVec2(10.0f, 10.0f);
    style.FramePadding = ImVec2(8.0f, 6.0f);
    style.ItemSpacing = ImVec2(10.0f, 7.0f);
    style.ItemInnerSpacing = ImVec2(6.0f, 4.0f);
    style.CellPadding = ImVec2(8.0f, 5.0f);
    style.WindowRounding = 9.0f;
    style.ChildRounding = 6.0f;
    style.FrameRounding = 5.0f;
    style.PopupRounding = 6.0f;
    style.ScrollbarRounding = 6.0f;
    style.GrabRounding = 5.0f;
    style.WindowBorderSize = 1.0f;
    style.ChildBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    style.ScrollbarSize = 13.0f;
    style.GrabMinSize = 12.0f;
    style.ButtonTextAlign = ImVec2(0.5f, 0.5f);

    ImVec4* colors = style.Colors;
    colors[ImGuiCol_Text] = RGB(0xC4E8FA);
    colors[ImGuiCol_TextDisabled] = RGB(0x82B5BE);
    colors[ImGuiCol_WindowBg] = RGB(0x061318, 0.98f);
    colors[ImGuiCol_ChildBg] = RGB(0x091E25, 0.94f);
    colors[ImGuiCol_PopupBg] = RGB(0x091822, 0.98f);
    colors[ImGuiCol_Border] = RGB(0x18D6D8, 0.42f);
    colors[ImGuiCol_Separator] = RGB(0x18D6D8, 0.30f);
    colors[ImGuiCol_FrameBg] = RGB(0x0B2930, 0.92f);
    colors[ImGuiCol_FrameBgHovered] = RGB(0x0E3C44, 0.98f);
    colors[ImGuiCol_FrameBgActive] = RGB(0x12535B, 1.0f);
    colors[ImGuiCol_Button] = RGB(0x0B2930, 0.96f);
    colors[ImGuiCol_ButtonHovered] = RGB(0x0E4A52, 1.0f);
    colors[ImGuiCol_ButtonActive] = RGB(0x13747A, 1.0f);
    colors[ImGuiCol_Header] = RGB(0x0D3D45, 0.92f);
    colors[ImGuiCol_HeaderHovered] = RGB(0x12626A, 0.96f);
    colors[ImGuiCol_HeaderActive] = RGB(0x20DADA, 0.74f);
    colors[ImGuiCol_CheckMark] = RGB(0x20DADA);
    colors[ImGuiCol_SliderGrab] = RGB(0x20DADA, 0.90f);
    colors[ImGuiCol_SliderGrabActive] = RGB(0x72FFFF);
    colors[ImGuiCol_TableRowBg] = RGB(0x071A20, 0.70f);
    colors[ImGuiCol_TableRowBgAlt] = RGB(0x0A252C, 0.76f);
    colors[ImGuiCol_TableBorderLight] = RGB(0x18D6D8, 0.16f);
    colors[ImGuiCol_ScrollbarBg] = RGB(0x000000, 0.0f);
    colors[ImGuiCol_ScrollbarGrab] = RGB(0x157079, 0.72f);
    colors[ImGuiCol_ScrollbarGrabHovered] = RGB(0x20DADA, 0.82f);
    colors[ImGuiCol_ScrollbarGrabActive] = RGB(0x20DADA);
}

}  // namespace

@interface SHV2PassThroughMTKView : MTKView
@property(nonatomic, assign) BOOL menuOpen;
@property(nonatomic,assign) CGRect touchableRect;
@end

@implementation SHV2PassThroughMTKView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event
{
    const CGRect rect = self.touchableRect;
    const BOOL inside = point.x >= rect.origin.x && point.y >= rect.origin.y
        && point.x <= rect.origin.x + rect.size.width
        && point.y <= rect.origin.y + rect.size.height;
    if (!self.menuOpen || !inside)
        return NO;
    return [super pointInside:point withEvent:event];
}

@end

@interface SHV2DiagnosticOverlayController : UIViewController <MTKViewDelegate> {
@private
    ImGuiContext* _imguiContext;
}
@property(nonatomic,strong) id<MTLDevice> metalDevice;
@property(nonatomic,strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic,assign,getter=isMenuVisible) BOOL menuVisible;
@property(nonatomic,assign) BOOL suspendedForBackground;
@property(nonatomic,assign) BOOL firstFramePending;
@property(nonatomic,assign) BOOL firstFrameSubmitted;
@property(nonatomic,assign) BOOL reportedFirstFrameEntry;
@property(nonatomic,assign) BOOL reportedDrawableAcquired;
@property(nonatomic,assign) NSUInteger firstFrameAttempts;
@property(nonatomic,assign) NSUInteger openGeneration;
@property(nonatomic,assign) CFTimeInterval lastFrameFailureLogTime;
@property(nonatomic,copy) NSString* currentFailureStage;
@property(nonatomic,copy) void (^firstFrameEnteredHandler)(void);
@property(nonatomic,copy) void (^firstFramePresentedHandler)(void);
@property(nonatomic,copy) void (^presentationFailureHandler)(NSString* stage);
@property(nonatomic,copy) void (^closeHandler)(void);
- (instancetype)initWithFailureStage:(NSString* __autoreleasing*)failureStage;
- (SHV2PassThroughMTKView*)metalView;
- (void)prepareAttachedClosed;
- (void)requestOpenAndDrawFirstFrame;
- (void)stopAndHide;
- (void)requestAnotherFirstFrameAttemptForGeneration:(NSUInteger)generation;
@end

@implementation SHV2DiagnosticOverlayController

- (instancetype)initWithFailureStage:(NSString* __autoreleasing*)failureStage
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;

    _metalDevice = MTLCreateSystemDefaultDevice();
    if (!_metalDevice) {
        if (failureStage)
            *failureStage = @"metal-device-unavailable";
        return nil;
    }
    _commandQueue = [_metalDevice newCommandQueue];
    if (!_commandQueue) {
        if (failureStage)
            *failureStage = @"metal-command-queue-unavailable";
        return nil;
    }

    IMGUI_CHECKVERSION();
    _imguiContext = ImGui::CreateContext();
    if (!_imguiContext) {
        if (failureStage)
            *failureStage = @"imgui-context-unavailable";
        return nil;
    }
    ImGui::SetCurrentContext(_imguiContext);
    ApplyDiagnosticTheme();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    io.Fonts->AddFontDefault();
    if (!ImGui_ImplMetal_Init(_metalDevice)) {
        ImGui::DestroyContext(_imguiContext);
        _imguiContext = nullptr;
        if (failureStage)
            *failureStage = @"imgui-metal-backend-unavailable";
        return nil;
    }
    _currentFailureStage = @"first-frame-not-entered";
    return self;
}

- (void)dealloc
{
    if (_imguiContext) {
        ImGui::SetCurrentContext(_imguiContext);
        ImGui_ImplMetal_Shutdown();
        ImGui::DestroyContext(_imguiContext);
        _imguiContext = nullptr;
    }
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)loadView
{
    SHV2PassThroughMTKView* view =
        [[SHV2PassThroughMTKView alloc] initWithFrame:UIScreen.mainScreen.bounds
                                               device:self.metalDevice];
    view.delegate = self;
    view.paused = YES;
    view.enableSetNeedsDisplay = YES;
    view.preferredFramesPerSecond = 30;
    view.opaque = NO;
    view.layer.opaque = NO;
    view.backgroundColor = UIColor.clearColor;
    view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.menuOpen = NO;
    view.touchableRect = CGRectMake(0.0, 0.0, 0.0, 0.0);
    view.hidden = YES;
    self.view = view;
}

- (SHV2PassThroughMTKView*)metalView
{
    return (SHV2PassThroughMTKView*)self.view;
}

- (void)configureContinuousRendering:(BOOL)shouldRender
{
    SHV2PassThroughMTKView* view = self.metalView;
    view.paused = !shouldRender;
    view.enableSetNeedsDisplay = !shouldRender;
}

- (void)prepareAttachedClosed
{
    [self stopAndHide];
}

- (void)requestOpenAndDrawFirstFrame
{
    ++self.openGeneration;
    self.menuVisible = YES;
    self.firstFramePending = YES;
    self.firstFrameSubmitted = NO;
    self.reportedFirstFrameEntry = NO;
    self.reportedDrawableAcquired = NO;
    self.firstFrameAttempts = 0;
    self.lastFrameFailureLogTime = 0.0;
    self.currentFailureStage = @"first-frame-not-entered";

    SHV2PassThroughMTKView* view = self.metalView;
    view.menuOpen = YES;
    view.hidden = NO;
    view.userInteractionEnabled = YES;
    [self configureContinuousRendering:NO];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [self requestAnotherFirstFrameAttemptForGeneration:self.openGeneration];
}

- (void)requestAnotherFirstFrameAttemptForGeneration:(NSUInteger)generation
{
    if (!self.menuVisible || !self.firstFramePending || self.firstFrameSubmitted
        || self.suspendedForBackground || generation != self.openGeneration
        || self.firstFrameAttempts >= kMaximumFirstFrameAttempts) {
        return;
    }

    ++self.firstFrameAttempts;
    SHV2PassThroughMTKView* view = self.metalView;
    [view setNeedsDisplay];
    [view draw];

    if (!self.firstFramePending || self.firstFrameSubmitted
        || self.firstFrameAttempts >= kMaximumFirstFrameAttempts) {
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 static_cast<int64_t>(kFirstFrameRetryInterval
                                                      * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self requestAnotherFirstFrameAttemptForGeneration:generation];
    });
}

- (void)stopAndHide
{
    ++self.openGeneration;
    self.menuVisible = NO;
    self.firstFramePending = NO;
    self.firstFrameSubmitted = NO;
    SHV2PassThroughMTKView* view = self.metalView;
    view.menuOpen = NO;
    view.touchableRect = CGRectMake(0.0, 0.0, 0.0, 0.0);
    view.userInteractionEnabled = NO;
    [self configureContinuousRendering:NO];
    view.hidden = YES;
}

- (void)setSuspendedForBackground:(BOOL)suspendedForBackground
{
    _suspendedForBackground = suspendedForBackground;
    if (suspendedForBackground) {
        [self configureContinuousRendering:NO];
        return;
    }
    if (!self.menuVisible)
        return;
    if (self.firstFramePending)
        [self requestAnotherFirstFrameAttemptForGeneration:self.openGeneration];
    else
        [self configureContinuousRendering:YES];
}

- (void)recordFrameFailure:(NSString*)stage
{
    self.currentFailureStage = stage;
    const CFTimeInterval now = CACurrentMediaTime();
    if (self.lastFrameFailureLogTime != 0.0
        && now - self.lastFrameFailureLogTime < kFrameFailureLogInterval) {
        return;
    }
    self.lastFrameFailureLogTime = now;
    LogUI(LogSeverity::Warning, "frame path unavailable stage=" + UTF8String(stage));
}

- (void)updateIOWithTouchEvent:(UIEvent*)event
{
    UITouch* touch = event.allTouches.anyObject;
    if (!touch || !_imguiContext)
        return;

    ImGui::SetCurrentContext(_imguiContext);
    const CGPoint location = [touch locationInView:self.view];
    ImGuiIO& io = ImGui::GetIO();
    io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
    io.AddMousePosEvent(location.x, location.y);

    BOOL active = NO;
    for (UITouch* current in event.allTouches) {
        if (current.phase != UITouchPhaseEnded && current.phase != UITouchPhaseCancelled) {
            active = YES;
            break;
        }
    }
    io.AddMouseButtonEvent(0, active);
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    (void)touches;
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    (void)touches;
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    (void)touches;
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    (void)touches;
    [self updateIOWithTouchEvent:event];
}

- (void)drawStatusPage:(const serverhost::v2::ui::DiagnosticPresentationModel&)model
{
    ImGui::TextColored(RGB(0x72FFFF), "Runtime capability receipt");
    ImGui::TextDisabled("Fail-closed diagnostics; no engine access in Gate 1.5");
    ImGui::Spacing();

    const ImGuiTableFlags flags = ImGuiTableFlags_RowBg
        | ImGuiTableFlags_BordersInnerH | ImGuiTableFlags_SizingStretchProp;
    if (ImGui::BeginTable("DiagnosticStatusTable", 2, flags)) {
        ImGui::TableSetupColumn("Field", ImGuiTableColumnFlags_WidthFixed, 122.0f);
        ImGui::TableSetupColumn("Value", ImGuiTableColumnFlags_WidthStretch);
        for (const serverhost::v2::ui::DiagnosticStatusRow& row : model.StatusRows()) {
            ImGui::TableNextRow();
            ImGui::TableSetColumnIndex(0);
            ImGui::TextColored(RGB(0x82B5BE), "%s", row.label.c_str());
            ImGui::TableSetColumnIndex(1);
            ImGui::TextWrapped("%s", row.value.c_str());
        }
        ImGui::EndTable();
    }
}

- (void)drawLogsPage:(const serverhost::v2::ui::DiagnosticPresentationModel&)model
{
    ImGui::TextColored(RGB(0x72FFFF), "Bounded presentation log");
    ImGui::SameLine();
    ImGui::TextDisabled("%zu / %zu retained, %llu dropped",
                        model.Logs().entries.size(), model.Logs().capacity,
                        static_cast<unsigned long long>(model.Logs().dropped));
    ImGui::Separator();
    ImGui::BeginChild("DiagnosticLogRows", ImVec2(0.0f, 0.0f), false,
                      ImGuiWindowFlags_HorizontalScrollbar);
    for (const serverhost::v2::diagnostics::LogEntry& entry : model.Logs().entries) {
        ImVec4 color = ImGui::GetStyleColorVec4(ImGuiCol_Text);
        if (entry.severity == serverhost::v2::diagnostics::LogSeverity::Warning)
            color = RGB(0xF4C15D);
        else if (entry.severity == serverhost::v2::diagnostics::LogSeverity::Error)
            color = RGB(0xFF6B72);
        else if (entry.severity == serverhost::v2::diagnostics::LogSeverity::Debug)
            color = RGB(0x74A9FF);
        const std::string formatted = serverhost::v2::diagnostics::FormatLogEntry(entry);
        ImGui::PushStyleColor(ImGuiCol_Text, color);
        ImGui::TextWrapped("%s", formatted.c_str());
        ImGui::PopStyleColor();
    }
    ImGui::EndChild();
}

- (void)drawInMTKView:(MTKView*)view
{
    if (!self.menuVisible || !_imguiContext)
        return;

    if (self.firstFramePending && !self.reportedFirstFrameEntry) {
        self.reportedFirstFrameEntry = YES;
        LogUI(LogSeverity::Info, "first frame entered");
        if (self.firstFrameEnteredHandler)
            self.firstFrameEnteredHandler();
    }

    MTLRenderPassDescriptor* descriptor = view.currentRenderPassDescriptor;
    if (!descriptor) {
        [self recordFrameFailure:@"metal-render-pass-descriptor-unavailable"];
        return;
    }
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!drawable) {
        [self recordFrameFailure:@"metal-drawable-unavailable"];
        return;
    }
    if (!self.reportedDrawableAcquired) {
        self.reportedDrawableAcquired = YES;
        LogUI(LogSeverity::Info, "Metal drawable and render-pass descriptor acquired");
    }

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    if (!commandBuffer) {
        [self recordFrameFailure:@"metal-command-buffer-unavailable"];
        return;
    }
    id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    if (!encoder) {
        [self recordFrameFailure:@"metal-render-encoder-unavailable"];
        return;
    }

    ImGui::SetCurrentContext(_imguiContext);
    const std::shared_ptr<const serverhost::v2::diagnostics::DiagnosticSnapshot> snapshot =
        serverhost::v2::diagnostics::CaptureDiagnosticSnapshot();
    const serverhost::v2::ui::DiagnosticPresentationModel model(*snapshot);

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    UIScreen* screen = view.window.screen;
    if (!screen)
        screen = UIScreen.mainScreen;
    const CGFloat scale = screen.nativeScale != 0.0 ? screen.nativeScale : screen.scale;
    io.DisplayFramebufferScale = ImVec2(scale, scale);
    const NSInteger framesPerSecond = view.preferredFramesPerSecond != 0
        ? view.preferredFramesPerSecond
        : 30;
    io.DeltaTime = 1.0f / static_cast<float>(framesPerSecond);

    ImGui_ImplMetal_NewFrame(descriptor);
    ImGui::NewFrame();

    const float viewWidth = static_cast<float>(view.bounds.size.width);
    const float viewHeight = static_cast<float>(view.bounds.size.height);
    const float panelWidth = std::max(300.0f, std::min(650.0f, viewWidth - 28.0f));
    const float panelHeight = std::max(300.0f, std::min(455.0f, viewHeight - 42.0f));
    ImGui::SetNextWindowSize(ImVec2(panelWidth, panelHeight), ImGuiCond_Always);
    ImGui::SetNextWindowPos(ImVec2(viewWidth * 0.5f, viewHeight * 0.5f),
                            ImGuiCond_Always, ImVec2(0.5f, 0.5f));

    bool copyRequested = false;
    bool closeRequested = false;
    static int selectedPage = 0;
    const ImGuiWindowFlags windowFlags = ImGuiWindowFlags_NoTitleBar
        | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize
        | ImGuiWindowFlags_NoSavedSettings;
    if (ImGui::Begin("##ServerHostV2Diagnostics", nullptr, windowFlags)) {
        ImGui::TextColored(RGB(0x72FFFF), "SERVER HOST V2");
        ImGui::SameLine();
        ImGui::TextDisabled("Gate 1.5 diagnostics");
        ImGui::Separator();

        constexpr float railWidth = 116.0f;
        constexpr float footerHeight = 43.0f;
        ImGui::BeginChild("DiagnosticNavigation", ImVec2(railWidth, -footerHeight), true);
        ImGui::TextDisabled("NAVIGATION");
        ImGui::Spacing();
        if (ImGui::Selectable("Status", selectedPage == 0, 0, ImVec2(0.0f, 38.0f)))
            selectedPage = 0;
        if (ImGui::Selectable("Logs", selectedPage == 1, 0, ImVec2(0.0f, 38.0f)))
            selectedPage = 1;
        ImGui::EndChild();

        ImGui::SameLine();
        ImGui::BeginChild("DiagnosticContent", ImVec2(0.0f, -footerHeight), true);
        if (selectedPage == 0)
            [self drawStatusPage:model];
        else
            [self drawLogsPage:model];
        ImGui::EndChild();

        ImGui::Separator();
        const float copyWidth = 112.0f;
        const float closeWidth = 78.0f;
        const float actionWidth = copyWidth + closeWidth + ImGui::GetStyle().ItemSpacing.x;
        ImGui::SetCursorPosX(std::max(ImGui::GetCursorPosX(),
                                     ImGui::GetWindowWidth()
                                         - actionWidth - ImGui::GetStyle().WindowPadding.x));
        if (ImGui::Button("Copy logs", ImVec2(copyWidth, 30.0f)))
            copyRequested = true;
        ImGui::SameLine();
        ImGui::PushStyleColor(ImGuiCol_Button, RGB(0x26323A));
        ImGui::PushStyleColor(ImGuiCol_ButtonHovered, RGB(0x3A4B55));
        if (ImGui::Button("Close", ImVec2(closeWidth, 30.0f)))
            closeRequested = true;
        ImGui::PopStyleColor(2);

        const ImVec2 windowPosition = ImGui::GetWindowPos();
        const ImVec2 windowSize = ImGui::GetWindowSize();
        self.metalView.touchableRect = CGRectMake(
            windowPosition.x, windowPosition.y, windowSize.x, windowSize.y);
    }
    ImGui::End();
    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, encoder);

    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];

    const BOOL isFirstFrame = self.firstFramePending && !self.firstFrameSubmitted;
    const NSUInteger generation = self.openGeneration;
    if (isFirstFrame) {
        self.firstFrameSubmitted = YES;
        self.currentFailureStage = @"metal-command-buffer-pending";
        LogUI(LogSeverity::Info, "ImGui frame rendered and submitted");
        __weak SHV2DiagnosticOverlayController* weakSelf = self;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completedBuffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SHV2DiagnosticOverlayController* strongSelf = weakSelf;
                if (!strongSelf || generation != strongSelf.openGeneration
                    || !strongSelf.firstFramePending) {
                    return;
                }
                if (completedBuffer.status == MTLCommandBufferStatusError) {
                    strongSelf.currentFailureStage = @"metal-command-buffer-error";
                    [strongSelf stopAndHide];
                    if (strongSelf.presentationFailureHandler)
                        strongSelf.presentationFailureHandler(@"metal-command-buffer-error");
                    return;
                }
                strongSelf.firstFramePending = NO;
                strongSelf.firstFrameSubmitted = NO;
                strongSelf.currentFailureStage = @"none";
                [strongSelf configureContinuousRendering:
                    !strongSelf.suspendedForBackground && strongSelf.menuVisible];
                if (strongSelf.firstFramePresentedHandler)
                    strongSelf.firstFramePresentedHandler();
            });
        }];
    }
    [commandBuffer commit];

    if (copyRequested) {
        const std::string text = model.CopyableLogs();
        NSString* value = [[NSString alloc] initWithBytes:text.data()
                                                   length:text.size()
                                                 encoding:NSUTF8StringEncoding];
        if (value) {
            UIPasteboard.generalPasteboard.string = value;
            LogUI(LogSeverity::Info, "bounded diagnostic logs copied");
        }
    }
    if (closeRequested && self.closeHandler)
        self.closeHandler();
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
    (void)view;
    (void)size;
}

@end

@interface SHV2DiagnosticUIBootstrap : NSObject <UIGestureRecognizerDelegate> {
@private
    std::unique_ptr<serverhost::v2::ui::PresentationStateMachine> _presentation;
}
@property(nonatomic,strong) SHV2DiagnosticOverlayController* overlay;
@property(nonatomic,strong) UIButton* floatingButton;
@property(nonatomic,weak) UIViewController* installedRoot;
@property(nonatomic,weak) UIWindow* installedWindow;
@property(nonatomic,strong) UIView* fallbackView;
@property(nonatomic,copy) NSString* overlayInitializationFailureStage;
@property(nonatomic,assign) NSInteger retryCount;
@property(nonatomic,assign) BOOL retryScheduled;
@property(nonatomic,assign) BOOL observersInstalled;
@property(nonatomic,assign) BOOL overlayInitializationAttempted;
@property(nonatomic,assign) BOOL dragDetected;
@property(nonatomic,assign) CGPoint dragStartCenter;
@property(nonatomic,assign) CFTimeInterval lastAcceptedButtonActionTime;
@property(nonatomic,assign) CFTimeInterval suppressTapUntil;
@property(nonatomic,assign) NSUInteger openRequestGeneration;
+ (instancetype)sharedBootstrap;
- (void)start;
- (void)lifecycleBecameUsable:(NSNotification*)notification;
- (void)applicationDidEnterBackground:(NSNotification*)notification;
- (UIWindow*)activeWindow;
- (void)scheduleBoundedRetry;
- (BOOL)attemptInstall;
- (void)buttonAction:(UIButton*)sender;
- (void)dragButton:(UIPanGestureRecognizer*)recognizer;
@end

@implementation SHV2DiagnosticUIBootstrap

+ (instancetype)sharedBootstrap
{
    static SHV2DiagnosticUIBootstrap* shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [SHV2DiagnosticUIBootstrap new];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _presentation = std::make_unique<serverhost::v2::ui::PresentationStateMachine>(
            24, kFirstFrameTimeoutMilliseconds);
    }
    return self;
}

- (void)start
{
    NSAssert(NSThread.isMainThread, @"diagnostic UI bootstrap must run on main thread");
    if (!self.observersInstalled) {
        self.observersInstalled = YES;
        NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIApplicationDidFinishLaunchingNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIApplicationWillEnterForegroundNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UISceneWillConnectNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UISceneWillEnterForegroundNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UISceneDidActivateNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIWindowDidBecomeVisibleNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIWindowDidBecomeKeyNotification object:nil];
        [center addObserver:self selector:@selector(applicationDidEnterBackground:)
                       name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    [self attemptInstall];
}

- (void)lifecycleBecameUsable:(NSNotification*)notification
{
    (void)notification;
    self.retryCount = 0;
    self.overlay.suspendedForBackground = NO;
    [self attemptInstall];
}

- (void)applicationDidEnterBackground:(NSNotification*)notification
{
    (void)notification;
    self.overlay.suspendedForBackground = YES;
}

- (UIWindow*)activeWindow
{
    UIWindow* foregroundFallback = nil;
    UIWindow* anyFallback = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;
        UIWindowScene* windowScene = (UIWindowScene*)scene;
        for (UIWindow* window in windowScene.windows) {
            if (window.hidden || window.alpha == 0.0 || !window.rootViewController)
                continue;
            if (!anyFallback)
                anyFallback = window;
            if (scene.activationState == UISceneActivationStateForegroundActive
                && (!foregroundFallback || window.windowLevel == UIWindowLevelNormal)) {
                foregroundFallback = window;
            }
            if (scene.activationState == UISceneActivationStateForegroundActive
                && window.isKeyWindow) {
                return window;
            }
        }
    }
    return foregroundFallback ? foregroundFallback : anyFallback;
}

- (void)scheduleBoundedRetry
{
    if (self.retryScheduled || self.retryCount >= kMaximumWindowRetries)
        return;
    self.retryScheduled = YES;
    ++self.retryCount;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 static_cast<int64_t>(kWindowRetryInterval * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.retryScheduled = NO;
        [self attemptInstall];
    });
}

- (void)configureOverlayCallbacks
{
    __weak SHV2DiagnosticUIBootstrap* weakSelf = self;
    self.overlay.firstFrameEnteredHandler = ^{
        SHV2DiagnosticUIBootstrap* strongSelf = weakSelf;
        if (strongSelf)
            strongSelf->_presentation->NoteFirstFrameEntered();
    };
    self.overlay.firstFramePresentedHandler = ^{
        SHV2DiagnosticUIBootstrap* strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_presentation->MarkFirstFramePresented())
            return;
        LogUI(LogSeverity::Info, "first frame presented");
        if (strongSelf->_presentation->ConfirmOpen())
            [strongSelf setButtonOpen:YES failed:NO animated:YES];
    };
    self.overlay.presentationFailureHandler = ^(NSString* stage) {
        [weakSelf presentVisibleFallbackForStage:stage];
    };
    self.overlay.closeHandler = ^{
        [weakSelf closePresentation];
    };
}

- (void)ensureOverlayCreated
{
    if (self.overlay || self.overlayInitializationAttempted)
        return;
    self.overlayInitializationAttempted = YES;
    NSString* failureStage = nil;
    self.overlay = [[SHV2DiagnosticOverlayController alloc]
        initWithFailureStage:&failureStage];
    if (!self.overlay) {
        self.overlayInitializationFailureStage = failureStage
            ? failureStage
            : @"metal-imgui-initialization-unavailable";
        LogUI(LogSeverity::Error,
              "diagnostic overlay initialization unavailable stage="
                  + UTF8String(self.overlayInitializationFailureStage));
        return;
    }
    [self configureOverlayCallbacks];
    [self.overlay prepareAttachedClosed];
}

- (void)createFloatingButtonIfNeeded
{
    if (self.floatingButton)
        return;
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(20.0, 110.0, 58.0, 58.0);
    button.backgroundColor = [UIColor colorWithRed:0.03 green:0.10 blue:0.13 alpha:0.96];
    button.tintColor = [UIColor colorWithRed:0.72 green:0.96 blue:1.0 alpha:1.0];
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = 1.2;
    button.layer.borderColor =
        [UIColor colorWithRed:0.13 green:0.85 blue:0.86 alpha:0.92].CGColor;
    UIImage* icon = [UIImage systemImageNamed:@"stethoscope"];
    if (icon)
        [button setImage:icon forState:UIControlStateNormal];
    else
        [button setTitle:@"V2" forState:UIControlStateNormal];
    button.accessibilityLabel = @"Server Host V2 diagnostics";
    button.accessibilityHint = @"Opens Status and Logs";
    [button addTarget:self action:@selector(buttonAction:)
      forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(buttonAction:)
      forControlEvents:UIControlEventPrimaryActionTriggered];

    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragButton:)];
    pan.cancelsTouchesInView = NO;
    pan.delaysTouchesBegan = NO;
    pan.delaysTouchesEnded = NO;
    pan.delegate = self;
    [button addGestureRecognizer:pan];
    self.floatingButton = button;
}

- (void)clampFloatingButtonInside:(UIView*)parent
{
    if (!parent || !self.floatingButton)
        return;
    CGPoint center = self.floatingButton.center;
    const UIEdgeInsets safeArea = parent.safeAreaInsets;
    const CGFloat halfWidth = self.floatingButton.bounds.size.width * 0.5;
    const CGFloat halfHeight = self.floatingButton.bounds.size.height * 0.5;
    center.x = std::max(safeArea.left + halfWidth,
                        std::min(parent.bounds.size.width - safeArea.right - halfWidth,
                                 center.x));
    center.y = std::max(safeArea.top + halfHeight,
                        std::min(parent.bounds.size.height - safeArea.bottom - halfHeight,
                                 center.y));
    self.floatingButton.center = center;
}

- (BOOL)hierarchyIsVerifiedForWindow:(UIWindow*)window root:(UIViewController*)root
{
    if (!window || !root || self.floatingButton.superview != root.view
        || self.floatingButton.window != window) {
        return NO;
    }
    if (!self.overlay)
        return YES;
    return self.overlay.parentViewController == root
        && self.overlay.view.superview == root.view
        && self.overlay.view.window == window;
}

- (void)bringPresentationToFrontForRoot:(UIViewController*)root
{
    if (self.overlay.view.superview == root.view)
        [root.view bringSubviewToFront:self.overlay.view];
    if (self.fallbackView.superview == root.view)
        [root.view bringSubviewToFront:self.fallbackView];
    if (self.floatingButton.superview == root.view)
        [root.view bringSubviewToFront:self.floatingButton];
}

- (BOOL)attemptInstall
{
    UIWindow* window = [self activeWindow];
    UIViewController* root = window.rootViewController;
    if (!window || !root) {
        [self scheduleBoundedRetry];
        return NO;
    }

    [self ensureOverlayCreated];
    [self createFloatingButtonIfNeeded];
    const BOOL rootChanged = self.installedRoot != root || self.installedWindow != window;

    if (self.overlay && self.overlay.parentViewController != root) {
        if (self.overlay.parentViewController) {
            [self.overlay willMoveToParentViewController:nil];
            [self.overlay.view removeFromSuperview];
            [self.overlay removeFromParentViewController];
        }
        [root addChildViewController:self.overlay];
        self.overlay.view.frame = root.view.bounds;
        self.overlay.view.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [root.view addSubview:self.overlay.view];
        [self.overlay didMoveToParentViewController:root];
    } else if (self.overlay && self.overlay.view.superview != root.view) {
        [self.overlay.view removeFromSuperview];
        self.overlay.view.frame = root.view.bounds;
        [root.view addSubview:self.overlay.view];
    }

    if (self.floatingButton.superview != root.view) {
        [self.floatingButton removeFromSuperview];
        [root.view addSubview:self.floatingButton];
    }
    if (self.fallbackView && self.fallbackView.superview != root.view) {
        [self.fallbackView removeFromSuperview];
        [root.view addSubview:self.fallbackView];
        self.fallbackView.center = CGPointMake(
            root.view.bounds.origin.x + root.view.bounds.size.width * 0.5,
            root.view.bounds.origin.y + root.view.bounds.size.height * 0.5);
    }

    self.installedRoot = root;
    self.installedWindow = window;
    [root.view setNeedsLayout];
    [root.view layoutIfNeeded];
    [self clampFloatingButtonInside:root.view];
    [self bringPresentationToFrontForRoot:root];

    const BOOL verified = [self hierarchyIsVerifiedForWindow:window root:root];
    if (!verified) {
        LogUI(LogSeverity::Warning,
              "presentation hierarchy not yet attached to the active window");
        [self scheduleBoundedRetry];
        return NO;
    }

    if (_presentation->State() == serverhost::v2::ui::PresentationState::Detached)
        (void)_presentation->Attach();
    self.retryCount = 0;
    if (rootChanged) {
        LogUI(LogSeverity::Info,
              self.overlay
                  ? "overlay attached and hierarchy verified; floating button visible"
                  : "floating button attached; overlay initialization unavailable");
    }
    if (_presentation->State() == serverhost::v2::ui::PresentationState::OpenRequested
        && self.overlay && !self.overlay.menuVisible) {
        LogUI(LogSeverity::Info,
              "overlay hierarchy verified after retry; requesting first frame");
        [self.overlay requestOpenAndDrawFirstFrame];
        [self bringPresentationToFrontForRoot:root];
    }
    return YES;
}

- (void)setButtonOpen:(BOOL)open failed:(BOOL)failed animated:(BOOL)animated
{
    void (^changes)(void) = ^{
        if (failed) {
            self.floatingButton.backgroundColor =
                [UIColor colorWithRed:0.48 green:0.10 blue:0.14 alpha:0.98];
            self.floatingButton.layer.borderColor =
                [UIColor colorWithRed:1.0 green:0.42 blue:0.45 alpha:1.0].CGColor;
            self.floatingButton.tintColor = UIColor.whiteColor;
        } else if (open) {
            self.floatingButton.backgroundColor =
                [UIColor colorWithRed:0.04 green:0.53 blue:0.56 alpha:0.98];
            self.floatingButton.layer.borderColor =
                [UIColor colorWithRed:0.45 green:1.0 blue:1.0 alpha:1.0].CGColor;
            self.floatingButton.tintColor = UIColor.whiteColor;
        } else {
            self.floatingButton.backgroundColor =
                [UIColor colorWithRed:0.03 green:0.10 blue:0.13 alpha:0.96];
            self.floatingButton.layer.borderColor =
                [UIColor colorWithRed:0.13 green:0.85 blue:0.86 alpha:0.92].CGColor;
            self.floatingButton.tintColor =
                [UIColor colorWithRed:0.72 green:0.96 blue:1.0 alpha:1.0];
        }
        self.floatingButton.selected = open || failed;
    };
    if (animated)
        [UIView animateWithDuration:0.15 animations:changes];
    else
        changes();
}

- (void)buttonAction:(UIButton*)sender
{
    (void)sender;
    const CFTimeInterval now = CACurrentMediaTime();
    if (self.dragDetected || now < self.suppressTapUntil) {
        LogUI(LogSeverity::Debug, "button release ignored after drag");
        return;
    }
    if (self.lastAcceptedButtonActionTime != 0.0
        && now - self.lastAcceptedButtonActionTime < kDuplicateButtonActionInterval) {
        return;
    }
    self.lastAcceptedButtonActionTime = now;
    LogUI(LogSeverity::Info, "button action received");

    const serverhost::v2::ui::PresentationState state = _presentation->State();
    if (state == serverhost::v2::ui::PresentationState::Open
        || state == serverhost::v2::ui::PresentationState::OpenRequested
        || state == serverhost::v2::ui::PresentationState::FirstFramePresented
        || state == serverhost::v2::ui::PresentationState::FailedWithVisibleFallback) {
        [self closePresentation];
        return;
    }
    [self openPresentation];
}

- (void)openPresentation
{
    if (![self attemptInstall]) {
        [self setButtonOpen:YES failed:NO animated:YES];
        if (_presentation->State() == serverhost::v2::ui::PresentationState::AttachedClosed
            && _presentation->RequestOpen()) {
            LogUI(LogSeverity::Info, "open requested; hierarchy pending");
            [self scheduleFirstFrameTimeoutForGeneration:++self.openRequestGeneration];
        }
        return;
    }
    if (_presentation->State() != serverhost::v2::ui::PresentationState::AttachedClosed
        || !_presentation->RequestOpen()) {
        LogUI(LogSeverity::Warning,
              "open request rejected by presentation state machine");
        return;
    }

    [self setButtonOpen:YES failed:NO animated:YES];
    LogUI(LogSeverity::Info, "open requested");

    UIWindow* window = [self activeWindow];
    UIViewController* root = window.rootViewController;
    [self bringPresentationToFrontForRoot:root];
    [root.view setNeedsLayout];
    [root.view layoutIfNeeded];
    if (![self hierarchyIsVerifiedForWindow:window root:root]) {
        [self presentVisibleFallbackForStage:@"overlay-hierarchy-unverified"];
        return;
    }
    if (!self.overlay) {
        [self presentVisibleFallbackForStage:
            self.overlayInitializationFailureStage
                ? self.overlayInitializationFailureStage
                : @"metal-imgui-initialization-unavailable"];
        return;
    }
    LogUI(LogSeverity::Info, "overlay attached and hierarchy verified for open");

    const NSUInteger generation = ++self.openRequestGeneration;
    [self.overlay requestOpenAndDrawFirstFrame];
    [self bringPresentationToFrontForRoot:root];
    [self scheduleFirstFrameTimeoutForGeneration:generation];
}

- (void)scheduleFirstFrameTimeoutForGeneration:(NSUInteger)generation
{
    const std::uint64_t timeout = _presentation->FirstFrameTimeoutMilliseconds();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 static_cast<int64_t>(timeout * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        if (generation != self.openRequestGeneration
            || !self->_presentation->ShouldPresentFirstFrameFallback(timeout)) {
            return;
        }
        NSString* stage = self.overlay.currentFailureStage
            ? self.overlay.currentFailureStage
            : @"first-frame-timeout";
        [self presentVisibleFallbackForStage:stage];
    });
}

- (void)presentVisibleFallbackForStage:(NSString*)stage
{
    if (_presentation->State() == serverhost::v2::ui::PresentationState::AttachedClosed)
        (void)_presentation->RequestOpen();
    if (!_presentation->IsAwaitingFirstFrame())
        return;

    NSString* boundedStage = stage.length != 0 ? stage : @"unknown-presentation-stage";
    if (!_presentation->FailWithVisibleFallback(UTF8String(boundedStage)))
        return;
    ++self.openRequestGeneration;
    [self.overlay stopAndHide];
    [self setButtonOpen:NO failed:YES animated:YES];
    LogUI(LogSeverity::Error,
          "presentation failed; visible fallback stage=" + UTF8String(boundedStage));

    [self.fallbackView removeFromSuperview];
    UIViewController* root = [self activeWindow].rootViewController;
    if (!root)
        return;

    const CGFloat width = std::max(260.0, std::min(380.0,
        static_cast<double>(root.view.bounds.size.width - 32.0)));
    UIView* card = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, 164.0)];
    card.center = CGPointMake(
        root.view.bounds.origin.x + root.view.bounds.size.width * 0.5,
        root.view.bounds.origin.y + root.view.bounds.size.height * 0.5);
    card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin
        | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin
        | UIViewAutoresizingFlexibleBottomMargin;
    card.backgroundColor = [UIColor colorWithRed:0.035 green:0.09 blue:0.11 alpha:0.98];
    card.layer.cornerRadius = 12.0;
    card.layer.borderWidth = 1.2;
    card.layer.borderColor =
        [UIColor colorWithRed:1.0 green:0.35 blue:0.40 alpha:0.95].CGColor;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 14.0, width - 32.0, 24.0)];
    title.text = @"Server Host V2 diagnostics";
    title.textColor = [UIColor colorWithRed:0.72 green:0.96 blue:1.0 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:16.0];
    [card addSubview:title];

    UILabel* message = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 44.0, width - 32.0, 62.0)];
    message.text = [NSString stringWithFormat:
        @"The Metal/ImGui panel could not present.\nFailed stage: %@", boundedStage];
    message.textColor = UIColor.whiteColor;
    message.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    message.numberOfLines = 3;
    [card addSubview:message];

    UIButton* close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 96.0, 116.0, 80.0, 34.0);
    [close setTitle:@"Close" forState:UIControlStateNormal];
    close.tintColor = [UIColor colorWithRed:0.45 green:1.0 blue:1.0 alpha:1.0];
    close.layer.cornerRadius = 6.0;
    close.layer.borderWidth = 1.0;
    close.layer.borderColor =
        [UIColor colorWithRed:0.13 green:0.85 blue:0.86 alpha:0.60].CGColor;
    [close addTarget:self action:@selector(closePresentation)
      forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:close];

    self.fallbackView = card;
    [root.view addSubview:card];
    [self bringPresentationToFrontForRoot:root];
}

- (void)closePresentation
{
    if (!_presentation->RequestClose())
        return;
    ++self.openRequestGeneration;
    [self.overlay stopAndHide];
    [self.fallbackView removeFromSuperview];
    self.fallbackView = nil;
    if (_presentation->CompleteClose()) {
        [self setButtonOpen:NO failed:NO animated:YES];
        LogUI(LogSeverity::Info, "close completed; Metal rendering stopped");
    }
}

- (void)dragButton:(UIPanGestureRecognizer*)recognizer
{
    UIView* parent = self.floatingButton.superview;
    if (!parent)
        return;

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.dragStartCenter = self.floatingButton.center;
        self.dragDetected = NO;
    }
    const CGPoint translation = [recognizer translationInView:parent];
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (!self.dragDetected
            && std::hypot(translation.x, translation.y) >= kDragThreshold) {
            self.dragDetected = YES;
        }
        if (self.dragDetected) {
            self.floatingButton.center = CGPointMake(
                self.dragStartCenter.x + translation.x,
                self.dragStartCenter.y + translation.y);
            [self clampFloatingButtonInside:parent];
        }
    }
    if (recognizer.state == UIGestureRecognizerStateEnded
        || recognizer.state == UIGestureRecognizerStateCancelled
        || recognizer.state == UIGestureRecognizerStateFailed) {
        if (self.dragDetected) {
            self.suppressTapUntil = CACurrentMediaTime()
                + kPostDragTapSuppressionInterval;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         static_cast<int64_t>(
                                             kPostDragTapSuppressionInterval
                                             * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (CACurrentMediaTime() >= self.suppressTapUntil)
                    self.dragDetected = NO;
            });
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)otherGestureRecognizer
{
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return YES;
}

@end

namespace serverhost::v2::ui {

void RequestDiagnosticUIBootstrap() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SHV2DiagnosticUIBootstrap sharedBootstrap] start];
    });
}

}  // namespace serverhost::v2::ui
