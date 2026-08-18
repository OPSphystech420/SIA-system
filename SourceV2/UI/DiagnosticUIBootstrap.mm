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

#include <algorithm>
#include <memory>
#include <string>

constexpr NSInteger kMaximumWindowRetries = 20;
constexpr NSTimeInterval kWindowRetryInterval = 0.25;

@interface SHV2PassThroughMTKView : MTKView
@property(nonatomic, assign) BOOL menuOpen;
@property(nonatomic, assign) CGRect touchableRect;
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

@interface SHV2DiagnosticOverlayController : UIViewController <MTKViewDelegate>
@property(nonatomic, strong) id<MTLDevice> metalDevice;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, assign, getter=isMenuVisible) BOOL menuVisible;
@property(nonatomic, assign) BOOL suspendedForBackground;
- (SHV2PassThroughMTKView*)metalView;
- (void)setMenuVisible:(BOOL)visible;
- (void)updateIOWithTouchEvent:(UIEvent*)event;
@end

@implementation SHV2DiagnosticOverlayController

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;

    _metalDevice = MTLCreateSystemDefaultDevice();
    _commandQueue = [_metalDevice newCommandQueue];
    if (!_metalDevice || !_commandQueue)
        return nil;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    io.Fonts->AddFontDefault();
    if (!ImGui_ImplMetal_Init(_metalDevice))
        return nil;
    return self;
}

- (void)dealloc
{
    if (ImGui::GetCurrentContext()) {
        ImGui_ImplMetal_Shutdown();
        ImGui::DestroyContext();
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
    view.backgroundColor = UIColor.clearColor;
    view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.menuOpen = NO;
    view.touchableRect = CGRectMake(0.0, 0.0, 0.0, 0.0);
    self.view = view;
}

- (SHV2PassThroughMTKView*)metalView
{
    return (SHV2PassThroughMTKView*)self.view;
}

- (void)setMenuVisible:(BOOL)visible
{
    _menuVisible = visible;
    SHV2PassThroughMTKView* view = self.metalView;
    view.menuOpen = visible;
    view.hidden = !visible;
    const BOOL shouldRender = visible && !self.suspendedForBackground;
    view.enableSetNeedsDisplay = !shouldRender;
    view.paused = !shouldRender;
    if (shouldRender)
        [view setNeedsDisplay];
}

- (void)setSuspendedForBackground:(BOOL)suspendedForBackground
{
    _suspendedForBackground = suspendedForBackground;
    [self setMenuVisible:self.menuVisible];
}

- (void)updateIOWithTouchEvent:(UIEvent*)event
{
    UITouch* touch = event.allTouches.anyObject;
    if (!touch)
        return;

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

- (void)drawInMTKView:(MTKView*)view
{
    if (!self.menuVisible)
        return;

    const std::shared_ptr<const serverhost::v2::diagnostics::DiagnosticSnapshot> snapshot =
        serverhost::v2::diagnostics::CaptureDiagnosticSnapshot();
    const serverhost::v2::ui::DiagnosticPresentationModel model(*snapshot);

    MTLRenderPassDescriptor* descriptor = view.currentRenderPassDescriptor;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!descriptor || !drawable)
        return;

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    const CGFloat windowScale = view.window.screen.nativeScale;
    const CGFloat scale = windowScale != 0.0 ? windowScale : UIScreen.mainScreen.nativeScale;
    io.DisplayFramebufferScale = ImVec2(scale, scale);
    const NSInteger framesPerSecond = view.preferredFramesPerSecond != 0
        ? view.preferredFramesPerSecond
        : 30;
    io.DeltaTime = 1.0f / static_cast<float>(framesPerSecond);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    if (!commandBuffer || !encoder)
        return;

    ImGui_ImplMetal_NewFrame(descriptor);
    ImGui::NewFrame();

    const float horizontalMargin = 20.0f;
    const float width = std::max(280.0f, std::min(560.0f,
        static_cast<float>(view.bounds.size.width) - horizontalMargin * 2.0f));
    ImGui::SetNextWindowPos(ImVec2(horizontalMargin, 82.0f), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(width, 410.0f), ImGuiCond_FirstUseEver);

    bool copyRequested = false;
    bool closeRequested = false;
    if (ImGui::Begin("Server Host V2 Diagnostics", nullptr,
                     ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings)) {
        if (ImGui::BeginTabBar("DiagnosticTabs")) {
            if (ImGui::BeginTabItem("Status")) {
                for (const serverhost::v2::ui::DiagnosticStatusRow& row : model.StatusRows()) {
                    ImGui::TextUnformatted(row.label.c_str());
                    ImGui::SameLine(145.0f);
                    ImGui::TextWrapped("%s", row.value.c_str());
                }
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Logs")) {
                ImGui::Text("Retained %zu / %zu; dropped %llu",
                            model.Logs().entries.size(), model.Logs().capacity,
                            static_cast<unsigned long long>(model.Logs().dropped));
                ImGui::BeginChild("DiagnosticLogs", ImVec2(0.0f, 280.0f), true);
                for (const serverhost::v2::diagnostics::LogEntry& entry : model.Logs().entries) {
                    ImVec4 color = ImGui::GetStyleColorVec4(ImGuiCol_Text);
                    if (entry.severity == serverhost::v2::diagnostics::LogSeverity::Warning)
                        color = ImVec4(1.0f, 0.74f, 0.25f, 1.0f);
                    else if (entry.severity == serverhost::v2::diagnostics::LogSeverity::Error)
                        color = ImVec4(1.0f, 0.35f, 0.35f, 1.0f);
                    else if (entry.severity == serverhost::v2::diagnostics::LogSeverity::Debug)
                        color = ImVec4(0.55f, 0.72f, 1.0f, 1.0f);
                    const std::string formatted =
                        serverhost::v2::diagnostics::FormatLogEntry(entry);
                    ImGui::TextColored(color, "%s", formatted.c_str());
                }
                ImGui::EndChild();
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }

        if (ImGui::Button("Copy logs"))
            copyRequested = true;
        ImGui::SameLine();
        if (ImGui::Button("Close"))
            closeRequested = true;

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
    [commandBuffer commit];

    if (copyRequested) {
        const std::string text = model.CopyableLogs();
        NSString* value = [[NSString alloc] initWithBytes:text.data()
                                                   length:text.size()
                                                 encoding:NSUTF8StringEncoding];
        if (value)
            UIPasteboard.generalPasteboard.string = value;
    }
    if (closeRequested)
        [self setMenuVisible:NO];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
    (void)view;
    (void)size;
}

@end

@interface SHV2DiagnosticUIBootstrap : NSObject
@property(nonatomic, strong) SHV2DiagnosticOverlayController* overlay;
@property(nonatomic, strong) UIButton* floatingButton;
@property(nonatomic, strong) UIViewController* installedRoot;
@property(nonatomic, assign) NSInteger retryCount;
@property(nonatomic, assign) BOOL retryScheduled;
@property(nonatomic, assign) BOOL observersInstalled;
+ (instancetype)sharedBootstrap;
- (void)start;
- (void)lifecycleBecameUsable:(NSNotification*)notification;
- (void)applicationDidEnterBackground:(NSNotification*)notification;
- (UIWindow*)activeWindow;
- (void)scheduleBoundedRetry;
- (void)attemptInstall;
- (void)toggleMenu;
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

- (void)start
{
    NSAssert(NSThread.isMainThread, @"diagnostic UI bootstrap must run on main thread");
    if (!self.observersInstalled) {
        self.observersInstalled = YES;
        NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIApplicationDidFinishLaunchingNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UIApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UISceneWillConnectNotification object:nil];
        [center addObserver:self selector:@selector(lifecycleBecameUsable:)
                       name:UISceneDidActivateNotification object:nil];
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
    UIWindow* fallback = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;
        UIWindowScene* windowScene = (UIWindowScene*)scene;
        for (UIWindow* window in windowScene.windows) {
            if (window.hidden || window.alpha == 0.0)
                continue;
            if (!fallback || scene.activationState == UISceneActivationStateForegroundActive)
                fallback = window;
            if (window.isKeyWindow)
                return window;
        }
    }
    return fallback;
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

- (void)attemptInstall
{
    UIWindow* window = [self activeWindow];
    UIViewController* root = window.rootViewController;
    if (!window || !root) {
        [self scheduleBoundedRetry];
        return;
    }

    if (self.installedRoot == root && self.floatingButton.superview) {
        [self.floatingButton.superview bringSubviewToFront:self.floatingButton];
        return;
    }

    if (self.overlay.parentViewController) {
        [self.overlay willMoveToParentViewController:nil];
        [self.overlay.view removeFromSuperview];
        [self.overlay removeFromParentViewController];
    }
    [self.floatingButton removeFromSuperview];

    if (!self.overlay)
        self.overlay = [SHV2DiagnosticOverlayController new];
    if (self.overlay) {
        [root addChildViewController:self.overlay];
        self.overlay.view.frame = root.view.bounds;
        self.overlay.view.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [root.view addSubview:self.overlay.view];
        [self.overlay didMoveToParentViewController:root];
        [self.overlay setMenuVisible:NO];
    }

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(20.0, 110.0, 58.0, 58.0);
    self.floatingButton.backgroundColor =
        [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.94];
    self.floatingButton.tintColor = UIColor.whiteColor;
    self.floatingButton.layer.cornerRadius = 18.0;
    self.floatingButton.layer.borderWidth = 1.0;
    self.floatingButton.layer.borderColor =
        [UIColor colorWithRed:0.20 green:0.65 blue:1.0 alpha:1.0].CGColor;
    UIImage* icon = [UIImage systemImageNamed:@"stethoscope"];
    if (icon)
        [self.floatingButton setImage:icon forState:UIControlStateNormal];
    else
        [self.floatingButton setTitle:@"V2" forState:UIControlStateNormal];
    self.floatingButton.accessibilityLabel = @"Server Host V2 diagnostics";
    [self.floatingButton addTarget:self action:@selector(toggleMenu)
                  forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer* pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragButton:)];
    [self.floatingButton addGestureRecognizer:pan];
    [root.view addSubview:self.floatingButton];

    self.installedRoot = root;
    self.retryCount = 0;
    serverhost::v2::diagnostics::ProcessLogger().Add(
        serverhost::v2::diagnostics::LogSeverity::Info,
        serverhost::v2::diagnostics::LogCategory::UI,
        "diagnostic UI installed; floating button visible");
}

- (void)toggleMenu
{
    if (!self.overlay) {
        serverhost::v2::diagnostics::ProcessLogger().Add(
            serverhost::v2::diagnostics::LogSeverity::Error,
            serverhost::v2::diagnostics::LogCategory::UI,
            "Metal diagnostic overlay unavailable");
        return;
    }
    [self.overlay setMenuVisible:!self.overlay.menuVisible];
    [self.floatingButton.superview bringSubviewToFront:self.floatingButton];
}

- (void)dragButton:(UIPanGestureRecognizer*)recognizer
{
    UIView* parent = self.floatingButton.superview;
    if (!parent)
        return;
    const CGPoint translation = [recognizer translationInView:parent];
    CGPoint center = self.floatingButton.center;
    center.x += translation.x;
    center.y += translation.y;

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
    [recognizer setTranslation:CGPointMake(0.0, 0.0) inView:parent];
}

@end

namespace serverhost::v2::ui {

void RequestDiagnosticUIBootstrap() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SHV2DiagnosticUIBootstrap sharedBootstrap] start];
    });
}

}  // namespace serverhost::v2::ui
