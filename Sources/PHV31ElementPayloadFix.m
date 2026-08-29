#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)render:(BOOL)hierarchyMode;
@end

static void (*PH31PreviousShowInspector)(id, SEL, NSString *, NSString *);
static void (*PH31PreviousRender)(id, SEL, BOOL);
static BOOL PH31Installed = NO;

static void PH31ShowInspector(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    NSString *payload = details ?: @"";
    if (PH31PreviousShowInspector) {
        PH31PreviousShowInspector(self, _cmd, details, subtitle);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        PHInspectorViewController *vc = (PHInspectorViewController *)self;
        vc.currentDetails = payload;
        vc.currentSubtitle = subtitle.length ? subtitle : @"Elemento Web selecionado";
        vc.showingHierarchy = NO;
        [vc render:NO];
    });
}

static void PH31Render(id self, SEL _cmd, BOOL hierarchyMode) {
    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    BOOL elementPayload = !hierarchyMode && [vc.currentDetails hasPrefix:@"HTML:"];
    if (!elementPayload) {
        if (PH31PreviousRender) PH31PreviousRender(self, _cmd, hierarchyMode);
        return;
    }

    NSString *originalSubtitle = vc.currentSubtitle;
    vc.currentSubtitle = @"Filtro JSON";
    if (PH31PreviousRender) PH31PreviousRender(self, _cmd, NO);

    dispatch_async(dispatch_get_main_queue(), ^{
        vc.currentSubtitle = originalSubtitle.length ? originalSubtitle : @"Elemento Web selecionado";
        for (UIView *view in vc.view.subviews) {
            UILabel *label = nil;
            if ([view isKindOfClass:UILabel.class]) label = (UILabel *)view;
            else {
                for (UIView *child in view.subviews) {
                    if ([child isKindOfClass:UILabel.class] && [[(UILabel *)child text] isEqualToString:@"Filtro JSON"]) {
                        label = (UILabel *)child;
                        break;
                    }
                }
            }
            if (label && [label.text isEqualToString:@"Filtro JSON"]) {
                label.text = vc.currentSubtitle;
            }
        }
    });
}

__attribute__((constructor)) static void PH31Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH31Installed) return;
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method show = class_getInstanceMethod(c, @selector(showInspectorDetails:subtitle:));
        if (show) {
            IMP current = method_getImplementation(show);
            if (current && current != (IMP)PH31ShowInspector) {
                PH31PreviousShowInspector = (void *)current;
                method_setImplementation(show, (IMP)PH31ShowInspector);
            }
        }

        Method render = class_getInstanceMethod(c, @selector(render:));
        if (render) {
            IMP current = method_getImplementation(render);
            if (current && current != (IMP)PH31Render) {
                PH31PreviousRender = (void *)current;
                method_setImplementation(render, (IMP)PH31Render);
            }
        }

        PH31Installed = YES;
    });
}
