#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP PHV17OriginalRender=NULL;

static UIButton*PHV17FindButton(UIView*root,NSString*title){
    if(!root)return nil;
    if([root isKindOfClass:UIButton.class]){
        UIButton*b=(UIButton*)root;
        if([[b titleForState:UIControlStateNormal]?:@"" isEqualToString:title])return b;
    }
    for(UIView*child in[root.subviews copy]){
        UIButton*r=PHV17FindButton(child,title);
        if(r)return r;
    }
    return nil;
}

static void PHV17StyleButton(UIButton*b,NSString*iconName){
    if(!b)return;

    // Somente aparência/alinhamento. A ação original do botão permanece intacta.
    b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    b.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;
    b.contentEdgeInsets=UIEdgeInsetsMake(0,18,0,18);
    b.titleEdgeInsets=UIEdgeInsetsMake(0,10,0,0);
    b.imageEdgeInsets=UIEdgeInsetsZero;
    b.titleLabel.textAlignment=NSTextAlignmentLeft;

    UIImage*icon=[UIImage systemImageNamed:iconName];
    if(icon){
        [b setImage:icon forState:UIControlStateNormal];
        b.imageView.tintColor=[UIColor colorWithRed:0.05 green:0.52 blue:1.0 alpha:1.0];
        b.imageView.contentMode=UIViewContentModeScaleAspectFit;
    }
}

static void PHV17Reorder(UIViewController*c){
    UIView*root=c.view;
    if(!root)return;

    UIButton*ocultar=PHV17FindButton(root,@"Ocultar");
    UIButton*ocultos=PHV17FindButton(root,@"Ocultos");
    UIButton*salvar=PHV17FindButton(root,@"Salvar");

    // Alinhamento interno dos três botões da fileira inferior, sem alterar ações.
    PHV17StyleButton(ocultar,@"eye.slash");
    PHV17StyleButton(ocultos,@"eye.slash");

    UIButton*copiar=PHV17FindButton(root,@"Copiar");
    PHV17StyleButton(copiar,@"doc.on.doc");

    // Mantém a posição combinada da fileira inferior: Ocultos à esquerda,
    // Ocultar no centro e Salvar à direita.
    if(ocultar&&ocultos&&salvar){
        UIView*panel=ocultar.superview;
        if(panel==ocultos.superview&&panel==salvar.superview){
            NSMutableArray*cs=[NSMutableArray array];
            for(NSLayoutConstraint*x in[panel.constraints copy]){
                BOOL h=x.firstAttribute==NSLayoutAttributeLeading||x.firstAttribute==NSLayoutAttributeTrailing||x.firstAttribute==NSLayoutAttributeCenterX;
                BOOL b=x.firstItem==ocultar||x.secondItem==ocultar||x.firstItem==ocultos||x.secondItem==ocultos||x.firstItem==salvar||x.secondItem==salvar;
                if(h&&b)[cs addObject:x];
            }
            if(cs.count)[panel removeConstraints:cs];
            [NSLayoutConstraint activateConstraints:@[
                [ocultos.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
                [ocultar.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
                [salvar.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18]
            ]];
            [panel setNeedsLayout];
            [panel layoutIfNeeded];
        }
    }
}

static void PHV17Render(id self,SEL _cmd,BOOL hierarchyMode){
    if(PHV17OriginalRender)((void(*)(id,SEL,BOOL))PHV17OriginalRender)(self,_cmd,hierarchyMode);
    dispatch_async(dispatch_get_main_queue(),^{
        PHV17Reorder((UIViewController*)self);
        dispatch_async(dispatch_get_main_queue(),^{PHV17Reorder((UIViewController*)self);});
    });
}

__attribute__((constructor))static void PHV17Install(void){
    dispatch_async(dispatch_get_main_queue(),^{
        Class cls=NSClassFromString(@"PHInspectorViewController");
        if(!cls)return;
        Method m=class_getInstanceMethod(cls,@selector(render:));
        if(!m)return;
        IMP cur=method_getImplementation(m);
        if(cur==(IMP)PHV17Render)return;
        PHV17OriginalRender=cur;
        method_setImplementation(m,(IMP)PHV17Render);
    });
}
