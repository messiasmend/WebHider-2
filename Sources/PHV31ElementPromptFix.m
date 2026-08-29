#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/* WebHider 3.1 — fixes the Element prompt payload only.
 * Base: branch 3.0. No GUI/layout changes.
 *
 * Root cause: PHV234ElementFlow's showInspectorDetails:subtitle: hook
 * schedules a hierarchy render after the real element-selection callback.
 * That late render replaces the selected element details with the DOM tree.
 *
 * This hook preserves the exact details passed to the inspector and
 * reasserts Element mode after the existing 3.0 hook chain has completed.
 */

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)render:(BOOL)hierarchyMode;
@end

static void (*PH31OriginalShowInspectorDetails)(id, SEL, NSString *, NSString *);
static BOOL PH31Installed = NO;

static void PH31RestoreElementPrompt(id self, NSString *details, NSString *subtitle) {
    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    vc.currentDetails = details ?: @"";
    vc.currentSubtitle = subtitle.length ? subtitle : @"Elemento Web selecionado";
    vc.showingHierarchy = NO;
    [vc render:NO];
}

static void PH31ShowInspectorDetails(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    NSString *payload = details ?: @"";
    NSString *sub = subtitle.length ? subtitle : @"Elemento Web selecionado";

    /* Preserve the exact payload before entering the existing 3.0 chain. */
    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    vc.currentDetails = payload;
    vc.currentSubtitle = sub;
    vc.showingHierarchy = NO;

    if (PH31OriginalShowInspectorDetails) {
        PH31OriginalShowInspectorDetails(self, _cmd, payload, sub);
    }

    /*
     * 3.0's PHV234 hook schedules its hierarchy render asynchronously.
     * Two main-queue turns put this final Element render after that queued
     * hierarchy update, regardless of which constructor installed first.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            PH31RestoreElementPrompt(self, payload, sub);
        });
    });
}

__attribute__((constructor)) static void PH31Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH31Installed) return;

        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method m = class_getInstanceMethod(c, @selector(showInspectorDetails:subtitle:));
        if (!m) return;

        IMP current = method_getImplementation(m);
        if (!current || current == (IMP)PH31ShowInspectorDetails) return;

        PH31OriginalShowInspectorDetails = (void *)current;
        method_setImplementation(m, (IMP)PH31ShowInspectorDetails);
        PH31Installed = YES;
    });
}
