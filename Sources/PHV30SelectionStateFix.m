#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* WebHider 3.0-16 — selection-state guard.
 * Prevents the visual renderer from turning the initial selection prompt
 * into an element screen before an element has actually been selected.
 */

static IMP PH30OriginalRender = NULL;

static BOOL PH30HasText(id object, SEL key) {
    @try {
        id value = [object valueForKey:NSStringFromSelector(key)];
        return [value isKindOfClass:NSString.class] && [(NSString *)value length] > 0;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL PH30SelectionMode(id object) {
    @try {
        return [[object valueForKey:@"selectionMode"] boolValue];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static void PH30Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if (!hierarchyMode && (PH30SelectionMode(self) ||
                           (!PH30HasText(self, @selector(currentDetails)) &&
                            !PH30HasText(self, @selector(currentSubtitle))))) {
        SEL prompt = @selector(showSelectionPrompt);
        if ([self respondsToSelector:prompt]) {
            ((void (*)(id, SEL))objc_msgSend)(self, prompt);
            return;
        }
    }

    if (PH30OriginalRender) {
        ((void (*)(id, SEL, BOOL))PH30OriginalRender)(self, _cmd, hierarchyMode);
    }
}

__attribute__((constructor)) static void PH30InstallSelectionStateGuard(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;

        Method render = class_getInstanceMethod(cls, @selector(render:));
        if (!render) return;

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            PH30OriginalRender = method_getImplementation(render);
            if (PH30OriginalRender && PH30OriginalRender != (IMP)PH30Render) {
                method_setImplementation(render, (IMP)PH30Render);
            }
        });
    });
}
