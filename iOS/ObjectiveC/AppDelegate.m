#import <AdSupport/AdSupport.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import "AlertManager.h"
#import "AppDelegate.h"
#import "AppSettings.h"
#import "BaseNavigationController.h"
#import "BaseTabBarController.h"
#import "DatabaseDataDefines.h"
#import "DatabaseDefines.h"
#import "FoxitRDK/FSPDFObjC.h"
#import "HomeViewController.h"
#import "LocalNotificationsScheduler.h"
#import "MACAddress.h"
#import "NSDictionary+Extensions.h"
#import "NSString+Extensions.h"
#import "RegisterUserViewController.h"
#import "ScanHistoryViewController.h"
#import "ScanViewController.h"
#import "SettingsViewController.h"
#import "SiteTimeLogsViewController.h"
#import "SyncViewController.h"
#import "UIAlertController+supportedInterfaceOrientations.h"
#import "UIColor+Extensions.h"
#import "UserManager.h"
#import "UsersViewController.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize tabBarController = _tabBarController;
@synthesize enteredBackground = _enteredBackground;
@synthesize connection = _connection;
@synthesize responseData = _responseData;
@synthesize clLocationManager = _clLocationManager;

- (NSString *)deviceUniqueIdentifier
{
    // Returns a unique identifier for the device
    
    NSString *vendorIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];

    ASIdentifierManager *asIdentifierManager = [ASIdentifierManager sharedManager];
    NSString *advertisingIdentifier = [[asIdentifierManager advertisingIdentifier] UUIDString];
    
    return (![vendorIdentifier isEqualToString:[NSString stringWithEmptyUUID]] ? vendorIdentifier : advertisingIdentifier);
}

#pragma mark - Application management

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Register Foxit SDK
    NSString *serialNumberFoxit = @"lHGjtRivGIb7Z7gFq2zyWAHM3Otw8x/Nm3MBFa701gOIliwH0/u57Q==";
    NSString *keyFoxit = @"ezJvj1/GvGh39zvoP2Xsb3l67x+ioyBWyhPMX8ez50+yjsFWj2EjwL1l/RosH9WpTetMRotZw4iZ8sAscFYe1+sLuznlMnn95zLQYsuCwIHEbDkwPXqCYPdQ9MhTsJc10y20RN/DDydwh4Ssk+fXP1VBkOL/1K3n5A1pSuTcsy/UHC+u6KT/+U7qmn3N0O1DxMlenw442tVVsmjO5xBG0TbQakbLW+RBU9XPhuKijp0lGTgIeFkDUQ0FxtQzszY3Y7oSf/GzSWfOctrDAP0xU4ZMstP1OlcPLGrMcl2/cMqua1+Hk5z8zmtOBswmtx9RBIquUC2XFyf1ORfKssUQ6jh1rXFCcGB1c0kc/di/TG5Yo4zyLjImZ53XCZ0R5uabh6YXiMlzq5XHfnLm9dpyglozlKM413vTZZh8vPT4fEK8ZcAp9LZ43fxqKyFmKDd7xiDq8hOyYvv7xgUYpLB2xU8dU32KdLHijXkplBZbhCZB+PgI28OfU/aSVCRD8FePhZamXgIlDMiMZBpvNLyUpQ5PlCEOSJIPWiLb0YBuVq5xSJKHMH2VYahkE8hFoh2DD8xeGZD3ED9l6kEMDSZMz/mLLMXeYyt4GwSCSZ2uEsG+0//mE6acapJ0PdkZ80HPH86CxojkG6O+5BexL0aoeUf/faUu37QXEpA0kzwVLuZGBOFCep0vZuGsnFY1kLHyzS/bsqGshY+pbnszCy3GklQHTwFDrCHRg3ZLAk4uO8/cdWAfxhKnI1HFiT/Z9xPlLf5NXJyGqRBxdMqQdvE4yAIfruUeUtXydqVZFTPFFOTwBC6ySr92ac9kXvBsDbrpKDWwys5ljNR53NsH6wc0s6upHQsxIFYf01U612AampOlXS97jvn98G/RCo5ZY0u/U0z9ar50+WTrLyj80zVVo0rJxQ6VgYPJ3XwdsltLEeWIOwaH+RxT3ZHIVq443clclLNzj9IlUgioRfNvVqQNRmb8FMFo4yp2qd6EFmKk/SH9/uK7uy1T6j3UThrDJtyD46Gax8JfBg1g0Q0zoKgyZWmXktvQLSELcFrQOyz5w6Bg195McJiKCKLk29tmBmlBWA+5bX0WaxggjZm0QpIWtHCos2AOHJI1DjQy9eO0+cC3MNIaEwHS3s44MDXOnozgVoEnlXWLGKK0TxZTLqmcQuHG2C0BDfnChwl23heTuwMJHQ0QD7Y=";
    FSErrorCode errorFoxit = [FSLibrary initialize:serialNumberFoxit key:keyFoxit];
    if (errorFoxit != FSErrSuccess) {
        [self displayAlertWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_ERROR", nil) message:NSLocalizedString(@"APP_DELEGATE_ALERT_FOXIT_INVALID_LICENCE", nil) cancelActionTitle:nil defaultActionTitles:[NSArray arrayWithObject:NSLocalizedString(@"COMMON_BUTTON_OK", nil)]];
    }

    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

    // Register notification settings to allow the application to be badged correctly
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];

    // Make sure the user has a copy of the SQLite database
    [self createEditableCopyOfDatabaseWithFileData:nil forceOverwrite:NO];

    // Load the main tab bar
    [self loadMainTabBar];
    
    self.tabBarController.customizableViewControllers = [NSArray array];
    
    // Show status bar
    application.statusBarHidden = NO;
    
    // Global settings of tint colour for all bar related controls.
    [[UIToolbar appearance] setTintColor:[UIColor engineerAppColorDarkGrey]];
    [[UITabBar appearance] setTintColor:[UIColor anordMardixColorLightBlue]];
    [[UINavigationBar appearance] setTintColor:[UIColor engineerAppColorDarkGrey]];
    [[UISearchBar appearance] setTintColor:[UIColor engineerAppColorDarkGrey]];
    
    // A little trick to get around a known bug that causes a slight delay the first time the keyboard is displayed
    // http://stackoverflow.com/questions/9357026/super-slow-lag-delay-on-initial-keyboard-animation-of-uitextfield
    UITextField *textField = [[UITextField alloc] init];
    [self.window addSubview:textField];
    [textField becomeFirstResponder];
    [textField resignFirstResponder];
    [textField removeFromSuperview];
    [textField release];
    
    // Show window
    [self.window makeKeyAndVisible];

    // Set up the local notifications for any launch notifications
    UILocalNotification *localNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (localNotification)
        [[LocalNotificationsScheduler sharedInstance] handleReceivedNotification:localNotification];

    // Set up the location manager
    /*
    CLLocationManager *clLocationManager = [[CLLocationManager alloc] init];
    self.clLocationManager = clLocationManager;
    [clLocationManager release];
    self.clLocationManager.delegate = self;
    self.clLocationManager.distanceFilter = kCLDistanceFilterNone;
    self.clLocationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.clLocationManager requestWhenInUseAuthorization];
    */

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    // Set time that the app entered the background
    self.enteredBackground = [NSDate date];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    AppSettings *appSettings = [AppSettings sharedInstance];
    
    if (!self.enteredBackground || ([[NSDate date] timeIntervalSinceDate:self.enteredBackground]/60) > appSettings.authenticationTimeoutMinutes)
    {
        if (![self authenticationInProgress])
        {
            // Authentication timeout has expired, so log the user out and enforce authentication
            UserManager *userManager = [UserManager sharedInstance];
            [userManager logout];
        }
        else
        {
            // Authentication was already being enforced when the app was reactivated, so do nothing
        }
    }
    
    NSMutableData *responseData = [[NSMutableData alloc] init];
    self.responseData = responseData;
    [responseData release];
    
    // Initiate a check to see whether the app is the latest version
    // The callback methods for the NSURLConnectionDelegate handle the response
    NSURL *plistUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", appSettings.appInstallUrl, appSettings.appManifestFileName]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:plistUrl];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:10];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    [task resume];
    [request release];
    
    // Check whether a download sync has been run within the recommended timescale
    if (appSettings.lastDownloadSyncDateTime && ([[NSDate date] timeIntervalSinceDate:appSettings.lastDownloadSyncDateTime]/60/60/24) >= appSettings.lastDownloadSyncWarningDays)
    {
        // Download sync has not been run within the recommended timescale, so alert the user
        [self displayAlertWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:[NSString stringWithFormat:NSLocalizedString(@"APP_DELEGATE_ALERT_DOWNLOAD_SYNC_NOT_RUN_WITHIN_TIMESCALE", nil), appSettings.lastDownloadSyncWarningDays] cancelActionTitle:nil defaultActionTitles:[NSArray arrayWithObject:NSLocalizedString(@"COMMON_BUTTON_OK", nil)]];
    }
    
    // Check whether the device has been powered off within the recommended timescale
    if (([[NSDate date] timeIntervalSinceDate:[self powerOnDate]]/60/60/24) >= appSettings.lastDevicePowerOffWarningDays)
    {
        // Device has not been powered off within the recommended timescale, so alert the user
        [self displayAlertWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:[NSString stringWithFormat:NSLocalizedString(@"APP_DELEGATE_ALERT_DEVICE_NOT_POWERED_OFF_WITHIN_TIMESCALE", nil), appSettings.lastDevicePowerOffWarningDays] cancelActionTitle:nil defaultActionTitles:[NSArray arrayWithObject:NSLocalizedString(@"COMMON_BUTTON_OK", nil)]];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

    UserManager *userManager = [UserManager sharedInstance];
    [userManager logout];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    // Called when the application receives a low memory warning
    [self displayAlertWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:NSLocalizedString(@"APP_DELEGATE_ALERT_MEMORY_WARNING", nil) cancelActionTitle:nil defaultActionTitles:[NSArray arrayWithObject:NSLocalizedString(@"COMMON_BUTTON_OK", nil)]];
}

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notification
{
    // Handle in app notifications
    
    // Only handle notifications if app has been brought back into the foreground from a notification confirmation button
    if ([app applicationState] != UIApplicationStateActive)
        [[LocalNotificationsScheduler sharedInstance] handleReceivedNotification:notification];
}

#pragma mark - Tab bar

- (void)loadMainTabBar
{
    // Set up the navigation controllers

    UIViewController *homeViewController = [[[HomeViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    UINavigationController *homeNavController = [[BaseNavigationController alloc] initWithRootViewController:homeViewController];
    
    UIViewController *syncViewController = [[[SyncViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    UINavigationController *syncNavController = [[BaseNavigationController alloc] initWithRootViewController:syncViewController];
    
    UIViewController *scanViewController = [[[ScanViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    UINavigationController *scanNavController = [[BaseNavigationController alloc] initWithRootViewController:scanViewController];
    
    UIViewController *scanHistoryViewController = [[[ScanHistoryViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    UINavigationController *scanHistoryNavController = [[BaseNavigationController alloc] initWithRootViewController:scanHistoryViewController];
    
    UIViewController *siteTimeLogsViewController = [[[SiteTimeLogsViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    UINavigationController *siteTimeLogsNavController = [[BaseNavigationController alloc] initWithRootViewController:siteTimeLogsViewController];

    UIViewController *settingsViewController = [[[SettingsViewController alloc] initWithNibName:nil bundle:nil] autorelease];
    UINavigationController *settingsNavController = [[BaseNavigationController alloc] initWithRootViewController:settingsViewController];
    
    // Create tab bar controller and assign the navigation controllers to it
    UITabBarController *tabBarController = [[[BaseTabBarController alloc] initWithNibName:nil bundle:nil] autorelease];
    tabBarController.delegate = self;
    tabBarController.viewControllers = [NSArray arrayWithObjects:homeNavController, syncNavController, scanNavController, scanHistoryNavController, siteTimeLogsNavController, settingsNavController, nil];
    
    [homeNavController release];
    [syncNavController release];
    [scanNavController release];
    [scanHistoryNavController release];
    [siteTimeLogsNavController release];
    [settingsNavController release];
    
    // Set tab bar controller as root controller
    self.tabBarController = tabBarController;
    self.window.rootViewController = tabBarController;
    
    // Update the badge count
    [self updateSyncBadgeCount];
}

- (void)popAllTabsToRootViewControllerAnimated:(BOOL)animated
{
    // Pops the navigation controller contained within each tab back to their root views
    
    for (UIViewController *viewController in self.tabBarController.viewControllers) {
        if ([viewController isKindOfClass:[UINavigationController class]])
        [(UINavigationController *)viewController popToRootViewControllerAnimated:animated];
    }
}

#pragma mark - Authentication

- (void)unAuthorisedAccess
{
    // Remove the logged-in user from the system
    UserManager *userManager = [UserManager sharedInstance];
    [userManager removeUsername:[userManager getLoggedInUsersUsername]];

    [self.tabBarController dismissViewControllerAnimated:NO completion:nil];
    
    // The user has to re-register
    RegisterUserViewController *reAuthenticateViewController = [[RegisterUserViewController alloc] initWithNibName:nil bundle:nil];
    reAuthenticateViewController.isRegister = NO;
    UINavigationController *reAuthenticateNavController = [[BaseNavigationController alloc] initWithRootViewController:reAuthenticateViewController];
    reAuthenticateNavController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.tabBarController presentViewController:reAuthenticateNavController animated:YES completion:nil];
    [reAuthenticateViewController release];
    [reAuthenticateNavController release];
}

- (void)enforceAuthentication
{
    if (self.tabBarController.selectedIndex == 2)
    {
        // If the user has closed the application whilst the scanner is up, switch back to home tab
        self.tabBarController.selectedIndex = 0;
    }
    
    UsersViewController *userView = [[UsersViewController alloc] init];
    UINavigationController *usersNavigationController = [[BaseNavigationController alloc] initWithRootViewController:userView];
    usersNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tabBarController presentViewController:usersNavigationController animated:NO completion:nil];
    });
    [userView release];
    [usersNavigationController release];
}

- (BOOL)authenticationInProgress
{
    // Returns true if the users screen is already being displayed in a modal window, or false if not
    
    if (self.tabBarController.presentedViewController) {
        if ([self.tabBarController.presentedViewController isKindOfClass:[BaseNavigationController class]]) {
            UIViewController *presentedViewController = ((BaseNavigationController *)(self.tabBarController.presentedViewController)).viewControllers[0];
            if ([presentedViewController isKindOfClass:[UsersViewController class]])
                return YES;
        }
    }
    return NO;
}

#pragma mark - Debugging

- (void)enableAutoLayoutWarnings
{
    // Enables auto layout warnings in debug console
    
    [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
}

- (void)disableAutoLayoutWarnings
{
    // Disables auto layout warnings in debug console
    
    // CAUTION: Use only if you are certain you are receiving temporary warnings during layout manipulation,
    // and ensure you call enableAutoLayoutWarnings as early in the normal code execution path as possible
    
    [[NSUserDefaults standardUserDefaults] setValue:@"NO" forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
}

#pragma mark - Instance methods

- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message cancelActionTitle:(NSString *)cancelActionTitle defaultActionTitles:(NSArray *)defaultActionTitles
{
    // Displays an alert with the specified title, message and action (button) titles and handlers
    // Abstracted as we need to perform a trick of using a second UIWindow to display the alert from the AppDelegate
    // http://stackoverflow.com/questions/36155769/how-to-show-uialertcontroller-from-appdelegate/36156077
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    UIWindow *topWindow = [[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds] autorelease];
    topWindow.rootViewController = [[[UIViewController alloc] init] autorelease];
    topWindow.windowLevel = UIWindowLevelAlert + 1;
    topWindow.hidden = YES;
    
    if (cancelActionTitle) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelActionTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { topWindow.hidden = YES; }];
        [alert addAction:cancelAction];
    }

    for (NSString *defaultActionTitle in defaultActionTitles) {
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultActionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { topWindow.hidden = YES; }];
        [alert addAction:defaultAction];
    }
    
    [topWindow makeKeyAndVisible];
    [topWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (BOOL)createDirectoryAtPath:(NSString *)path
{
    // Creates the directory at the specified path if it does not already exist
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    AppSettings *appSettings = [AppSettings sharedInstance];
    AlertManager *alertManager = [AlertManager sharedInstance];
    NSError *error;
    errors errorType;
    BOOL result = YES;
    
    // Set error type based on relative path
    if (path == appSettings.equipmentDocumentsDirectoryPath)
        errorType = CreateEquipmentDocumentsDirectory;
    else if (path == appSettings.siteVisitReportsDocumentsDirectoryPath)
        errorType = CreateSVRDocumentsDirectory;
    else if (path == appSettings.testSessionDocumentsDirectoryPath)
        errorType = CreateTestSessionDocumentsDirectory;
    else if (path == appSettings.testDocumentsDirectoryPath)
        errorType = CreateTestDocumentsDirectory;
    else
        errorType = CreateDocumentsDirectory;
    
    if (![fileManager fileExistsAtPath:path]) {
        result = [fileManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
        if (!result)
            [alertManager showAlertForErrorType:errorType withError:error];
    }
    
    return result;
}

- (BOOL)createEditableCopyOfDatabaseWithFileData:(id)fileData forceOverwrite:(BOOL)forceOverwrite
{
    // Creates a copy of the SQLite database in the Documents directory of the user's application sandbox
    // If the forceOverwrite flag is not set, the database is only copied to the Documents directory if it doesn't already exist
    // If a SQLite database is not supplied as the fileData parameter, an empty copy is created instead

    AppSettings *appSettings = [AppSettings sharedInstance];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    AlertManager *alertManager = [AlertManager sharedInstance];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Define error handlers
    BOOL success = YES;
    BOOL successRollback = YES;
    errors errorType = UnknownError;
    errors errorTypeRollback = UnknownError;
    NSError *error = nil;
    NSError *errorRollback = nil;

    // Define file paths
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:appSettings.databaseName];
    NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:appSettings.databaseName];
    NSString *writableDBPathBak = [documentsDirectory stringByAppendingPathComponent:appSettings.databaseBackupName];

    if ([fileManager fileExistsAtPath:writableDBPath]) {
        // Database exists in Documents directory, so check the version number stored in its configuration table
        // against the version in [Common/AppSettings.h] (which is the current correct schema version)
        NSDictionary *databaseConfiguration = [databaseManager getDatabaseConfigurationValueFor:TABLE_DATABASE_CONFIGURATION_COLUMN_NAME_VALUE_SCHEMA_VERSION];
        NSString *schemaVersion = [databaseConfiguration nullableObjectForKey:TABLE_DATABASE_CONFIGURATION_COLUMN_VALUE];
        if ([schemaVersion isEqual:appSettings.databaseSchemaVersion] && !forceOverwrite)
            // Database schema is already the most recent version and forceOverwrite flag is not set, so exit method
            return success;
        else {
            // If no file data is supplied, alert the user that the database is being updated to a new schema
            if (!fileData) {
                [self displayAlertWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_INFORMATION", nil) message:NSLocalizedString(@"APP_DELEGATE_ALERT_LOCAL_DATABASE_UPDATED", nil) cancelActionTitle:nil defaultActionTitles:[NSArray arrayWithObject:NSLocalizedString(@"COMMON_BUTTON_OK", nil)]];
            }
        }
    }

    // Get data to be preserved
    NSArray *preservedData = [databaseManager getPreservedData];

    // Rename existing database to create a backup file
    success = [fileManager moveItemAtPath:writableDBPath toPath:writableDBPathBak error:&error];
    if (!success) errorType = errorType == UnknownError ? MoveDatabaseToBak : errorType;
    
    // If file data is supplied, write this as a database file to the user's Documents directory
    if (success && fileData) {
        // Write fileData to database file location
        success = [fileData writeToFile:writableDBPath atomically:YES];
        if (!success) errorType = errorType == UnknownError ? WriteSqliteDataToFile : errorType;
        // Verify that we do actually have a valid database
        else success = [databaseManager verifyDatabase];
        if (!success) errorType = errorType == UnknownError ? VerifyDatabase : errorType;
    }
    
    // If no file data is supplied, copy the template database from the bundle to the user's Documents directory
    if (success && !fileData) {
        // Copy the template database from the bundle to the user's Documents directory
        success = [fileManager copyItemAtPath:defaultDBPath toPath:writableDBPath error:&error];
        if (!success) errorType = errorType == UnknownError ? CopyBlankDatabase : errorType;
    }
    
    // Update database with schema number and preserved data
    if (success) success = [databaseManager createDatabaseConfigurationValue:appSettings.databaseSchemaVersion forKey:TABLE_DATABASE_CONFIGURATION_COLUMN_NAME_VALUE_SCHEMA_VERSION];
    if (!success) errorType = errorType == UnknownError ? UpdateDatabaseSchemaVersion : errorType;
    // Write preserved data back to database
    else success = [databaseManager writePreservedDataBackToDatabase:preservedData];
    if (!success) errorType = errorType == UnknownError ? SavePreservedDataBackToDatabase : errorType;
    
    // If we have any errors, roll back the original database
    if (!success) {
        if ([fileManager fileExistsAtPath:writableDBPath])
            successRollback = [fileManager removeItemAtPath:writableDBPath error:&errorRollback];
        if (!successRollback) errorTypeRollback = errorTypeRollback == UnknownError ? RemoveDatabase : errorTypeRollback;
        else successRollback = [fileManager moveItemAtPath:writableDBPathBak toPath:writableDBPath error:&errorRollback];
        if (!successRollback) errorTypeRollback = errorTypeRollback == UnknownError ? RestoreDatabase : errorTypeRollback;
        // Output any detected errors
        if (errorType != UnknownError) [alertManager showAlertForErrorType:errorType withError:error];
        if (errorTypeRollback != UnknownError) [alertManager showAlertForErrorType:errorTypeRollback withError:errorRollback];
    }
    
    // Remove the backup file
    if (success && [fileManager fileExistsAtPath:writableDBPathBak])
        [fileManager removeItemAtPath:writableDBPathBak error:&errorRollback];

    return success;
}

- (void)updateSyncBadgeCount
{
    // Updates the 'Unsynced' number badge shown on the Sync tab bar icon
    // and also on the app icon on the iOS desktop
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    NSInteger badgeCount = [databaseManager totalNumberOfUnsyncedItems];
    
    // In application badges will show 0 in a badge ... gay ... so make sure 0 is not shown
    if (badgeCount > 0){
        [(UIViewController *)[_tabBarController.viewControllers objectAtIndex:1] tabBarItem].badgeValue = [NSString stringWithFormat:@"%li", (long)badgeCount];
    } else {
        [(UIViewController *)[_tabBarController.viewControllers objectAtIndex:1] tabBarItem].badgeValue = nil;
    }
    
    // Update the application icon (on the phone's icon) with the same badge count ... this badge handles 0
    [UIApplication sharedApplication].applicationIconBadgeNumber = badgeCount;
}

- (void)cleanUpDirectoryWithPath:(NSString *)directoryPath
{
    // Cleans up the specified documents directory
    // This can be necessary because, for example, the SVR documents collection is held in memory until the SVR is saved
    // so we can get files that are left over after being created but not persisted
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    AppSettings *appSettings = [AppSettings sharedInstance];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    // Site visit report documents directory
    if ([directoryPath isEqualToString:appSettings.siteVisitReportsDocumentsDirectoryPath]) {
        for(NSString *fileName in [fileManager contentsOfDirectoryAtPath:directoryPath error:nil])
        {
            NSString *path = [directoryPath stringByAppendingPathComponent:fileName];
            if ([[databaseManager getDocumentByFilePath:[path stringByRemovingDocumentsDirectoryFilepath] includeThumbnail:YES] count] == 0)
                [fileManager removeItemAtPath:path error:nil];
        }
    }
}

- (NSDate *)powerOnDate
{
    // Returns the date the device was last powered on
    // https://stackoverflow.com/questions/11282897/get-the-precise-time-of-system-bootup-on-ios-os-x
    
    #define MIB_SIZE 2
    
    int mib[MIB_SIZE];
    size_t size;
    struct timeval  boottime;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_BOOTTIME;
    size = sizeof(boottime);
    
    if (sysctl(mib, MIB_SIZE, &boottime, &size, NULL, 0) != -1)
        return [NSDate dateWithTimeIntervalSince1970:boottime.tv_sec + boottime.tv_usec / 1.e6];
    
    return nil;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // Delegate method to handle data received in response to the url request sent for the plist file on the deployment server
    
    [self.responseData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // Delegate method called when the data transfer in response to the url request sent for the plist file on the deployment server is complete

    // We have a response that should be a plist, so attempt to deserialise it from the source XML
    CFPropertyListRef plist = CFPropertyListCreateWithData(kCFAllocatorDefault, (CFDataRef)self.responseData, 0, kCFPropertyListImmutable, NULL);
    
    if ([(id)plist isKindOfClass:[NSDictionary class]])
    {
        // Deserialiation successful, so we now attempt to extract the latest app version from the metadata received
        @try {
            NSString *latestAppVersion = [[[[(NSDictionary *)plist objectForKey:@"items"] objectAtIndex:0] objectForKey:@"metadata"] objectForKey:@"bundle-version"];
            if (latestAppVersion) {
                if ([latestAppVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] options:NSNumericSearch] == NSOrderedDescending)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // A later version of the app is available, so alert the user
                        [self displayAlertWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:NSLocalizedString(@"APP_DELEGATE_ALERT_NEWER_APP_VERSION_AVAILABLE", nil) cancelActionTitle:nil defaultActionTitles:[NSArray arrayWithObject:NSLocalizedString(@"COMMON_BUTTON_OK", nil)]];
                    });
                }
            }
        }
        @catch (NSException *exception) {
        }
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    /*
    NSLog(@"Location manager updated locations");
    
    // TODO: Make clGeocoder a property
    // TODO: Re-enable all LocationManager code, including requestLocation calls
    
    if (locations == nil)
        return;
    
    CLLocation *location = [locations objectAtIndex:0];
    
    CLGeocoder *clGeocoder = [[CLGeocoder alloc] init];
    [clGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (placemarks == nil)
            return;
        
        CLPlacemark *clPlacemark = [placemarks objectAtIndex:0];
        NSLog(@"Country: %@", clPlacemark.country);
        NSLog(@"Country code: %@", clPlacemark.ISOcountryCode);
    }];
    [clGeocoder release];
    */
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(nonnull NSError *)error
{
    /*
    NSLog(@"Location manager failed with error");
    */
}

#pragma mark - Deallocation

- (void)dealloc
{
    [_window release];
    [_tabBarController release];
    [_enteredBackground release];
    [_connection release];
    [_responseData release];
    [_clLocationManager release];

    [super dealloc];
}

@end
