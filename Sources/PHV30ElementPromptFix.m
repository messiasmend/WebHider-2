#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,assign) BOOL selectionMode;
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)showSelectionPrompt;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
@end

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)selectionModeActive;
@end

static void (*PH30OriginalShowSelectedWebElement)(id, SEL, NSString *);
static void (*PH30OriginalRender)(id, SEL, BOOL);
static BOOL PH30Installed = NO;

static BOOL PH30SelectionModeActive(void) {
    Class managerClass = NSClassFromString(@"PHOverlayManager");
    if (!managerClass || ![managerClass respondsToSelector:@selector(sharedManager)]) return NO;
    id manager = [managerClass performSelector:@selector(sharedManager)];
    if (!manager) return NO;
    @try { return [(PHOverlayManager *)manager selectionModeActive]; }
    @catch (__unused NSException *e) { return NO; }
}

static void PH30ShowSelectedWebElement(id self, SEL _cmd, NSString *details) {
    // Never turn the startup selection screen into an Element screen.
    // A genuine tap clears selectionModeActive before this callback arrives.
    if (PH30SelectionModeActive()) return;

    PHInspectorViewController *vc=(PHInspectorViewController *)self;
    NSString *payload=details?:@"";
    vc.currentDetails=payload;
    vc.currentSubtitle=@"Elemento Web selecionado";
    if(PH30OriginalShowSelectedWebElement) PH30OriginalShowSelectedWebElement(self,_cmd,payload);
    dispatch_async(dispatch_get_main_queue(),^{
        if(PH30SelectionModeActive()) return;
        vc.currentDetails=payload;
        vc.currentSubtitle=@"Elemento Web selecionado";
        dispatch_async(dispatch_get_main_queue(),^{
            if(PH30SelectionModeActive()) return;
            vc.currentDetails=payload;
            vc.currentSubtitle=@"Elemento Web selecionado";
            [vc render:NO];
        });
    });
}

static void PH30Render(id self, SEL _cmd, BOOL hierarchyMode) {
    PHInspectorViewController *vc=(PHInspectorViewController *)self;

    // PHV233FinalUI replaces the original renderer. Its renderer otherwise
    // defaults an empty subtitle to "Elemento Web selecionado", which makes
    // the Element screen appear at startup. At startup we must explicitly
    // restore the native selection prompt instead of allowing that renderer.
    if(PH30SelectionModeActive() || vc.selectionMode){
        [vc showSelectionPrompt];
        return;
    }

    if(PH30OriginalRender) PH30OriginalRender(self,_cmd,hierarchyMode);
}

__attribute__((constructor)) static void PH30Install(void){
    dispatch_async(dispatch_get_main_queue(),^{
        if(PH30Installed) return;
        Class c=NSClassFromString(@"PHInspectorViewController");
        if(!c) return;

        Method selected=class_getInstanceMethod(c,@selector(showSelectedWebElement:));
        Method render=class_getInstanceMethod(c,@selector(render:));
        if(!selected||!render) return;

        IMP currentSelected=method_getImplementation(selected);
        IMP currentRender=method_getImplementation(render);
        if(!currentSelected||!currentRender) return;

        PH30OriginalShowSelectedWebElement=(void *)currentSelected;
        PH30OriginalRender=(void *)currentRender;
        method_setImplementation(selected,(IMP)PH30ShowSelectedWebElement);
        method_setImplementation(render,(IMP)PH30Render);
        PH30Installed=YES;
    });
}
