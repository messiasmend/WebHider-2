#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/*
 * WebHider 2.3 — GUI-only visual layer.
 *
 * This file replaces only PHInspectorViewController's render: implementation
 * at runtime. Existing action methods and WebHider logic remain untouched.
 */

static UIColor *PH23Color(NSString *hex, CGFloat alpha) {
    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]];
    [scanner scanHexInt:&value];
    return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                           green:((value >> 8) & 0xFF) / 255.0
                            blue:(value & 0xFF) / 255.0
                           alpha:alpha];
}

static UIButton *PH23Button(UIViewController *vc,
                            NSString *title,
                            NSString *symbol,
                            SEL action,
                            UIColor *tint,
                            UIColor *fill,
                            UIColor *border,
                            BOOL filled) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:tint forState:UIControlStateNormal];
    button.tintColor = tint;
    button.backgroundColor = fill;
    button.layer.cornerRadius = 16.0;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = border.CGColor;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    if (symbol.length) {
        UIImage *image = [UIImage systemImageNamed:symbol];
        if (image) {
            [button setImage:image forState:UIControlStateNormal];
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            button.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
        }
    }
    [button addTarget:vc action:action forControlEvents:UIControlEventTouchUpInside];
    if (filled) {
        button.layer.borderWidth = 0.0;
    }
    return button;
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

static UILabel *PH23Label(NSString *text, UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text ?: @"";
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.adjustsFontSizeToFitWidth = NO;
    return label;
}

static NSDictionary *PH23ParseDetails(NSString *details) {
    NSMutableDictionary *rows = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *raw = [NSMutableArray array];
    NSArray<NSString *> *lines = [details componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!trimmed.length) continue;
        NSRange colon = [trimmed rangeOfString:@":"];
        if (colon.location != NSNotFound && colon.location > 0) {
            NSString *key = [[trimmed substringToIndex:colon.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            NSString *value = [[trimmed substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            NSSet *known = [NSSet setWithObjects:@"HTML", @"ID", @"Classe", @"Classes", @"Tipo", @"Texto", @"Link", @"Tag", @"Hidden", @"Alpha", nil];
            if ([known containsObject:key] && value.length) {
                rows[key] = value;
                continue;
            }
        }
        if ([trimmed isEqualToString:@"Rect"] || [trimmed isEqualToString:@"Rect:" ]) {
            continue;
        }
        [raw addObject:trimmed];
    }

    NSArray *rectKeys = @[@"x", @"y", @"largura", @"altura"];
    NSMutableArray *rect = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSRange colon = [trimmed rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[trimmed substringToIndex:colon.location] lowercaseString];
        if ([rectKeys containsObject:key]) {
            NSString *value = [[trimmed substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (value.length) [rect addObject:[NSString stringWithFormat:@"%@: %@", key.capitalizedString, value]];
        }
    }
    if (rect.count) rows[@"Retângulo (Rect)"] = [rect componentsJoinedByString:@"  "]; 
    if (raw.count) rows[@"Detalhes"] = [raw componentsJoinedByString:@"\n"];
    return rows;
}

static void PH23AddInfoRow(UIView *card, NSString *labelText, NSString *valueText, UIView *previous, BOOL isLast) {
    UILabel *key = PH23Label(labelText, [UIFont systemFontOfSize:15.5 weight:UIFontWeightRegular], PH23Color(@"#8F949D", 1.0));
    UILabel *value = PH23Label(valueText, [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular], UIColor.whiteColor);
    value.textAlignment = NSTextAlignmentRight;
    value.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [card addSubview:key];
    [card addSubview:value];

    NSMutableArray *constraints = [NSMutableArray arrayWithObjects:
        [key.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [key.topAnchor constraintEqualToAnchor:previous ? ((UILabel *)previous).bottomAnchor : card.topAnchor constant:64],
        [value.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [value.centerYAnchor constraintEqualToAnchor:key.centerYAnchor],
        [value.leadingAnchor constraintGreaterThanOrEqualToAnchor:key.trailingAnchor constant:12],
        nil];
    if (!previous) {
        [constraints addObject:[key.topAnchor constraintEqualToAnchor:card.topAnchor constant:64]];
    } else {
        [constraints addObject:[key.topAnchor constraintEqualToAnchor:((UILabel *)previous).bottomAnchor constant:17]];
    }
    if (isLast) {
        [constraints addObject:[key.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-22]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
}

static UIView *PH23SectionHeader(UIView *card, NSString *title, NSString *symbol) {
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = PH23Color(@"#0A84FF", 1.0);
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:icon];

    UILabel *label = PH23Label(title, [UIFont systemFontOfSize:20 weight:UIFontWeightMedium], UIColor.whiteColor);
    [card addSubview:label];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = PH23Color(@"#8F949D", 1.0);
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22],
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [icon.widthAnchor constraintEqualToConstant:25],
        [icon.heightAnchor constraintEqualToConstant:25],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:18],
        [label.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [chevron.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [chevron.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:18],
        [chevron.heightAnchor constraintEqualToConstant:18]
    ]];
    return label;
}

static UIView *PH23DimBackground(void) {
    UIView *view = [UIView new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.34];
    view.userInteractionEnabled = YES;
    return view;
}

static void PH23Render(id self, SEL _cmd, BOOL hierarchyMode) {
    UIViewController *vc = (UIViewController *)self;
    [UIView performWithoutAnimation:^{
        for (UIView *subview in vc.view.subviews.copy) [subview removeFromSuperview];

        vc.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:1.0];
        UIView *dim = PH23DimBackground();
        [vc.view addSubview:dim];

        UIView *panel = [UIView new];
        panel.translatesAutoresizingMaskIntoConstraints = NO;
        panel.backgroundColor = PH23Color(@"#0E1013", 0.985);
        panel.layer.cornerRadius = 26.0;
        panel.layer.borderWidth = 1.0;
        panel.layer.borderColor = PH23Color(@"#35383E", 1.0).CGColor;
        panel.layer.masksToBounds = YES;
        [vc.view addSubview:panel];

        UIView *handle = [UIView new];
        handle.translatesAutoresizingMaskIntoConstraints = NO;
        handle.backgroundColor = PH23Color(@"#4B4F57", 1.0);
        handle.layer.cornerRadius = 4.0;
        [panel addSubview:handle];

        UILabel *title = PH23Label(@"WebHider Inspector", [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold], UIColor.whiteColor);
        title.textAlignment = NSTextAlignmentCenter;
        [panel addSubview:title];

        NSString *subtitleValue = nil;
        @try { subtitleValue = [self valueForKey:@"currentSubtitle"]; } @catch (__unused NSException *exception) {}
        if (![subtitleValue isKindOfClass:NSString.class] || !subtitleValue.length) subtitleValue = @"Elemento Web selecionado";
        UILabel *subtitle = PH23Label(subtitleValue, [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular], PH23Color(@"#8F949D", 1.0));
        subtitle.textAlignment = NSTextAlignmentCenter;
        [panel addSubview:subtitle];

        UIButton *closeTop = PH23Button(vc, @"", @"xmark", @selector(closeTapped), PH23Color(@"#C8CBD0", 1.0), PH23Color(@"#1A1C21", 1.0), PH23Color(@"#202329", 1.0), NO);
        closeTop.layer.cornerRadius = 26.0;
        [panel addSubview:closeTop];

        UIView *infoCard = PH23Card();
        [panel addSubview:infoCard];
        PH23SectionHeader(infoCard, @"Informações do elemento", @"doc.text");

        NSString *details = nil;
        @try { details = [self valueForKey:@"currentDetails"]; } @catch (__unused NSException *exception) {}
        NSDictionary *rows = PH23ParseDetails(details ?: @"");
        NSArray *preferredKeys = @[@"HTML", @"ID", @"Classe", @"Classes", @"Tipo", @"Texto", @"Link", @"Retângulo (Rect)", @"Tag", @"Hidden", @"Alpha", @"Detalhes"];
        NSMutableArray *available = [NSMutableArray array];
        for (NSString *key in preferredKeys) if (rows[key]) [available addObject:key];
        if (!available.count) {
            available = [NSMutableArray arrayWithObject:@"Detalhes"];
            rows = @{ @"Detalhes": details ?: @"" };
        }

        UILabel *previous = nil;
        NSUInteger limit = MIN((NSUInteger)6, available.count);
        for (NSUInteger i = 0; i < limit; i++) {
            NSString *key = available[i];
            NSString *value = rows[key];
            UILabel *label = PH23Label(key, [UIFont systemFontOfSize:15.5 weight:UIFontWeightRegular], PH23Color(@"#8F949D", 1.0));
            UILabel *valueLabel = PH23Label(value, [UIFont systemFontOfSize:16.5 weight:UIFontWeightRegular], UIColor.whiteColor);
            label.tag = 2300 + i;
            valueLabel.textAlignment = NSTextAlignmentRight;
            valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [infoCard addSubview:label];
            [infoCard addSubview:valueLabel];
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:20],
                [label.topAnchor constraintEqualToAnchor:(previous ? previous.bottomAnchor : infoCard.topAnchor) constant:(previous ? 16 : 64)],
                [valueLabel.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-20],
                [valueLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
                [valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:10]
            ]];
            previous = label;
            if (i == limit - 1) {
                [valueLabel.bottomAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:-22].active = YES;
            }
        }

        BOOL jsonScreen = [subtitleValue isEqualToString:@"Filtro JSON"];
        NSString *leftTitle = jsonScreen ? @"Voltar" : @"Hierarquia";
        SEL leftAction = jsonScreen ? @selector(backTapped) : @selector(hierarchyTapped);
        NSString *leftSymbol = jsonScreen ? @"chevron.left" : @"list.bullet.indent";
        UIButton *left = PH23Button(vc, leftTitle, leftSymbol, leftAction,
                                    PH23Color(@"#0A84FF", 1.0),
                                    PH23Color(@"#191D24", 1.0),
                                    PH23Color(@"#25496F", 0.95), NO);

        UIButton *json = PH23Button(vc, @"JSON", @"curlybraces", NSSelectorFromString(@"ph_jsonTapped26"),
                                    jsonScreen ? UIColor.whiteColor : PH23Color(@"#C7CBD1", 1.0),
                                    jsonScreen ? PH23Color(@"#191D24", 1.0) : PH23Color(@"#15171B", 0.98),
                                    jsonScreen ? PH23Color(@"#25496F", 0.95) : PH23Color(@"#292C32", 1.0),
                                    NO);

        UIView *segment = [UIView new];
        segment.translatesAutoresizingMaskIntoConstraints = NO;
        segment.backgroundColor = PH23Color(@"#15171B", 1.0);
        segment.layer.cornerRadius = 18.0;
        segment.layer.borderWidth = 1.0;
        segment.layer.borderColor = PH23Color(@"#2B2E35", 1.0).CGColor;
        segment.layer.masksToBounds = YES;
        [panel addSubview:segment];
        [segment addSubview:left];
        [segment addSubview:json];

        UIView *copyCard = PH23Card();
        UIButton *copy = PH23Button(vc, @"Copiar", @"doc.on.doc", @selector(copyTapped),
                                    PH23Color(@"#0A84FF", 1.0), UIColor.clearColor,
                                    UIColor.clearColor, NO);
        copyCard.backgroundColor = PH23Color(@"#15171B", 0.98);
        [copyCard addSubview:copy];
        [panel addSubview:copyCard];

        UIView *hiddenCard = PH23Card();
        UIButton *hidden = PH23Button(vc, @"Ocultos", @"eye.slash", @selector(hiddenTapped),
                                      PH23Color(@"#A970FF", 1.0), UIColor.clearColor,
                                      UIColor.clearColor, NO);
        hiddenCard.backgroundColor = PH23Color(@"#15171B", 0.98);
        UIImageView *hiddenChevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        hiddenChevron.translatesAutoresizingMaskIntoConstraints = NO;
        hiddenChevron.tintColor = PH23Color(@"#8F949D", 1.0);
        [hiddenCard addSubview:hidden];
        [hiddenCard addSubview:hiddenChevron];
        [panel addSubview:hiddenCard];

        UIView *hideCard = PH23Card();
        hideCard.backgroundColor = PH23Color(@"#281417", 0.98);
        hideCard.layer.borderColor = PH23Color(@"#6A2B31", 0.85).CGColor;
        UIButton *hide = PH23Button(vc, @"Ocultar", @"eye.slash", @selector(hideTapped),
                                    PH23Color(@"#FF5E67", 1.0), UIColor.clearColor,
                                    UIColor.clearColor, NO);
        [hideCard addSubview:hide];
        [panel addSubview:hideCard];

        UIButton *close = PH23Button(vc, @"Fechar", @"xmark", @selector(closeTapped),
                                     UIColor.whiteColor, PH23Color(@"#17191D", 1.0), PH23Color(@"#30343A", 1.0), NO);
        [panel addSubview:close];

        UIButton *save = PH23Button(vc, @"Salvar", @"square.and.arrow.down", @selector(saveTapped),
                                    UIColor.whiteColor, PH23Color(@"#0A84FF", 1.0), PH23Color(@"#0A84FF", 1.0), YES);
        BOOL hasPending = NO;
        @try {
            id pending = [NSClassFromString(@"PHOverlayManager") valueForKey:@"dummy"];
            (void)pending;
            id manager = [NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
            if (manager) {
                id pendingSelectors = [manager valueForKey:@"pendingSelectors"];
                if ([pendingSelectors isKindOfClass:NSArray.class]) hasPending = [pendingSelectors count] > 0;
            }
        } @catch (__unused NSException *exception) {}
        save.hidden = !hasPending;
        [panel addSubview:save];

        [NSLayoutConstraint activateConstraints:@[
            [dim.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor],
            [dim.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor],
            [dim.topAnchor constraintEqualToAnchor:vc.view.topAnchor],
            [dim.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor],

            [panel.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:12],
            [panel.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-12],
            [panel.topAnchor constraintGreaterThanOrEqualToAnchor:vc.view.safeAreaLayoutGuide.topAnchor constant:8],
            [panel.bottomAnchor constraintLessThanOrEqualToAnchor:vc.view.bottomAnchor constant:-12],
            [panel.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
            [panel.heightAnchor constraintLessThanOrEqualToConstant:780],

            [handle.topAnchor constraintEqualToAnchor:panel.topAnchor constant:16],
            [handle.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],
            [handle.widthAnchor constraintEqualToConstant:78],
            [handle.heightAnchor constraintEqualToConstant:7],

            [title.topAnchor constraintEqualToAnchor:handle.bottomAnchor constant:24],
            [title.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22],
            [title.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-70],

            [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7],
            [subtitle.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],

            [closeTop.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-24],
            [closeTop.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
            [closeTop.widthAnchor constraintEqualToConstant:52],
            [closeTop.heightAnchor constraintEqualToConstant:52],

            [infoCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
            [infoCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
            [infoCard.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:24],
            [infoCard.heightAnchor constraintEqualToConstant:228],

            [segment.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
            [segment.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
            [segment.topAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:18],
            [segment.heightAnchor constraintEqualToConstant:70],

            [left.leadingAnchor constraintEqualToAnchor:segment.leadingAnchor constant:6],
            [left.topAnchor constraintEqualToAnchor:segment.topAnchor constant:6],
            [left.bottomAnchor constraintEqualToAnchor:segment.bottomAnchor constant:-6],
            [left.widthAnchor constraintEqualToAnchor:segment.widthAnchor multiplier:0.5 constant:-9],

            [json.trailingAnchor constraintEqualToAnchor:segment.trailingAnchor constant:-6],
            [json.topAnchor constraintEqualToAnchor:segment.topAnchor constant:6],
            [json.bottomAnchor constraintEqualToAnchor:segment.bottomAnchor constant:-6],
            [json.widthAnchor constraintEqualToAnchor:left.widthAnchor],

            [copyCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
            [copyCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
            [copyCard.topAnchor constraintEqualToAnchor:segment.bottomAnchor constant:16],
            [copyCard.heightAnchor constraintEqualToConstant:74],
            [copy.leadingAnchor constraintEqualToAnchor:copyCard.leadingAnchor],
            [copy.trailingAnchor constraintEqualToAnchor:copyCard.trailingAnchor],
            [copy.topAnchor constraintEqualToAnchor:copyCard.topAnchor],
            [copy.bottomAnchor constraintEqualToAnchor:copyCard.bottomAnchor],

            [hiddenCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
            [hiddenCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
            [hiddenCard.topAnchor constraintEqualToAnchor:copyCard.bottomAnchor constant:14],
            [hiddenCard.heightAnchor constraintEqualToConstant:74],
            [hidden.leadingAnchor constraintEqualToAnchor:hiddenCard.leadingAnchor],
            [hidden.trailingAnchor constraintEqualToAnchor:hiddenCard.trailingAnchor constant:-36],
            [hidden.topAnchor constraintEqualToAnchor:hiddenCard.topAnchor],
            [hidden.bottomAnchor constraintEqualToAnchor:hiddenCard.bottomAnchor],
            [hiddenChevron.trailingAnchor constraintEqualToAnchor:hiddenCard.trailingAnchor constant:-20],
            [hiddenChevron.centerYAnchor constraintEqualToAnchor:hiddenCard.centerYAnchor],
            [hiddenChevron.widthAnchor constraintEqualToConstant:18],
            [hiddenChevron.heightAnchor constraintEqualToConstant:18],

            [hideCard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
            [hideCard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
            [hideCard.topAnchor constraintEqualToAnchor:hiddenCard.bottomAnchor constant:14],
            [hideCard.heightAnchor constraintEqualToConstant:74],
            [hide.leadingAnchor constraintEqualToAnchor:hideCard.leadingAnchor],
            [hide.trailingAnchor constraintEqualToAnchor:hideCard.trailingAnchor],
            [hide.topAnchor constraintEqualToAnchor:hideCard.topAnchor],
            [hide.bottomAnchor constraintEqualToAnchor:hideCard.bottomAnchor],

            [close.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
            [close.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],
            [close.heightAnchor constraintEqualToConstant:72],
            [close.widthAnchor constraintEqualToConstant:150],

            [save.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
            [save.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20],
            [save.heightAnchor constraintEqualToConstant:72],
            [save.widthAnchor constraintEqualToConstant:180]
        ]];

        save.accessibilityLabel = @"Salvar";
        close.accessibilityLabel = @"Fechar";
        hidden.accessibilityLabel = @"Ocultos";
        hide.accessibilityLabel = @"Ocultar";
        copy.accessibilityLabel = @"Copiar";
    }];
}

__attribute__((constructor)) static void PH23Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;
        SEL selector = @selector(render:);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) return;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            method_setImplementation(method, (IMP)PH23Render);
        });
    });
}
