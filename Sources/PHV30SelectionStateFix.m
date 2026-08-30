#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,assign) BOOL selectionMode;
- (void)showSelectionPrompt;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
@end

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)selectionModeActive;
@end

static void (*PH30OrigShowInspectorDetails)(id, SEL, NSString *, NSString *);

static BOOL PH30IsSelecting(id vc) {
    BOOL vcSelecting = NO;
    @try { vcSelecting = [(PHInspectorViewController *)vc selectionMode]; }
    @catch (__unused NSException *e) {}
    BOOL managerSelecting = NO;
    Class mc = NSClassFromString(@"PHOverlayManager");
    if (mc && [mc respondsToSelector:@selector(sharedManager)]) {
        id manager = [mc performSelector:@selector(sharedManager)];
        if (manager) {
            @try { managerSelecting = [(PHOverlayManager *)manager selectionModeActive]; }
            @catch (__unused NSException *e) {}
        }
    }
    return vcSelecting || managerSelecting;
}

static void PH30ShowInspectorDetails(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    if (PH30IsSelecting(self)) {
        [(PHInspectorViewController *)self showSelectionPrompt];
        return;
    }
    if (PH30OrigShowInspectorDetails) {
        PH30OrigShowInspectorDetails(self, _cmd, details, subtitle);
    }
}

__attribute__((constructor)) static void PH30InstallSelectionStateFix(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;
        Method m = class_getInstanceMethod(c, @selector(showInspectorDetails:subtitle:));
        if (!m) return;
        IMP current = method_getImplementation(m);
        if (!current || current == (IMP)PH30ShowInspectorDetails) return;
        PH30OrigShowInspectorDetails = (void *)current;
        method_setImplementation(m, (IMP)PH30ShowInspectorDetails);
    });
}
