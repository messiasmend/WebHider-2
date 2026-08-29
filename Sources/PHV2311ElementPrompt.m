#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@end

static NSString *PH2311Value(NSString *details, NSString *key) {
    NSString *prefix=[key stringByAppendingString:@":"];
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static void PH2311SetElementPrompt(UIViewController *vc) {
    if (![vc.currentSubtitle isEqualToString:@"Elemento Web selecionado"]) return;
    NSString *html=PH2311Value(vc.currentDetails ?: @"", @"HTML");
    if (!html.length) return;

    // Only fill an existing text/code view belonging to the approved Element page.
    // Do not add views, move the DOM tree, or rebuild the GUI.
    NSMutableArray *stack=[NSMutableArray arrayWithObject:vc.view];
    while (stack.count) {
        UIView *view=stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:UITextView.class]) {
            UITextView *tv=(UITextView *)view;
            if (tv.editable==NO || tv.font.pointSize <= 14.0) {
                tv.text=html;
                return;
            }
        }
        for (UIView *sub in view.subviews) [stack addObject:sub];
    }
}

static void (*PH2311OrigShow)(id,SEL,NSString*);
static void PH2311Show(id self,SEL cmd,NSString *details) {
    PHInspectorViewController *vc=(PHInspectorViewController *)self;
    vc.currentDetails=details ?: @"";
    vc.currentSubtitle=@"Elemento Web selecionado";
    if (PH2311OrigShow) PH2311OrigShow(self,cmd,details);
    dispatch_async(dispatch_get_main_queue(),^{ PH2311SetElementPrompt(vc); });
}

static BOOL PH2311Installed=NO;
__attribute__((constructor)) static void PH2311Install(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        if(PH2311Installed)return;
        Class c=NSClassFromString(@"PHInspectorViewController");
        if(!c)return;
        Method m=class_getInstanceMethod(c,@selector(showSelectedWebElement:));
        if(!m)return;
        PH2311Installed=YES;
        PH2311OrigShow=(void *)method_getImplementation(m);
        method_setImplementation(m,(IMP)PH2311Show);
    });
}
