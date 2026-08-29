#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)showSelectionPrompt;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
@end

static void (*PH30OriginalShowSelectionPrompt)(id, SEL);
static void (*PH30OriginalShowInspectorDetails)(id, SEL, NSString *, NSString *);
static void (*PH30OriginalShowSelectedWebElement)(id, SEL, NSString *);
static BOOL PH30Installed = NO;
static BOOL PH30WaitingForSelection = NO;

static void PH30ShowSelectionPrompt(id self, SEL _cmd) {
    // This is the authoritative transition into the selection state.
    PH30WaitingForSelection = YES;
    if (PH30OriginalShowSelectionPrompt) PH30OriginalShowSelectionPrompt(self, _cmd);
}

static void PH30ShowInspectorDetails(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    // showInspectorDetails: is also used by the startup/bootstrap path.
    // Its payload can contain HTML/Rect, so payload shape must NOT decide
    // whether a real element was selected. Stay on the selection prompt
    // until showSelectedWebElement: is actually called by the selection flow.
    if (PH30WaitingForSelection) {
        if (PH30OriginalShowSelectionPrompt) PH30OriginalShowSelectionPrompt(self, @selector(showSelectionPrompt));
        return;
    }
    if (PH30OriginalShowInspectorDetails) PH30OriginalShowInspectorDetails(self, _cmd, details, subtitle);
}

static void PH30ShowSelectedWebElement(id self, SEL _cmd, NSString *details) {
    // This is the real transition from selection mode to Element.
    PH30WaitingForSelection = NO;
    if (PH30OriginalShowSelectedWebElement) PH30OriginalShowSelectedWebElement(self, _cmd, details ?: @"");
}

__attribute__((constructor)) static void PH30Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH30Installed) return;
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method prompt = class_getInstanceMethod(c, @selector(showSelectionPrompt));
        Method inspector = class_getInstanceMethod(c, @selector(showInspectorDetails:subtitle:));
        Method selected = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        if (!prompt || !inspector || !selected) return;

        PH30OriginalShowSelectionPrompt = (void *)method_getImplementation(prompt);
        PH30OriginalShowInspectorDetails = (void *)method_getImplementation(inspector);
        PH30OriginalShowSelectedWebElement = (void *)method_getImplementation(selected);

        method_setImplementation(prompt, (IMP)PH30ShowSelectionPrompt);
        method_setImplementation(inspector, (IMP)PH30ShowInspectorDetails);
        method_setImplementation(selected, (IMP)PH30ShowSelectedWebElement);
        PH30Installed = YES;
    });
}
