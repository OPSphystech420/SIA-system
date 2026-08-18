#import "OverlayView.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "../ImGui/imgui.h"
#include "../ImGui/imgui_impl_metal.h"
#include "../Menu/HostMenu.hpp"
#include "../Source/Hosting/HostingRuntime.h"

@interface ServerHostOverlayView () <MTKViewDelegate>
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation ServerHostOverlayView

static BOOL MenuVisible = NO;
static __weak ServerHostOverlayView* ActiveOverlay = nil;

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    ActiveOverlay = self;
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    ImGuiIO& IO = ImGui::GetIO();
    IO.IniFilename = nullptr;
    IO.Fonts->AddFontDefault();
    ImGui_ImplMetal_Init(_device);
    return self;
}

+ (void)setMenuVisible:(BOOL)visible
{
    MenuVisible = visible;
    ActiveOverlay.view.userInteractionEnabled = visible;
}

+ (BOOL)isMenuVisible
{
    return MenuVisible;
}

- (void)loadView
{
    MTKView* View = [[MTKView alloc] initWithFrame:UIScreen.mainScreen.bounds device:self.device];
    View.delegate = self;
    View.paused = NO;
    View.enableSetNeedsDisplay = NO;
    View.preferredFramesPerSecond = 30;
    View.opaque = NO;
    View.backgroundColor = UIColor.clearColor;
    View.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
    View.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    View.userInteractionEnabled = MenuVisible;
    self.view = View;
}

- (void)updateIOWithTouchEvent:(UIEvent*)event
{
    UITouch* Touch = event.allTouches.anyObject;
    if (!Touch)
        return;

    const CGPoint Location = [Touch locationInView:self.view];
    ImGuiIO& IO = ImGui::GetIO();
    IO.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
    IO.AddMousePosEvent(Location.x, Location.y);

    BOOL Active = NO;
    for (UITouch* Current in event.allTouches)
    {
        if (Current.phase != UITouchPhaseEnded && Current.phase != UITouchPhaseCancelled)
        {
            Active = YES;
            break;
        }
    }
    IO.AddMouseButtonEvent(0, Active);
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)drawInMTKView:(MTKView*)view
{
    ServerHost::HostingRuntime::Get().Tick();

    MTLRenderPassDescriptor* Descriptor = view.currentRenderPassDescriptor;
    id<CAMetalDrawable> Drawable = view.currentDrawable;
    if (!Descriptor || !Drawable)
        return;

    ImGuiIO& IO = ImGui::GetIO();
    IO.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    const CGFloat Scale = view.window.screen.nativeScale ?: UIScreen.mainScreen.nativeScale;
    IO.DisplayFramebufferScale = ImVec2(Scale, Scale);
    IO.DeltaTime = 1.0f / static_cast<float>(view.preferredFramesPerSecond ?: 30);

    id<MTLCommandBuffer> CommandBuffer = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> Encoder =
        [CommandBuffer renderCommandEncoderWithDescriptor:Descriptor];

    ImGui_ImplMetal_NewFrame(Descriptor);
    ImGui::NewFrame();
    if (MenuVisible)
        ServerHost::Menu::Render();
    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), CommandBuffer, Encoder);

    [Encoder endEncoding];
    [CommandBuffer presentDrawable:Drawable];
    [CommandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
}

@end
