#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
@end

static const void *kPH239SelectedDetails = &kPH239SelectedDetails;

static NSString *PH239GetDetails(id obj) {
    return objc_getAssociatedObject(obj, kPH239SelectedDetails);
}

static void PH239SetDetails(id obj, NSString *details) {
    objc_setAssociatedObject(obj, kPH239SelectedDetails, details ?: @"", OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static UIButton *PH239FindButton(UIView *root, NSString *title) {
    if (!root) return nil;
    if ([root isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)root;
        NSString *current = [button titleForState:UIControlStateNormal] ?: @"";
        if ([current isEqualToString:title]) return button;
    }
    for (UIView *child in [root.subviews copy]) {
        UIButton *found = PH239FindButton(child, title);
        if (found) return found;
    }
    return nil;
}

static void PH239AlignActionButtons(UIViewController *vc) {
    UIButton *copy = PH239FindButton(vc.view, @"Copiar");
    UIButton *hidden = PH239FindButton(vc.view, @"Ocultos");
    UIButton *hide = PH239FindButton(vc.view, @"Ocultar");

    for (UIButton *button in @[copy ?: [UIButton new], hidden ?: [UIButton new], hide ?: [UIButton new]]) {
        if (!button.superview) continue;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
        button.imageEdgeInsets = UIEdgeInsetsZero;
        button.titleLabel.textAlignment = NSTextAlignmentLeft;
        button.titleLabel.numberOfLines = 1;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.78;
    }
}

static void (*PH239OrigShowSelectedWeb)(id, SEL, NSString *);
static void PH239ShowSelectedWeb(id self, SEL _cmd, NSString *details) {
    PH239SetDetails(self, details);
    if (PH239OrigShowSelectedWeb) PH239OrigShowSelectedWeb(self, _cmd, details);
}

static void (*PH239OrigRender)(id, SEL, BOOL);
static void PH239Render(id self, SEL _cmd, BOOL hierarchyMode) {
    NSString *savedDetails = PH239GetDetails(self);
    NSString *subtitle = nil;
    @try { subtitle = [self valueForKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}

    // When returning from the DOM tree, PHV234 temporarily restores a generated
    // HTML snippet. Prefer the complete details captured at selection time.
    if (!hierarchyMode && savedDetails.length && [subtitle isEqualToString:@"Elemento Web selecionado"]) {
        @try { [self setValue:savedDetails forKey:@"currentDetails"]; } @catch (__unused NSException *e) {}
    }

    if (PH239OrigRender) PH239OrigRender(self, _cmd, hierarchyMode);
    dispatch_async(dispatch_get_main_queue(), ^{
        PH239AlignActionButtons((UIViewController *)self);
    });
}

__attribute__((constructor)) static void PH239Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;

        Method show = class_getInstanceMethod(cls, @selector(showSelectedWebElement:));
        if (show) {
            PH239OrigShowSelectedWeb = (void *)method_getImplementation(show);
            method_setImplementation(show, (IMP)PH239ShowSelectedWeb);
        }

        Method render = class_getInstanceMethod(cls, @selector(render:));
        if (render) {
            PH239OrigRender = (void *)method_getImplementation(render);
            method_setImplementation(render, (IMP)PH239Render);
        }
    });
}
