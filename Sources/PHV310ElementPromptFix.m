#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@end

static const void *kPH310Details = &kPH310Details;
static void (*PH310OriginalShowSelected)(id, SEL, NSString *);
static void (*PH310OriginalRender)(id, SEL, BOOL);

static void PH310SetDetails(id self, NSString *details) {
    NSString *value = details ?: @"";
    objc_setAssociatedObject(self, kPH310Details, value, OBJC_ASSOCIATION_COPY_NONATOMIC);
    @try { [(PHInspectorViewController *)self setCurrentDetails:value]; } @catch (__unused NSException *e) {}
    @try { [(PHInspectorViewController *)self setCurrentSubtitle:@"Elemento Web selecionado"]; } @catch (__unused NSException *e) {}
}

static void PH310ShowSelected(id self, SEL _cmd, NSString *details) {
    PH310SetDetails(self, details);
    if (PH310OriginalShowSelected) PH310OriginalShowSelected(self, _cmd, details);
    PH310SetDetails(self, details);
    dispatch_async(dispatch_get_main_queue(), ^{
        PH310SetDetails(self, details);
        if (PH310OriginalRender) PH310OriginalRender(self, @selector(render:), NO);
    });
}

static void PH310Render(id self, SEL _cmd, BOOL hierarchyMode) {
    NSString *saved = objc_getAssociatedObject(self, kPH310Details);
    if (!hierarchyMode && saved.length) PH310SetDetails(self, saved);
    if (PH310OriginalRender) PH310OriginalRender(self, _cmd, hierarchyMode);
}

__attribute__((constructor)) static void PH310Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;
        Method show = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        if (show) {
            IMP current = method_getImplementation(show);
            if (current != (IMP)PH310ShowSelected) {
                PH310OriginalShowSelected = (void *)current;
                method_setImplementation(show, (IMP)PH310ShowSelected);
            }
        }
        Method render = class_getInstanceMethod(c, @selector(render:));
        if (render) {
            IMP current = method_getImplementation(render);
            if (current != (IMP)PH310Render) {
                PH310OriginalRender = (void *)current;
                method_setImplementation(render, (IMP)PH310Render);
            }
        }
    });
}
