#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)render:(BOOL)hierarchyMode;
- (void)backTapped;
@end

static NSString *P2310V(NSString *d, NSString *k) {
    for (NSString *l in [d componentsSeparatedByString:@"\n"]) {
        NSString *p = [k stringByAppendingString:@":"];
        if ([l hasPrefix:p]) return [[l substringFromIndex:p.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static NSString *P2310Code(NSString *d) {
    NSString *h = P2310V(d ?: @"", @"HTML");
    return h.length ? h : (d ?: @"");
}

static UIButton *P2310Button(UIView *r, NSString *t) {
    if ([r isKindOfClass:UIButton.class] && [[(UIButton *)r titleForState:UIControlStateNormal] isEqualToString:t]) return (UIButton *)r;
    for (UIView *v in [r.subviews copy]) {
        UIButton *b = P2310Button(v, t);
        if (b) return b;
    }
    return nil;
}

static UITextView *P2310TextView(UIView *r) {
    if ([r isKindOfClass:UITextView.class]) return (UITextView *)r;
    for (UIView *v in [r.subviews copy]) {
        UITextView *tv = P2310TextView(v);
        if (tv) return tv;
    }
    return nil;
}

static UILabel *P2310Label(UIView *r) {
    if ([r isKindOfClass:UILabel.class]) return (UILabel *)r;
    for (UIView *v in [r.subviews copy]) {
        UILabel *l = P2310Label(v);
        if (l) return l;
    }
    return nil;
}

static void P2310AlignBack(PHInspectorViewController *vc) {
    UIButton *b = P2310Button(vc.view, @"JSON");
    if (!b) b = P2310Button(vc.view, @"Voltar");
    if (!b) return;
    [b setTitle:@"Voltar" forState:UIControlStateNormal];
    UIImage *i = [UIImage systemImageNamed:@"chevron.left"];
    if (i) [b setImage:i forState:UIControlStateNormal];
    [b removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [b addTarget:vc action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
    b.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
}

static void P2310PutElementCode(PHInspectorViewController *vc) {
    if (![vc.currentSubtitle isEqualToString:@"Elemento Web selecionado"]) return;
    NSString *code = P2310Code(vc.currentDetails ?: @"");
    if (!code.length) return;

    UITextView *tv = P2310TextView(vc.view);
    if (tv) {
        tv.text = code;
        tv.editable = NO;
        tv.scrollEnabled = YES;
        tv.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        return;
    }

    UILabel *label = P2310Label(vc.view);
    if (label) {
        label.text = code;
        label.numberOfLines = 0;
        label.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    }
}

static void P2310Refresh(PHInspectorViewController *vc) {
    if ([vc.currentSubtitle isEqualToString:@"Filtro JSON"]) P2310AlignBack(vc);
    P2310PutElementCode(vc);
}

static void (*P2310OrigS)(id, SEL, NSString *);
static void P2310S(id x, SEL cmd, NSString *d) {
    @try {
        [x setValue:(d ?: @"") forKey:@"currentDetails"];
        [x setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"];
    } @catch (__unused NSException *e) {}
    if (P2310OrigS) P2310OrigS(x, cmd, d);
    dispatch_async(dispatch_get_main_queue(), ^{ P2310Refresh((PHInspectorViewController *)x); });
}

static void (*P2310OrigR)(id, SEL, BOOL);
static void P2310R(id x, SEL cmd, BOOL hierarchyMode) {
    if (P2310OrigR) P2310OrigR(x, cmd, hierarchyMode);
    dispatch_async(dispatch_get_main_queue(), ^{ P2310Refresh((PHInspectorViewController *)x); });
}

static BOOL P2310Installed = NO;

__attribute__((constructor)) static void P2310Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (P2310Installed) return;
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;
        P2310Installed = YES;

        Method m = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        if (m) {
            P2310OrigS = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)P2310S);
        }

        m = class_getInstanceMethod(c, @selector(render:));
        if (m) {
            P2310OrigR = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)P2310R);
        }
    });
}
