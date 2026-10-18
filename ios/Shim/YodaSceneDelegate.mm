// UIScene life cycle for Unity 4.6's Trampoline.
//
// Apps built with the iOS 27 SDK must use scenes. Unity's 2015 Trampoline creates its window in
// application:didFinishLaunchingWithOptions: and starts the engine from applicationDidBecomeActive:,
// which UIKit no longer calls once a scene manifest is present. This delegate attaches Unity's window to
// the scene and forwards the scene's life-cycle events to the app controller's old callbacks.
#import <UIKit/UIKit.h>

extern "C" UIWindow* UnityGetMainWindow();

@interface YodaSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow* window;
@end

@implementation YodaSceneDelegate

static void ForwardToAppController(SEL sel)
{
    UIApplication* app = [UIApplication sharedApplication];
    id controller = app.delegate;
    if ([controller respondsToSelector:sel])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [controller performSelector:sel withObject:app];
#pragma clang diagnostic pop
    }
}

- (void)scene:(UIScene*)scene willConnectToSession:(UISceneSession*)session options:(UISceneConnectionOptions*)options
{
    UIWindow* window = UnityGetMainWindow();
    if (window == nil)
    {
        NSLog(@"[yoda] no Unity window at scene connection");
        return;
    }
    window.windowScene = (UIWindowScene*)scene;
    window.frame = ((UIWindowScene*)scene).coordinateSpace.bounds;
    self.window = window;
    [window makeKeyAndVisible];
    NSLog(@"[yoda] Unity window attached to scene, %@", NSStringFromCGRect(window.bounds));
}

- (void)sceneDidBecomeActive:(UIScene*)scene      { ForwardToAppController(@selector(applicationDidBecomeActive:)); }
- (void)sceneWillResignActive:(UIScene*)scene     { ForwardToAppController(@selector(applicationWillResignActive:)); }
- (void)sceneDidEnterBackground:(UIScene*)scene   { ForwardToAppController(@selector(applicationDidEnterBackground:)); }
- (void)sceneWillEnterForeground:(UIScene*)scene  { ForwardToAppController(@selector(applicationWillEnterForeground:)); }

@end
