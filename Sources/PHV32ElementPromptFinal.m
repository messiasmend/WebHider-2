#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/* WebHider 3.1 — final Element prompt fix.
 * This runs after the existing GUI swizzles and owns the selected-element
 * presentation. It intentionally does not change layout or button styling.
 */

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)render:(BOOL)hierarchyMode;
@end

static void PH32InstallHook(void);
static void (*PH32PreviousShow)(id, SEL, NSString *, NSString *);
static BOOL PH32Installed = NO;

static void PH32ShowInspectorDetails(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    NSString *payload = details ?: @"";
    NSString *sub = subtitle.length ? subtitle : @"Elemento Web selecionado";

    /* The selection callback is the Element screen. Never switch to DOM here. */
    vc.currentDetails = payload;
    vc.currentSubtitle = sub;
    vc.showingHierarchy = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        vc.currentDetails = payload;
        vc.currentSubtitle = sub;
        vc.showingHierarchy = NO;
        [vc render:NO];
    });
}

static void PH32InstallHook(void) {
    if (PH32Installed) return;
    Class c = NSClassFromString(@"PHInspectorViewController");
    if (!c) return;

    Method m = class_getInstanceMethod(c, @selector(showInspectorDetails:subtitle:));
    if (!m) return;

    IMP current = method_getImplementation(m);
    if (!current || current == (IMP)PH32ShowInspectorDetails) {
        PH32Installed = YES;
        return;
    }

    PH32PreviousShow = (void *)current;
    method_setImplementation(m, (IMP)PH32ShowInspectorDetails);
    PH32Installed = YES;
}

__attribute__((constructor)) static void PH32Constructor(void) {
    /* Existing 2.3.x/3.0/3.1 constructors install their hooks on the main
       queue. Delay this final hook so it wraps the final implementation. */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PH32InstallHook();
    });
}
