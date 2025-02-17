#import "uYouPlusSettings.h"
#import "RootOptionsController.h"
#import "ColourOptionsController.h"
#import "ColourOptionsController2.h"
#import "SettingsKeys.h"
#import "AppIconOptionsController.h"

#define VERSION_STRING [[NSString stringWithFormat:@"%@", @(OS_STRINGIFY(TWEAK_VERSION))] stringByReplacingOccurrencesOfString:@"\"" withString:@""]
#define SHOW_RELAUNCH_YT_SNACKBAR [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"RESTART_YOUTUBE")]]

#define SECTION_HEADER(s) [sectionItems addObject:[%c(YTSettingsSectionItem) itemWithTitle:@"\t" titleDescription:[s uppercaseString] accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger sectionItemIndex) { return NO; }]]

#define SPOOFER_VERSION(version, index) \
    [YTSettingsSectionItemClass checkmarkItemWithTitle:version titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) { \
        [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"versionSpoofer"]; \
        [settingsViewController reloadData]; \
        return YES; \
    }]

// Basic Switch
#define SWITCH(title, description, key, ...) \
    [sectionItems addObject:[%c(YTSettingsSectionItem) \
        switchItemWithTitle:title \
        titleDescription:description \
        accessibilityIdentifier:nil \
        switchOn:IS_ENABLED(key) \
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) { \
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key]; \
            __VA_ARGS__; \
            return YES; \
        } \
        settingItemId:0 \
    ]]

// Switch with Restart popup (SHOW_RELAUNCH_YT_SNACKBAR;)
#define SWITCH2(title, description, key) \
    SWITCH(title, description, key, SHOW_RELAUNCH_YT_SNACKBAR)

// Switch with customizable code
#define SWITCH3(title, description, key, code) \
    [sectionItems addObject:[%c(YTSettingsSectionItem) \
        switchItemWithTitle:title \
        titleDescription:description \
        accessibilityIdentifier:nil \
        switchOn:IS_ENABLED(key) \
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enable) { \
            code \
        } \
        settingItemId:0]]

/** Example SWITCH3 Usage
SWITCH3(
    LOC(@"Your title here"), 
    LOC(@"Your description here"), 
    @"yourKey_enabled",
    // Custom code goes in this block, wrapped in ({...}); Make sure to return YES at the end
    ({
        // Show an alert if this setting is being enabled
        if (enable) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"Some alert message here" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okAction];
            [settingsViewController presentViewController:alert animated:YES completion:nil];
        }
        // Update the setting in the storage and reload
        [[NSUserDefaults standardUserDefaults] setBool:enable forKey:@"yourKey_enabled"];
        [settingsViewController reloadData];
        SHOW_RELAUNCH_YT_SNACKBAR;
        return YES;
    });
);
*/

static void ResetNetworkSettings() { // "Refresh Connection"
    NSURLSession *session = [NSURLSession sharedSession];
    [session invalidateAndCancel];
    [session resetWithCompletionHandler:^{
    }];
}
static NSString *GetCacheSize() { // YTLite - @dayanch96
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:cachePath error:nil];

    unsigned long long int folderSize = 0;
    for (NSString *fileName in filesArray) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:fileName];
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        folderSize += [fileAttributes fileSize];
    }

    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;

    return [formatter stringFromByteCount:folderSize];
}
static int contrastMode() {
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSComparisonResult result1 = [appVersion compare:@"17.33.2" options:NSNumericSearch];
    NSComparisonResult result2 = [appVersion compare:@"17.38.10" options:NSNumericSearch];

    if (result1 != NSOrderedAscending && result2 != NSOrderedDescending) {
        return [[NSUserDefaults standardUserDefaults] integerForKey:@"lcm"];
    } else {
        return 0;
    }
}
static int appVersionSpoofer() { // App Version Spoofer
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"versionSpoofer"];
}
static int getNotificationIconStyle() { // Notifications Tab
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"notificationIconStyle"];
}
static const NSInteger uYouPlusSection = 500;

@interface YTSettingsSectionItemManager (uYouPlus)
- (void)updateTweakSectionWithEntry:(id)entry;
@end

extern NSBundle *uYouPlusBundle();

// Settings Search Bar
%hook YTSettingsViewController
- (void)loadWithModel:(id)model fromView:(UIView *)view {
    %orig;
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == uYouPlusSection)
        MSHookIvar<BOOL>(self, "_shouldShowSearchBar") = YES;
}
- (void)setSectionControllers {
    %orig;
    if (MSHookIvar<BOOL>(self, "_shouldShowSearchBar")) {
        YTSettingsSectionController *settingsSectionController = [self settingsSectionControllers][[self valueForKey:@"_detailsCategoryID"]];
        YTSearchableSettingsViewController *searchableVC = [self valueForKey:@"_searchableSettingsViewController"];
        if (settingsSectionController)
            [searchableVC storeCollectionViewSections:@[settingsSectionController]];
    }
}
%end

// Settings
%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSMutableArray *mutableOrder = [order mutableCopy];
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound)
        [mutableOrder insertObject:@(uYouPlusSection) atIndex:insertIndex + 1];
    return mutableOrder;
}
%end

%hook YTSettingsSectionController
- (void)setSelectedItem:(NSUInteger)selectedItem {
    if (selectedItem != NSNotFound) %orig;
}
%end

%hook YTSettingsSectionItemManager
%new(v@:@)
- (void)updateTweakSectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = uYouPlusBundle();
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    # pragma mark - About
    // SECTION_HEADER(LOC(@"ABOUT"));

    YTSettingsSectionItem *version = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"uYouEnhanced")
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            return VERSION_STRING;
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@""]];
        }
    ];
    [sectionItems addObject:version];

    YTSettingsSectionItem *bug = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"REPORT_AN_ISSUE")
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSString *url = [NSString stringWithFormat:@"https://github.com/arichornlover/uYouEnhanced/issues/new?assignees=&labels=bug&projects=&template=bug.yaml&title=[v%@] %@", VERSION_STRING, LOC(@"ADD_TITLE")];

            return [%c(YTUIUtils) openURL:[NSURL URLWithString:[url stringByReplacingOccurrencesOfString:@" " withString:@"%20"]]];
        }
    ];
    [sectionItems addObject:bug];

    YTSettingsSectionItem *developers = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"SUPPORT_THE_DEVELOPERS")
        titleDescription:LOC(@"MiRO92, PoomSmart, level3tjg, BandarHL, julioverne & Galactic-dev")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            return nil;
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/arichornlover/uYouEnhanced/blob/main/README.md#support-the-developers"]];
        }
    ];
    [sectionItems addObject:developers];

# pragma mark - Copy/Export and Paste/Import Settings
    YTSettingsSectionItem *copySettings = [%c(YTSettingsSectionItem)
        itemWithTitle:IS_ENABLED(kReplaceCopyandPasteButtons) ? LOC(@"EXPORT_SETTINGS") : LOC(@"COPY_SETTINGS")
        titleDescription:IS_ENABLED(kReplaceCopyandPasteButtons) ? LOC(@"EXPORT_SETTINGS_DESC") : LOC(@"COPY_SETTINGS_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            if (IS_ENABLED(kReplaceCopyandPasteButtons)) {
                // Export Settings functionality
                NSURL *tempFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"uYouEnhancedSettings.txt"]];
                NSMutableString *settingsString = [NSMutableString string];
                for (NSString *key in NSUserDefaultsCopyKeys) {
                    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
                    if (value) {
                        [settingsString appendFormat:@"%@: %@\n", key, value];
                    }
                }
                [settingsString writeToURL:tempFileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
                UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:tempFileURL inMode:UIDocumentPickerModeExportToService];
                documentPicker.allowsMultipleSelection = NO;
                [settingsViewController presentViewController:documentPicker animated:YES completion:nil];
            } else {
                // Copy Settings functionality (DEFAULT - Copies to Clipboard)
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                NSMutableString *settingsString = [NSMutableString string];
                for (NSString *key in NSUserDefaultsCopyKeys) {
                    id value = [userDefaults objectForKey:key];
                    id defaultValue = NSUserDefaultsCopyKeysDefaults[key];

                    // Only include the setting if it is different from the default value
                    // If no default value is found, include it by default
                    if (value && (!defaultValue || ![value isEqual:defaultValue])) {
                        [settingsString appendFormat:@"%@: %@\n", key, value];
                    }
                }       
                [[UIPasteboard generalPasteboard] setString:settingsString];
                // Show a confirmation message or perform some other action here
                [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:@"Settings copied"]];
            }
            // Prompt to export uYouEnhanced settings - @bhackel
            UIAlertController *exportAlert = [UIAlertController alertControllerWithTitle:@"Export Settings" message:@"Note: This feature cannot save iSponsorBlock and most YouTube settings.\n\nWould you like to also export your uYouEnhanced Settings?" preferredStyle:UIAlertControllerStyleAlert];
            [exportAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [exportAlert addAction:[UIAlertAction actionWithTitle:@"Export" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // Export uYouEnhanced Settings functionality - @bhackhel
                [%c(YTLUserDefaults) exportYtlSettings];
            }]];
            [settingsViewController presentViewController:exportAlert animated:YES completion:nil];
            return YES;
        }
    ];
    [sectionItems addObject:copySettings];

    YTSettingsSectionItem *pasteSettings = [%c(YTSettingsSectionItem)
        itemWithTitle:IS_ENABLED(kReplaceCopyandPasteButtons) ? LOC(@"IMPORT_SETTINGS") : LOC(@"PASTE_SETTINGS")
        titleDescription:IS_ENABLED(kReplaceCopyandPasteButtons) ? LOC(@"IMPORT_SETTINGS_DESC") : LOC(@"PASTE_SETTINGS_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            if (IS_ENABLED(@"replaceCopyandPasteButtons_enabled")) {
                // Import Settings functionality
                UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.text"] inMode:UIDocumentPickerModeImport];
                documentPicker.allowsMultipleSelection = NO;
                documentPicker.delegate = self;
                [settingsViewController presentViewController:documentPicker animated:YES completion:nil];
                return YES;
            } else {
                // Paste Settings functionality (default behavior)
                UIAlertController *confirmPasteAlert = [UIAlertController alertControllerWithTitle:LOC(@"Are you sure you want to paste the settings?") message:nil preferredStyle:UIAlertControllerStyleAlert];
                [confirmPasteAlert addAction:[UIAlertAction actionWithTitle:LOC(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
                [confirmPasteAlert addAction:[UIAlertAction actionWithTitle:LOC(@"Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSString *settingsString = [[UIPasteboard generalPasteboard] string];
                    if (settingsString.length > 0) {
                        NSArray *lines = [settingsString componentsSeparatedByString:@"\n"];
                        for (NSString *line in lines) {
                            NSArray *components = [line componentsSeparatedByString:@": "];
                            if (components.count == 2) {
                                NSString *key = components[0];
                                NSString *value = components[1];
                                [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
                            }
                        }                 
                        [settingsViewController reloadData];
                        [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:@"Settings applied"]];
                        SHOW_RELAUNCH_YT_SNACKBAR;
                    }
                }]];
                [settingsViewController presentViewController:confirmPasteAlert animated:YES completion:nil];
            }
            // Reminder to import uYouEnhanced settings - @bhackel
            UIAlertController *reminderAlert = [UIAlertController alertControllerWithTitle:@"Reminder" 
                                                                                message:@"Remember to import your uYouEnhanced settings as well." 
                                                                            preferredStyle:UIAlertControllerStyleAlert];
            [reminderAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [settingsViewController presentViewController:reminderAlert animated:YES completion:nil];
            return YES;
        }
    ];
    [sectionItems addObject:pasteSettings];

    SWITCH(LOC(@"REPLACE_COPY_AND_PASTE_BUTTONS"), LOC(@"REPLACE_COPY_AND_PASTE_BUTTONS_DESC"), kReplaceCopyandPasteButtons);

    YTSettingsSectionItem *exitYT = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"QUIT_YOUTUBE")
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            // https://stackoverflow.com/a/17802404/19227228
            [[UIApplication sharedApplication] performSelector:@selector(suspend)];
            [NSThread sleepForTimeInterval:0.5];
            exit(0);
        }
    ];
    [sectionItems addObject:exitYT];

    SECTION_HEADER(LOC(@"📺 App Personalization"));
    # pragma mark - uYouEnhanced Essential Menu
    YTSettingsSectionItem *customAppMenu = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"UYOUENHANCED_ESSENTIAL_MENU")
        titleDescription:LOC(@"This menu includes App Color Customization 🎨 & Ability to Clear the Cache 🗑️")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            RootOptionsController *rootOptionsController = [[RootOptionsController alloc] init];
            [settingsViewController.navigationController pushViewController:rootOptionsController animated:YES];
            return YES;
        }
    ];
    [sectionItems addObject:customAppMenu];

    YTSettingsSectionItem *appIcon = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"CHANGE_APP_ICON")
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            AppIconOptionsController *appIconController = [[AppIconOptionsController alloc] init];
            [settingsViewController.navigationController pushViewController:appIconController animated:YES];
            return YES;
        }
    ];
    [sectionItems addObject:appIcon];

NSString *cacheDescription = [NSString stringWithFormat:@"%@", GetCacheSize()];
    YTSettingsSectionItem *clearCache = [%c(YTSettingsSectionItem)
        itemWithTitle:@"Clear Cache"
        titleDescription:cacheDescription
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
                [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"Done") firstResponder:[self parentResponder]] send];
                });
            });
            return YES;
        }
    ];
    [sectionItems addObject:clearCache];

    YTSettingsSectionItem *refreshConnection = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"REFRESH_CONNECTION")
        titleDescription:LOC(@"REFRESH_CONNECTION_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            ResetNetworkSettings();
            return YES;
        }
    ];
    [sectionItems addObject:refreshConnection];

    # pragma mark - App theme
    SECTION_HEADER(LOC(@"THEME_OPTIONS"));

    YTSettingsSectionItem *themeGroup = [YTSettingsSectionItemClass
        itemWithTitle:LOC(@"DARK_THEME")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            switch (APP_THEME_IDX) {
                case 1:
                    return LOC(@"OLD_DARK_THEME");
                case 2:
                    return LOC(@"OLED_DARK_THEME_2");
                case 0:
                default:
                    return LOC(@"DEFAULT_THEME");
            }
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [YTSettingsSectionItemClass
                    checkmarkItemWithTitle:LOC(@"DEFAULT_THEME")
                    titleDescription:LOC(@"DEFAULT_THEME_DESC")
                    selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kAppTheme];
                        [settingsViewController reloadData];
                        SHOW_RELAUNCH_YT_SNACKBAR;
                        return YES;
                    }
                ],
                [YTSettingsSectionItemClass
                    checkmarkItemWithTitle:LOC(@"OLD_DARK_THEME")
                    titleDescription:LOC(@"OLD_DARK_THEME_DESC")
                    selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:kAppTheme];
                        [settingsViewController reloadData];
                        SHOW_RELAUNCH_YT_SNACKBAR;
                        return YES;
                    }
                ],
                [YTSettingsSectionItemClass
                    checkmarkItemWithTitle:LOC(@"OLED_DARK_THEME")
                    titleDescription:LOC(@"OLED_DARK_THEME_DESC")
                    selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:kAppTheme];
                        [settingsViewController reloadData];
                        SHOW_RELAUNCH_YT_SNACKBAR;
                        return YES;
                    }
                ],
                [YTSettingsSectionItemClass
                    checkmarkItemWithTitle:LOC(@"CUSTOM_DARK_THEME")
                    titleDescription:LOC(@"In order to use Custom Themes, go to uYouEnhanced Essential Menu, you will need to press Custom Theme Color and than change the colors.")
                    selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:kAppTheme];
                        [settingsViewController reloadData];
                        SHOW_RELAUNCH_YT_SNACKBAR;
                        return YES;
                    }
                ],
                [YTSettingsSectionItemClass
                    switchItemWithTitle:LOC(@"OLED_KEYBOARD")
                    titleDescription:LOC(@"OLED_KEYBOARD_DESC")
                    accessibilityIdentifier:nil
                    switchOn:IS_ENABLED(kOLEDKeyboard)
                    switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kOLEDKeyboard];
                        SHOW_RELAUNCH_YT_SNACKBAR;
                        return YES;
                    }
                    settingItemId:0
                ]
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                initWithNavTitle:LOC(@"THEME_OPTIONS")
                pickerSectionTitle:[LOC(@"THEME_OPTIONS") uppercaseString]
                rows:rows selectedItemIndex:APP_THEME_IDX
                parentResponder:[self parentResponder]
            ];
            [settingsViewController pushViewController:picker];
            return YES;
        }
    ];
    [sectionItems addObject:themeGroup];

    # pragma mark - Video player options
    SECTION_HEADER(LOC(@"VIDEO_PLAYER_OPTIONS"));

    SWITCH2(LOC(@"ENABLE_PORTRAIT_FULLSCREEN"), LOC(@"ENABLE_PORTRAIT_FULLSCREEN_DESC"), kPortraitFullscreen);
    SWITCH2(LOC(@"FULLSCREEN_TO_THE_RIGHT"), LOC(@"FULLSCREEN_TO_THE_RIGHT_DESC"), kFullscreenToTheRight);
    SWITCH2(LOC(@"SLIDE_TO_SEEK"), LOC(@"SLIDE_TO_SEEK_DESC"), kSlideToSeek);
    SWITCH2(LOC(@"ENABLE_TAP_TO_SEEK"), LOC(@"ENABLE_TAP_TO_SEEK_DESC"), kYTTapToSeek);
    SWITCH(LOC(@"DISABLE_DOUBLE_TAP_TO_SEEK"), LOC(@"DISABLE_DOUBLE_TAP_TO_SEEK_DESC"), kDoubleTapToSeek);
    SWITCH(LOC(@"SNAP_TO_CHAPTER"), LOC(@"SNAP_TO_CHAPTER_DESC"), kSnapToChapter);
    SWITCH2(LOC(@"PINCH_TO_ZOOM"), LOC(@"PINCH_TO_ZOOM_DESC"), kPinchToZoom);
    SWITCH(LOC(@"YT_MINIPLAYER"), LOC(@"YT_MINIPLAYER_DESC"), kYTMiniPlayer);
    SWITCH2(LOC(@"STOCK_VOLUME_HUD"), LOC(@"STOCK_VOLUME_HUD_DESC"), kStockVolumeHUD);
    SWITCH(LOC(@"REPLACE_YT_DOWNLOAD_WITH_UYOU"), LOC(@"REPLACE_YT_DOWNLOAD_WITH_UYOU_DESC"), kReplaceYTDownloadWithuYou);
    SWITCH2(LOC(@"DISABLE_PULL_TO_FULLSCREEN_GESTURE"), LOC(@"ENABLE_PORTRAIT_FULLSCREEN_DESC"), kDisablePullToFull);
    SWITCH(LOC(@"DISABLE_DOUBLE_TAP_TO_SKIP_CHAPTER"), LOC(@"DISABLE_DOUBLE_TAP_TO_SKIP_CHAPTER_DESC"), kDisableChapterSkip);
    SWITCH(LOC(@"ALWAYS_USE_REMAINING_TIME"), LOC(@"ALWAYS_USE_REMAINING_TIME_DESC"), kAlwaysShowRemainingTime);
    SWITCH(LOC(@"DISABLE_TOGGLE_TIME_REMAINING"), LOC(@"DISABLE_TOGGLE_TIME_REMAINING_DESC"), kDisableRemainingTime);

    # pragma mark - Video controls overlay options
    SECTION_HEADER(LOC(@"VIDEO_CONTROLS_OVERLAY_OPTIONS"));

    SWITCH(LOC(@"ENABLE_SHARE_BUTTON"), LOC(@"ENABLE_SHARE_BUTTON_DESC"), kEnableShareButton);
    SWITCH(LOC(@"ENABLE_SAVE_TO_PLAYLIST_BUTTON"), LOC(@"ENABLE_SAVE_TO_PLAYLIST_BUTTON_DESC"), kEnableSaveToButton);
    SWITCH(LOC(@"HIDE_YTMUSIC_BUTTON"), LOC(@"HIDE_YTMUSIC_BUTTON_DESC"), kHideYTMusicButton);
    SWITCH(LOC(@"HIDE_AUTOPLAY_SWITCH"), LOC(@"HIDE_AUTOPLAY_SWITCH_DESC"), kHideAutoplaySwitch);
    SWITCH(LOC(@"HIDE_SUBTITLES_BUTTON"), LOC(@"HIDE_SUBTITLES_BUTTON_DESC"), kHideCC);
    SWITCH(LOC(@"HIDE_VIDEO_TITLE_IN_FULLSCREEN"), LOC(@"HIDE_VIDEO_TITLE_IN_FULLSCREEN_DESC"), kHideVideoTitle);
    SWITCH(LOC(@"HIDE_COLLAPSE_BUTTON"), LOC(@"HIDE_COLLAPSE_BUTTON_DESC"), kDisableCollapseButton);
    SWITCH(LOC(@"HIDE_FULLSCREEN_BUTTON"), LOC(@"HIDE_FULLSCREEN_BUTTON_DESC"), kDisableFullscreenButton);
    SWITCH(LOC(@"HIDE_HUD_MESSAGES"), LOC(@"HIDE_HUD_MESSAGES_DESC"), kHideHUD);
    SWITCH(LOC(@"HIDE_PAID_PROMOTION_CARDS"), LOC(@"HIDE_PAID_PROMOTION_CARDS_DESC"), kHidePaidPromotionCard);
    SWITCH2(LOC(@"HIDE_CHANNEL_WATERMARK"), LOC(@"HIDE_CHANNEL_WATERMARK_DESC"), kHideChannelWatermark);
    SWITCH2(LOC(@"HIDE_SHADOW_OVERLAY_BUTTONS"), LOC(@"HIDE_SHADOW_OVERLAY_BUTTONS_DESC"), kHideVideoPlayerShadowOverlayButtons);
    SWITCH2(LOC(@"HIDE_PREVIOUS_AND_NEXT_BUTTON"), LOC(@"HIDE_PREVIOUS_AND_NEXT_BUTTON_DESC"), kHidePreviousAndNextButton);
    SWITCH2(LOC(@"RED_PROGRESS_BAR"), LOC(@"RED_PROGRESS_BAR_DESC"), kRedProgressBar);
    SWITCH(LOC(@"HIDE_HOVER_CARD"), LOC(@"HIDE_HOVER_CARD_DESC"), kHideHoverCards);
    SWITCH2(LOC(@"HIDE_RIGHT_PANEL"), LOC(@"HIDE_RIGHT_PANEL_DESC"), kHideRightPanel);
    SWITCH2(LOC(@"HIDE_FULLSCREEN_ACTION_BUTTONS"), LOC(@"HIDE_FULLSCREEN_ACTION_BUTTONS_DESC"), kHideFullscreenActions);
    SWITCH2(LOC(@"HIDE_SUGGESTED_VIDEO"), LOC(@"HIDE_SUGGESTED_VIDEO_DESC"), kHideSuggestedVideo);
    SWITCH2(LOC(@"HIDE_HEATWAVES_BAR"), LOC(@"HIDE_HEATWAVES_BAR_DESC"), kHideHeatwaves);
    SWITCH2(LOC(@"HIDE_DOUBLE_TAP_TO_SEEK_OVERLAY"), LOC(@"HIDE_DOUBLE_TAP_TO_SEEK_OVERLAY_DESC"), kHideDoubleTapToSeekOverlay);
    SWITCH2(LOC(@"HIDE_DARK_OVERLAY_BACKGROUND"), LOC(@"HIDE_DARK_OVERLAY_BACKGROUND_DESC"), kHideOverlayDarkBackground);
    SWITCH2(LOC(@"HIDE_AMBIENT_MODE_IN_FULLSCREEN"), LOC(@"HIDE_AMBIENT_MODE_IN_FULLSCREEN_DESC"), kDisableAmbientMode);
    SWITCH2(LOC(@"HIDE_SUGGESTED_VIDEOS_IN_FULLSCREEN"), LOC(@"HIDE_SUGGESTED_VIDEOS_IN_FULLSCREEN_DESC"), kHideVideosInFullscreen);
    SWITCH3(
        LOC(@"HIDE_ALL_VIDEOS_UNDER_PLAYER"), 
        LOC(@"HIDE_ALL_VIDEOS_UNDER_PLAYER_DESC"), 
        kHideRelatedWatchNexts,
        ({
            if (enable) {
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"Enabling this option will not hide the videos under the player on an iPad while being in Landscape Mode." preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                    [alert addAction:okAction];
                    [settingsViewController presentViewController:alert animated:YES completion:nil];
                }
                [[NSUserDefaults standardUserDefaults] setBool:enable forKey:kHideRelatedWatchNexts];
                [settingsViewController reloadData];
                SHOW_RELAUNCH_YT_SNACKBAR;
                return YES;
            }
            [[NSUserDefaults standardUserDefaults] setBool:enable forKey:kHideRelatedWatchNexts];
            [settingsViewController reloadData];
            SHOW_RELAUNCH_YT_SNACKBAR;
            return YES;
        });
    );

   # pragma mark - Shorts controls overlay options
    SECTION_HEADER(LOC(@"SHORTS_CONTROLS_OVERLAY_OPTIONS"));

    SWITCH(LOC(@"HIDE_SUPER_THANKS"), LOC(@"HIDE_SUPER_THANKS_DESC"), kHideBuySuperThanks);
    SWITCH(LOC(@"HIDE_SUBCRIPTIONS"), LOC(@"HIDE_SUBCRIPTIONS_DESC"), kHideSubscriptions);
    // SWITCH(LOC(@"DISABLE_RESUME_TO_SHORTS"), LOC(@"DISABLE_RESUME_TO_SHORTS_DESC"), kDisableResumeToShorts);
    SWITCH2(LOC(@"SHORTS_QUALITY_PICKER"), LOC(@"SHORTS_QUALITY_PICKER_DESC"), kShortsQualityPicker);

    # pragma mark - Video player button options
    SECTION_HEADER(LOC(@"VIDEO_PLAYER_BUTTON_OPTIONS"));

// (the options "Red Subscribe Button" and "Hide Button Containers under player" are currently not working, would most likely result in effecting the whole entire app.)
//
//  SWITCH(LOC(@"RED_SUBSCRIBE_BUTTON"), LOC(@"RED_SUBSCRIBE_BUTTON_DESC"), kRedSubscribeButton);
//  SWITCH2(LOC(@"HIDE_BUTTON_CONTAINERS_UNDER_PLAYER"), LOC(@"HIDE_BUTTON_CONTAINERS_UNDER_PLAYER_DESC"), kHideButtonContainers);
    SWITCH(LOC(@"HIDE_CONNECT_BUTTON"), LOC(@"HIDE_CONNECT_BUTTON_DESC"), kHideConnectButton);
    SWITCH(LOC(@"HIDE_SHARE_BUTTON"), LOC(@"HIDE_SHARE_BUTTON_DESC"), kHideShareButton);
    SWITCH(LOC(@"HIDE_REMIX_BUTTON"), LOC(@"HIDE_REMIX_BUTTON_DESC"), kHideRemixButton);
    SWITCH(LOC(@"HIDE_THANKS_BUTTON"), LOC(@"HIDE_THANKS_BUTTON_DESC"), kHideThanksButton);
    SWITCH(LOC(@"HIDE_DOWNLOAD_BUTTON"), LOC(@"HIDE_DOWNLOAD_BUTTON_DESC"), kHideDownloadButton);
    SWITCH(LOC(@"HIDE_CLIP_BUTTON"), LOC(@"HIDE_CLIP_BUTTON_DESC"), kHideClipButton);
    SWITCH(LOC(@"HIDE_SAVE_BUTTON"), LOC(@"HIDE_SAVE_BUTTON_DESC"), kHideSaveToPlaylistButton);
    SWITCH(LOC(@"HIDE_REPORT_BUTTON"), LOC(@"HIDE_REPORT_BUTTON_DESC"), kHideReportButton);
    SWITCH(LOC(@"HIDE_COMMENT_PREVIEWS_UNDER_PLAYER"), LOC(@"HIDE_COMMENT_PREVIEWS_UNDER_PLAYER_DESC"), kHidePreviewCommentSection);
    SWITCH(LOC(@"HIDE_COMMENT_SECTION_BUTTON"), LOC(@"HIDE_COMMENT_SECTION_BUTTON_DESC"), kHideCommentSection);

# pragma mark - App settings overlay options
    SECTION_HEADER(LOC(@"App Settings Overlay Options"));

    SWITCH2(LOC(@"HIDE_ACCOUNT_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableAccountSection);
//  SWITCH2(LOC(@"Hide `DontEatMyContent` Section"), LOC(@"RESTART_REQUIRED"), kDisableDontEatMyContentSection);
//  SWITCH2(LOC(@"Hide `YouTube Return Dislike` Section"), LOC(@"RESTART_REQUIRED"), kDisableReturnYouTubeDislikeSection);
//  SWITCH2(LOC(@"Hide `YouPiP` Section"), LOC(@"RESTART_REQUIRED"), kDisableYouPiPSection);
    SWITCH2(LOC(@"HIDE_AUTOPLAY_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableAutoplaySection);
    SWITCH2(LOC(@"HIDE_TRY_NEW_FEATURES_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableTryNewFeaturesSection);
    SWITCH2(LOC(@"HIDE_VIDEO_QUALITY_PREFERENCES_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableVideoQualityPreferencesSection);
    SWITCH2(LOC(@"HIDE_NOTIFICATIONS_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableNotificationsSection);
    SWITCH2(LOC(@"HIDE_MANAGE_ALL_HISTORY_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableManageAllHistorySection);
    SWITCH2(LOC(@"HIDE_YOUR_DATA_IN_YOUTUBE_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableYourDataInYouTubeSection);
    SWITCH2(LOC(@"HIDE_PRIVACY_SECTION"), LOC(@"RESTART_REQUIRED"), kDisablePrivacySection);
    SWITCH2(LOC(@"HIDE_LIVE_CHAT_SECTION"), LOC(@"RESTART_REQUIRED"), kDisableLiveChatSection);
    SWITCH2(LOC(@"HIDE_GET_YOUTUBE_PREMIUM_SECTION"), LOC(@"RESTART_REQUIRED"), kHidePremiumPromos);

    # pragma mark - UI interface options
    SECTION_HEADER(LOC(@"UI_INTERFACE_OPTIONS"));

    SWITCH2(LOC(@"HIDE_HOME_TAB"), LOC(@"RESTART_REQUIRED"), kHideHomeTab);
    SWITCH3(
        LOC(@"LOW_CONTRAST_MODE"),
        LOC(@"LOW_CONTRAST_MODE_DESC"),
        kLowContrastMode,
        ({
            if (enable) {
                Class YTVersionUtilsClass = %c(YTVersionUtils);
                NSString *appVersion = [YTVersionUtilsClass performSelector:@selector(appVersion)];
                NSComparisonResult result1 = [appVersion compare:@"17.33.2" options:NSNumericSearch];
                NSComparisonResult result2 = [appVersion compare:@"17.38.10" options:NSNumericSearch];
                if (result1 == NSOrderedAscending) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Discontinued" message:[NSString stringWithFormat:@"You are using v%@ which is a discontinued version of YouTube that no longer works. Please use v17.33.2-17.38.10 in order to use LowContrastMode.", appVersion] preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                    [alert addAction:okAction];
                    [settingsViewController presentViewController:alert animated:YES completion:nil];
                    return NO;
                } else if (result2 == NSOrderedDescending) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Incompatible" message:[NSString stringWithFormat:@"LowContrastMode is only available for app versions v17.33.2-v17.38.10. \nYou are currently using v%@. \nWorkaround: if you want to use this then I recommend enabling \"Fix LowContrastMode\" Option.", appVersion] preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                    [alert addAction:okAction];
                    [settingsViewController presentViewController:alert animated:YES completion:nil];
                    return NO;
            } else if (UIScreen.mainScreen.traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Light Mode Detected" message:@"LowContrastMode is only available in Dark Mode. Please switch to Dark Mode to be able to use LowContrastMode." preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okAction];
                [settingsViewController presentViewController:alert animated:YES completion:nil];
                return NO;
                }
            }
            [[NSUserDefaults standardUserDefaults] setBool:enable forKey:kLowContrastMode];
            [settingsViewController reloadData];
            SHOW_RELAUNCH_YT_SNACKBAR;
            return YES;
        });
    );
    YTSettingsSectionItem *lowContrastModeButton = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"LOW_CONTRAST_MODE_SELECTOR")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            switch (contrastMode()) {
                case 1:
                    return LOC(@"CUSTOM_COLOR");
                case 0:
                default:
                    return LOC(@"DEFAULT");
            }
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            if (contrastMode() == 0) {
                // Get the current version (including spoofed versions)
                Class YTVersionUtilsClass = %c(YTVersionUtils);
                NSString *appVersion = [YTVersionUtilsClass performSelector:@selector(appVersion)];
                // Alert the user that they need to enable the fix
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Incompatibile" message:[NSString stringWithFormat:@"LowContrastMode is only available for app versions v17.33.2-v17.38.10. \nYou are currently using v%@. \n\nWorkaround: if you want to use this then I recommend enabling \"Fix LowContrastMode\" Option.", appVersion] preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okAction];
                [settingsViewController presentViewController:alert animated:YES completion:nil];
                return NO;
            } else {
                NSArray <YTSettingsSectionItem *> *rows = @[
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"Default") titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"lcm"];
                        [settingsViewController reloadData];
                        return YES;
                    }],
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"Custom Color") titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"lcm"];
                        [settingsViewController reloadData];
                        return YES;
                    }]

                ];
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Low Contrast Mode Selector") pickerSectionTitle:nil rows:rows selectedItemIndex:contrastMode() parentResponder:[self parentResponder]];
                [settingsViewController pushViewController:picker];
                return YES;
            }
        }
    ];
    [sectionItems addObject:lowContrastModeButton];
    SWITCH2(LOC(@"CLASSIC_VIDEO_PLAYER"), LOC(@"CLASSIC_VIDEO_PLAYER_DESC"), kClassicVideoPlayer);
    SWITCH2(LOC(@"FIX_LOWCONTRASTMODE"), LOC(@"FIX_LOWCONTRASTMODE_DESC"), kFixLowContrastMode);
    SWITCH2(LOC(@"DISABLE_MODERN_BUTTONS"), LOC(@"DISABLE_MODERN_BUTTONS_DESC"), kDisableModernButtons);
    SWITCH2(LOC(@"DISABLE_ROUNDED_CORNERS_ON_HINTS"), LOC(@"DISABLE_ROUNDED_CORNERS_ON_HINTS_DESC"), kDisableRoundedHints);
    SWITCH2(LOC(@"DISABLE_MODERN_FLAGS"), LOC(@"DISABLE_MODERN_FLAGS_DESC"), kDisableModernFlags);
    SWITCH3(
        LOC(@"YTNOMODERNUI"), 
        LOC(@"YTNOMODERNUI_DESC"), 
        kYTNoModernUI,
        ({
            if (enable) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning" message:@"This will force-enable other settings on restart. To disable them, you must turn this setting off." preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okAction];
                [settingsViewController presentViewController:alert animated:YES completion:nil];
            }
            [[NSUserDefaults standardUserDefaults] setBool:enable forKey:kYTNoModernUI];
            [settingsViewController reloadData];
            SHOW_RELAUNCH_YT_SNACKBAR;
            return YES;
        });
    );
    SWITCH2(LOC(@"ENABLE_APP_VERSION_SPOOFER"), LOC(@"ENABLE_APP_VERSION_SPOOFER_DESC"), kEnableVersionSpoofer);
    
    YTSettingsSectionItem *versionSpoofer = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"VERSION_SPOOFER_SELECTOR")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            switch (appVersionSpoofer()) {
                case 1:
                    return @"v19.49.5";
                case 2:
                    return @"v19.49.3";
                case 3:
                    return @"v19.47.7";
                case 4:
                    return @"v19.46.3";
                case 5:
                    return @"v19.45.4";
                case 6:
                    return @"v19.44.4";
                case 7:
                    return @"v19.43.2";
                case 8:
                    return @"v19.42.1";
                case 9:
                    return @"v19.41.3";
                case 10:
                    return @"v19.40.4";
                case 11:
                    return @"v19.39.1";
                case 12:
                    return @"v19.38.2";
                case 13:
                    return @"v19.37.2";
                case 14:
                    return @"v19.36.1";
                case 15:
                    return @"v19.35.3";
                case 16:
                    return @"v19.34.2";
                case 17:
                    return @"v19.33.2";
                case 18:
                    return @"v19.32.8";
                case 19:
                    return @"v19.32.6";
                case 20:
                    return @"v19.31.4";
                case 21:
                    return @"v19.30.2";
                case 22:
                    return @"v19.29.1";
                case 23:
                    return @"v19.28.1";
                case 24:
                    return @"v19.26.5";
                case 25:
                    return @"v19.25.4";
                case 26:
                    return @"v19.25.3";
                case 27:
                    return @"v19.24.3";
                case 28:
                    return @"v19.24.2";
                case 29:
                    return @"v19.23.3";
                case 30:
                    return @"v19.22.6";
                case 31:
                    return @"v19.22.3";
                case 32:
                    return @"v19.21.3";
                case 33:
                    return @"v19.21.2";
                case 34:
                    return @"v19.20.2";
                case 35:
                    return @"v19.19.7";
                case 36:
                    return @"v19.19.5";
                case 37:
                    return @"v19.18.2";
                case 38:
                    return @"v19.17.2";
                case 39:
                    return @"v19.16.3";
                case 40:
                    return @"v19.15.1";
                case 41:
                    return @"v19.14.3";
                case 42:
                    return @"v19.14.2";
                case 43:
                    return @"v19.13.1";
                case 44:
                    return @"v19.12.3";
                case 45:
                    return @"v19.10.7";
                case 46:
                    return @"v19.10.6";
                case 47:
                    return @"v19.10.5";
                case 48:
                    return @"v19.09.4";
                case 49:
                    return @"v19.09.3";
                case 50:
                    return @"v19.08.2";
                case 51:
                    return @"v19.07.5";
                case 52:
                    return @"v19.07.4";
                case 53:
                    return @"v19.06.2";
                case 54:
                    return @"v19.05.5";
                case 55:
                    return @"v19.05.3";
                case 56:
                    return @"v19.04.3";
                case 57:
                    return @"v19.03.2";
                case 58:
                    return @"v19.02.1";
                case 59:
                    return @"v19.01.1";
                case 60:
                    return @"v18.49.3";
                case 61:
                    return @"v18.48.3";
                case 62:
                    return @"v18.46.3";
                case 63:
                    return @"v18.45.2";
                case 64:
                    return @"v18.44.3";
                case 65:
                    return @"v18.43.4";
                case 66:
                    return @"v18.41.5";
                case 67:
                    return @"v18.41.3";
                case 68:
                    return @"v18.41.2";
                case 69:
                    return @"v18.40.1";
                case 70:
                    return @"v18.39.1";
                case 71:
                    return @"v18.38.2";
                case 72:
                    return @"v18.35.4";
                case 73:
                    return @"v18.34.5 (Deprecated)";
                case 74:
                    return @"v18.33.3 (Deprecated)";
                case 75:
                    return @"v18.33.2 (Deprecated)";
                case 76:
                    return @"v18.32.2 (Deprecated)";
                case 77:
                    return @"v18.31.3 (Deprecated)";
                case 78:
                    return @"v18.30.7 (Deprecated)";
                case 79:
                    return @"v18.30.6 (Deprecated)";
                case 80:
                    return @"v18.29.1 (Deprecated)";
                case 81:
                    return @"v18.28.3 (Deprecated)";
                case 82:
                    return @"v18.27.3 (Deprecated)";
                case 83:
                    return @"v18.25.1 (Deprecated)";
                case 84:
                    return @"v18.23.3 (Deprecated)";
                case 85:
                    return @"v18.22.9 (Deprecated)";
                case 86:
                    return @"v18.21.3 (Deprecated)";
                case 87:
                    return @"v18.20.3 (Deprecated)";
                case 88:
                    return @"v18.19.1 (Deprecated)";
                case 89:
                    return @"v18.18.2 (Deprecated)";
                case 90:
                    return @"v18.17.2 (Deprecated)";
                case 91:
                    return @"v18.16.2 (Deprecated)";
                case 92:
                    return @"v18.15.1 (Deprecated)";
                case 93:
                    return @"v18.14.1 (Deprecated)";
                case 94:
                    return @"v18.13.4 (Deprecated)";
                case 95:
                    return @"v18.12.2 (Deprecated)";
                case 96:
                    return @"v18.11.2 (Deprecated)";
                case 97:
                    return @"v18.10.1 (Deprecated)";
                case 98:
                    return @"v18.09.4 (Deprecated)";
                case 99:
                    return @"v18.08.1 (Deprecated)";
                case 100:
                    return @"v18.07.5 (Deprecated)";
                case 101:
                    return @"v18.05.2 (Deprecated)";
                case 102:
                    return @"v18.04.3 (Deprecated)";
                case 103:
                    return @"v18.03.3 (Deprecated)";
                case 104:
                    return @"v18.02.03 (Deprecated)";
                case 105:
                    return @"v18.01.6 (Deprecated)";
                case 106:
                    return @"v18.01.4 (Deprecated)";
                case 107:
                    return @"v18.01.2 (Deprecated)";
                case 108:
                    return @"v17.49.6 (Deprecated)";
                case 109:
                    return @"v17.49.4 (Deprecated)";
                case 110:
                    return @"v17.46.4 (Deprecated)";
                case 111:
                    return @"v17.45.1 (Deprecated)";
                case 112:
                    return @"v17.44.4 (Deprecated)";
                case 113:
                    return @"v17.43.1 (Deprecated)";
                case 114:
                    return @"v17.42.7 (Deprecated)";
                case 115:
                    return @"v17.42.6 (Deprecated)";
                case 116:
                    return @"v17.41.2 (Deprecated)";
                case 117:
                    return @"v17.40.5 (Deprecated)";
                case 118:
                    return @"v17.39.4 (Deprecated)";
                case 119:
                    return @"v17.38.10 (Deprecated)";
                case 120:
                    return @"v17.38.9 (Deprecated)";
                case 121:
                    return @"v17.37.2 (Deprecated)";
                case 122:
                    return @"v17.36.4 (Deprecated)";
                case 123:
                    return @"v17.36.3 (Deprecated)";
                case 124:
                    return @"v17.35.3 (Deprecated)";
                case 125:
                    return @"v17.34.3 (Deprecated)";
                case 126:
                    return @"v17.33.2 (Deprecated)";
                case 0:
                default:
                    return @"v19.49.7";
            }
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                SPOOFER_VERSION(@"v19.49.7", 0),
                SPOOFER_VERSION(@"v19.49.5", 1),
                SPOOFER_VERSION(@"v19.49.3", 2),
                SPOOFER_VERSION(@"v19.47.7", 3),
                SPOOFER_VERSION(@"v19.46.3", 4),
                SPOOFER_VERSION(@"v19.45.4", 5),
                SPOOFER_VERSION(@"v19.44.4", 6),
                SPOOFER_VERSION(@"v19.43.2", 7),
                SPOOFER_VERSION(@"v19.42.1", 8),
                SPOOFER_VERSION(@"v19.41.3", 9),
                SPOOFER_VERSION(@"v19.40.4", 10),
                SPOOFER_VERSION(@"v19.39.1", 11),
                SPOOFER_VERSION(@"v19.38.2", 12),
                SPOOFER_VERSION(@"v19.37.2", 13),
                SPOOFER_VERSION(@"v19.36.1", 14),
                SPOOFER_VERSION(@"v19.35.3", 15),
                SPOOFER_VERSION(@"v19.34.2", 16),
                SPOOFER_VERSION(@"v19.33.2", 17),
                SPOOFER_VERSION(@"v19.32.8", 18),
                SPOOFER_VERSION(@"v19.32.6", 19),
                SPOOFER_VERSION(@"v19.31.4", 20),
                SPOOFER_VERSION(@"v19.30.2", 21),
                SPOOFER_VERSION(@"v19.29.1", 22),
                SPOOFER_VERSION(@"v19.28.1", 23),
                SPOOFER_VERSION(@"v19.26.5", 24),
                SPOOFER_VERSION(@"v19.25.4", 25),
                SPOOFER_VERSION(@"v19.25.3", 26),
                SPOOFER_VERSION(@"v19.24.3", 27),
                SPOOFER_VERSION(@"v19.24.2", 28),
                SPOOFER_VERSION(@"v19.23.3", 29),
                SPOOFER_VERSION(@"v19.22.6", 30),
                SPOOFER_VERSION(@"v19.22.3", 31),
                SPOOFER_VERSION(@"v19.21.3", 32),
                SPOOFER_VERSION(@"v19.21.2", 33),
                SPOOFER_VERSION(@"v19.20.2", 34),
                SPOOFER_VERSION(@"v19.19.7", 35),
                SPOOFER_VERSION(@"v19.19.5", 36),
                SPOOFER_VERSION(@"v19.18.2", 37),
                SPOOFER_VERSION(@"v19.17.2", 38),
                SPOOFER_VERSION(@"v19.16.3", 39),
                SPOOFER_VERSION(@"v19.15.1", 40),
                SPOOFER_VERSION(@"v19.14.3", 41),
                SPOOFER_VERSION(@"v19.14.2", 42),
                SPOOFER_VERSION(@"v19.13.1", 43),
                SPOOFER_VERSION(@"v19.12.3", 44),
                SPOOFER_VERSION(@"v19.10.7", 45),
                SPOOFER_VERSION(@"v19.10.6", 46),
                SPOOFER_VERSION(@"v19.10.5", 47),
                SPOOFER_VERSION(@"v19.09.4", 48),
                SPOOFER_VERSION(@"v19.09.3", 49),
                SPOOFER_VERSION(@"v19.08.2", 50),
                SPOOFER_VERSION(@"v19.07.5", 51),
                SPOOFER_VERSION(@"v19.07.4", 52),
                SPOOFER_VERSION(@"v19.06.2", 53),
                SPOOFER_VERSION(@"v19.05.5", 54),
                SPOOFER_VERSION(@"v19.05.3", 55),
                SPOOFER_VERSION(@"v19.04.3", 56),
                SPOOFER_VERSION(@"v19.03.2", 57),
                SPOOFER_VERSION(@"v19.02.1", 58),
                SPOOFER_VERSION(@"v19.01.1", 59),
                SPOOFER_VERSION(@"v18.49.3", 60),
                SPOOFER_VERSION(@"v18.48.3", 61),
                SPOOFER_VERSION(@"v18.46.3", 62),
                SPOOFER_VERSION(@"v18.45.2", 63),
                SPOOFER_VERSION(@"v18.44.3", 64),
                SPOOFER_VERSION(@"v18.43.4", 65),
                SPOOFER_VERSION(@"v18.41.5", 66),
                SPOOFER_VERSION(@"v18.41.3", 67),
                SPOOFER_VERSION(@"v18.41.2", 68),
                SPOOFER_VERSION(@"v18.40.1", 69),
                SPOOFER_VERSION(@"v18.39.1", 70),
                SPOOFER_VERSION(@"v18.38.2", 71),
                SPOOFER_VERSION(@"v18.35.4", 72),
                SPOOFER_VERSION(@"v18.34.5", 73),
                SPOOFER_VERSION(@"v18.33.3", 74),
                SPOOFER_VERSION(@"v18.33.2", 75),
                SPOOFER_VERSION(@"v18.32.2", 76),
                SPOOFER_VERSION(@"v18.31.3", 77),
                SPOOFER_VERSION(@"v18.30.7", 78),
                SPOOFER_VERSION(@"v18.30.6", 79),
                SPOOFER_VERSION(@"v18.29.1", 80),
                SPOOFER_VERSION(@"v18.28.3", 81),
                SPOOFER_VERSION(@"v18.27.3", 82),
                SPOOFER_VERSION(@"v18.25.1", 83),
                SPOOFER_VERSION(@"v18.23.3", 84),
                SPOOFER_VERSION(@"v18.22.9", 85),
                SPOOFER_VERSION(@"v18.21.3", 86),
                SPOOFER_VERSION(@"v18.20.3", 87),
                SPOOFER_VERSION(@"v18.19.1", 88),
                SPOOFER_VERSION(@"v18.18.2", 89),
                SPOOFER_VERSION(@"v18.17.2", 90),
                SPOOFER_VERSION(@"v18.16.2", 91),
                SPOOFER_VERSION(@"v18.15.1", 92),
                SPOOFER_VERSION(@"v18.14.1", 93),
                SPOOFER_VERSION(@"v18.13.4", 94),
                SPOOFER_VERSION(@"v18.12.2", 95),
                SPOOFER_VERSION(@"v18.11.2", 96),
                SPOOFER_VERSION(@"v18.10.1", 97),
                SPOOFER_VERSION(@"v18.09.4", 98),
                SPOOFER_VERSION(@"v18.08.1", 99),
                SPOOFER_VERSION(@"v18.07.5", 100),
                SPOOFER_VERSION(@"v18.05.2", 101),
                SPOOFER_VERSION(@"v18.04.3", 102),
                SPOOFER_VERSION(@"v18.03.3", 103),
                SPOOFER_VERSION(@"v18.02.03", 104),
                SPOOFER_VERSION(@"v18.01.6", 105),
                SPOOFER_VERSION(@"v18.01.4", 106),
                SPOOFER_VERSION(@"v18.01.2", 107),
                SPOOFER_VERSION(@"v17.49.6", 108),
                SPOOFER_VERSION(@"v17.49.4", 109),
                SPOOFER_VERSION(@"v17.46.4", 110),
                SPOOFER_VERSION(@"v17.45.1", 111),
                SPOOFER_VERSION(@"v17.44.4", 112),
                SPOOFER_VERSION(@"v17.43.1", 113),
                SPOOFER_VERSION(@"v17.42.7", 114),
                SPOOFER_VERSION(@"v17.42.6", 115),
                SPOOFER_VERSION(@"v17.41.2", 116),
                SPOOFER_VERSION(@"v17.40.5", 117),
                SPOOFER_VERSION(@"v17.39.4", 118),
                SPOOFER_VERSION(@"v17.38.10", 119),
                SPOOFER_VERSION(@"v17.38.9", 120),
                SPOOFER_VERSION(@"v17.37.2", 121),
                SPOOFER_VERSION(@"v17.36.4", 122),
                SPOOFER_VERSION(@"v17.36.3", 123),
                SPOOFER_VERSION(@"v17.35.3", 124),
                SPOOFER_VERSION(@"v17.34.3", 125),
                SPOOFER_VERSION(@"v17.33.2", 126)
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"VERSION_SPOOFER_SELECTOR") pickerSectionTitle:nil rows:rows selectedItemIndex:appVersionSpoofer() parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }
    ];
    [sectionItems addObject:versionSpoofer];

    # pragma mark - Miscellaneous
    SECTION_HEADER(LOC(@"MISCELLANEOUS"));

    SWITCH2(LOC(@"YouTube Sign-In Patch"), LOC(@"When turned on, you can sign in to the YouTube App when Sideloaded.\nHowever, most material ui icons might disappear, and notifications could stop working.\nThis fix will automatically turn off after two app restarts."), kGoogleSignInPatch);
    SWITCH2(LOC(@"ADBLOCK_WORKAROUND_LITE"), LOC(@"ADBLOCK_WORKAROUND_LITE_DESC"), kAdBlockWorkaroundLite);
    SWITCH2(LOC(@"ADBLOCK_WORKAROUND"), LOC(@"ADBLOCK_WORKAROUND_DESC"), kAdBlockWorkaround);
    SWITCH3(
        LOC(@"FAKE_PREMIUM"),
        LOC(@"FAKE_PREMIUM_DESC"),
        kYouTabFakePremium,
        ({
            // Get the current version (including spoofed versions)
            Class YTVersionUtilsClass = %c(YTVersionUtils);
            NSString *appVersion = [YTVersionUtilsClass performSelector:@selector(appVersion)];
            // Alert if the version is partially incompatible and the toggle is being turned on
            NSComparisonResult result = [appVersion compare:@"18.35.4" options:NSNumericSearch];
            if (enable && result == NSOrderedAscending) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning" message:[NSString stringWithFormat:@"The \"You\" Tab doesn't exist in v%@, fake buttons will not be created.\nBut the \"Fake Premium Logo\" will still work.", appVersion] preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:okAction];
                [settingsViewController presentViewController:alert animated:YES completion:nil];
            }
            // Enable the "Disable Animated YouTube Logo" setting
            [[NSUserDefaults standardUserDefaults] setBool:enable forKey:kDisableAnimatedYouTubeLogo];
            // Refresh data and show the relaunch popup
            [[NSUserDefaults standardUserDefaults] setBool:enable forKey:kYouTabFakePremium];
            [settingsViewController reloadData];
            SHOW_RELAUNCH_YT_SNACKBAR;
            return YES;
        });
    );
    SWITCH(LOC(@"DISABLE_ANIMATED_YOUTUBE_LOGO"), nil, kDisableAnimatedYouTubeLogo);
    SWITCH(LOC(@"CENTER_YOUTUBE_LOGO"), LOC(@"CENTER_YOUTUBE_LOGO_DESC"), kCenterYouTubeLogo);
    SWITCH(LOC(@"HIDE_YOUTUBE_LOGO"), LOC(@"HIDE_YOUTUBE_LOGO_DESC"), kHideYouTubeLogo);
    SWITCH2(LOC(@"ENABLE_YT_STARTUP_ANIMATION"), LOC(@"ENABLE_YT_STARTUP_ANIMATION_DESC"), kYTStartupAnimation);
    SWITCH(LOC(@"DISABLE_HINTS"), LOC(@"DISABLE_HINTS_DESC"), kDisableHints);
    SWITCH(LOC(@"STICK_NAVIGATION_BAR"), LOC(@"STICK_NAVIGATION_BAR_DESC"), kStickNavigationBar);
    SWITCH2(LOC(@"HIDE_ISPONSORBLOCK"), nil, kHideiSponsorBlockButton);
    SWITCH(LOC(@"HIDE_CHIP_BAR"), LOC(@"HIDE_CHIP_BAR_DESC"), kHideChipBar);
    SWITCH2(LOC(@"Enable Notifications Tab"), LOC(@"Makes the Notifications Tab appear back onto the Pivot Bar, experimental: Testing customization options."), kShowNotificationsTab);
    YTSettingsSectionItem *notificationIconStyle = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"Notifications Tab nostalgic customization")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            switch (getNotificationIconStyle()) {
                case 1:
                    return @"Thin Outline (2020+)";
                case 2:
                    return @"Filled (2018+)";
                case 3:
                    return @"Classic/Inbox (2014+)";
                case 0:
                default:
                    return @"Default";
            }
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [YTSettingsSectionItemClass checkmarkItemWithTitle:@"Default" titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"notificationIconStyle"];
                    [settingsViewController reloadData];
                    return YES;
                }],
                [YTSettingsSectionItemClass checkmarkItemWithTitle:@"Thin Outline (2020+)" titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"notificationIconStyle"];
                    [settingsViewController reloadData];
                    return YES;
                }],
                [YTSettingsSectionItemClass checkmarkItemWithTitle:@"Filled (2018+)" titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"notificationIconStyle"];
                    [settingsViewController reloadData];
                    return YES;
                }],
                [YTSettingsSectionItemClass checkmarkItemWithTitle:@"Classic/Inbox (2014+)" titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:@"notificationIconStyle"];
                    [settingsViewController reloadData];
                    return YES;
                }]
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Notifications Tab nostalgic customization") pickerSectionTitle:nil rows:rows selectedItemIndex:getNotificationIconStyle() parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }
    ];
    [sectionItems addObject:notificationIconStyle];
    SWITCH(LOC(@"HIDE_PLAY_NEXT_IN_QUEUE"), LOC(@"HIDE_PLAY_NEXT_IN_QUEUE_DESC"), kHidePlayNextInQueue);
    SWITCH2(LOC(@"HIDE_COMMUNITY_POSTS"), LOC(@"HIDE_COMMUNITY_POSTS_DESC"), kHideCommunityPosts);
    SWITCH2(LOC(@"HIDE_HEADER_LINKS_UNDER_PROFILE"), LOC(@"HIDE_HEADER_LINKS_UNDER_PROFILE_DESC"), kHideChannelHeaderLinks);
    SWITCH2(LOC(@"IPHONE_LAYOUT"), LOC(@"IPHONE_LAYOUT_DESC"), kiPhoneLayout);
    SWITCH2(LOC(@"NEW_MINIPLAYER_STYLE"), LOC(@"NEW_MINIPLAYER_STYLE_DESC"), kBigYTMiniPlayer);
    SWITCH2(LOC(@"YT_RE_EXPLORE"), LOC(@"YT_RE_EXPLORE_DESC"), kReExplore);
    SWITCH2(LOC(@"AUTO_HIDE_HOME_INDICATOR"), LOC(@"AUTO_HIDE_HOME_INDICATOR_DESC"), kAutoHideHomeBar);
    SWITCH2(LOC(@"HIDE_INDICATORS"), LOC(@"HIDE_INDICATORS_DESC"), kHideSubscriptionsNotificationBadge);
    SWITCH2(LOC(@"FIX_CASTING"), LOC(@"FIX_CASTING_DESC"), kFixCasting);
    SWITCH2(LOC(@"NEW_SETTINGS_UI"), LOC(@"NEW_SETTINGS_UI_DESC"), kNewSettingsUI);
    SWITCH(LOC(@"ENABLE_FLEX"), LOC(@"ENABLE_FLEX_DESC"), kFlex);

    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)])
        [settingsViewController setSectionItems:sectionItems forCategory:uYouPlusSection title:@"uYouEnhanced" icon:nil titleDescription:LOC(@"TITLE DESCRIPTION") headerHidden:YES];
    else
        [settingsViewController setSectionItems:sectionItems forCategory:uYouPlusSection title:@"uYouEnhanced" titleDescription:LOC(@"TITLE DESCRIPTION") headerHidden:YES];
}

// File Manager (Import Settings .txt)
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        NSURL *url = urls.firstObject;
        NSError *error = nil;
        NSString *settingsString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Error reading file: %@", error.localizedDescription);
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Failed to read the settings file." preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            return;
        }
        NSArray *lines = [settingsString componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            NSArray *components = [line componentsSeparatedByString:@": "];
            if (components.count == 2) {
                NSString *key = components[0];
                NSString *value = components[1];
                [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
            }
        }                 
        [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:@"Settings imported"]];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"Document picker was cancelled");
}

//
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == uYouPlusSection) {
        [self updateTweakSectionWithEntry:entry];
        return;
    }
    %orig;
}
%end
