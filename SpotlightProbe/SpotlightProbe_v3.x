#import <UIKit/UIKit.h>

static void runeLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"RUNE_SPOTLIGHT: %@", msg);
}

%hook UIImageView

- (void)setImage:(UIImage *)image {
    if (image) {
        UIView *superview = self.superview;
        NSMutableString *chain = [NSMutableString string];
        int depth = 0;
        while (superview && depth < 5) {
            [chain appendFormat:@" > %s", class_getName([superview class])];
            superview = superview.superview;
            depth++;
        }
        runeLog(@"[UIImageView setImage:] %dx%d superviews=%@",
            (int)image.size.width, (int)image.size.height, chain);
    }
    %orig;
}

%end

__attribute__((constructor))
static void runeSpotlightProbeInit3(void) {
    runeLog(@"probe v3 loaded");
}
