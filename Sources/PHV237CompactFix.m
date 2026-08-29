#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/* WebHider 2.3.7 — compact GUI + selected-element content fix. */

static const void *kPH237Adjusted = &kPH237Adjusted;
static const void *kPH237SelectedCode = &kPH237SelectedCode;

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

static void PH237ShrinkViewHeight(UIView *container) {
    if (!container || objc_getAssociatedObject(container, kPH237Adjusted)) return;
    BOOL changed = NO;
    for (NSLayoutConstraint *c in [container.constraints copy]) {
        BOOL height = (c.firstAttribute == NSLayoutAttributeHeight || c.secondAttribute == NSLayoutAttributeHeight);
        BOOL owns = (c.firstItem == container || c.secondItem == container);
        if (height && owns && c.constant > 40.0 && c.constant < 65.0) {
            c.constant = c.constant * 0.80;
            changed = YES;
        }
    }
    if (changed) objc_setAssociatedObject(container, kPH237Adjusted, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PH237AlignLeft(UIButton *button) {
    if (!button) return;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 0);
    button.imageEdgeInsets = UIEdgeInsetsZero;
    button.titleLabel.textAlignment = NSTextAlignmentLeft;
    button.titleLabel.numberOfLines = 1;
}

static void PH237Fit(UIButton *button) {
    if (!button) return;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.80;
    button.titleLabel.numberOfLines = 1;
}

static NSString *PH237Value(NSString *details, NSString *key) {
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *prefix = [key stringByAppendingString:@":"];
        if ([line hasPrefix:prefix]) {
            return [[line substringFromIndex:prefix.length]
                    stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        }
    }
    return @"";
}

static NSString *PH237ElementCode(NSString *details) {
    NSString *html = PH237Value(details ?: @"", @"HTML");
    NSString *tag = @"div";
    NSRange open = [html rangeOfString:@"<"];
    NSRange close = (open.location != NSNotFound)
        ? [html rangeOfString:@">" options:0 range:NSMakeRange(open.location, html.length - open.location)]
        : NSMakeRange(NSNotFound, 0);
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

    // A versão anterior já havia reduzido 10%. Este passo reduz mais 20%.
    // Resultado acumulado: 58 -> 52.2 -> 41.76 pt para os cartões de ação.
    PH237ShrinkViewHeight(copy.superview);
    PH237ShrinkViewHeight(hidden.superview);
    PH237ShrinkViewHeight(hide.superview);
    if (json) PH237ShrinkViewHeight(json.superview);

    PH237AlignLeft(copy);
    PH237AlignLeft(hidden);
    PH237AlignLeft(hide);
    PH237Fit(copy);
    PH237Fit(hidden);
    PH237Fit(hide);
    PH237Fit(json);
    PH237Fit(left);
    PH237Fit(close);
    PH237Fit(save);

    if (left && [[left titleForState:UIControlStateNormal] isEqualToString:@"Elemento"]) {
        left.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        left.contentEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 18);
        left.titleEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 0);
    }

    // Reduz a altura global da GUI para acompanhar os novos controles.
    // O conteúdo permanece intacto; somente a margem inferior é aumentada.
    for (NSLayoutConstraint *c in [panel.superview.constraints copy]) {
        if (c.firstItem == panel && c.firstAttribute == NSLayoutAttributeBottom && c.constant > -80.0) {
            c.constant = -38.0;
        }
    }

    [panel.superview setNeedsLayout];
    [panel.superview layoutIfNeeded];
}

static void PH237SetElementContent(id self, NSString *details) {
    NSString *code = PH237ElementCode(details ?: @"");
    if (!code.length) code = details ?: @"";
    objc_setAssociatedObject(self, kPH237SelectedCode, code, OBJC_ASSOCIATION_COPY_NONATOMIC);

    @try {
        [self setValue:code forKey:@"currentDetails"];
        [self setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"];
        [self setValue:@NO forKey:@"showingHierarchy"];
    } @catch (__unused NSException *e) {}
}

static void (*PH237OrigSelected)(id, SEL, NSString *);
static void (*PH237OrigRender)(id, SEL, BOOL);

static void PH237Selected(id self, SEL _cmd, NSString *details) {
    if (PH237OrigSelected) PH237OrigSelected(self, _cmd, details);
    PH237SetElementContent(self, details);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { [self setValue:@NO forKey:@"showingHierarchy"]; } @catch (__unused NSException *e) {}
        if (PH237OrigRender) PH237OrigRender(self, @selector(render:), NO);
        PH237CompactGUI((UIViewController *)self);
    });
}

static void PH237Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PH237OrigRender) PH237OrigRender(self, _cmd, hierarchyMode);
    dispatch_async(dispatch_get_main_queue(), ^{
        PH237CompactGUI((UIViewController *)self);
        dispatch_async(dispatch_get_main_queue(), ^{
            PH237CompactGUI((UIViewController *)self);
        });
    });
}

__attribute__((constructor)) static void PH237Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method m = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        if (m) {
            IMP current = method_getImplementation(m);
            if (current != (IMP)PH237Selected) {
                PH237OrigSelected = (void *)current;
                method_setImplementation(m, (IMP)PH237Selected);
            }
        }

        m = class_getInstanceMethod(c, @selector(render:));
        if (m) {
            IMP current = method_getImplementation(m);
            if (current != (IMP)PH237Render) {
                PH237OrigRender = (void *)current;
                method_setImplementation(m, (IMP)PH237Render);
            }
        }
    });
}
