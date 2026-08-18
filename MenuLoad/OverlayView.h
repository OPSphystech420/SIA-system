#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ServerHostOverlayView : UIViewController

+ (void)setMenuVisible:(BOOL)visible;
+ (BOOL)isMenuVisible;
- (void)updateIOWithTouchEvent:(UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
