#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@end

static NSString *PH2310Value(NSString *details, NSString *key) {
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *prefix=[key stringByAppendingString:@":"];
        if ([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static NSString *PH2310ElementCode(NSString *details) {
    NSString *html=PH2310Value(details ?: @"",@"HTML");
    if (!html.length) return details ?: @"";
    NSString *tag=html;
    NSRange open=[html rangeOfString:@"<"];
    NSRange close=open.location!=NSNotFound ? [html rangeOfString:@">" options:0 range:NSMakeRange(open.location,html.length-open.location)] : NSMakeRange(NSNotFound,0);
    if(open.location!=NSNotFound&&close.location!=NSNotFound){NSString *inside=[html substringWithRange:NSMakeRange(open.location+1,close.location-open.location-1)];NSArray *parts=[inside componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if(parts.count&&[parts[0] length])tag=parts[0];}
    NSMutableString *attrs=[NSMutableString string];
    NSString *identifier=PH2310Value(details,@"ID");
    NSString *classes=PH2310Value(details,@"Classe");
    NSString *type=PH2310Value(details,@"Tipo");
    NSString *href=PH2310Value(details,@"Link");
    if(identifier.length)[attrs appendFormat:@" id=\"%@\"",identifier];
    if(classes.length)[attrs appendFormat:@" class=\"%@\"",classes];
    if(type.length&&![type isEqualToString:tag])[attrs appendFormat:@" type=\"%@\"",type];
    if(href.length)[attrs appendFormat:@" href=\"%@\"",href];
    NSString *text=PH2310Value(details,@"Texto");
    if(text.length)return[NSString stringWithFormat:@"<%@%@>\n    %@\n</%@>",tag,attrs,text,tag];
    return[NSString stringWithFormat:@"<%@%@></%@>",tag,attrs,tag];
}

static void (*PH2310OriginalSelected)(id,SEL,NSString*);
static void PH2310Selected(id self,SEL cmd,NSString *details){
    // Store the exact selection before any other render hook can rebuild the panel.
    @try{[self setValue:details?:@"" forKey:@"currentDetails"];}@catch(__unused NSException*e){}
    @try{[self setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"];}@catch(__unused NSException*e){}
    if(PH2310OriginalSelected)PH2310OriginalSelected(self,cmd,details);
}

__attribute__((constructor)) static void PH2310Install(void){
    dispatch_async(dispatch_get_main_queue(),^{
        Class c=NSClassFromString(@"PHInspectorViewController");
        if(!c)return;
        Method m=class_getInstanceMethod(c,@selector(showSelectedWebElement:));
        if(m){PH2310OriginalSelected=(void*)method_getImplementation(m);if(PH2310OriginalSelected!=(IMP)PH2310Selected)method_setImplementation(m,(IMP)PH2310Selected);}
    });
}

// Exposed helper used by the GUI fix without changing the existing 2.3.8 view hierarchy.
NSString *PH2310BuildElementPrompt(NSString *details){return PH2310ElementCode(details ?: @"");}
