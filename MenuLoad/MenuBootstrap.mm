#import "OverlayView.h"

#import <UIKit/UIKit.h>

@interface ServerHostMenuBootstrap : NSObject
@property(nonatomic, strong) ServerHostOverlayView* overlay;
@property(nonatomic, strong) UIButton* floatingButton;
@end

@implementation ServerHostMenuBootstrap

static ServerHostMenuBootstrap* SharedBootstrap = nil;

+ (UIWindow*)activeWindow
{
    UIWindow* Fallback = nil;
    for (UIScene* Scene in UIApplication.sharedApplication.connectedScenes)
    {
        if (![Scene isKindOfClass:UIWindowScene.class])
            continue;

        UIWindowScene* WindowScene = (UIWindowScene*)Scene;
        for (UIWindow* Window in WindowScene.windows)
        {
            if (!Fallback)
                Fallback = Window;
            if (Window.isKeyWindow)
                return Window;
        }
    }
    return Fallback;
}

+ (void)load
{
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            SharedBootstrap = [ServerHostMenuBootstrap new];
            [SharedBootstrap install];
        });
    });
}

- (void)install
{
    if (self.overlay)
        return;

    UIWindow* Window = [ServerHostMenuBootstrap activeWindow];
    UIViewController* Root = Window.rootViewController;
    if (!Window || !Root)
    {
        // Some launches do not have a key scene two seconds after +load.
        // Retry instead of silently losing the only way to control the host.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            [self install];
        });
        return;
    }

    self.overlay = [ServerHostOverlayView new];
    [Root addChildViewController:self.overlay];
    self.overlay.view.frame = Root.view.bounds;
    self.overlay.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [Root.view addSubview:self.overlay.view];
    [self.overlay didMoveToParentViewController:Root];
    [ServerHostOverlayView setMenuVisible:NO];

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(20.0, 110.0, 58.0, 58.0);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:0.92];
    self.floatingButton.tintColor = UIColor.whiteColor;
    self.floatingButton.layer.cornerRadius = 18.0;
    self.floatingButton.layer.borderWidth = 1.0;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.20 green:0.65 blue:1.0 alpha:1.0].CGColor;

    UIImage* Icon = [UIImage systemImageNamed:@"server.rack"];
    if (Icon)
        [self.floatingButton setImage:Icon forState:UIControlStateNormal];
    else
        [self.floatingButton setTitle:@"HOST" forState:UIControlStateNormal];

    [self.floatingButton addTarget:self action:@selector(toggleMenu)
                  forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer* Pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(dragButton:)];
    [self.floatingButton addGestureRecognizer:Pan];
    [Root.view addSubview:self.floatingButton];
}

- (void)toggleMenu
{
    const BOOL Visible = ![ServerHostOverlayView isMenuVisible];
    [ServerHostOverlayView setMenuVisible:Visible];
    [self.floatingButton.superview bringSubviewToFront:self.floatingButton];
}

- (void)dragButton:(UIPanGestureRecognizer*)recognizer
{
    UIView* Parent = self.floatingButton.superview;
    if (!Parent)
        return;

    const CGPoint Translation = [recognizer translationInView:Parent];
    CGPoint Center = self.floatingButton.center;
    Center.x += Translation.x;
    Center.y += Translation.y;

    const CGFloat HalfWidth = CGRectGetWidth(self.floatingButton.bounds) * 0.5;
    const CGFloat HalfHeight = CGRectGetHeight(self.floatingButton.bounds) * 0.5;
    Center.x = MAX(HalfWidth, MIN(CGRectGetWidth(Parent.bounds) - HalfWidth, Center.x));
    Center.y = MAX(HalfHeight, MIN(CGRectGetHeight(Parent.bounds) - HalfHeight, Center.y));
    self.floatingButton.center = Center;
    [recognizer setTranslation:CGPointZero inView:Parent];
}

@end
