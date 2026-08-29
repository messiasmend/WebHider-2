#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)render:(BOOL)hierarchyMode;
- (void)backTapped;
@end

static NSString *PH2310Value(NSString *details, NSString *key) {
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *prefix=[key stringByAppendingString:@":"];
        if ([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static NSString *PH2310Code(NSString *details) {
    NSString *html=PH2310Value(details ?: @"",@"HTML");
    if(!html.length)return details ?: @"";
    NSString *tag=@"div";
    NSRange o=[html rangeOfString:@"<"], c=o.location!=NSNotFound?[html rangeOfString:@">" options:0 range:NSMakeRange(o.location,html.length-o.location)]:NSMakeRange(NSNotFound,0);
    if(o.location!=NSNotFound&&c.location!=NSNotFound){NSString *inside=[html substringWithRange:NSMakeRange(o.location+1,c.location-o.location-1)];NSArray *p=[inside componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if(p.count&&[p[0] length])tag=p[0];}
    NSMutableString *a=[NSMutableString string];
    NSString *v=PH2310Value(details,@"ID");if(v.length)[a appendFormat:@" id=\"%@\"",v];
    v=PH2310Value(details,@"Classe");if(v.length)[a appendFormat:@" class=\"%@\"",v];
    v=PH2310Value(details,@"Tipo");if(v.length&&![v isEqualToString:tag])[a appendFormat:@" type=\"%@\"",v];
    v=PH2310Value(details,@"Link");if(v.length)[a appendFormat:@" href=\"%@\"",v];
    v=PH2310Value(details,@"Texto");
    if(v.length)return[NSString stringWithFormat:@"<%@%@>\n    %@\n</%@>",tag,a,v,tag];
    return[NSString stringWithFormat:@"<%@%@></%@>",tag,a,tag];
}

static UIButton *PH2310FindButton(UIView *root, NSString *title) {
    if(!root)return nil;
    if([root isKindOfClass:UIButton.class]&&[[((UIButton *)root) titleForState:UIControlStateNormal] isEqualToString:title])return(UIButton *)root;
    for(UIView *v in [root.subviews copy]){UIButton*b=PH2310FindButton(v,title);if(b)return b;}
    return nil;
}

static UILabel *PH2310FindPromptLabel(UIView *root) {
    if(!root)return nil;
    if([root isKindOfClass:UILabel.class])return(UILabel *)root;
    for(UIView *v in [root.subviews copy]){UILabel*l=PH2310FindPromptLabel(v);if(l)return l;}
    return nil;
}

static void PH2310Refresh(UIViewController *vc) {
    dispatch_async(dispatch_get_main_queue(),^{
        NSString *sub=vc.currentSubtitle ?: @"";
        UIButton *left=PH2310FindButton(vc.view,@"Hierarquia");
        if(!left)left=PH2310FindButton(vc.view,@"Elemento");
        if(!left)left=PH2310FindButton(vc.view,@"JSON");
        if(!left)left=PH2310FindButton(vc.view,@"Voltar");
        if([sub isEqualToString:@"Filtro JSON"]&&left){
            UIImage *im=[UIImage systemImageNamed:@"chevron.left"];
            [left setTitle:@"Voltar" forState:UIControlStateNormal];
            [left setImage:im forState:UIControlStateNormal];
            [left removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
            [left addTarget:vc action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
            left.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
            left.contentEdgeInsets=UIEdgeInsetsMake(0,18,0,18);
            left.titleEdgeInsets=UIEdgeInsetsMake(0,8,0,0);
        }
        if(![sub isEqualToString:@"Elemento Web selecionado"])return;
        NSString *code=PH2310Code(vc.currentDetails ?: @"");
        if(!code.length)return;
        // The 2.3.8 GUI creates the prompt as a UIScrollView containing one UILabel.
        // Find that scroll view and replace only its content, leaving the approved GUI untouched.
        for(UIView *v in [vc.view.subviews copy]){
            for(UIView *p in [v.subviews copy]){
                if(![p isKindOfClass:UIScrollView.class])continue;
                UILabel *label=PH2310FindPromptLabel(p);
                if(label){label.text=code;label.font=[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];label.numberOfLines=0;[label sizeToFit];return;}
            }
        }
    });
}

static void (*PH2310OrigSelected)(id,SEL,NSString*);
static void PH2310Selected(id self,SEL cmd,NSString *details){
    @try{[self setValue:details?:@"" forKey:@"currentDetails"];}@catch(__unused NSException*e){}
    @try{[self setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"];}@catch(__unused NSException*e){}
    if(PH2310OrigSelected)PH2310OrigSelected(self,cmd,details);
    PH2310Refresh((UIViewController *)self);
}

static void (*PH2310OrigRender)(id,SEL,BOOL);
static void PH2310Render(id self,SEL cmd,BOOL hierarchyMode){
    if(PH2310OrigRender)PH2310OrigRender(self,cmd,hierarchyMode);
    dispatch_async(dispatch_get_main_queue(),^{PH2310Refresh((UIViewController *)self);dispatch_async(dispatch_get_main_queue(),^{PH2310Refresh((UIViewController *)self);});});
}

__attribute__((constructor))static void PH2310Install(void){
    dispatch_async(dispatch_get_main_queue(),^{
        Class c=NSClassFromString(@"PHInspectorViewController");if(!c)return;Method m;
        m=class_getInstanceMethod(c,@selector(showSelectedWebElement:));if(m){PH2310OrigSelected=(void*)method_getImplementation(m);if(PH2310OrigSelected!=(IMP)PH2310Selected)method_setImplementation(m,(IMP)PH2310Selected);}
        m=class_getInstanceMethod(c,@selector(render:));if(m){PH2310OrigRender=(void*)method_getImplementation(m);if(PH2310OrigRender!=(IMP)PH2310Render)method_setImplementation(m,(IMP)PH2310Render);}
    });
}
