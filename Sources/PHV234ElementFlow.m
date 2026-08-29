#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
- (void)backTapped;
- (void)hierarchyTapped;
@end

static const void *kPH234SelectedCode = &kPH234SelectedCode;
static const void *kPH234SelectedSubtitle = &kPH234SelectedSubtitle;
static const void *kPH234InTree = &kPH234InTree;

static NSString *PH234Get(id obj, const void *key) { return objc_getAssociatedObject(obj,key); }
static void PH234Set(id obj, const void *key, NSString *value) { objc_setAssociatedObject(obj,key,value,OBJC_ASSOCIATION_COPY_NONATOMIC); }
static BOOL PH234Tree(id obj) { return [objc_getAssociatedObject(obj,kPH234InTree) boolValue]; }
static void PH234SetTree(id obj, BOOL value) { objc_setAssociatedObject(obj,kPH234InTree,@(value),OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

static NSString *PH234Value(NSString *details, NSString *key) {
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *prefix = [key stringByAppendingString:@":"];
        if ([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static NSString *PH234ElementCode(NSString *details) {
    NSString *html = PH234Value(details,@"HTML");
    NSString *tag = @"div";
    NSRange open = [html rangeOfString:@"<"];
    NSRange close = (open.location != NSNotFound) ? [html rangeOfString:@">" options:0 range:NSMakeRange(open.location,html.length-open.location)] : NSMakeRange(NSNotFound,0);
    if (open.location != NSNotFound && close.location != NSNotFound && close.location > open.location) {
        NSString *inside = [html substringWithRange:NSMakeRange(open.location+1,close.location-open.location-1)];
        NSArray *parts = [inside componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (parts.count && [parts[0] length]) tag = parts[0];
    }
    NSMutableString *attrs=[NSMutableString string];
    NSString *identifier=PH234Value(details,@"ID");
    NSString *classes=PH234Value(details,@"Classe");
    NSString *type=PH234Value(details,@"Tipo");
    NSString *href=PH234Value(details,@"Link");
    if(identifier.length)[attrs appendFormat:@" id=\"%@\"",identifier];
    if(classes.length)[attrs appendFormat:@" class=\"%@\"",classes];
    if(type.length && ![type isEqualToString:tag])[attrs appendFormat:@" type=\"%@\"",type];
    if(href.length)[attrs appendFormat:@" href=\"%@\"",href];
    NSString *text=PH234Value(details,@"Texto");
    if(text.length) return [NSString stringWithFormat:@"<%@%@>\n    %@\n</%@>",tag,attrs,text,tag];
    return [NSString stringWithFormat:@"<%@%@></%@>",tag,attrs,tag];
}

static void (*PH234OrigShowInspector)(id,SEL,NSString*,NSString*);
static void (*PH234OrigShowSelectedWeb)(id,SEL,NSString*);
static void (*PH234OrigRender)(id,SEL,BOOL);
static void (*PH234OrigBack)(id,SEL);
static void (*PH234OrigHierarchy)(id,SEL);

static void PH234ShowInspector(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    PH234Set(self,kPH234SelectedCode,PH234ElementCode(details ?: @""));
    PH234Set(self,kPH234SelectedSubtitle,subtitle ?: @"Elemento Web selecionado");
    if(PH234OrigShowInspector) PH234OrigShowInspector(self,_cmd,details,subtitle);
    dispatch_async(dispatch_get_main_queue(),^{
        id manager=[NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
        if([manager respondsToSelector:@selector(showHierarchy)]) [manager performSelector:@selector(showHierarchy)];
        PH234SetTree(self,YES);
    });
}

static void PH234ShowSelectedWeb(id self, SEL _cmd, NSString *details) {
    PH234Set(self,kPH234SelectedCode,PH234ElementCode(details ?: @""));
    if(PH234OrigShowSelectedWeb) PH234OrigShowSelectedWeb(self,_cmd,details);
}

static void PH234Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if(PH234OrigRender) PH234OrigRender(self,_cmd,hierarchyMode);
    dispatch_async(dispatch_get_main_queue(),^{
        PHInspectorViewController *vc=(PHInspectorViewController *)self;
        BOOL tree=PH234Tree(self);
        for(UIView *v in vc.view.subviews) {
            for(UIView *sub in v.subviews) {
                if(![sub isKindOfClass:[UIButton class]]) continue;
                UIButton *b=(UIButton *)sub;
                NSString *title=[b titleForState:UIControlStateNormal];
                if([title isEqualToString:@"Hierarquia"] || [title isEqualToString:@"Voltar"]) [b setTitle:(tree?@"Elemento":@"Voltar") forState:UIControlStateNormal];
            }
        }
    });
}

static void PH234Back(id self, SEL _cmd) {
    PHInspectorViewController *vc=(PHInspectorViewController *)self;
    if(PH234Tree(self)) {
        vc.currentDetails=PH234Get(self,kPH234SelectedCode) ?: @"";
        vc.currentSubtitle=PH234Get(self,kPH234SelectedSubtitle) ?: @"Elemento Web selecionado";
        vc.showingHierarchy=NO;
        PH234SetTree(self,NO);
        if(PH234OrigRender) PH234OrigRender(self,@selector(render:),NO);
        return;
    }
    id manager=[NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
    if([manager respondsToSelector:@selector(showHierarchy)]) [manager performSelector:@selector(showHierarchy)];
    PH234SetTree(self,YES);
}

static void PH234Hierarchy(id self, SEL _cmd) {
    id manager=[NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
    if([manager respondsToSelector:@selector(showHierarchy)]) [manager performSelector:@selector(showHierarchy)];
    PH234SetTree(self,YES);
}

__attribute__((constructor)) static void PH234Install(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        Class c=NSClassFromString(@"PHInspectorViewController");
        if(!c)return;
        Method m;
        m=class_getInstanceMethod(c,@selector(showInspectorDetails:subtitle:)); if(m){PH234OrigShowInspector=(void*)method_getImplementation(m); method_setImplementation(m,(IMP)PH234ShowInspector);}
        m=class_getInstanceMethod(c,@selector(showSelectedWebElement:)); if(m){PH234OrigShowSelectedWeb=(void*)method_getImplementation(m); method_setImplementation(m,(IMP)PH234ShowSelectedWeb);}
        m=class_getInstanceMethod(c,@selector(render:)); if(m){PH234OrigRender=(void*)method_getImplementation(m); method_setImplementation(m,(IMP)PH234Render);}
        m=class_getInstanceMethod(c,@selector(backTapped)); if(m){PH234OrigBack=(void*)method_getImplementation(m); method_setImplementation(m,(IMP)PH234Back);}
        m=class_getInstanceMethod(c,@selector(hierarchyTapped)); if(m){PH234OrigHierarchy=(void*)method_getImplementation(m); method_setImplementation(m,(IMP)PH234Hierarchy);}
    });
}
