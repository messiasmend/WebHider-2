#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)render:(BOOL)hierarchyMode;
@end

static void (*P32OrigRender)(id,SEL,BOOL);
static BOOL P32Installed=NO;

static NSString *P32Value(NSString *s, NSString *key){
    NSString *prefix=[key stringByAppendingString:@":"];
    for(NSString *line in [s componentsSeparatedByString:@"\n"]){
        if([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static NSString *P32Code(NSString *details){
    NSString *html=P32Value(details?:@"",@"HTML");
    if(html.length) return html;
    return details?:@"";
}

static UILabel *P32FindLabel(UIView *root, NSString *text){
    if([root isKindOfClass:UILabel.class] && [((UILabel *)root).text isEqualToString:text]) return (UILabel *)root;
    for(UIView *v in root.subviews){ UILabel *r=P32FindLabel(v,text); if(r)return r; }
    return nil;
}

static void P32Render(id self,SEL _cmd,BOOL hierarchyMode){
    if(P32OrigRender) P32OrigRender(self,_cmd,hierarchyMode);
    if(hierarchyMode) return;
    dispatch_async(dispatch_get_main_queue(),^{
        PHInspectorViewController *vc=(PHInspectorViewController *)self;
        if(vc.showingHierarchy) return;
        UILabel *header=P32FindLabel(vc.view,@"Informações do elemento");
        if(!header) return;
        UIView *card=header.superview;
        NSString *code=P32Code(vc.currentDetails);
        NSMutableArray *labels=[NSMutableArray array];
        for(UIView *v in card.subviews) if([v isKindOfClass:UILabel.class] && v!=header) [labels addObject:v];
        UILabel *value=labels.lastObject;
        if(!value){
            value=[UILabel new]; value.translatesAutoresizingMaskIntoConstraints=NO; [card addSubview:value];
            [NSLayoutConstraint activateConstraints:@[[value.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],[value.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],[value.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],[value.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12]]];
        } else {
            for(UILabel *l in labels) l.hidden=YES;
            value.hidden=NO;
        }
        value.text=code;
        value.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        value.textColor=UIColor.whiteColor;
        value.textAlignment=NSTextAlignmentLeft;
        value.numberOfLines=0;
        value.lineBreakMode=NSLineBreakByCharWrapping;
        value.adjustsFontSizeToFitWidth=NO;
    });
}

__attribute__((constructor)) static void P32Install(void){
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        if(P32Installed)return;
        Class c=NSClassFromString(@"PHInspectorViewController"); if(!c)return;
        Method m=class_getInstanceMethod(c,@selector(render:)); if(!m)return;
        IMP old=method_getImplementation(m); if(!old)return;
        P32OrigRender=(void *)old; method_setImplementation(m,(IMP)P32Render); P32Installed=YES;
    });
}
