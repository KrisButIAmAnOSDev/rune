#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dirent.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>
#import <stdarg.h>
#import <time.h>
#import <notify.h>

#define kRuneIconsDir "/var/jb/Library/rune/Icons"

@interface SBIcon : NSObject
- (id)leafIdentifier;
@end

@interface SBIconImageView : UIView
- (SBIcon *)icon;
@end

@interface SBMainSwitcherWindow : UIWindow
@end

@interface SBHIconImageCache : NSObject
- (UIImage *)cachedImageForIcon:(id)icon;
- (UIImage *)imageForIcon:(id)icon imageAppearance:(id)appearance options:(unsigned long long)options;
@end

@interface SBFluidSwitcherIconImageContainerView : UIView
@end

@interface SBFluidSwitcherIconOverlayView : UIView
@end

@interface SBFluidSwitcherItemContainerHeaderView : UIView
@end

static BOOL kEnabled = NO;
static NSSet *kThemedBIDs = nil;
static NSMutableDictionary *kImageCache = nil;
static NSMutableDictionary *kRuneNameMap = nil;
static int kRuneNotifyToken = 0;

// Resolve a bundle id for an icon, even when leafIdentifier is a scene UUID.
static NSString *runeResolveBID(id icon) {
    if (!icon) return nil;
    NSString *leaf = nil;
    if ([icon respondsToSelector:@selector(leafIdentifier)]) {
        id v = [icon leafIdentifier];
        if ([v isKindOfClass:[NSString class]] && [v length]) leaf = v;
    }
    if (leaf) {
        NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
        NSArray *parts = [leaf componentsSeparatedByString:@"-"];
        if (parts.count != 5) return leaf;
        NSArray *sizes = @[@8, @4, @4, @4, @12];
        for (NSUInteger i = 0; i < parts.count; i++) {
            NSString *p = parts[i];
            if (p.length != [sizes[i] unsignedIntegerValue]) return leaf;
            if ([p rangeOfCharacterFromSet:hex.invertedSet].location != NSNotFound) return leaf;
        }
        // UUID-like scene id -> keep looking for the real bundle id
    }

    SEL sels[] = { @selector(applicationBundleIdentifier), @selector(bundleIdentifier),
                   @selector(representedApplicationBundleIdentifier), @selector(applicationIdentifier) };
    for (NSUInteger i = 0; i < sizeof(sels)/sizeof(sels[0]); i++) {
        if ([icon respondsToSelector:sels[i]]) {
            id v = ((id(*)(id,SEL))objc_msgSend)(icon, sels[i]);
            if ([v isKindOfClass:[NSString class]] && [v length]) return v;
        }
    }
    if ([icon respondsToSelector:@selector(application)]) {
        id app = ((id(*)(id,SEL))objc_msgSend)(icon, @selector(application));
        if (app && [app respondsToSelector:@selector(bundleIdentifier)]) {
            id v = ((id(*)(id,SEL))objc_msgSend)(app, @selector(bundleIdentifier));
            if ([v isKindOfClass:[NSString class]] && [v length]) return v;
        }
    }
    return leaf;
}

static NSString *runeFetchBID(SBIconImageView *iv) {
    if (iv && [iv respondsToSelector:@selector(icon)]) {
        SBIcon *icon = [iv icon];
        return runeResolveBID(icon);
    }
    return nil;
}

static UIImage *runeLoadImage(const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return nil;
    struct stat st;
    if (fstat(fd, &st) != 0) { close(fd); return nil; }
    size_t sz = (size_t)st.st_size;
    void *buf = malloc(sz ? sz : 1);
    if (!buf) { close(fd); return nil; }
    size_t total = 0;
    ssize_t rd = 0;
    while (total < sz && (rd = read(fd, (char *)buf + total, sz - total)) > 0) total += (size_t)rd;
    close(fd);
    NSData *data = [NSData dataWithBytes:buf length:total];
    free(buf);
    return [UIImage imageWithData:data];
}

static UIImage *runeThemedForBID(NSString *bid) {
    if (!bid) return nil;
    NSString *lower = [bid lowercaseString];
    if (![kThemedBIDs containsObject:lower]) return nil;
    NSString *realName = kRuneNameMap[lower] ?: lower;
    @synchronized (kImageCache) {
        UIImage *th = kImageCache[lower];
        if (!th) {
            NSString *path = [NSString stringWithFormat:@"%s/%@.png", kRuneIconsDir, realName];
            th = runeLoadImage([path UTF8String]);
            if (th) kImageCache[lower] = th;
        }
        return th;
    }
}

static void runeLoadConfig(void) {
    Boolean valid = false;
    kEnabled = CFPreferencesGetAppBooleanValue(CFSTR("EnableRune"), CFSTR("com.krasei.rune"), &valid);
    if (!valid) kEnabled = NO;

    NSMutableSet *set = [NSMutableSet set];
    DIR *dir = opendir(kRuneIconsDir);
    if (dir) {
        struct dirent *e;
        while ((e = readdir(dir)) != NULL) {
            NSString *name = [NSString stringWithUTF8String:e->d_name];
            if (name.length && [[name.pathExtension lowercaseString] isEqualToString:@"png"])
                [set addObject:[[name stringByDeletingPathExtension] lowercaseString]];
        }
        closedir(dir);
    }
    NSMutableDictionary *nameMap = [NSMutableDictionary dictionary];
    for (NSString *name in set) {
        NSString *lower = [name lowercaseString];
        nameMap[lower] = name;
    }
    kThemedBIDs = [set copy];
    kImageCache = [NSMutableDictionary dictionary];
    kRuneNameMap = [nameMap copy];
}

%hook SBIconImageView

- (void)updateImageContentsWithImage:(UIImage *)image
                      imageAppearance:(id)appearance
                    isRealContentsImage:(BOOL)real
                            animated:(BOOL)animated {
    if (!kEnabled) {
        %orig(image, appearance, real, animated);
        return;
    }
    NSString *bid = runeFetchBID(self);
    UIImage *th = runeThemedForBID(bid);
    if (th) {
        %orig(th, appearance, real, animated);
        return;
    }
    %orig(image, appearance, real, animated);
}

- (void)setDisplayedImage:(UIImage *)image {
    if (!kEnabled) {
        %orig(image);
        return;
    }
    if (image != nil) {
        NSString *bid = runeFetchBID(self);
        UIImage *th = runeThemedForBID(bid);
        if (th) {
            %orig(th);
            return;
        }
    }
    %orig(image);
}

%end

%hook SBHIconImageCache

- (UIImage *)cachedImageForIcon:(id)icon {
    if (!kEnabled) return %orig(icon);
    UIImage *img = %orig(icon);
    NSString *bid = runeResolveBID(icon);
    UIImage *th = runeThemedForBID(bid);
    if (th) return th;
    return img;
}

- (UIImage *)imageForIcon:(id)icon imageAppearance:(id)appearance options:(unsigned long long)options {
    if (!kEnabled) return %orig(icon, appearance, options);
    UIImage *img = %orig(icon, appearance, options);
    NSString *bid = runeResolveBID(icon);
    UIImage *th = runeThemedForBID(bid);
    if (th) return th;
    return img;
}

%end

%ctor {
    runeLoadConfig();
    notify_register_dispatch("com.krasei.rune.settingschanged", &kRuneNotifyToken, dispatch_get_main_queue(), ^(int token) {
        runeLoadConfig();
    });
}
