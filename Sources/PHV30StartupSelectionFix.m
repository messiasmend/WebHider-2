#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)showSelectionPrompt;
@end

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)selectionModeActive;
@end

static void (*PH30StartupOriginal)(id, SEL, NSString *, NSString *);
static BOOL PH30StartupInstalled = NO;

static BOOL PH30StartupSelectionActive(void) {
    Class c=NSClassFromString(@"PHOverlayManager");
    if(!c || ![c respondsToSelector:@selector(sharedManager)]) return NO;
    PHOverlayManager *m=[c performSelector:@selector(sharedManager)];
    if(!m) return NO;
    @try { return [m selectionModeActive]; }
    @catch(__unused NSException *e) { return NO; }
}

static void PH30StartupShowInspector(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    // PHV234ElementFlow 3.0-6 classifies any payload containing HTML + Rect
    // as a selected element. During startup the same method can receive a
    // bootstrap payload while selectionModeActive is still YES. That payload
    // must never switch the GUI to Element mode.
    if(PH30StartupSelectionActive()) {
        dispatch_async(dispatch_get_main_queue(),^{
            if(PH30StartupSelectionActive()) {
                [(PHInspectorViewController *)self showSelectionPrompt];
            }
        });
        return;
    }

    if(PH30StartupOriginal) PH30StartupOriginal(self,_cmd,details,subtitle);
}

__attribute__((constructor)) static void PH30StartupInstall(void) {
    // Delay installation so PHV234ElementFlow's own constructor has already
    // installed its 3.0-6 showInspectorDetails hook. We then wrap that hook,
    // preserving all working Element payload behavior unchanged.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(PH30StartupInstalled) return;
        Class c=NSClassFromString(@"PHInspectorViewController");
        if(!c) return;
        Method m=class_getInstanceMethod(c,@selector(showInspectorDetails:subtitle:));
        if(!m) return;
        IMP current=method_getImplementation(m);
        if(!current) return;
        PH30StartupOriginal=(void *)current;
        method_setImplementation(m,(IMP)PH30StartupShowInspector);
        PH30StartupInstalled=YES;
    });
}
