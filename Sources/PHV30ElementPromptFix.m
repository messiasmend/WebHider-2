#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
- (void)showSelectionPrompt;
@end

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
@property(nonatomic,assign) BOOL selectionModeActive;
@end

static void (*PH30OriginalShowSelectedWebElement)(id, SEL, NSString *);
static void (*PH30OriginalRender)(id, SEL, BOOL);
static BOOL PH30Installed = NO;

static BOOL PH30SelectionModeActive(void) {
    id manager = [NSClassFromString(@"PHOverlayManager") respondsToSelector:@selector(sharedManager)]
        ? [NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)]
        : nil;
    if (!manager) return NO;
    @try { return [[manager valueForKey:@"selectionModeActive"] boolValue]; }
    @catch (__unused NSException *e) { return NO; }
}

static void PH30ShowSelectedWebElement(id self, SEL _cmd, NSString *details) {
    // While the inspector is still in selection mode, ignore any stale
    // render/selection callback. A real user selection turns this flag off
    // before calling showSelectedWebElement:.
    if (PH30SelectionModeActive()) return;

    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    NSString *payload = details ?: @"";

    // Preserve the exact selected-element payload before any asynchronous
    // renderer can rebuild the Element page.
    vc.currentDetails = payload;
    vc.currentSubtitle = @"Elemento Web selecionado";

    if (PH30OriginalShowSelectedWebElement) {
        PH30OriginalShowSelectedWebElement(self, _cmd, payload);
    }

    // The base UI renders asynchronously. Re-assert the payload after that
    // render so the Element prompt cannot be left empty by a stale render.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH30SelectionModeActive()) return;
        vc.currentDetails = payload;
        vc.currentSubtitle = @"Elemento Web selecionado";

        dispatch_async(dispatch_get_main_queue(), ^{
            if (PH30SelectionModeActive()) return;
            vc.currentDetails = payload;
            vc.currentSubtitle = @"Elemento Web selecionado";
            [vc render:NO];
        });
    });
}

static void PH30Render(id self, SEL _cmd, BOOL hierarchyMode) {
    // This is the important startup guard: while the overlay is waiting for
    // the user to tap an element, no late render is allowed to replace the
    // selection prompt with the Element screen.
    if (PH30SelectionModeActive()) {
        return;
    }
    if (PH30OriginalRender) {
        PH30OriginalRender(self, _cmd, hierarchyMode);
    }
}

__attribute__((constructor)) static void PH30Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH30Installed) return;

        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method selected = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        Method render = class_getInstanceMethod(c, @selector(render:));
        if (!selected || !render) return;

        IMP currentSelected = method_getImplementation(selected);
        IMP currentRender = method_getImplementation(render);
        if (!currentSelected || !currentRender) return;

        PH30OriginalShowSelectedWebElement = (void *)currentSelected;
        PH30OriginalRender = (void *)currentRender;

        method_setImplementation(selected, (IMP)PH30ShowSelectedWebElement);
        method_setImplementation(render, (IMP)PH30Render);
        PH30Installed = YES;
    });
}
