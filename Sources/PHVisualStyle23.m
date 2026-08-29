#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/* WebHider 2.3 — GUI-only visual layer. */

static UIColor *PH23Color(NSString *hex, CGFloat alpha) {
    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]];
    [scanner scanHexInt:&value];
    return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0 green:((value >> 8) & 0xFF) / 255.0 blue:(value & 0xFF) / 255.0 alpha:alpha];
}

static UILabel *PH23Label(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text ?: @"";
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

static UIView *PH23Card(void) {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = PH23Color(@"#17191D", 0.96);
    card.layer.cornerRadius = 18.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = PH23Color(@"#34373D", 0.92).CGColor;
    card.layer.masksToBounds = YES;
    return card;
}

static UIButton *PH23Button(UIViewController *vc, NSString *title, NSString *symbol, SEL action, UIColor *tint, UIColor *fill, UIColor *border, BOOL filled) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:tint forState:UIControlStateNormal];
    button.tintColor = tint;
    button.backgroundColor = fill;
    button.layer.cornerRadius = 16.0;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = filled ? 0.0 : 1.0;
    button.layer.borderColor = border.CGColor;
    if (symbol.length) {
        UIImage *image = [UIImage systemImageNamed:symbol];
        if (image) {
            [button setImage:image forState:UIControlStateNormal];
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            button.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
        }
    }
    [button addTarget:vc action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static NSDictionary *PH23ParseDetails(NSString *details) {
    NSMutableDictionary *rows = [NSMutableDictionary dictionary];
    NSArray<NSString *> *lines = [details componentsSeparatedByString:@"\n"];
    NSSet *known = [NSSet setWithObjects:@"HTML", @"ID", @"Classe", @"Classes", @"Tipo", @"Texto", @"Link", @"Tag", @"Hidden", @"Alpha", nil];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSRange colon = [trimmed rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) continue;
        NSString *key = [[trimmed substringToIndex:colon.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *value = [[trimmed substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([known containsObject:key] && value.length) rows[key] = value;
    }
    NSMutableArray *rect = [NSMutableArray array];
    NSSet *rectKeys = [NSSet setWithObjects:@"x", @"y", @"largura", @"altura", nil];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSRange colon = [trimmed rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[trimmed substringToIndex:colon.location] lowercaseString];
        NSString *value = [[trimmed substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([rectKeys containsObject:key] && value.length) [rect addObject:[NSString stringWithFormat:@"%@: %@", key.capitalizedString, value]];
    }
    if (rect.count) rows[@"Retângulo (Rect)"] = [rect componentsJoinedByString:@"  "];
    return rows;
}

static void PH23AddInfoRow(UIView *card, NSString *keyText, NSString *valueText, NSLayoutYAxisAnchor *topAnchor, CGFloat spacing) {
    UILabel *key = PH23Label(keyText, [UIFont systemFontOfSize:15.5 weight:UIFontWeightRegular], PH23Color(@"#8F949D", 1.0));
    UILabel *value = PH23Label(valueText, [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular], UIColor.whiteColor);
    value.textAlignment = NSTextAlignmentRight;
    value.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [card addSubview:key]; [card addSubview:value];
    [NSLayoutConstraint activateConstraints:@[
        [key.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [key.topAnchor constraintEqualToAnchor:topAnchor constant:spacing],
        [value.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [value.centerYAnchor constraintEqualToAnchor:key.centerYAnchor],
        [value.leadingAnchor constraintGreaterThanOrEqualToAnchor:key.trailingAnchor constant:10]
    ]];
    key.accessibilityIdentifier = @"PH23InfoKey";
}

static void PH23Render(id self, SEL _cmd, BOOL hierarchyMode) {
    UIViewController *vc = (UIViewController *)self;
    [UIView performWithoutAnimation:^{
        for (UIView *subview in vc.view.subviews.copy) [subview removeFromSuperview];
        vc.view.backgroundColor = UIColor.blackColor;

        UIView *panel = [UIView new];
        panel.translatesAutoresizingMaskIntoConstraints = NO;
        panel.backgroundColor = PH23Color(@"#0E1013", 0.985);
        panel.layer.cornerRadius = 26.0;
        panel.layer.borderWidth = 1.0;
        panel.layer.borderColor = PH23Color(@"#35383E", 1.0).CGColor;
        panel.layer.masksToBounds = YES;
        [vc.view addSubview:panel];

        UIView *handle = [UIView new]; handle.translatesAutoresizingMaskIntoConstraints = NO; handle.backgroundColor = PH23Color(@"#4B4F57", 1); handle.layer.cornerRadius = 4; [panel addSubview:handle];
        UILabel *title = PH23Label(@"WebHider Inspector", [UIFont systemFontOfSize:26 weight:UIFontWeightBold], UIColor.whiteColor); title.textAlignment = NSTextAlignmentCenter; [panel addSubview:title];
        NSString *subtitleValue = nil; @try { subtitleValue = [self valueForKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}
        if (![subtitleValue isKindOfClass:NSString.class] || !subtitleValue.length) subtitleValue = @"Elemento Web selecionado";
        UILabel *subtitle = PH23Label(subtitleValue, [UIFont systemFontOfSize:17 weight:UIFontWeightRegular], PH23Color(@"#8F949D", 1)); subtitle.textAlignment = NSTextAlignmentCenter; [panel addSubview:subtitle];

        UIButton *topClose = PH23Button(vc, @"", @"xmark", @selector(closeTapped), PH23Color(@"#C8CBD0",1), PH23Color(@"#1A1C21",1), PH23Color(@"#202329",1), NO); topClose.layer.cornerRadius = 26; [panel addSubview:topClose];

        UIView *info = PH23Card(); [panel addSubview:info];
        UIImageView *infoIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"doc.text"]]; infoIcon.translatesAutoresizingMaskIntoConstraints = NO; infoIcon.tintColor = PH23Color(@"#0A84FF",1); [info addSubview:infoIcon];
        UILabel *infoTitle = PH23Label(@"Informações do elemento", [UIFont systemFontOfSize:20 weight:UIFontWeightMedium], UIColor.whiteColor); [info addSubview:infoTitle];
        UIImageView *infoChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]]; infoChevron.translatesAutoresizingMaskIntoConstraints = NO; infoChevron.tintColor = PH23Color(@"#8F949D",1); [info addSubview:infoChevron];
        [NSLayoutConstraint activateConstraints:@[[infoIcon.leadingAnchor constraintEqualToAnchor:info.leadingAnchor constant:22],[infoIcon.topAnchor constraintEqualToAnchor:info.topAnchor constant:18],[infoIcon.widthAnchor constraintEqualToConstant:25],[infoIcon.heightAnchor constraintEqualToConstant:25],[infoTitle.leadingAnchor constraintEqualToAnchor:infoIcon.trailingAnchor constant:18],[infoTitle.centerYAnchor constraintEqualToAnchor:infoIcon.centerYAnchor],[infoChevron.trailingAnchor constraintEqualToAnchor:info.trailingAnchor constant:-20],[infoChevron.centerYAnchor constraintEqualToAnchor:infoIcon.centerYAnchor],[infoChevron.widthAnchor constraintEqualToConstant:18],[infoChevron.heightAnchor constraintEqualToConstant:18]]];

        NSString *details = nil; @try { details = [self valueForKey:@"currentDetails"]; } @catch (__unused NSException *e) {}
        NSDictionary *rows = PH23ParseDetails(details ?: @"");
        NSArray *keys = @[@"HTML", @"ID", @"Classe", @"Classes", @"Tipo", @"Texto", @"Link", @"Retângulo (Rect)", @"Tag", @"Hidden", @"Alpha"];
        NSMutableArray *used = [NSMutableArray array]; for (NSString *key in keys) if (rows[key]) [used addObject:key];
        if (!used.count) { rows = @{ @"Detalhes": details ?: @"" }; [used addObject:@"Detalhes"]; }
        UILabel *previous = nil; NSUInteger count = MIN((NSUInteger)6, used.count);
        for (NSUInteger i=0; i<count; i++) {
            NSString *key = used[i];
            UILabel *k = PH23Label(key, [UIFont systemFontOfSize:15.5 weight:UIFontWeightRegular], PH23Color(@"#8F949D",1));
            UILabel *v = PH23Label(rows[key], [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular], UIColor.whiteColor);
            v.textAlignment = NSTextAlignmentRight; v.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [info addSubview:k]; [info addSubview:v];
            [NSLayoutConstraint activateConstraints:@[[k.leadingAnchor constraintEqualToAnchor:info.leadingAnchor constant:20],[k.topAnchor constraintEqualToAnchor:(previous ? previous.bottomAnchor : info.topAnchor) constant:(previous ? 16 : 64)],[v.trailingAnchor constraintEqualToAnchor:info.trailingAnchor constant:-20],[v.centerYAnchor constraintEqualToAnchor:k.centerYAnchor],[v.leadingAnchor constraintGreaterThanOrEqualToAnchor:k.trailingAnchor constant:10]]];
            previous = k;
        }

        BOOL jsonScreen = [subtitleValue isEqualToString:@"Filtro JSON"];
        UIButton *left = PH23Button(vc, jsonScreen ? @"Voltar" : @"Hierarquia", jsonScreen ? @"chevron.left" : @"list.bullet.indent", jsonScreen ? @selector(backTapped) : @selector(hierarchyTapped), PH23Color(@"#0A84FF",1), PH23Color(@"#191D24",1), PH23Color(@"#25496F",.95), NO);
        UIButton *json = PH23Button(vc, @"JSON", @"curlybraces", NSSelectorFromString(@"ph_jsonTapped26"), jsonScreen ? UIColor.whiteColor : PH23Color(@"#C7CBD1",1), PH23Color(@"#15171B",1), PH23Color(@"#292C32",1), NO);
        if (jsonScreen) json.layer.borderColor = PH23Color(@"#25496F",.95).CGColor;
        UIView *segment = [UIView new]; segment.translatesAutoresizingMaskIntoConstraints = NO; segment.backgroundColor = PH23Color(@"#15171B",1); segment.layer.cornerRadius = 18; segment.layer.borderWidth = 1; segment.layer.borderColor = PH23Color(@"#2B2E35",1).CGColor; segment.layer.masksToBounds = YES; [panel addSubview:segment]; [segment addSubview:left]; [segment addSubview:json];

        UIView *copyCard=PH23Card(); UIButton *copy=PH23Button(vc,@"Copiar",@"doc.on.doc",@selector(copyTapped),PH23Color(@"#0A84FF",1),UIColor.clearColor,UIColor.clearColor,NO); copyCard.backgroundColor=PH23Color(@"#15171B",.98); [copyCard addSubview:copy]; [panel addSubview:copyCard];
        UIView *hiddenCard=PH23Card(); UIButton *hidden=PH23Button(vc,@"Ocultos",@"eye.slash",@selector(hiddenTapped),PH23Color(@"#A970FF",1),UIColor.clearColor,UIColor.clearColor,NO); hiddenCard.backgroundColor=PH23Color(@"#15171B",.98); UIImageView *hc=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right"]]; hc.translatesAutoresizingMaskIntoConstraints=NO; hc.tintColor=PH23Color(@"#8F949D",1); [hiddenCard addSubview:hidden]; [hiddenCard addSubview:hc]; [panel addSubview:hiddenCard];
        UIView *hideCard=PH23Card(); hideCard.backgroundColor=PH23Color(@"#281417",.98); hideCard.layer.borderColor=PH23Color(@"#6A2B31",.85).CGColor; UIButton *hide=PH23Button(vc,@"Ocultar",@"eye.slash",@selector(hideTapped),PH23Color(@"#FF5E67",1),UIColor.clearColor,UIColor.clearColor,NO); [hideCard addSubview:hide]; [panel addSubview:hideCard];

        UIButton *close=PH23Button(vc,@"Fechar",@"xmark",@selector(closeTapped),UIColor.whiteColor,PH23Color(@"#17191D",1),PH23Color(@"#30343A",1),NO); [panel addSubview:close];
        UIButton *save=PH23Button(vc,@"Salvar",@"square.and.arrow.down",@selector(saveTapped),UIColor.whiteColor,PH23Color(@"#0A84FF",1),PH23Color(@"#0A84FF",1),YES); [panel addSubview:save];

        [NSLayoutConstraint activateConstraints:@[
            [panel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:12],[panel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-12],[panel.topAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.topAnchor constant:8],[panel.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor constant:-12],
            [handle.topAnchor constraintEqualToAnchor:panel.topAnchor constant:16],[handle.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],[handle.widthAnchor constraintEqualToConstant:78],[handle.heightAnchor constraintEqualToConstant:7],
            [title.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:24],[title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22],[title.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-70],
            [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7],[subtitle.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
            [topClose.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-24],[topClose.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],[topClose.widthAnchor constraintEqualToConstant:52],[topClose.heightAnchor constraintEqualToConstant:52],
            [info.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],[info.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],[info.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:24],[info.heightAnchor constraintEqualToConstant:228],
            [segment.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],[segment.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],[segment.topAnchor constraintEqualToAnchor:info.bottomAnchor constant:18],[segment.heightAnchor constraintEqualToConstant:70],
            [left.leadingAnchor constraintEqualToAnchor:segment.leadingAnchor constant:6],[left.topAnchor constraintEqualToAnchor:segment.topAnchor constant:6],[left.bottomAnchor constraintEqualToAnchor:segment.bottomAnchor constant:-6],[left.widthAnchor constraintEqualToAnchor:segment.widthAnchor multiplier:.5 constant:-9],
            [json.trailingAnchor constraintEqualToAnchor:segment.trailingAnchor constant:-6],[json.topAnchor constraintEqualToAnchor:segment.topAnchor constant:6],[json.bottomAnchor constraintEqualToAnchor:segment.bottomAnchor constant:-6],[json.widthAnchor constraintEqualToAnchor:left.widthAnchor],
            [copyCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],[copyCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],[copyCard.topAnchor constraintEqualToAnchor:segment.bottomAnchor constant:16],[copyCard.heightAnchor constraintEqualToConstant:74],[copy.leadingAnchor constraintEqualToAnchor:copyCard.leadingAnchor],[copy.trailingAnchor constraintEqualToAnchor:copyCard.trailingAnchor],[copy.topAnchor constraintEqualToAnchor:copyCard.topAnchor],[copy.bottomAnchor constraintEqualToAnchor:copyCard.bottomAnchor],
            [hiddenCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],[hiddenCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],[hiddenCard.topAnchor constraintEqualToAnchor:copyCard.bottomAnchor constant:14],[hiddenCard.heightAnchor constraintEqualToConstant:74],[hidden.leadingAnchor constraintEqualToAnchor:hiddenCard.leadingAnchor],[hidden.trailingAnchor constraintEqualToAnchor:hiddenCard.trailingAnchor constant:-36],[hidden.topAnchor constraintEqualToAnchor:hiddenCard.topAnchor],[hidden.bottomAnchor constraintEqualToAnchor:hiddenCard.bottomAnchor],[hc.trailingAnchor constraintEqualToAnchor:hiddenCard.trailingAnchor constant:-20],[hc.centerYAnchor constraintEqualToAnchor:hiddenCard.centerYAnchor],[hc.widthAnchor constraintEqualToConstant:18],[hc.heightAnchor constraintEqualToConstant:18],
            [hideCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],[hideCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],[hideCard.topAnchor constraintEqualToAnchor:hiddenCard.bottomAnchor constant:14],[hideCard.heightAnchor constraintEqualToConstant:74],[hide.leadingAnchor constraintEqualToAnchor:hideCard.leadingAnchor],[hide.trailingAnchor constraintEqualToAnchor:hideCard.trailingAnchor],[hide.topAnchor constraintEqualToAnchor:hideCard.topAnchor],[hide.bottomAnchor constraintEqualToAnchor:hideCard.bottomAnchor],
            [close.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],[close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],[close.heightAnchor constraintEqualToConstant:72],[close.widthAnchor constraintEqualToConstant:150],
            [save.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],[save.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],[save.heightAnchor constraintEqualToConstant:72],[save.widthAnchor constraintEqualToConstant:180]
        ]];
    }];
}

__attribute__((constructor)) static void PH23Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;
        Method method = class_getInstanceMethod(cls, @selector(render:));
        if (!method) return;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ method_setImplementation(method, (IMP)PH23Render); });
    });
}
