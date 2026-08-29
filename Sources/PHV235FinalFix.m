#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)render:(BOOL)hierarchyMode;
- (void)hierarchyTapped;
- (void)backTapped;
@end

static const void *kPH235OriginalDetails = &kPH235OriginalDetails;
static const void *kPH235InElement = &kPH235InElement;

static NSString *PH235Get(id obj, const void *key) {
    return objc_getAssociatedObject(obj, key);
}

static void PH235Set(id obj, const void *key, NSString *value) {
    objc_setAssociatedObject(obj, key, value, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static BOOL PH235InElement(id obj) {
    return [objc_getAssociatedObject(obj, kPH235InElement) boolValue];
}

static void PH235SetElement(id obj, BOOL value) {
    objc_setAssociatedObject(obj, kPH235InElement, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *PH235Value(NSString *details, NSString *key) {
    NSString *prefix = [key stringByAppendingString:@":"];
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *s = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([s hasPrefix:prefix]) {
            return [[s substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        }
    }
    return @"";
}

static NSString *PH235ElementCode(NSString *details) {
    NSString *html = PH235Value(details ?: @"", @"HTML");
    NSString *tag = @"div";
    NSRange open = [html rangeOfString:@"<"];
    if (open.location != NSNotFound) {
        NSRange close = [html rangeOfString:@">" options:0 range:NSMakeRange(open.location, html.length - open.location)];
        if (close.location != NSNotFound && close.location > open.location) {
            NSString *inside = [html substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
            NSArray *parts = [inside componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (parts.count && [parts[0] length]) tag = parts[0];
        }
    }

    NSMutableString *attrs = [NSMutableString string];
    NSString *identifier = PH235Value(details, @"ID");
    NSString *classes = PH235Value(details, @"Classes");
    if (!classes.length) classes = PH235Value(details, @"Classe");
    NSString *type = PH235Value(details, @"Tipo");
    NSString *href = PH235Value(details, @"Link");
    if (identifier.length) [attrs appendFormat:@" id=\"%@\"", identifier];
    if (classes.length) [attrs appendFormat:@" class=\"%@\"", classes];
    if (type.length && ![type isEqualToString:tag]) [attrs appendFormat:@" type=\"%@\"", type];
    if (href.length) [attrs appendFormat:@" href=\"%@\"", href];

    NSString *text = PH235Value(details, @"Texto");
    if (text.length) return [NSString stringWithFormat:@"<%@%@>\n    %@\n</%@>", tag, attrs, text, tag];
    return [NSString stringWithFormat:@"<%@%@></%@>", tag, attrs, tag];
}

static void (*PH235OrigRender)(id, SEL, BOOL);
static void (*PH235OrigHierarchy)(id, SEL);

static void PH235AlignButton(UIButton *button) {
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 42);
}

static void PH235Walk(UIView *view, BOOL inElement, BOOL jsonScreen, UIViewController *vc) {
    for (UIView *sub in view.subviews.copy) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)sub;
            NSString *title = [button titleForState:UIControlStateNormal] ?: @"";

            if ([title isEqualToString:@"Copiar"] ||
                [title isEqualToString:@"Ocultos"] ||
                [title isEqualToString:@"Ocultar"] ||
                [title isEqualToString:@"Elemento"] ||
                [title isEqualToString:@"Voltar"] ||
                [title isEqualToString:@"Hierarquia"]) {
                PH235AlignButton(button);
            }

            if (!jsonScreen &&
                ([title isEqualToString:@"Elemento"] ||
                 [title isEqualToString:@"Voltar"] ||
                 [title isEqualToString:@"Hierarquia"])) {
                NSString *wantedTitle = inElement ? @"Voltar" : @"Elemento";
                SEL wantedAction = inElement ? @selector(backTapped) : @selector(hierarchyTapped);
                [button setTitle:wantedTitle forState:UIControlStateNormal];
                [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
                [button addTarget:vc action:wantedAction forControlEvents:UIControlEventTouchUpInside];
            }
        }
        PH235Walk(sub, inElement, jsonScreen, vc);
    }
}

static void PH235Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (PH235OrigRender) PH235OrigRender(self, _cmd, hierarchyMode);
    dispatch_async(dispatch_get_main_queue(), ^{
        PHInspectorViewController *vc = (PHInspectorViewController *)self;
        BOOL inElement = PH235InElement(self);
        BOOL jsonScreen = [vc.currentSubtitle isEqualToString:@"Filtro JSON"];
        PH235Walk(vc.view, inElement, jsonScreen, vc);

        if (inElement) {
            for (UIView *sub in vc.view.subviews.copy) {
                for (UIView *nested in sub.subviews.copy) {
                    if ([nested isKindOfClass:[UILabel class]]) {
                        UILabel *label = (UILabel *)nested;
                        if ([label.text isEqualToString:@"Hierarquia DOM"]) {
                            label.text = @"Elemento Web selecionado";
                        }
                    }
                }
            }
        }
    });
}

static void PH235Hierarchy(id self, SEL _cmd) {
    PHInspectorViewController *vc = (PHInspectorViewController *)self;

    if (PH235InElement(self)) {
        PH235SetElement(self, NO);
        NSString *original = PH235Get(self, kPH235OriginalDetails);
        if (original.length) vc.currentDetails = original;
        vc.currentSubtitle = @"Hierarquia DOM";
        if (PH235OrigHierarchy) PH235OrigHierarchy(self, _cmd);
        if (PH235OrigRender) PH235OrigRender(self, @selector(render:), YES);
        return;
    }

    NSString *original = vc.currentDetails ?: @"";
    PH235Set(self, kPH235OriginalDetails, original);
    NSString *code = PH235ElementCode(original);
    vc.currentDetails = code;
    vc.currentSubtitle = @"Elemento Web selecionado";
    PH235SetElement(self, YES);

    if (PH235OrigRender) PH235OrigRender(self, @selector(render:), NO);
}

__attribute__((constructor)) static void PH235Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method m = class_getInstanceMethod(c, @selector(render:));
        if (m) {
            PH235OrigRender = (void *)method_getImplementation(m);
            if (PH235OrigRender != (void *)PH235Render) method_setImplementation(m, (IMP)PH235Render);
        }

        m = class_getInstanceMethod(c, @selector(hierarchyTapped));
        if (m) {
            PH235OrigHierarchy = (void *)method_getImplementation(m);
            if (PH235OrigHierarchy != (void *)PH235Hierarchy) method_setImplementation(m, (IMP)PH235Hierarchy);
        }
    });
}
