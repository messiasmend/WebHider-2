#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Sources/PHThreeFingerGesture.h"
#import "Sources/PHOverlayManager.h"

static PHThreeFingerGesture *PHGestureDetector(void) {
    static PHThreeFingerGesture *detector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ detector = [PHThreeFingerGesture new]; });
    return detector;
}

static void (*PHOriginalUIApplicationSendEvent)(id, SEL, UIEvent *);
static void (*PHOriginalUIWindowSendEvent)(id, SEL, UIEvent *);

static void PHProcessInspectionEvent(UIEvent *event) {
    if (event == nil) return;
    [[PHOverlayManager sharedManager] processInspectionEvent:event];
}

static void PHProcessGestureEvent(UIEvent *event) {
    if (event == nil) return;
    [PHGestureDetector() processEvent:event];
}

static void PHUIApplicationSendEvent(id self, SEL _cmd, UIEvent *event) {
    PHProcessInspectionEvent(event);
    if (PHOriginalUIApplicationSendEvent != NULL) PHOriginalUIApplicationSendEvent(self, _cmd, event);
    PHProcessGestureEvent(event);
}

static void PHUIWindowSendEvent(id self, SEL _cmd, UIEvent *event) {
    PHProcessInspectionEvent(event);
    if (PHOriginalUIWindowSendEvent != NULL) PHOriginalUIWindowSendEvent(self, _cmd, event);
    PHProcessGestureEvent(event);
}

static BOOL PHInstallHook(Class cls, SEL selector, IMP replacement, void (**originalStorage)(id, SEL, UIEvent *)) {
    if (cls == Nil) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL) return NO;
    IMP original = method_getImplementation(method);
    if (original == NULL || original == replacement) return NO;
    *originalStorage = (void (*)(id, SEL, UIEvent *))original;
    method_setImplementation(method, replacement);
    return YES;
}

static void PHInstallSendEventHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selector = @selector(sendEvent:);
        Class applicationClass = objc_getClass("UIApplication");
        Class windowClass = objc_getClass("UIWindow");
        PHInstallHook(applicationClass, selector, (IMP)PHUIApplicationSendEvent, &PHOriginalUIApplicationSendEvent);
        PHInstallHook(windowClass, selector, (IMP)PHUIWindowSendEvent, &PHOriginalUIWindowSendEvent);
    });
}

/* WebHider 2.3.7 — compact GUI + selected-element code restoration. */
static const void *PH237AdjustedKey = &PH237AdjustedKey;
static const void *PH237CodeKey = &PH237CodeKey;
static void (*PH237OriginalSelected)(id, SEL, NSString *);
static void (*PH237OriginalRender)(id, SEL, BOOL);

static UIButton *PH237FindButton(UIView *root, NSString *title) {
    if (!root) return nil;
    if ([root isKindOfClass:UIButton.class]) {
        UIButton *b = (UIButton *)root;
        if ([[b titleForState:UIControlStateNormal] ?: @"" isEqualToString:title]) return b;
    }
    for (UIView *child in [root.subviews copy]) {
        UIButton *found = PH237FindButton(child, title);
        if (found) return found;
    }
    return nil;
}

static UIView *PH237Panel(UIViewController *vc) {
    for (UIView *v in [vc.view.subviews copy]) {
        if (![v isKindOfClass:UIButton.class]) return v;
    }
    return nil;
}

static void PH237Shrink(UIView *view) {
    if (!view || objc_getAssociatedObject(view, PH237AdjustedKey)) return;
    BOOL changed = NO;
    for (NSLayoutConstraint *c in [view.constraints copy]) {
        BOOL isHeight = c.firstAttribute == NSLayoutAttributeHeight || c.secondAttribute == NSLayoutAttributeHeight;
        BOOL owns = c.firstItem == view || c.secondItem == view;
        if (isHeight && owns && c.constant > 40.0 && c.constant < 65.0) {
            c.constant *= 0.80; // 20% additional reduction after the previous 10%
            changed = YES;
        }
    }
    if (changed) objc_setAssociatedObject(view, PH237AdjustedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PH237Left(UIButton *b) {
    if (!b) return;
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    b.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
    b.titleEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 0);
    b.imageEdgeInsets = UIEdgeInsetsZero;
    b.titleLabel.textAlignment = NSTextAlignmentLeft;
    b.titleLabel.numberOfLines = 1;
}

static void PH237Fit(UIButton *b) {
    if (!b) return;
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.80;
    b.titleLabel.numberOfLines = 1;
}

static NSString *PH237Value(NSString *details, NSString *key) {
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *prefix = [key stringByAppendingString:@":"];
        if ([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static NSString *PH237ElementCode(NSString *details) {
    NSString *html = PH237Value(details ?: @"", @"HTML");
    NSString *tag = @"div";
    NSRange open = [html rangeOfString:@"<"];
    NSRange close = open.location != NSNotFound ? [html rangeOfString:@">" options:0 range:NSMakeRange(open.location, html.length - open.location)] : NSMakeRange(NSNotFound, 0);
    if (open.location != NSNotFound && close.location != NSNotFound && close.location > open.location) {
        NSString *inside = [html substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
        NSArray *parts = [inside componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (parts.count && [parts[0] length]) tag = parts[0];
    }
    NSMutableString *attrs = [NSMutableString string];
    NSString *identifier = PH237Value(details, @"ID");
    NSString *classes = PH237Value(details, @"Classe");
    NSString *type = PH237Value(details, @"Tipo");
    NSString *href = PH237Value(details, @"Link");
    if (identifier.length) [attrs appendFormat:@" id=\"%@\"", identifier];
    if (classes.length) [attrs appendFormat:@" class=\"%@\"", classes];
    if (type.length && ![type isEqualToString:tag]) [attrs appendFormat:@" type=\"%@\"", type];
    if (href.length) [attrs appendFormat:@" href=\"%@\"", href];
    NSString *text = PH237Value(details, @"Texto");
    if (text.length) return [NSString stringWithFormat:@"<%@%@>\n    %@\n</%@>", tag, attrs, text, tag];
    return [NSString stringWithFormat:@"<%@%@></%@>", tag, attrs, tag];
}

static void PH237CompactGUI(UIViewController *vc) {
    UIView *panel = PH237Panel(vc);
    if (!panel) return;
    UIButton *copy = PH237FindButton(panel, @"Copiar");
    UIButton *hidden = PH237FindButton(panel, @"Ocultos");
    UIButton *hide = PH237FindButton(panel, @"Ocultar");
    UIButton *json = PH237FindButton(panel, @"JSON");
    UIButton *left = PH237FindButton(panel, @"Elemento");
    if (!left) left = PH237FindButton(panel, @"Voltar");
    if (!left) left = PH237FindButton(panel, @"Hierarquia");
    UIButton *close = PH237FindButton(panel, @"Fechar");
    UIButton *save = PH237FindButton(panel, @"Salvar");

    PH237Shrink(copy.superview);
    PH237Shrink(hidden.superview);
    PH237Shrink(hide.superview);
    if (json) PH237Shrink(json.superview);

    PH237Left(copy);
    PH237Left(hidden);
    PH237Left(hide);
    PH237Fit(copy);
    PH237Fit(hidden);
    PH237Fit(hide);
    PH237Fit(json);
    PH237Fit(left);
    PH237Fit(close);
    PH237Fit(save);

    if (left && [[left titleForState:UIControlStateNormal] isEqualToString:@"Elemento"]) {
        PH237Left(left);
    }

    // A GUI é encurtada para acompanhar a redução dos controles.
    for (NSLayoutConstraint *c in [panel.superview.constraints copy]) {
        if (c.firstItem == panel && c.firstAttribute == NSLayoutAttributeBottom && c.constant > -80.0) c.constant = -38.0;
    }
    [panel.superview setNeedsLayout];
    [panel.superview layoutIfNeeded];
}

static void PH237SetElementCode(id self, NSString *details) {
    NSString *code = PH237ElementCode(details ?: @"");
    if (!code.length) code = details ?: @"";
    objc_setAssociatedObject(self, PH237CodeKey, code, OBJC_ASSOCIATION_COPY_NONATOMIC);
    @try {
        [self setValue:code forKey:@"currentDetails"];
        [self setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"];
        [self setValue:@NO forKey:@"showingHierarchy"];
    } @catch (__unused NSException *e) {}
}

static void PH237Selected(id self, SEL _cmd, NSString *details) {
    if (PH237OriginalSelected) PH237OriginalSelected(self, _cmd, details);
    PH237SetElementCode(self, details);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { [self setValue:@NO forKey:@"showingHierarchy"]; } @catch (__unused NSException *e) {}
        if (PH237OriginalRender) PH237OriginalRender(self, @selector(render:), NO);
        PH237CompactGUI((UIViewController *)self);
    });
}

static void PH237Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PH237OriginalRender) PH237OriginalRender(self, _cmd, hierarchyMode);
    dispatch_async(dispatch_get_main_queue(), ^{
        PH237CompactGUI((UIViewController *)self);
        dispatch_async(dispatch_get_main_queue(), ^{ PH237CompactGUI((UIViewController *)self); });
    });
}

static void PH237InstallInspectorHooks(void) {
    Class c = NSClassFromString(@"PHInspectorViewController");
    if (!c) return;
    Method m = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
    if (m) {
        IMP current = method_getImplementation(m);
        if (current != (IMP)PH237Selected) {
            PH237OriginalSelected = (void *)current;
            method_setImplementation(m, (IMP)PH237Selected);
        }
    }
    m = class_getInstanceMethod(c, @selector(render:));
    if (m) {
        IMP current = method_getImplementation(m);
        if (current != (IMP)PH237Render) {
            PH237OriginalRender = (void *)current;
            method_setImplementation(m, (IMP)PH237Render);
        }
    }
}

%ctor {
    @autoreleasepool {
        PHGestureDetector();
        [PHOverlayManager sharedManager];
        dispatch_async(dispatch_get_main_queue(), ^{
            PHInstallSendEventHooks();
            PH237InstallInspectorHooks();
        });
    }
}
