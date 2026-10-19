// Developer taps for testing without a person at the Simulator (like ninjago-recomp's NJ_TAPS).
//
// Inactive unless the environment variable YODA_TAPS is set (simctl: SIMCTL_CHILD_YODA_TAPS). Format:
//   "T:x,y;T:x,y>x2,y2@D;..."   T seconds after the app became active, x/y fractions of the game view
//   (0,0 = top left), ">x2,y2@D" makes it a drag lasting D seconds.
// Touches go through the same engine entry points UnityView uses (UnitySendTouches*). The engine reads
// view, phase, timestamp, locationInView:, previousLocationInView: and tapCount from each touch and the
// touch set from -[UIEvent allTouches], so small stand-in objects are enough.
#import <UIKit/UIKit.h>

extern "C" void UnitySendTouchesBegin(NSSet* touches, UIEvent* event);
extern "C" void UnitySendTouchesMoved(NSSet* touches, UIEvent* event);
extern "C" void UnitySendTouchesEnded(NSSet* touches, UIEvent* event);
extern "C" UIView* UnityGetGLView();

@interface YodaFakeTouch : NSObject
@property (nonatomic) CGPoint loc;
@property (nonatomic) CGPoint prev;
@property (nonatomic) UITouchPhase phase;
@property (nonatomic) NSTimeInterval timestamp;
@property (nonatomic) NSUInteger tapCount;
@property (nonatomic, weak) UIView* view;
@end

@implementation YodaFakeTouch
- (CGPoint)locationInView:(UIView*)v			{ return self.loc; }
- (CGPoint)previousLocationInView:(UIView*)v	{ return self.prev; }
@end

@interface YodaFakeEvent : NSObject
@property (nonatomic, strong) NSSet* touches;
@end

@implementation YodaFakeEvent
- (NSSet*)allTouches { return self.touches; }
@end

@interface YodaDevTaps : NSObject
@end

@implementation YodaDevTaps

static void Send(YodaFakeTouch* t, UITouchPhase phase, CGPoint p)
{
    t.prev = t.loc;
    t.loc = p;
    t.phase = phase;
    t.timestamp = [NSProcessInfo processInfo].systemUptime;
    NSSet* set = [NSSet setWithObject:t];
    YodaFakeEvent* ev = [YodaFakeEvent new];
    ev.touches = set;
    if (phase == UITouchPhaseBegan)			UnitySendTouchesBegin(set, (UIEvent*)ev);
    else if (phase == UITouchPhaseMoved)	UnitySendTouchesMoved(set, (UIEvent*)ev);
    else									UnitySendTouchesEnded(set, (UIEvent*)ev);
}

static CGPoint ToView(CGPoint frac)
{
    CGSize s = UnityGetGLView().bounds.size;
    return CGPointMake(frac.x * s.width, frac.y * s.height);
}

static void Schedule(double at, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

+ (void)runScript:(NSString*)script
{
    for (NSString* item in [script componentsSeparatedByString:@";"])
    {
        NSArray* tp = [item componentsSeparatedByString:@":"];
        if (tp.count != 2) continue;
        double t = [tp[0] doubleValue];
        NSString* rest = tp[1];
        double dur = 0.08;
        NSArray* durSplit = [rest componentsSeparatedByString:@"@"];
        if (durSplit.count == 2) { dur = [durSplit[1] doubleValue]; rest = durSplit[0]; }
        NSArray* ends = [rest componentsSeparatedByString:@">"];
        NSArray* a = [ends[0] componentsSeparatedByString:@","];
        NSArray* b = [ends.lastObject componentsSeparatedByString:@","];
        if (a.count != 2 || b.count != 2) continue;
        CGPoint p0 = CGPointMake([a[0] doubleValue], [a[1] doubleValue]);
        CGPoint p1 = CGPointMake([b[0] doubleValue], [b[1] doubleValue]);

        YodaFakeTouch* touch = [YodaFakeTouch new];
        touch.tapCount = 1;
        Schedule(t, ^{
            touch.view = UnityGetGLView();
            CGPoint p = ToView(p0);
            touch.loc = p;
            NSLog(@"[yoda] dev tap at %.2f,%.2f (%.0f,%.0f)", p0.x, p0.y, p.x, p.y);
            // would a real touch at this point reach Unity's view through UIKit hit-testing?
            UIView* gl = UnityGetGLView();
            UIView* hit = [gl.window hitTest:[gl convertPoint:p toView:gl.window] withEvent:nil];
            NSLog(@"[yoda] hit-test -> %@, reaches Unity view: %s", NSStringFromClass([hit class]),
                  (hit == gl || [hit isDescendantOfView:gl]) ? "yes" : "NO");
            Send(touch, UITouchPhaseBegan, p);
        });
        const int steps = ends.count > 1 ? 10 : 0;
        for (int i = 1; i <= steps; ++i)
        {
            double f = (double)i / steps;
            Schedule(t + dur * f * 0.95, ^{
                Send(touch, UITouchPhaseMoved, ToView(CGPointMake(p0.x + (p1.x - p0.x) * f, p0.y + (p1.y - p0.y) * f)));
            });
        }
        Schedule(t + dur, ^{ Send(touch, UITouchPhaseEnded, ToView(p1)); });
    }
}

+ (void)load
{
    NSString* script = [NSProcessInfo processInfo].environment[@"YODA_TAPS"];
    if (script.length == 0)
        return;
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* n) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            NSLog(@"[yoda] dev tap script: %@", script);
            [YodaDevTaps runScript:script];
        }];
}

@end
