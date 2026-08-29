#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)render:(BOOL)hierarchyMode;
@end

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)selectionModeActive;
@end

static void (*PH30OriginalShowSelectedWebElement)(id, SEL, NSString *);
static void (*PH30OriginalShowInspectorDetails)(id, SEL, NSString *, NSString *);
static void (*PH30OriginalRender)(id, SEL, BOOL);
static BOOL PH30Installed = NO;

static BOOL PH30SelectionModeActive(void) {
    Class managerClass = NSClassFromString(@"PHOverlayManager");
    if (!managerClass || ![managerClass respondsToSelector:@selector(sharedManager)]) return NO;

    id manager = [managerClass performSelector:@selector(sharedManager)];
    if (!manager) return NO;

    // Use the real property getter, not KVC. This is the exact state owned by
    // PHOverlayManager while the inspector is waiting for a user selection.
    @try {
        return [(PHOverlayManager *)manager selectionModeActive];
    } @catch (__unused NSException *e) {
        return NO;
    }
}

static void PH30ShowSelectedWebElement(id self, SEL _cmd, NSString *details) {
    // A selection callback can arrive immediately after the inspector window
    // is created. While selection mode is active this is stale startup state,
    // not a real user selection. Do not let it replace the selection prompt.
    if (PH30SelectionModeActive()) return;

    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    NSString *payload = details ?: @"";
    vc.currentDetails = payload;
    vc.currentSubtitle = @"Elemento Web selecionado";

    if (PH30OriginalShowSelectedWebElement) {
        PH30OriginalShowSelectedWebElement(self, _cmd, payload);
    }

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

static void PH30ShowInspectorDetails(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    // PHV234ElementFlow also routes element details through this method.
    // Guard that path as well, otherwise showSelectedWebElement alone is not
    // sufficient to prevent the startup screen from being replaced.
    if (PH30SelectionModeActive()) return;

    if (PH30OriginalShowInspectorDetails) {
        PH30OriginalShowInspectorDetails(self, _cmd, details ?: @"", subtitle ?: @"Elemento Web selecionado");
    }
}

static void PH30Render(id self, SEL _cmd, BOOL hierarchyMode) {
    // Do not allow a late render to replace the selection prompt while the
    // overlay is waiting for the user to tap an element.
    if (PH30SelectionModeActive()) return;
    if (PH30OriginalRender) PH30OriginalRender(self, _cmd, hierarchyMode);
}

__attribute__((constructor)) static void PH30Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH30Installed) return;

        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method selected = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        Method inspector = class_getInstanceMethod(c, @selector(showInspectorDetails:subtitle:));
        Method render = class_getInstanceMethod(c, @selector(render:));
        if (!selected || !inspector || !render) return;

        IMP currentSelected = method_getImplementation(selected);
        IMP currentInspector = method_getImplementation(inspector);
        IMP currentRender = method_getImplementation(render);
        if (!currentSelected || !currentInspector || !currentRender) return;

        PH30OriginalShowSelectedWebElement = (void *)currentSelected;
        PH30OriginalShowInspectorDetails = (void *)currentInspector;
        PH30OriginalRender = (void *)currentRender;

        method_setImplementation(selected, (IMP)PH30ShowSelectedWebElement);
        method_setImplementation(inspector, (IMP)PH30ShowInspectorDetails);
        method_setImplementation(render, (IMP)PH30Render);
        PH30Installed = YES;
    });
}
