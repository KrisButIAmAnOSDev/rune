#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import <dirent.h>
#import <sys/stat.h>
#import <spawn.h>
#import <sys/wait.h>

#define kRunePrefsDomain "com.krasei.rune"
#define kThemesDir "/var/jb/Library/Themes"
#define kRuneIconsDir "/var/jb/Library/rune/Icons"

static NSArray *runeScanThemes(void) {
    NSMutableArray *themes = [NSMutableArray array];
    DIR *dir = opendir(kThemesDir);
    if (!dir) return themes;
    struct dirent *e;
    while ((e = readdir(dir)) != NULL) {
        NSString *name = [NSString stringWithUTF8String:e->d_name];
        if (name.length < 7 || ![[name pathExtension] isEqualToString:@"theme"]) continue;
        NSString *ib = [NSString stringWithFormat:@"%s/%@/IconBundles", kThemesDir, name];
        struct stat st;
        if (stat([ib UTF8String], &st) != 0 || !S_ISDIR(st.st_mode)) continue;
        // Only count as an icon theme if it has at least one real per-app icon
        // (i.e. a PNG that isn't the generic "Icon.png"). This filters out
        // badge / clock / lockscreen sub-themes.
        BOOL hasAppIcon = NO;
        DIR *ibd = opendir([ib UTF8String]);
        if (ibd) {
            struct dirent *ie;
            while ((ie = readdir(ibd)) != NULL) {
                NSString *fn = [NSString stringWithUTF8String:ie->d_name];
                if (fn.length && ![[fn pathExtension] isEqualToString:@"png"]) continue;
                NSString *base = [fn stringByDeletingPathExtension];
                if (![base isEqualToString:@"Icon"]) { hasAppIcon = YES; break; }
            }
            closedir(ibd);
        }
        if (hasAppIcon) [themes addObject:name];
    }
    closedir(dir);
    return [themes sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSString *runeReadPref(NSString *key) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR(kRunePrefsDomain));
    if (v) {
        if (CFGetTypeID(v) == CFStringGetTypeID()) return (__bridge NSString *)v;
        CFRelease(v);
    }
    return nil;
}

static BOOL runeReadBoolPref(NSString *key, BOOL def) {
    Boolean valid = false;
    Boolean v = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, CFSTR(kRunePrefsDomain), &valid);
    return valid ? (BOOL)v : def;
}

static void runeWritePref(NSString *key, id value) {
    CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value,
                          CFSTR(kRunePrefsDomain), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

static void runeSyncPrefs(void) {
    CFPreferencesAppSynchronize(CFSTR(kRunePrefsDomain));
}

static void runeRespring(void) {
    pid_t pid = 0;
    const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)argv, NULL);
    if (pid > 0) waitpid(pid, NULL, 0);
}

@interface RuneViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *themes;
@property (nonatomic, strong) NSString *selectedTheme;
@property (nonatomic, assign) BOOL enabled;
@end

@implementation RuneViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Rune";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.themes = [@[@"None (Stock)"] arrayByAddingObjectsFromArray:runeScanThemes()];
    self.enabled = runeReadBoolPref(@"EnableRune", NO);

    NSString *sel = runeReadPref(@"SelectedSnowBoardTheme");
    if (!sel || sel.length == 0 || [sel isEqualToString:@"none"]) sel = @"None (Stock)";
    self.selectedTheme = sel;

    self.enableSwitch = [[UISwitch alloc] init];
    self.enableSwitch.on = self.enabled;

    UILabel *enableLabel = [[UILabel alloc] init];
    enableLabel.text = @"Enable Icon Theme";
    enableLabel.font = [UIFont systemFontOfSize:17];
    [enableLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[enableLabel, self.enableSwitch]];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.spacing = 12;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.translatesAutoresizingMaskIntoConstraints = NO;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [applyBtn setTitle:@"Apply" forState:UIControlStateNormal];
    [applyBtn addTarget:self action:@selector(applyTapped) forControlEvents:UIControlEventTouchUpInside];
    applyBtn.backgroundColor = [UIColor systemBlueColor];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.layer.cornerRadius = 10;
    applyBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [applyBtn.heightAnchor constraintEqualToConstant:46].active = YES;

    UIStackView *main = [[UIStackView alloc] initWithArrangedSubviews:@[topRow, self.tableView, applyBtn]];
    main.axis = UILayoutConstraintAxisVertical;
    main.spacing = 16;
    main.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:main];

    [NSLayoutConstraint activateConstraints:@[
        [main.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [main.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [main.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [main.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [self.tableView.heightAnchor constraintGreaterThanOrEqualToConstant:200],
    ]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.themes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    NSString *name = self.themes[indexPath.row];
    cell.textLabel.text = name;
    cell.accessoryType = [name isEqualToString:self.selectedTheme] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.selectedTheme = self.themes[indexPath.row];
    [tableView reloadData];
}

- (void)applyTapped {
    self.enabled = self.enableSwitch.on;
    NSString *themeValue = [self.selectedTheme isEqualToString:@"None (Stock)"] ? @"none" : self.selectedTheme;

    runeWritePref(@"EnableRune", self.enabled ? @YES : @NO);
    runeWritePref(@"SelectedSnowBoardTheme", themeValue);
    runeSyncPrefs();

    notify_post("com.krasei.rune.settingschanged");

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Rune"
                                                              message:@"Settings saved. Respring to fully apply the theme."
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        runeRespring();
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *nav;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    RuneViewController *vc = [[RuneViewController alloc] init];
    self.nav = [[UINavigationController alloc] initWithRootViewController:vc];
    self.window.rootViewController = self.nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
