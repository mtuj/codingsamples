#import <QuartzCore/QuartzCore.h>
#import "AlertManager.h"
#import "ApiDefines.h"
#import "AppDelegate.h"
#import "AppSettings.h"
#import "CreateSiteVisitReportSignatoryViewController.h"
#import "DatabaseDataDefines.h"
#import "DatabaseDefines.h"
#import "DataWrapper.h"
#import "FileSystemDefines.h"
#import "FormFieldDataDefines.h"
#import "FormFieldDefines.h"
#import "FSPDFDoc+Extensions.h"
#import "ImageManager.h"
#import "JSONDefines.h"
#import "MardixDefaultTableViewCell.h"
#import "MardixImageTableViewCell.h"
#import "NSDate+Extensions.h"
#import "NSDictionary+Extensions.h"
#import "NSString+Extensions.h"
#import "PDFDocumentViewController.h"
#import "QRCodeDefines.h"
#import "RegexDefines.h"
#import "ServiceDocumentsViewController.h"
#import "TestSessionDetailsViewController.h"
#import "UIColor+Extensions.h"
#import "UIAlertController+supportedInterfaceOrientations.h"
#import "UITableView+Extensions.h"
#import "UITableViewCell+Extensions.h"
#import "UIViewController+Extensions.h"
#import "UserManager.h"
#import "ViewImageViewController.h"

@implementation TestSessionDetailsViewController {
    ApiManager *_apiManager;
    NSMutableArray *_tableArray;
    NSInteger _selectedIndex;
    BOOL _presentingModalViewController;
}

@synthesize equipmentData = _equipmentData;
@synthesize testSessionData = _testSessionData;
@synthesize tests = _tests;
@synthesize serviceDocuments = _serviceDocuments;
@synthesize photos = _photos;
@synthesize testSessionTableView = _testSessionTableView;
@synthesize tableFooter = _tableFooter;
@synthesize activationControls = _activationControls;
@synthesize notStarted = _notStarted;
@synthesize notAuthorised = _notAuthorised;
@synthesize activateButton = _activateButton;
@synthesize avCaptureViewController = _avCaptureViewController;
@synthesize selectedTestData = _selectedTestData;
@synthesize buildLocationId = _buildLocationId;
@synthesize pdfDocumentMaster = _pdfDocumentMaster;

#pragma mark - Initialisation

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = NSLocalizedString(@"TEST_SESSION_DETAILS_TITLE", nil);
        _apiManager = [[ApiManager alloc] init];
        _apiManager.delegate = self;
    }
    
    return self;
}

#pragma mark - View management

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self addMardixDefaultBackgroundSubview];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    self.buildLocationId = nil;
    _presentingModalViewController = NO;
    
    // Refresh test session data
    [self refreshTestSession];
    
    // Set up the scanner
    AVCaptureViewController *avCaptureViewController = [[AVCaptureViewController alloc] init];
    self.avCaptureViewController = avCaptureViewController;
    [avCaptureViewController release];
    self.avCaptureViewController.delegate = self;
    self.avCaptureViewController.modalPresentationStyle = UIModalPresentationFullScreen;

    // Populate the array of required table sections and rows
    [self populateTableArray];
    
    // Main table
    UITableView *testSessionTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.testSessionTableView = testSessionTableView;
    [testSessionTableView release];
    [self.testSessionTableView applyMardixStyle];
    self.testSessionTableView.delegate = self;
    self.testSessionTableView.dataSource = self;
    [self.view addSubview:self.testSessionTableView];
    [self applyDefaultConstraintsForFullScreenView:self.testSessionTableView];

    // Table footer view
    // Note we do not add this as a subview; instead we return it in tableView:viewForFooterInSection: to display activation controls (if needed)
    UIView *tableFooter = [[UIView alloc] init];
    self.tableFooter = tableFooter;
    [tableFooter release];
    self.tableFooter.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    // Activation controls
    UIView *activationControls = [[UIView alloc] init];
    self.activationControls = activationControls;
    [activationControls release];
    self.activationControls.translatesAutoresizingMaskIntoConstraints = NO;
    self.activationControls.autoresizesSubviews = YES;
    self.activationControls.backgroundColor = [UIColor whiteColor];
    self.activationControls.layer.borderWidth = 1.0f;
    self.activationControls.layer.borderColor = [[UIColor systemColorGreyTableCellBorder] CGColor];
    [self.tableFooter addSubview:self.activationControls];

    // Message to inform user that the test session is not started
    UILabel *notStarted = [[UILabel alloc] init];
    self.notStarted = notStarted;
    [notStarted release];
    self.notStarted.translatesAutoresizingMaskIntoConstraints = NO;
    self.notStarted.numberOfLines = 0;
    self.notStarted.font = [UIFont systemFontOfSize:14.0f];
    self.notStarted.textAlignment = NSTextAlignmentCenter;
    self.notStarted.text = NSLocalizedString(@"TEST_SESSION_DETAILS_TEXT_TEST_SESSION_NOT_STARTED", nil);
    [self.activationControls addSubview:self.notStarted];
    
    // Button to activate test session
    UIView *activateButtonContainer = [[UIView alloc] init];
    activateButtonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activationControls addSubview:activateButtonContainer];
    [activateButtonContainer release];
    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton setTitle:NSLocalizedString(@"TEST_SESSION_DETAILS_BUTTON_ACTIVATE_TEST_SESSION", nil) forState:UIControlStateNormal];
    [self.activateButton addTarget:self action:@selector(activateTestSession) forControlEvents:UIControlEventTouchUpInside];
    self.activateButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 20.0f, 0.0f, 20.0f);
    [activateButtonContainer addSubview:self.activateButton];

    // Message to inform user they are not authorised to activate the test session
    UILabel *notAuthorised = [[UILabel alloc] init];
    self.notAuthorised = notAuthorised;
    [notAuthorised release];
    self.notAuthorised.translatesAutoresizingMaskIntoConstraints = NO;
    self.notAuthorised.numberOfLines = 0;
    self.notAuthorised.font = [UIFont systemFontOfSize:14.0f];
    self.notAuthorised.textAlignment = NSTextAlignmentCenter;
    self.notAuthorised.text = NSLocalizedString(@"TEST_SESSION_DETAILS_TEXT_NOT_AUTHORISED_TO_ACTIVATE_TEST_SESSION", nil);
    [activateButtonContainer addSubview:self.notAuthorised];

    // Temporarily disable auto layout warnings, as the constraints we are about to apply will throw warnings
    // up to the point where the table footer view frame is corrected in viewDidLayoutSubviews
    [appDelegate disableAutoLayoutWarnings];

    // Layout constraints
    [self.tableFooter addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[_activationControls]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_activationControls)]];
    [self.tableFooter addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_activationControls]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_activationControls)]];
    [self.activationControls addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[_notStarted]-10-[activateButtonContainer]-15-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_notStarted, activateButtonContainer)]];
    [self.activationControls addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_notStarted]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_notStarted)]];
    [self.activationControls addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[activateButtonContainer]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(activateButtonContainer)]];
    [activateButtonContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_activateButton]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_activateButton)]];
    [activateButtonContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_notAuthorised]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_notAuthorised)]];
    [activateButtonContainer addConstraint:[NSLayoutConstraint constraintWithItem:self.activateButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:activateButtonContainer attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [activateButtonContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_notAuthorised]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_notAuthorised)]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_presentingModalViewController)
    {
        // Clear Api loading dialogue
        [self hideProgressIcon];
        
        // Refresh test session data
        [self refreshTestSession];
        
        [self.testSessionTableView reloadData];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    self.activationControls.hidden = YES;
    self.notStarted.hidden = YES;
    self.activateButton.hidden = YES;
    self.notAuthorised.hidden = YES;

    if ([[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqual:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_NOT_STARTED] ||
        [[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqual:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_PRE_ACTIVATED])
    {
        // Test session is not started, so display activation controls
        self.activationControls.hidden = NO;
        self.notStarted.hidden = NO;

        // Display either the activation button, or authorisation warning, depending on whether the user has authorisation or not
        if ([self canActivateTestSession])
            self.activateButton.hidden = NO;
        else
            self.notAuthorised.hidden = NO;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // Recalculate the height of the table view footer - required by autolayout
    // http://stackoverflow.com/questions/16471846/is-it-possible-to-use-autolayout-with-uitableviews-tableheaderview
    // iOS 10 and below only
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 11.0)
    {
        [self.activationControls setNeedsLayout];
        [self.activationControls layoutIfNeeded];
        CGRect frame = self.tableFooter.frame;
        frame.size.height = [self.activationControls systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
        frame.size.width = self.testSessionTableView.bounds.size.width;
        self.tableFooter.frame = frame;
    }

    // Re-enable auto layout warnings, now that the table footer view frame has been corrected
    [appDelegate enableAutoLayoutWarnings];
    
    if ([self canEditTestSession])
    {
        // Test session is in progress, so add button to the navigation bar to allow it to be abandoned
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(abandonTestSession)] autorelease];
    }
    else
        self.navigationItem.rightBarButtonItem = nil;
    
    [self setScrollingEnabledForScrollViewsInView:self.view];
}

#pragma mark - Table array

- (void)populateTableArray
{
    // Populates the array of table sections and rows, which can be different depending on the type of test session
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];

    _tableArray = [[[NSMutableArray alloc] init] retain];

    // Details
    [_tableArray addObject:[self tableSectionDictionaryDetails]];
    
    // Tests
    if ([self.tests count] > 0)
        [_tableArray addObject:[self tableSectionDictionaryTests]];
    
    // Photos
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_PHOTO] boolValue] && [self canEditTestSession])
        [_tableArray addObject:[self tableSectionDictionaryPhotos]];
    
    // Additional Documents
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_ADDITIONAL_DOCUMENTS] boolValue] && [self canEditTestSession])
        [_tableArray addObject:[self tableSectionDictionaryAdditionalDocuments]];
    
    // Verification
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_VERIFICATION] boolValue])
        [_tableArray addObject:[self tableSectionDictionaryVerification]];
    
    // Additional Information
    NSDictionary *additionalInformation = [self tableSectionDictionaryAdditionalInformation];
    if ([((NSArray *)[additionalInformation objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS]) count] > 0)
        [_tableArray addObject:additionalInformation];
    
    // Sign Off
    [_tableArray addObject:[self tableSectionDictionarySignOff]];
}

- (NSDictionary *)tableSectionDictionaryDetails
{
    // Returns a table section dictionary representing Details

    NSArray *details = [NSArray arrayWithObjects:TABLE_EQUIPMENT_COLUMN_PROJECT_NAME,TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_WO_NUMBER,TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME,TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE,TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER,TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER,TABLE_EQUIPMENT_COLUMN_UNIT_DRAWING_REF,nil];
    NSDictionary *detailsRows = [NSDictionary dictionaryWithObjectsAndKeys:
                                 TESTS_TABLE_SECTION_DETAILS, TESTS_TABLE_SECTIONS_KEY_NAME,
                                 details, TESTS_TABLE_SECTIONS_KEY_ROWS, nil];
    return detailsRows;
}

- (NSDictionary *)tableSectionDictionaryTests
{
    // Returns a table section dictionary representing Tests

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];

    NSMutableArray *tests = [NSMutableArray arrayWithArray:self.tests];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_ALLOW_CREATE_TESTS] boolValue]) {
        // If the test session allows tests to be created, include extra placeholder item for 'Add Test' button
        // This will be processed during creation of the table
        [tests addObject:[NSNull null]];
    }
    NSDictionary *testsRows = [NSDictionary dictionaryWithObjectsAndKeys:
                               TESTS_TABLE_SECTION_TESTS, TESTS_TABLE_SECTIONS_KEY_NAME,
                               [NSArray arrayWithArray:tests], TESTS_TABLE_SECTIONS_KEY_ROWS,
                               nil];
    return testsRows;
}

- (NSDictionary *)tableSectionDictionaryPhotos
{
    // Returns a table section dictionary representing Photos

    NSMutableArray *photos = [NSMutableArray arrayWithArray:self.photos];
    // Include extra placeholder item for 'Add Photo' button
    [photos addObject:[NSNull null]];
    NSDictionary *photoRows = [NSDictionary dictionaryWithObjectsAndKeys:
                                             TESTS_TABLE_SECTION_PHOTOS, TESTS_TABLE_SECTIONS_KEY_NAME,
                                             [NSArray arrayWithArray:photos], TESTS_TABLE_SECTIONS_KEY_ROWS,
                                             nil];
    return photoRows;
}

- (NSDictionary *)tableSectionDictionaryAdditionalDocuments
{
    // Returns a table section dictionary representing Additional Documents

    NSDictionary *additionalDocumentsRows = [NSDictionary dictionaryWithObjectsAndKeys:
                                             TESTS_TABLE_SECTION_ADDITIONAL_DOCUMENTS, TESTS_TABLE_SECTIONS_KEY_NAME,
                                             [NSArray arrayWithObjects:TABLE_DOCUMENT_COLUMN_ID,nil], TESTS_TABLE_SECTIONS_KEY_ROWS,
                                             nil];
    return additionalDocumentsRows;
}

- (NSDictionary *)tableSectionDictionaryVerification
{
    // Returns a table section dictionary representing Verification

    NSArray *verification = [NSArray arrayWithObjects:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME,TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION,TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION,nil];
    NSDictionary *verificationRows = [NSDictionary dictionaryWithObjectsAndKeys:
                                      TESTS_TABLE_SECTION_VERIFICATION, TESTS_TABLE_SECTIONS_KEY_NAME,
                                      verification, TESTS_TABLE_SECTIONS_KEY_ROWS,
                                      nil];
    return verificationRows;
}

- (NSDictionary *)tableSectionDictionaryAdditionalInformation
{
    // Returns a table section dictionary representing Additional Information

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];

    NSMutableArray *additionalInformation = [NSMutableArray array];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_EQUIPMENT_LOCATION_REQUIRED_FOR_PASS] boolValue])
        [additionalInformation addObject:TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_PDU_TYPE_SERIALS_RATINGS] boolValue])
        [additionalInformation addObjectsFromArray:[NSArray arrayWithObjects:TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO, nil]];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_UNIT_RATING] boolValue])
        [additionalInformation addObject:TABLE_TEST_SESSION_COLUMN_UNIT_RATING];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_PDU_TYPE_SERIALS_RATINGS] boolValue])
        [additionalInformation addObjectsFromArray:[NSArray arrayWithObjects:TABLE_TEST_SESSION_COLUMN_TX_RATING,TABLE_TEST_SESSION_COLUMN_STS_RATING,TABLE_TEST_SESSION_COLUMN_AHF_RATING, nil]];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_ELECTRICAL_SUPPLY_SYSTEM] boolValue])
        [additionalInformation addObject:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_LOCATION] boolValue])
        [additionalInformation addObject:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_COMMENTS] boolValue])
        [additionalInformation addObject:TABLE_TEST_SESSION_COLUMN_COMMENTS];
    NSDictionary *additionalInformationRows = [NSDictionary dictionaryWithObjectsAndKeys:
                                               TESTS_TABLE_SECTION_ADDITIONAL_INFORMATION, TESTS_TABLE_SECTIONS_KEY_NAME,
                                               additionalInformation, TESTS_TABLE_SECTIONS_KEY_ROWS,
                                               nil];
    return additionalInformationRows;
}

- (NSDictionary *)tableSectionDictionarySignOff
{
    // Returns a table section dictionary representing Sign Off

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];

    NSMutableArray *signOff = [NSMutableArray arrayWithObjects:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME, nil];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_REQUIRES_WITNESS] boolValue])
        [signOff addObject:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME];
    NSDictionary *signOffRows = [NSDictionary dictionaryWithObjectsAndKeys:
                                 TESTS_TABLE_SECTION_SIGN_OFF, TESTS_TABLE_SECTIONS_KEY_NAME,
                                 signOff, TESTS_TABLE_SECTIONS_KEY_ROWS,
                                 nil];
    return signOffRows;
}

- (NSInteger)tableSectionIndexForName:(NSString *)sectionName
{
    // Returns the table index of the table section with the supplied name
    
    NSInteger count = 0;
    for (NSDictionary* dictionary in _tableArray) {
        if ([[dictionary objectForKey:TESTS_TABLE_SECTIONS_KEY_NAME] isEqualToString:sectionName])
            return count;
        count++;
    }
    return NSNotFound;
}

- (NSString *)tableSectionNameForIndex:(NSInteger)sectionIndex
{
    // Returns the name of the table section at the supplied index
    
    NSDictionary *dictionary = [_tableArray objectAtIndex:sectionIndex];
    return [dictionary nullableObjectForKey:TESTS_TABLE_SECTIONS_KEY_NAME];
}

- (BOOL)tableArrayContainsRow:(NSString *)rowName
{
    // Returns true if the supplied table row name exists in the table array, or false if not
    
    for (NSDictionary* dictionary in _tableArray) {
        NSArray *rows = [dictionary objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        if ([rows containsObject:rowName])
            return YES;
    }
    return NO;
}

#pragma mark - Validation

- (BOOL)canActivateTestSession
{
    // Returns true if the current user is authorised to activate the test session
    // To be authorised, the tester needs to be blank or set to the logged-in user
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    UserManager *userManager = [UserManager sharedInstance];
    NSDictionary *engineerFromLoggedInUser = [databaseManager getEngineerByEmail:[userManager getLoggedInUsersUsername]];
    
    if (![self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_TESTER_ID] ||
        [[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TESTER_ID] isEqual:[engineerFromLoggedInUser objectForKey:TABLE_ENGINEER_COLUMN_ID]])
        return YES;
    else
        return NO;
}

- (BOOL)canEditTestSession
{
    // Returns true if the current user is authorised to edit the test session
    // To be authorised, the tester needs to be set to the logged-in user, the device to the current device, and the test session set to In Progress
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    UserManager *userManager = [UserManager sharedInstance];
    NSDictionary *engineerFromLoggedInUser = [databaseManager getEngineerByEmail:[userManager getLoggedInUsersUsername]];
    
    if ([databaseManager testSessionInProgressOnThisDeviceForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]] && [[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TESTER_ID] isEqual:[engineerFromLoggedInUser objectForKey:TABLE_ENGINEER_COLUMN_ID]])
        return YES;
    else
        return NO;
}

- (BOOL)canSignOffTestSession
{
    // Returns true if the test session can be signed off
    // This requires an overall result to be set (all tests completed) and all required fields to be set
    // A photo must also have been taken, if required

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
    
    BOOL photoRequiredForSignOff = ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_DISPLAY_PHOTO] boolValue] && ![self photographyNotAllowedOnSiteForEquipment]);

    NSString *overallResult = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME];
    return (
            ([overallResult isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS] || [overallResult isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL])
            && ([self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID] || ![self tableArrayContainsRow:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME])
            && ([self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION] || ![self tableArrayContainsRow:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION])
            && ([self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION] || ![self tableArrayContainsRow:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION])
            && ([self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID] || ![self tableArrayContainsRow:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME])
            && ([self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_UNIT_RATING] || ![self tableArrayContainsRow:TABLE_TEST_SESSION_COLUMN_UNIT_RATING])
            && ([self.testSessionData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID] || ![self tableArrayContainsRow:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME])
            && ([self.photos count] > 0 || !photoRequiredForSignOff)
            );
}

- (BOOL)equipmentLocationRequiredButMissing
{
    // Returns true if the equipment location is required but missing, or false if not

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
    
    return (
            [[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_EQUIPMENT_LOCATION_REQUIRED_FOR_PASS] boolValue]
            &&
            ![self.equipmentData keyIsNotMissingNullOrEmpty:TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION]
            );
}

- (BOOL)photographyNotAllowedOnSiteForEquipment
{
    // Returns true if photography is not allowed on site for the equipment's works order, or otherwise false

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSNumber *photographyNotAllowedOnSite =
        ([self.equipmentData hasParentEquipment])
        ? [[databaseManager getEquipmentById:[self.equipmentData objectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]] objectForKey:TABLE_EQUIPMENT_COLUMN_PROJECT_PHOTOGRAPHY_NOT_ALLOWED_ON_SITE]
        : [self.equipmentData objectForKey:TABLE_EQUIPMENT_COLUMN_PROJECT_PHOTOGRAPHY_NOT_ALLOWED_ON_SITE];
    
    return (photographyNotAllowedOnSite && photographyNotAllowedOnSite != (NSNumber *)[NSNull null]) ? [photographyNotAllowedOnSite boolValue] : NO;
}

- (NSDictionary *)ibarInstallationJointTestDuctorResistanceFieldsWithRequired:(BOOL)required notRequired:(BOOL)notRequired
{
    // Returns a list of Ibar Installation Joint Test ductor resistance fields and values
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    // Retrieve the existing IBAR Installation Joint Test Metadatas from the database
    // This is always created upon activation of an IBAR Installation Joint test
    NSArray *ibarInstallationJointTestMetadatas = [databaseManager getIbarInstallationJointTestMetadatasForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];

    if ([ibarInstallationJointTestMetadatas count] == 0)
        return dictionary;
    
    // Note although the ibarInstallationJointTestMetadatas database manager call returned an array, we expect only one so simply load the first result
    NSMutableDictionary *ibarInstallationJointTestMetadata = [NSMutableDictionary dictionaryWithDictionary:[ibarInstallationJointTestMetadatas objectAtIndex:0]];
    
    NSMutableArray *fieldNames = [NSMutableArray array];
    
    if ([self.equipmentData hasParentEquipment])
    {
        NSDictionary *parentEquipmentData = [databaseManager getEquipmentById:[self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]];
        NSDictionary *conductorConfiguration = [databaseManager getConductorConfigurationById:[parentEquipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_ID]];

        // We can only validate correctly if the parent Bar has a conductor configuration set
        if ([[conductorConfiguration allKeys] count] > 0)
        {
            NSMutableArray *requiredFieldNames = [NSMutableArray array];
            NSMutableArray *notRequiredFieldNames = [NSMutableArray array];
            
            // Add the field names into the appropriate collection - required or not required
            
            if ([[conductorConfiguration objectForKey:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_CONDUCTOR_L1] boolValue])
                [requiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1];
            else
                [notRequiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1];

            if ([[conductorConfiguration objectForKey:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_CONDUCTOR_L2] boolValue])
                [requiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2];
            else
                [notRequiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2];

            if ([[conductorConfiguration objectForKey:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_CONDUCTOR_L3] boolValue])
                [requiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3];
            else
                [notRequiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3];

            if ([[conductorConfiguration objectForKey:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_CONDUCTOR_N] boolValue])
                [requiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL];
            else
                [notRequiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL];

            if ([[conductorConfiguration objectForKey:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_CONDUCTOR_N_2] boolValue])
                [requiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2];
            else
                [notRequiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2];

            if ([[conductorConfiguration objectForKey:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_CONDUCTOR_E] boolValue])
                [requiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH];
            else
                [notRequiredFieldNames addObject:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH];

            // Filter the field names based on the required flags
            
            if (required)
                [fieldNames addObjectsFromArray:requiredFieldNames];
            if (notRequired)
                [fieldNames addObjectsFromArray:notRequiredFieldNames];
        }
    }

    // Iterate the fields and populate the return array with their names and values
    for (NSString *fieldName in fieldNames) {
        [dictionary setObject:[ibarInstallationJointTestMetadata nullableObjectForKey:fieldName] forKey:fieldName];
    }

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

- (NSDictionary *)ibarInstallationJointTestDuctorResistanceFieldsRequiredButIncomplete
{
    // Returns a list of ductor resistance fields required for sign off, but not yet complete
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    NSDictionary *ibarInstallationJointTestDuctorResistanceFields = [self ibarInstallationJointTestDuctorResistanceFieldsWithRequired:YES notRequired:NO];
    for (id key in ibarInstallationJointTestDuctorResistanceFields) {
        // Only add the data to the return dictionary if the field value is empty
        if ([self ibarInstallationJointTestDuctorResistanceValueIsEmpty:[ibarInstallationJointTestDuctorResistanceFields valueForKey:key]])
            [dictionary setObject:[ibarInstallationJointTestDuctorResistanceFields valueForKey:key] forKey:key];
    }

    // If this bar has configuration 2P&E, we handle this specifically as a special case
    // This is because this configuration can have '2 of x' fields populated, rather than a straightforward list of required fields
    if ([self parentEquipmentForEquipment:self.equipmentData hasConductorConfiguration:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_NAME_VALUE_2P_E])
    {
        // If at least 2 of the accepted permutation fields for this configuration are populated, we remove any others from the return dictionary that are empty
        NSNumber *fieldCount = [self ibarInstallationJointTestDuctorResistance2PEFieldCount];
        if (fieldCount != nil && [fieldCount intValue] >= 2)
            dictionary = [self removeEmptyIbarInstallationJointTestDuctorResistance2PEFields:dictionary];
    }

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

- (NSDictionary *)ibarInstallationJointTestDuctorResistanceFieldsNotWithinTolerance
{
    // Returns a list of ductor resistance fields with values not within tolerance
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    NSDictionary *ibarInstallationJointTestDuctorResistanceFields = [self ibarInstallationJointTestDuctorResistanceFieldsWithRequired:YES notRequired:NO];
    if ([self.equipmentData hasParentEquipment])
    {
        // Get the maximum ductor resistance
        NSDictionary *parentEquipmentData = [databaseManager getEquipmentById:[self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]];
        double maximumDuctorResistance = [[parentEquipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_MAXIMUM_DUCTOR_RESISTANCE_MICROOHMS] doubleValue];

        for (id key in ibarInstallationJointTestDuctorResistanceFields) {
            NSString *value = [ibarInstallationJointTestDuctorResistanceFields valueForKey:key];
            // Only add the data to the return dictionary if the field value is numeric and outside the maximum tolerance
            if ([self ibarInstallationJointTestDuctorResistanceValueIsNumeric:value] && [value doubleValue] > maximumDuctorResistance && maximumDuctorResistance > 0)
                [dictionary setObject:[ibarInstallationJointTestDuctorResistanceFields objectForKey:key] forKey:key];
        }
    }

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

- (NSDictionary *)ibarInstallationJointTestDuctorResistanceFieldsContainingInvalidCharacters
{
    // Returns a list of ductor resistance fields containing invalid characters
        
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    // Required fields: Numbers or dots only
    NSDictionary *ibarInstallationJointTestDuctorResistanceFieldsRequired = [self ibarInstallationJointTestDuctorResistanceFieldsWithRequired:YES notRequired:NO];
    for (id key in ibarInstallationJointTestDuctorResistanceFieldsRequired) {
        NSString *value = [ibarInstallationJointTestDuctorResistanceFieldsRequired valueForKey:key];
        // Only add the data to the return dictionary if the field value is not numeric
        if (![self ibarInstallationJointTestDuctorResistanceValueIsNumeric:value])
            [dictionary setObject:[ibarInstallationJointTestDuctorResistanceFieldsRequired objectForKey:key] forKey:key];
    }
    
    // If this bar has configuration 2P&E, we handle this specifically as a special case
    // This is because this configuration can have '2 of x' fields populated, rather than a straightforward list of required fields
    if ([self parentEquipmentForEquipment:self.equipmentData hasConductorConfiguration:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_NAME_VALUE_2P_E])
    {
        // If at least 2 of the accepted permutation fields for this configuration are populated, we remove any others from the return dictionary that are empty
        NSNumber *fieldCount = [self ibarInstallationJointTestDuctorResistance2PEFieldCount];
        if (fieldCount != nil && [fieldCount intValue] >= 2)
            dictionary = [self removeEmptyIbarInstallationJointTestDuctorResistance2PEFields:dictionary];
    }

    // Non-required fields: Empty or dashes only
    NSDictionary *ibarInstallationJointTestDuctorResistanceFieldsNotRequired = [self ibarInstallationJointTestDuctorResistanceFieldsWithRequired:NO notRequired:YES];
    for (id key in ibarInstallationJointTestDuctorResistanceFieldsNotRequired) {
        NSString *value = [ibarInstallationJointTestDuctorResistanceFieldsNotRequired valueForKey:key];
        // Only add the data to the return dictionary if the field value is not empty
        if (![self ibarInstallationJointTestDuctorResistanceValueIsEmpty:value])
            [dictionary setObject:[ibarInstallationJointTestDuctorResistanceFieldsNotRequired objectForKey:key] forKey:key];
    }

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

- (NSNumber *)ibarInstallationJointTestDuctorResistance2PEFieldCount
{
    // Returns a count of populated ductor resistance fields from the 2P&E permutation list
    // or nil if the bar does not conform to that configuration

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    // Retrieve the existing IBAR Installation Joint Test Metadatas from the database
    // This count is only valid for test sessions with this associated dictionary
    NSArray *ibarInstallationJointTestMetadatas = [databaseManager getIbarInstallationJointTestMetadatasForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
    if ([ibarInstallationJointTestMetadatas count] == 0)
        return nil;

    if ([self parentEquipmentForEquipment:self.equipmentData hasConductorConfiguration:TABLE_CONDUCTOR_CONFIGURATION_COLUMN_NAME_VALUE_2P_E])
    {
        // Get a count of the populated fields from the permutation list
        int fieldCount = 0;
        NSDictionary *ibarInstallationJointTestDuctorResistanceFields = [self ibarInstallationJointTestDuctorResistanceFieldsWithRequired:YES notRequired:YES];
        for (NSString *fieldName in [self ibarInstallationJointTestDuctorResistancePermutationFieldNamesFor2PE]) {
            if (
                [ibarInstallationJointTestDuctorResistanceFields objectForKey:fieldName] != nil
                &&
                ![self ibarInstallationJointTestDuctorResistanceValueIsEmpty:[ibarInstallationJointTestDuctorResistanceFields valueForKey:fieldName]]
                )
                fieldCount++;
        }
        return [NSNumber numberWithInt:fieldCount];
    }
    return nil;
}

- (NSMutableDictionary *)removeEmptyIbarInstallationJointTestDuctorResistance2PEFields:(NSMutableDictionary *)dictionary
{
    // Returns the dictionary with all empty 2P&E ductor resistance fields removed

    NSMutableDictionary *filteredDictionary = [NSMutableDictionary dictionary];
    for (id key in dictionary) {
        if ([[self ibarInstallationJointTestDuctorResistancePermutationFieldNamesFor2PE] containsObject:key])
        {
            if (![self ibarInstallationJointTestDuctorResistanceValueIsEmpty:[dictionary objectForKey:key]])
                [filteredDictionary setObject:[dictionary valueForKey:key] forKey:key];
        }
        else
            // Otherwise add field to return dictionary
            [filteredDictionary setObject:[dictionary valueForKey:key] forKey:key];
    }
    return filteredDictionary;
}

- (BOOL)parentEquipmentForEquipment:(NSDictionary *)equipmentData hasConductorConfiguration:(NSString *)conductorConfiguration
{
    // Returns true if the equipment's parent has the specified conductor configuration, or false if not
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    if ([equipmentData hasParentEquipment])
    {
        NSDictionary *parentEquipmentData = [databaseManager getEquipmentById:[equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]];
        if ([[parentEquipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_NAME] isEqualToString:conductorConfiguration]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)ibarInstallationJointTestDuctorResistanceValueIsEmpty:(NSString *)value
{
    // Returns true if the value is a recognised empty entry, or false if not

    NSString *trimmedValue = [value trimmed];
    return ([trimmedValue length] == 0 || [trimmedValue isEqualToString:IBAR_INSTALLATION_JOINT_TEST_DUCTOR_RESISTANCE_PLACEHOLDER]);
}

- (BOOL)ibarInstallationJointTestDuctorResistanceValueIsNumeric:(NSString *)value
{
    // Returns true if the value is a recognised numeric entry, or false if not

    NSCharacterSet *numericCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"1234567890."];
    NSString *trimmedValueForNumeric = [[value trimmed] stringByTrimmingCharactersInSet:numericCharacterSet];
    return ([[value trimmed] length] > 0 && [trimmedValueForNumeric length] == 0);
}

- (NSArray *)ibarInstallationJointTestDuctorResistanceFieldNames
{
    // Returns a full list of Ibar Installation Joint Test ductor resistance field names
 
    return [NSArray arrayWithObjects:
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3,
        nil
        ];
}

- (NSArray *)ibarInstallationJointTestDuctorResistancePermutationFieldNamesFor2PE
{
    // Returns a list of Ibar Installation Joint Test ductor resistance field names,
    // any 2 of which must be completed for the 2P&E conductor configuration
 
    return [NSArray arrayWithObjects:
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2,
        TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3,
        nil
        ];
}

- (NSString *)ibarInstallationJointTestDuctorResistanceFormFieldFromDatabaseField:(NSString *)fieldName
{
    // Translates the supplied Ibar Installation Joint Test ductor resistance database field to its corresponding form field
    
    if ([fieldName isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH])
        return FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_EARTH;

    if ([fieldName isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL])
        return FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL;

    if ([fieldName isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2])
        return FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2;

    if ([fieldName isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1])
        return FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1;

    if ([fieldName isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2])
        return FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2;

    if ([fieldName isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3])
        return FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3;

    return @"";
}

#pragma mark - Instance methods

- (void)refreshTestSession
{
    // Refreshes the test session data
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    self.testSessionData = [NSMutableDictionary dictionaryWithDictionary:[databaseManager getTestSessionById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]];
    self.tests = [NSMutableArray arrayWithArray:[databaseManager getTestSessionTestsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]];
    self.serviceDocuments = [NSMutableArray arrayWithArray:[databaseManager getDocumentsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME_VALUE_TEST_SESSION_DOCUMENT filterForRequiresDataSync:NO]];
    
    [self refreshPhotos];

    // If the equipment location is required but missing, reset all test results with a document
    // This ensures that if the location is entered onto the test document, the test has to be re-opened to update this field
    if ([self equipmentLocationRequiredButMissing] && ![[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqualToString:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_ABANDONED])
    {
        for (NSDictionary *test in self.tests) {
            NSMutableDictionary *testData = [NSMutableDictionary dictionaryWithDictionary:test];
            if ([test keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID])
            {
                [testData setObject:[NSNull null] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
                [testData setObject:[NSNull null] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME];

                // Update the test record in the database
                [databaseManager updateTestSessionTestWithRow:testData];
            }
            // Refresh tests
            self.tests = [NSMutableArray arrayWithArray:[databaseManager getTestSessionTestsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]];
        }
    }
    
    // Derive the overall result, if the test session is in progress on this device
    if ([databaseManager testSessionInProgressOnThisDeviceForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]])
    {
        NSString *originalResultName = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME];
        
        // Get the collection of test results
        NSArray *testResults = [self.tests valueForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME];
        
        // Begin by setting the default overall result to 'Pass'
        NSString *overallResultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS;
        
        // If any test has failed, set the overall result to 'Fail'
        if ([testResults containsObject:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL])
            overallResultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL;
        
        // If any test has not yet been completed, clear the overall result as the test session is still in progress
        if ([testResults containsObject:@""] || [testResults containsObject:[NSNull null]])
            overallResultName = @"";
        
        // Set the overall result for the test session
        NSDictionary *overallResult = [databaseManager getTestResultByName:overallResultName];
        if ([overallResult keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_STATUS_COLUMN_ID]) {
            [self.testSessionData setObject:[overallResult objectForKey:TABLE_TEST_RESULT_COLUMN_ID] forKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID];
            [self.testSessionData setObject:[overallResult objectForKey:TABLE_TEST_RESULT_COLUMN_NAME] forKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME];
        }
        else {
            [self.testSessionData removeObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID];
            [self.testSessionData removeObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME];
        }

        // Finally, persist the test session then refresh it back from the database
        if (![overallResultName isEqualToString:originalResultName]) {
            [databaseManager updateTestSessionWithRow:self.testSessionData requiresDataSync:YES];
            self.testSessionData = [NSMutableDictionary dictionaryWithDictionary:[databaseManager getTestSessionById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]];
        }
    }
}

- (void)refreshPhotos
{
    // Updates the photos array to contain only the most recent photo that has a valid filepath
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    self.photos = [NSArray array];
    
    // Get all photos ordered by date descending
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:TABLE_DOCUMENT_COLUMN_DATE_CREATED ascending:NO];
    NSArray *allPhotos = [[databaseManager getDocumentsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:TABLE_DOCUMENT_TYPE_COLUMN_NAME_VALUE_TEST_SESSION_PHOTO qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:NO] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
    
    // Return only the most recent profile image that has a valid filepath
    for (NSDictionary *photo in allPhotos) {
        if (![[photo nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] isEqualToString:@""] && [fileManager fileExistsAtPath:[[photo nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] stringByPrependingDocumentsDirectoryFilepath]]) {
            self.photos = [NSArray arrayWithObject:photo];
            break;
        }
    }
}

- (void)refreshDisplay
{
    // Refreshes the view
    
    // Refresh the model data and UITableView
    [self refreshTestSession];
    
    // Repopulate the array of required table sections and rows
    [self populateTableArray];
    
    // Reload the table view
    [self.testSessionTableView reloadData];
    
    // Refresh activation controls
    [self.view setNeedsLayout];
}

- (void)activateTestSession
{
    // Fired when the 'Activate' button is tapped

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    if (self.overlayActivityIndicator.superview)
        [self hideProgressIcon];

    [self showProgressIconAndExecute:^{
        // If this test session requires a build location and we have not yet scanned one, display the scan window
        NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
        if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_REQUIRES_BUILD_LOCATION] boolValue] && !self.buildLocationId)
        {
            [self displayScanWindowWithOverlayText:NSLocalizedString(@"TEST_SESSION_DETAILS_SCAN_OVERLAY_TEXT_SCAN_LOCATION_TAG", nil)];
            return;
        }
        
        if (self.buildLocationId)
            [self.testSessionData setObject:self.buildLocationId forKey:TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID];
        
        // Activate test session
        TestSessionActivationManager *testSessionActivationManager = [TestSessionActivationManager sharedInstance];
        testSessionActivationManager.delegate = self;
        [testSessionActivationManager activateTestSession:self.testSessionData];
    }];
}

- (void)abandonTestSession
{
    // Fired when the 'Abandon' button is tapped
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    // Show confirmation dialogue to user
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_ABANDON_TEST_SESSION", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_NO", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_YES", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // Abandon the test session
        // Set status property of test session model
        NSDictionary *statusAbandoned = [databaseManager getTestSessionStatusByName:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_ABANDONED];
        [self.testSessionData setObject:[statusAbandoned objectForKey:TABLE_TEST_SESSION_STATUS_COLUMN_ID] forKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID];
        
        // Add all the Json objects required by a test session dictionary, prior to syncing up to the server
        self.testSessionData = [databaseManager addDataSyncJsonObjectsToTestSession:self.testSessionData];
        
        [self showProgressIconAndExecute:^{
            // Make an Api call to update the test session on the server, then wait for the Api delegate
            [_apiManager putDataToApiMethod:TestSessionsLite withUrlSegments:[NSArray arrayWithObject:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]] withPostData:[self.testSessionData jsonDictionaryWithPopulatedDocuments]];
        }];
    }];
    [alert addAction:cancelAction];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)keepDatabaseUpdated
{
    // Adopting the Apple save as you perform an action pattern,
    // this method should be called AFTER any property has been modified by whatever Ui actions
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    [databaseManager updateTestSessionWithRow:self.testSessionData requiresDataSync:YES];
    
    // Also update the associated master document
    [self updateMasterDocument];
    
    [appDelegate updateSyncBadgeCount];
}

- (void)createTest
{
    // Fired when user taps the Add Test button

    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    AppSettings *appSettings = [AppSettings sharedInstance];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    AlertManager *alertManager = [AlertManager sharedInstance];
    
    BOOL result = YES;
    NSError *error = nil;
    
    // Get the details of the test session type master document type
    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
    NSDictionary *documentType = [databaseManager getDocumentTypeById:[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_ID]];
    NSString *qualityManagementSystemCode = [documentType nullableObjectForKey:TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE];
    NSString *documentTypeName = [documentType nullableObjectForKey:TABLE_DOCUMENT_TYPE_COLUMN_NAME];
    
    // Get the template version of the document type
    NSDictionary *templateDocumentType = [databaseManager getDocumentTypeByName:nil qualityManagementSystemCode:qualityManagementSystemCode documentTypeCategoryName:TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME_VALUE_TEST_DOCUMENT_TEMPLATE];
    if (result) result = [templateDocumentType count] > 0;
    if (!result) { [alertManager showAlertForErrorType:RetrieveTestDocumentTemplateDocumentType withError:error]; return; }

    // Get the template document; by convention we assume there is only one record per template type
    NSDictionary *testDocumentTemplate = [[databaseManager getDocumentsByDocumentTypeId:[templateDocumentType nullableObjectForKey:TABLE_DOCUMENT_TYPE_COLUMN_ID]] objectAtIndex:0];
    if (result) result = [testDocumentTemplate count] > 0;
    if (!result) { [alertManager showAlertForErrorType:RetrieveTestDocumentTemplate withError:error]; return; }
    
    NSData *fileData = [NSData dataWithContentsOfFile:[[testDocumentTemplate objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] stringByPrependingDocumentsDirectoryFilepath]];
    if (result) result = fileData.length > 0;
    if (!result) { [alertManager showAlertForErrorType:LoadTestDocumentTemplateFileData withError:error]; return; }
    
    // Create the document

    // Set up file path
    NSString *documentId = [[NSString stringWithUUID] lowercaseString];
    NSString *filePath = nil;
    NSString *fileName = [self defaultTestDocumentFileNameForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentType:documentType index:([self.tests count] + 1)];
    fileName = [fileName stringByRemovingIllegalFilenameCharacters];
    filePath = [appSettings.testDocumentsDirectoryPath stringByAppendingPathComponent:fileName];

    // Create document dictionary
    NSDictionary *document = [NSDictionary documentDictionaryWithDocumentTypeName:documentTypeName qualityManagementSystemCode:qualityManagementSystemCode documentTypeCategoryName:TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME_VALUE_TEST_DOCUMENT filePath:filePath mimeType:MIME_TYPE_PDF documentId:documentId];
    
    // Create the file
    if (result) result = [fileData writeToFile:filePath atomically:YES];
    if (!result) { [alertManager showAlertForErrorType:WriteTestDocumentToFile withError:error]; return; }
    
    // Create the database record
    DataWrapper *dataWrapper = [databaseManager createDocumentWithRow:document isNew:NO requiresDataSync:NO];
    if (!dataWrapper.isValid) { [alertManager showAlertForErrorType:SaveTestDocumentMetadata withError:error]; return; }

    // Create the test
    
    // Get an existing test to clone the type from
    // By convention, we assume that if the test session allows creation of tests, it only has one test type
    NSDictionary *test = [self.tests objectAtIndex:0];
    NSDictionary *testType = [databaseManager getTestTypeById:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID]];

    // Create test dictionary
    NSMutableDictionary *testData = [NSMutableDictionary dictionary];
    [testData setObject:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID];
    [testData setObject:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID];
    [testData setObject:documentId forKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID];
    // If test type does not require a result, set its result to pass
    if (![[testType objectForKey:TABLE_TEST_TYPE_COLUMN_REQUIRES_RESULT] boolValue]) {
        NSDictionary *resultPass = [databaseManager getTestResultByName:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS];
        [testData setObject:[resultPass objectForKey:TABLE_TEST_RESULT_COLUMN_ID] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
    }
    
    // Create the database record
    if (result) result = [databaseManager createTestSessionTestWithRow:testData requiresDataSync:0];
    if (!result) { [alertManager showAlertForErrorType:SaveTest withError:error]; return; }
    
    // Refresh view
    [self refreshDisplay];
    
    [appDelegate updateSyncBadgeCount];
}

- (void)updateMasterDocument
{
    // Updates the associated master document based on the test session data
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *mardixWitnessSignatoryName = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_NAME]];
    NSString *clientWitnessSignatoryName = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME]];
    
    NSDictionary *testSessionType = [databaseManager getTestSessionTypeById:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
    NSString *testSessionTypeName = [testSessionType nullableObjectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_NAME];
    if ([[testSessionType objectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_SPECIFY_WITNESS_IN_NAME] boolValue] && ![clientWitnessSignatoryName isEqualToString:@""]) {
        testSessionTypeName = [testSessionTypeName stringByReplacingOccurrencesOfString:NSLocalizedString(@"TEST_SESSION_DETAILS_TEXT_TEST", nil) withString:NSLocalizedString(@"TEST_SESSION_DETAILS_TEXT_WITNESS_TEST", nil)];
    }

    // First get the master document records for the test session
    NSArray *documents = [databaseManager getMasterDocumentsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
    if (documents && [documents count])
    {
        for (NSDictionary *document in documents)
        {
            // Initialise the User PDF Document object and load the document from the file system
            NSString *filePath = [[document objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] stringByPrependingDocumentsDirectoryFilepath];
            FSPDFDoc *pdfDocumentMaster = [[FSPDFDoc alloc] initWithPath:filePath];
            self.pdfDocumentMaster = pdfDocumentMaster;
            [pdfDocumentMaster release];
            [self.pdfDocumentMaster load:nil];

            // Enforce form field values from model data
            [self setFormFieldsInTestDocument:_pdfDocumentMaster withDateString:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_START_DATE]];

            // Set test session form field values
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO]]
                            forFormField:FORM_FIELD_TX_SERIAL_NO forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO]]
                            forFormField:FORM_FIELD_STS_SERIAL_NO forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO]]
                            forFormField:FORM_FIELD_AHF_SERIAL_NO forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_UNIT_RATING]]
                            forFormField:FORM_FIELD_UNIT_RATING forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TX_RATING]]
                            forFormField:FORM_FIELD_TX_RATING forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_STS_RATING]]
                            forFormField:FORM_FIELD_STS_RATING forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_AHF_RATING]]
                            forFormField:FORM_FIELD_AHF_RATING forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:testSessionTypeName
                            forFormField:FORM_FIELD_CATEGORY_OF_TESTING forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME]]
                            forFormField:FORM_FIELD_ELECTRICAL_SUPPLY_SYSTEM forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME]]
                            forFormField:FORM_FIELD_VERIFY_BREAKER_TRIP_UNITS forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_COMMENTS]]
                            forFormField:FORM_FIELD_COMMENTS forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION]]
                            forFormField:FORM_FIELD_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION]]
                            forFormField:FORM_FIELD_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME]]
                            forFormField:FORM_FIELD_NAME_TESTER forceOverwrite:YES];
            [self.pdfDocumentMaster setValue:[mardixWitnessSignatoryName isEqualToString:@""] ? clientWitnessSignatoryName : mardixWitnessSignatoryName
                            forFormField:FORM_FIELD_NAME_WITNESS forceOverwrite:YES];
            
            // Set individual test form field values
            NSArray *tests = [databaseManager getTestSessionTestsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
            for (NSDictionary *test in tests)
            {
                NSNumber *testNumber = (NSNumber *)[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NUMBER];
                
                [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE]]
                                forFormField:[NSString stringWithFormat:@"%@%02ld", FORM_FIELD_TEST_INST_REF, (long)[testNumber integerValue]] forceOverwrite:YES];
                if ([test keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE])
                    [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE]]
                                    forFormField:[NSString stringWithFormat:@"%@%02ld", FORM_FIELD_TEST_DOCUMENT_USED, (long)[testNumber integerValue]] forceOverwrite:YES];
                if ([test keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME])
                    [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME]]
                                    forFormField:[NSString stringWithFormat:@"%@%02ld", FORM_FIELD_TEST_RESULT, (long)[testNumber integerValue]] forceOverwrite:YES];
                [self.pdfDocumentMaster setValue:[NSString stringWithFormat:@"%@", [test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE]]
                                forFormField:[NSString stringWithFormat:@"%@%02ld", FORM_FIELD_TEST_VOLTAGE, (long)[testNumber integerValue]] forceOverwrite:YES];
            }
            
            // Get the current file path for the test document, and a new incremented file path
            NSDictionary *documentType = [databaseManager getDocumentTypeById:[document objectForKey:TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID]];
            // We have to save a new version of the file then remove the old one, as the SDK won't allow an open document to be saved over
            NSString *oldFilePath = [document objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
            NSString *newFilePath = [self incrementedTestDocumentFilePathForFilePath:[document objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] testSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentType:documentType];
            
            // Save a new version of the file and update the associated database record
            BOOL result = [self updateTestDocument:_pdfDocumentMaster withNewFilePath:newFilePath forDocumentId:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID]];
            
            // Remove old file
            if (result)
                [fileManager removeItemAtPath:[oldFilePath stringByPrependingDocumentsDirectoryFilepath] error:nil];
        }
    }
}

- (void)loadSignatoryAddForm
{
    // Load the Add Signatory view
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    CreateSiteVisitReportSignatoryViewController *signatory = [[[CreateSiteVisitReportSignatoryViewController alloc] init] autorelease];
    NSDictionary *branch = [databaseManager getBranchById:[self.equipmentData nullableObjectforKeyFromEquipmentOrParentEquipment:TABLE_EQUIPMENT_COLUMN_BRANCH_ID]];
    if ([branch objectForKey:TABLE_BRANCH_COLUMN_ORGANISATION_ID]) {
        signatory.organisationId = [branch objectForKey:TABLE_BRANCH_COLUMN_ORGANISATION_ID];
    }
    [self.navigationController pushViewController:signatory animated:YES];
}

- (void)loadPhotoActionSheet
{
    // Loads the photo action sheet to allow a profile image to be added
    
    UIImagePickerController *photoPicker = [[UIImagePickerController alloc] init];
    photoPicker.delegate = self;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_SELECT_SOURCE_FOR_IMAGE", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    alert.modalPresentationStyle = UIModalPresentationPopover;
    UITableViewCell *cell = [self.testSessionTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[self.photos count] inSection:[self tableSectionIndexForName:TESTS_TABLE_SECTION_PHOTOS]]];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_CANCEL", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];
    UIAlertAction *takePhotoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_TAKE_PHOTO", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // Take photo
        photoPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:photoPicker animated:YES completion:nil];
        [photoPicker release];
    }];
    UIAlertAction *choosePhotoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_CHOOSE_EXISTING_PHOTO", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // Choose existing photo
        photoPicker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        [self presentViewController:photoPicker animated:YES completion:nil];
        [photoPicker release];
    }];
    [alert addAction:cancelAction];
    [alert addAction:takePhotoAction];
    [alert addAction:choosePhotoAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)updateTestDocument:(FSPDFDoc *)pdfDocument withNewFilePath:(NSString *)newFilePath forDocumentId:(NSString *)documentId
{
    // Saves the specified document to the new filepath, and updates the associated document record in the database
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    AlertManager *alertManager = [AlertManager sharedInstance];
    
    BOOL result = YES;
    
    // If for some reason a file already exists with the same name as the new document to be saved, remove it first
    if ([fileManager fileExistsAtPath:[newFilePath stringByPrependingDocumentsDirectoryFilepath]] && result)
        result = [fileManager removeItemAtPath:[newFilePath stringByPrependingDocumentsDirectoryFilepath] error:nil];

    // Save new version
    if (result)
    {
        if ([pdfDocument saveAs:[newFilePath stringByPrependingDocumentsDirectoryFilepath] save_flags:FSPDFDocSaveFlagNormal] != YES) {
            // Error saving document, so alert user
            [alertManager showAlertForErrorType:WriteTestDocumentToFile withError:nil];
            result = NO;
        }
        else
        {
            // Document saved successfully, so update document file path in database Documents table
            NSMutableDictionary *document = [NSMutableDictionary dictionaryWithDictionary:[databaseManager getDocumentById:documentId]];
            [document setObject:newFilePath forKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
            result = [databaseManager updateDocumentWithRow:document requiresDataSync:NO].isValid;
            if (!result)
                [alertManager showAlertForErrorType:UpdateTestDocumentFilePath withError:nil];
        }
    }
    
    return result;
}

- (NSString *)incrementedTestDocumentFilePathForFilePath:(NSString *)filePath testSessionId:(NSString *)testSessionId documentType:(NSDictionary *)documentType
{
    // Returns the next incremental filepath for the specified test document filepath, test session and document type
    // This is done by obtaining the current filename, and increasing the file version number
    
    if ([filePath length] == 0)
        return [self defaultTestDocumentFileNameForTestSessionId:testSessionId documentType:documentType index:1];
    
    return [filePath incrementedDocumentFilePath];
}
                          
- (NSString *)defaultTestDocumentFileNameForTestSessionId:(NSString *)testSessionId documentType:(NSDictionary *)documentType index:(NSInteger)index
{
    // Returns the default first version filname for a test document with the specified parameters
    // based on the convention [TestSession {TestSessionId} {QMF code} {DocumentType} {VersionNo}.pdf]

    return [NSString stringWithFormat:@"%@ %@ %@ %@ %li %i.%@", NSLocalizedString(@"COMMON_FILE_NAME_TEXT_TEST_SESSION", nil), testSessionId, [documentType nullableObjectForKey:TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE], [documentType nullableObjectForKey:TABLE_DOCUMENT_TYPE_COLUMN_NAME], (long)index, DOCUMENT_DEFAULT_VERSION_INDEX, FILE_EXTENSION_PDF];
}

- (void)displayScanWindowWithOverlayText:(NSString *)overlayText
{
    // Displays a scan window with the supplied optional overlay text
    
    if (overlayText)
    {
        // Overlay view for scan window
        UILabel *overlayLabel = [[UILabel alloc] init];
        overlayLabel.translatesAutoresizingMaskIntoConstraints = NO;
        overlayLabel.numberOfLines = 0;
        overlayLabel.lineBreakMode = NSLineBreakByWordWrapping;
        overlayLabel.textColor = [UIColor whiteColor];
        overlayLabel.layer.shadowColor = [[UIColor blackColor] CGColor];
        overlayLabel.layer.shadowOffset = CGSizeMake(1.0f, 1.0f);
        overlayLabel.layer.shadowRadius = 1.0;
        overlayLabel.layer.shadowOpacity = 1.0;
        overlayLabel.text = overlayText;
        self.avCaptureViewController.overlay = overlayLabel;
        [overlayLabel release];
    }

    [self presentViewController:self.avCaptureViewController animated:YES completion:nil];

    _presentingModalViewController = YES;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSString *statusName = [self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME];
    return [statusName isEqual:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_NOT_STARTED] || [statusName isEqual:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_PRE_ACTIVATED] ? 1 : [_tableArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *tableSectionName = [self tableSectionNameForIndex:section];
    
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_DETAILS])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_DETAILS", nil);
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_TESTS])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_TESTS", nil);
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_PHOTOS])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_PHOTOS", nil);
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_ADDITIONAL_DOCUMENTS])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_ADDITIONAL_DOCUMENTS", nil);
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_VERIFICATION])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_VERIFICATION", nil);
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_ADDITIONAL_INFORMATION])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_ADDITIONAL_INFORMATION", nil);
    if ([tableSectionName isEqualToString:TESTS_TABLE_SECTION_SIGN_OFF])
        return NSLocalizedString(@"TEST_SESSION_DETAILS_TABLE_SECTION_HEADER_SIGN_OFF", nil);
    
    return NSLocalizedString(@"COMMON_TABLE_SECTION_HEADER_UNKNOWN", nil);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // If test session has not yet been activated, display the table footer view
    if (
        section == 0 &&
        ([[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqual:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_NOT_STARTED] ||
         [[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqual:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_PRE_ACTIVATED])
        )
        return self.tableFooter;
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[_tableArray objectAtIndex:section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MardixBaseTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[MardixDefaultTableViewCell defaultCellIdentifier]];
    if (cell == nil)
        cell = [[[MardixDefaultTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[MardixDefaultTableViewCell defaultCellIdentifier]] autorelease];
    
    cell.disabled = ![self canEditTestSession];
    cell.textLabel.textColor = [MardixDefaultTableViewCell defaultTextLabelFontColor];
    cell.detailTextLabel.textColor = [MardixDefaultTableViewCell defaultDetailTextLabelFontColor];
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    cell.imageView.image = nil;
    
    NSInteger detailsIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_DETAILS];
    NSInteger testsIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_TESTS];
    NSInteger photosIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_PHOTOS];
    NSInteger additionalDocumentIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_ADDITIONAL_DOCUMENTS];
    NSInteger verificationIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_VERIFICATION];
    NSInteger additionalInformationIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_ADDITIONAL_INFORMATION];
    NSInteger signOffIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_SIGN_OFF];

    // Details
    
    if (detailsIndex != NSNotFound && indexPath.section == detailsIndex)
    {
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        // Project Name
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_PROJECT_NAME]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_PROJECT_NAME", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_PROJECT_NAME]];
        }
        
        // Job Number
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_WO_NUMBER]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_JOB_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_WO_NUMBER]];
        }
        
        // Equipment Type
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_EQUIPMENT_TYPE", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME]];
        }
        
        // Unit Reference
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_UNIT_REFERENCE", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE]];
        }
        
        // Unit Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_UNIT_SERIAL_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER]];
        }
        
        // Service Tag No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_SERVICE_TAG_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER]];
        }
        
        // Drawing No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_UNIT_DRAWING_REF]) {
            NSString *mechanicalDrawingRef = [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_DRAWING_REF];
            NSString *electricalDrawingRef = [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_ELECTRICAL_SCHEMATIC_DRAWING_REF];

            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_DRAWING_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@%@", mechanicalDrawingRef, [mechanicalDrawingRef isEqualToString:@""] ? @"" : @" & ", electricalDrawingRef];
        }
    }
    
    // Tests
    
    if (testsIndex != NSNotFound && indexPath.section == testsIndex)
    {
        // Don't bother to dequeue an image cell for this, just allocate a unique one
        cell = [[[MardixImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];

        cell.disabled = ![self canEditTestSession];

        if (indexPath.row < [self.tests count])
        {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            
            NSDictionary *test = [self.tests objectAtIndex:indexPath.row];
            NSInteger testNumber = [[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NUMBER] integerValue];  // Only display test number if not 0
            NSString *circuitBreakerReference = [[NSString stringWithFormat:@"%@", [test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE]] trimmed];
            
            cell.textLabel.text = [NSString stringWithFormat:@"%@%@",
                                   NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_TEST", nil),
                                   testNumber == 0 ? @"" : [NSString stringWithFormat:@" %li", (long)testNumber]
                                   ];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",
                                         [test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NAME],
                                         circuitBreakerReference.length == 0 ? @"" : [NSString stringWithFormat:@"\n%@: %@", NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_CIRCUIT_BREAKER_REFERENCE", nil), circuitBreakerReference]
                                         ];

            // Display test status icon based on result
            NSString *result = [test nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME];
            if ([result isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS])
                cell.imageView.image = [UIImage imageNamed:@"tick.png"];
            else if ([result isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL])
                cell.imageView.image = [UIImage imageNamed:@"redCross.png"];
            else if ([result isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_NOT_APPLICABLE])
                cell.imageView.image = [UIImage imageNamed:@"notApplicable.png"];
            else
                cell.imageView.image = [UIImage imageNamed:@"notsaved.png"];
        }
        else
        {
            // Additional row, so add an Add Test row
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell.imageView.image = [UIImage imageNamed:@"add.png"];

            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_ADD", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_TEST", nil);
        }
    }
    
    // Photos
    
    if (photosIndex != NSNotFound && indexPath.section == photosIndex)
    {
        // Don't bother to dequeue an image cell for this, just allocate a unique one
        cell = [[[MardixImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];

        if (indexPath.row < [self.photos count])
        {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";

            // Get the image file path
            NSString *imageFilePath = [[self.photos objectAtIndex:indexPath.row] objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
            
            // For no jerky UI performance, load the thumbnail version of this image
            ImageManager *imageManager = [ImageManager sharedInstance];
            NSString *thumbnailImageFilePath = [imageManager getThumbnailFilePathForStandardImageFilePath:imageFilePath];
            cell.imageView.image = [UIImage imageWithContentsOfFile:[thumbnailImageFilePath stringByPrependingDocumentsDirectoryFilepath]];
        }
        else
        {
            // Last row, so add an Add Photo row
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            cell.imageView.image = [UIImage imageNamed:@"add.png"];

            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_PHOTO", nil);
            cell.detailTextLabel.text = @"";

            cell.disabled = [self photographyNotAllowedOnSiteForEquipment];

            if ([self.photos count] > 0)
                cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_PHOTO_SUCCESSFULLY_TAKEN", nil);
            else {
                if ([self photographyNotAllowedOnSiteForEquipment])
                    cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_PHOTOGRAPHY_NOT_ALLOWED_ON_SITE", nil);
                else
                    [cell setRequiredForSignOff];
            }
        }
    }
    
    // Additional Documents
    
    if (additionalDocumentIndex != NSNotFound && indexPath.section == additionalDocumentIndex)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        cell.textLabel.text = NSLocalizedString(@"COMMON_CELL_TEXT_SHOW_ALL", nil);
        cell.detailTextLabel.text = [self.serviceDocuments count] > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)[self.serviceDocuments count]] : @"";
    }
    
    // Verification
    
    if (verificationIndex != NSNotFound && indexPath.section == verificationIndex)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        NSString *result = @"";
        
        // Verify breaker trip units set up correctly
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME])
        {
            // Don't bother to dequeue an image cell for this, just allocate a unique one
            cell = [[[MardixImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
            
            cell.disabled = ![self canEditTestSession];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;

            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_ADDITIONAL_CHECK", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_VERIFY_BREAKER_TRIP_UNITS_SET_UP_CORRECTLY", nil);
            
            // Display additional check status based on result
            result = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME];
            if ([result isEqualToString:TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_NAME_VALUE_YES])
                cell.imageView.image = [UIImage imageNamed:@"tick.png"];
            else if ([result isEqualToString:TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_NAME_VALUE_NO])
                cell.imageView.image = [UIImage imageNamed:@"redCross.png"];
            else if ([result isEqualToString:TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_NAME_VALUE_NOT_APPLICABLE])
                cell.imageView.image = [UIImage imageNamed:@"notApplicable.png"];
            else
                cell.imageView.image = [UIImage imageNamed:@"notsaved.png"];
        }
        
        // Tested to Mardix general arrangement drawing revision
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_TESTED_TO_MARDIX_GENERAL_ARRANGEMENT_DRAWING_REVISION", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION]];
        }
        
        // Tested to Mardix electrical schematic drawing revision
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_TESTED_TO_MARDIX_ELECTRICAL_SCHEMATIC_DRAWING_REVISION", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION]];
        }
        
        [cell setRequiredForSignOff];
    }
    
    // Additional Information
    
    if (additionalInformationIndex != NSNotFound && indexPath.section == additionalInformationIndex)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        // Equipment Location
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION]) {
            cell.textLabel.text = ([self.equipmentData hasParentEquipment])
                ? NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_COMPONENT_LOCATION", nil)
                : NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_EQUIPMENT_LOCATION", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION]];
            
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            [cell setRequiredForSignOff];
        }

        // TX Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_TX_SERIAL_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO]];
        }
        
        // STS Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_STS_SERIAL_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO]];
        }
        
        // AHF Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_AHF_SERIAL_NUMBER", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO]];
        }
        
        // Unit Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_UNIT_RATING]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_UNIT_RATING", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_UNIT_RATING]];
            
            [cell setRequiredForSignOff];
        }
        
        // TX Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TX_RATING]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_TX_RATING", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TX_RATING]];
        }
        
        // STS Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_STS_RATING]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_STS_RATING", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_STS_RATING]];
        }
        
        // AHF Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_AHF_RATING]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_AHF_RATING", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_AHF_RATING]];
        }
        
        // Electrical Supply System
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_ELECTRICAL_SUPPLY_SYSTEM", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME]];
            
            [cell setRequiredForSignOff];
        }
        
        // Location
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_LOCATION", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME]];
            
            [cell setRequiredForSignOff];
        }
        
        // Comments
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_COMMENTS]) {
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_COMMENTS", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_COMMENTS]];
        }
    }
    
    // Sign Off
    
    if (signOffIndex != NSNotFound && indexPath.section == signOffIndex)
    {
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        // Overall result
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME])
        {
            // Don't bother to dequeue an image cell for this, just allocate a unique one
            cell = [[[MardixImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
            
            cell.disabled = ![self canEditTestSession];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            NSString *overallResultName = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME];
            
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_OVERALL_RESULT", nil);
            
            if ([overallResultName isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS]) {
                cell.imageView.image = [UIImage imageNamed:@"tick.png"];
                cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_PASS", nil);
            }
            else if ([overallResultName isEqualToString:TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL]) {
                cell.imageView.image = [UIImage imageNamed:@"redCross.png"];
                cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_FAIL", nil);
            }
            else {
                cell.imageView.image = [UIImage imageNamed:@"notsaved.png"];
                cell.detailTextLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TEXT_IN_PROGRESS", nil);
            }
        }
        
        // Mardix signatory
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME])
        {
            if ([self canSignOffTestSession])
            {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
            
            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_SIGNED_FOR_MARDIX", nil);
            cell.detailTextLabel.text = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME];
            
            if ([cell.detailTextLabel.text isEqualToString:@""] && [self canSignOffTestSession]) {
                cell.detailTextLabel.textColor = [UIColor redColor];
                cell.detailTextLabel.text = NSLocalizedString(@"COMMON_CELL_TEXT_SIGNATURE_REQUIRED", nil);
            }
        }
        
        // Witness signatory
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME])
        {
            if ([self canSignOffTestSession])
            {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
            
            NSString *mardixWitnessSignatoryName = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_NAME];
            NSString *clientWitnessSignatoryName = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME];

            cell.textLabel.text = NSLocalizedString(@"TEST_SESSION_DETAILS_CELL_TITLE_SIGNED_BY_WITNESS", nil);
            cell.detailTextLabel.text = [mardixWitnessSignatoryName isEqualToString:@""] ? clientWitnessSignatoryName : mardixWitnessSignatoryName;
            
            if ([cell.detailTextLabel.text isEqualToString:@""] && [self canSignOffTestSession]) {
                cell.detailTextLabel.textColor = [UIColor redColor];
                cell.detailTextLabel.text = NSLocalizedString(@"COMMON_CELL_TEXT_SIGNATURE_REQUIRED", nil);
            }
        }
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Allow editing of cells, to allow tests to be deleted
    
    NSInteger testsIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_TESTS];
    NSInteger photosIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_PHOTOS];

    if (testsIndex != NSNotFound && indexPath.section == testsIndex && indexPath.row < [self.tests count]) {
        NSDictionary *test = [self.tests objectAtIndex:indexPath.row];
        return [[test objectForKey:TABLE_COMMON_IS_NEW] boolValue];
    }

    if (photosIndex != NSNotFound && indexPath.section == photosIndex && indexPath.row < [self.photos count]) {
        NSDictionary *document = [self.photos objectAtIndex:indexPath.row];
        return [[document objectForKey:TABLE_COMMON_IS_NEW] boolValue];
    }

    return NO;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    NSInteger testsIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_TESTS];
    NSInteger photosIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_PHOTOS];
    NSInteger additionalDocumentIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_ADDITIONAL_DOCUMENTS];
    NSInteger verificationIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_VERIFICATION];
    NSInteger additionalInformationIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_ADDITIONAL_INFORMATION];
    NSInteger signOffIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_SIGN_OFF];
    
    // Tests
    
    if (testsIndex != NSNotFound && indexPath.section == testsIndex)
    {
        if (indexPath.row < [self.tests count])
        {
            NSMutableDictionary *testData = [NSMutableDictionary dictionaryWithDictionary:[self.tests objectAtIndex:indexPath.row]];
            
            // Set test start date, if it has not already been set
            if (![testData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TEST_COLUMN_START_DATE]) {
                // TODO: Dates are currently handled as strings, when this is addressed need to change here as well
                [testData setObject:[[NSDate date] toLongDateTimeUtcString] forKey:TABLE_TEST_SESSION_TEST_COLUMN_START_DATE];
                [databaseManager updateTestSessionTestWithRow:testData];
                NSLog(@"Setting test start date");
            }
            
            if (![testData keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID])
            {
                // Test has no associated document, so load a reference data view to allow the user to select Pass or Fail result
                
                // Give the reference data a custom data dictionary
                // This is used to supply an identifier so that the delegate method knows which test the result relates to
                NSMutableDictionary *customData = [[[NSMutableDictionary alloc] initWithObjectsAndKeys: [testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_ID], TABLE_TEST_SESSION_TEST, nil] autorelease];
                
                TestSessionTestReferenceDataViewController *referenceData = [[TestSessionTestReferenceDataViewController alloc] init];
                referenceData.delegate = self;
                referenceData.allData = [databaseManager getTestResults];
                referenceData.idKey = TABLE_REFERENCE_ID;
                referenceData.displayKey = TABLE_REFERENCE_NAME;
                referenceData.selectedId = [testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
                referenceData.idKeyToUpdate = nil;
                referenceData.displayKeyToUpdate = nil;
                referenceData.customData = customData;
                referenceData.testData = testData;
                
                [self.navigationController pushViewController:referenceData animated:YES];
            }
            else
            {
                // Test has associated document, so load a PDF document view to allow the user to modify the details

                [self showProgressIconAndExecute:^{
                    // Initialise the PDF Document object and load the document from the file system
                    NSString *filePath = [[testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_FILE_PATH] stringByPrependingDocumentsDirectoryFilepath];
                    FSPDFDoc *pdfDocument = [[FSPDFDoc alloc] initWithPath:filePath];
                    [pdfDocument load:nil];
                    
                    // Load a PDF document view to allow the user to edit the document
                    PDFDocumentViewController *pdfDocumentViewController = [[PDFDocumentViewController alloc] init];
                    pdfDocumentViewController.title = [testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE];
                    pdfDocumentViewController.delegate = self;
                    pdfDocumentViewController.pdfDocument = pdfDocument;
                    [pdfDocument release];
                    
                    // Load selected data into test data property so this can be accessed by the delegate methods
                    self.selectedTestData = testData;
                    
                    [self.navigationController pushViewController:pdfDocumentViewController animated:YES];
                    [pdfDocumentViewController release];
                }];
            }
        }
        else
        {
            // Add Test
            
            [self createTest];
        }
    }
    
    // Photos
    
    if (photosIndex != NSNotFound && indexPath.section == photosIndex)
    {
        if (indexPath.row < [self.photos count])
        {
            // Existing photo selected
            
            ViewImageViewController *imageController = [[ViewImageViewController alloc] init];
            
            // Load image view to display the full size version of the image
            NSString *imageFilePath = [[self.photos objectAtIndex:indexPath.row] objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
            imageController.imageToViewFilePath = imageFilePath;
            
            [self.navigationController pushViewController:imageController animated:YES];
            [imageController release];
        }
        else
        {
            // Last row (Add Photo) selected
            
            // Load photo action sheet
            // We do this on the main thread so it appears instantly
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadPhotoActionSheet];
            });
        }
    }
    
    // Additional Documents

    if (additionalDocumentIndex != NSNotFound && indexPath.section == additionalDocumentIndex)
    {
        // Load the Service Documents view

        ServiceDocumentsViewController *serviceDocumentsViewController = [[ServiceDocumentsViewController alloc] initWithParent:TestSessionDetails];
        serviceDocumentsViewController.testSessionData = self.testSessionData;
        serviceDocumentsViewController.branchData = [databaseManager getBranchById:[self.equipmentData nullableObjectforKeyFromEquipmentOrParentEquipment:TABLE_EQUIPMENT_COLUMN_BRANCH_ID]];
        serviceDocumentsViewController.documents = self.serviceDocuments;
        [self.navigationController pushViewController:serviceDocumentsViewController animated:YES];
        [serviceDocumentsViewController release];
    }
    
    // Verification
    
    if (verificationIndex != NSNotFound && indexPath.section == verificationIndex)
    {
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        // Verify breaker trip units set up correctly
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME])
        {
            // Load a reference data view to allow the user to select Yes or No result
            ReferenceDataViewController *referenceData = [[ReferenceDataViewController alloc] init];
            referenceData.delegate = self;
            referenceData.allData = [databaseManager getTestSessionCheckOutcomes];
            referenceData.idKey = TABLE_REFERENCE_ID;
            referenceData.displayKey = TABLE_REFERENCE_NAME;
            referenceData.selectedId = [self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID];
            referenceData.idKeyToUpdate = TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID;
            referenceData.displayKeyToUpdate = TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME;
            
            [self.navigationController pushViewController:referenceData animated:YES];
        }
        
        // Tested to Mardix general arrangement drawing revision
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 50;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION;
            
            // If we have a valid general arrangement drawing revision, set this as the text to copy
            NSString *unitDrawingRef = [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_DRAWING_REF];
            NSRange unitDrawingRefRevisionRange = [[unitDrawingRef lowercaseString] rangeOfString:TABLE_COMMON_VALUE_REV];
            if (unitDrawingRefRevisionRange.length > 0)
            {
                NSString *unitDrawingRefRevision = [unitDrawingRef substringFromIndex:(unitDrawingRefRevisionRange.location + unitDrawingRefRevisionRange.length)];
                if ([unitDrawingRefRevision length] >= 1) {
                    textEditor.textToCopy = [unitDrawingRefRevision substringToIndex:1];
                    textEditor.textCopyButtonTitle = NSLocalizedString(@"TEST_SESSION_DETAILS_BUTTON_USE_LATEST", nil);
                }
            }
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // Tested to Mardix electrical schematic drawing revision
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 50;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION;
            
            // If we have a valid electrical schematic drawing revision, set this as the text to copy
            NSString *electricalSchematicDrawingRef = [self.equipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_ELECTRICAL_SCHEMATIC_DRAWING_REF];
            NSRange electricalSchematicDrawingRefRevisionRange = [[electricalSchematicDrawingRef lowercaseString] rangeOfString:TABLE_COMMON_VALUE_REV];
            if (electricalSchematicDrawingRefRevisionRange.length > 0)
            {
                NSString *electricalSchematicDrawingRefRevision = [electricalSchematicDrawingRef substringFromIndex:(electricalSchematicDrawingRefRevisionRange.location + electricalSchematicDrawingRefRevisionRange.length)];
                if ([electricalSchematicDrawingRefRevision length] >= 1) {
                    textEditor.textToCopy = [electricalSchematicDrawingRefRevision substringToIndex:1];
                    textEditor.textCopyButtonTitle = NSLocalizedString(@"TEST_SESSION_DETAILS_BUTTON_USE_LATEST", nil);
                }
            }
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
    }
    
    // Additional Information
    
    if (additionalInformationIndex != NSNotFound && indexPath.section == additionalInformationIndex)
    {
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        // TX Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // STS Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // AHF Serial No
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // Unit Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_UNIT_RATING])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_UNIT_RATING];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_UNIT_RATING;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // TX Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TX_RATING])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TX_RATING];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_TX_RATING;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // STS Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_STS_RATING])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_STS_RATING];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_STS_RATING;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // AHF Rating
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_AHF_RATING])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 255;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_AHF_RATING];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_AHF_RATING;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
        
        // Electrical Supply System
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME])
        {
            // Load a reference data view to allow the user to select electrical supply system
            ReferenceDataViewController *referenceData = [[ReferenceDataViewController alloc] init];
            referenceData.delegate = self;
            referenceData.allData = [databaseManager getTestSessionElectricalSupplySystems];
            referenceData.idKey = TABLE_REFERENCE_ID;
            referenceData.displayKey = TABLE_REFERENCE_NAME;
            referenceData.selectedId = [self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID];
            referenceData.idKeyToUpdate = TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID;
            referenceData.displayKeyToUpdate = TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME;
            
            [self.navigationController pushViewController:referenceData animated:YES];
        }
        
        // Location
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME])
        {
            // Load a reference data view to allow the user to select location
            ReferenceDataViewController *referenceData = [[ReferenceDataViewController alloc] init];
            referenceData.delegate = self;
            referenceData.allData = [databaseManager getTestSessionLocations];
            referenceData.idKey = TABLE_REFERENCE_ID;
            referenceData.displayKey = TABLE_REFERENCE_NAME;
            referenceData.selectedId = [self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID];
            referenceData.idKeyToUpdate = TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID;
            referenceData.displayKeyToUpdate = TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME;
            
            [self.navigationController pushViewController:referenceData animated:YES];
        }
        
        // Comments
        if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_COMMENTS])
        {
            TextEditorViewController *textEditor = [[TextEditorViewController alloc] init];
            textEditor.delegate = self;
            textEditor.maximumLength = 200;
            textEditor.textToEdit = [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_COMMENTS];
            textEditor.keyToUpdate = TABLE_TEST_SESSION_COLUMN_COMMENTS;
            
            [self.navigationController pushViewController:textEditor animated:YES];
            [textEditor release];
        }
    }
    
    // Sign Off
    
    if (signOffIndex != NSNotFound && indexPath.section == signOffIndex)
    {
        NSArray *rows = [[_tableArray objectAtIndex:indexPath.section] objectForKey:TESTS_TABLE_SECTIONS_KEY_ROWS];
        
        UserManager *userManager = [UserManager sharedInstance];
        
        // Signatories are only enabled when we have a valid result and required fields are completed
        if (![self canSignOffTestSession] && ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME] || [[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME]))
        {
            // If required fields have not yet been completed, display a tooltip
            [self displayAlertWithMessage:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_COMPLETE_TESTS_AND_REQUIRED_FIELDS_BEFORE_SIGN_OFF", nil) atIndexPath:indexPath ofTableView:tableView];
        }
        else
        {
            // Mardix signatory
            if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME])
            {
                NSArray *data = [databaseManager getUnarchivedEngineers];
                NSDictionary *engineerFromLoggedInUser = [databaseManager getEngineerByEmail:[userManager getLoggedInUsersUsername]];
                
                // Load a reference data view to allow the user to select a Signatory
                // We set the scrollToId to automatically scroll to the logged-in user if no selection is specified
                
                // Give the reference data a custom data dictionary
                // This is used to supply an identifier (so that e.g. delegate objects know which specific reference data view controller called the method)
                NSMutableDictionary *customData = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                                    TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID, REFERENCE_DATA_IDENTIFIER,
                                                    REFERENCE_DATA_NAVIGATION_ACTION_PREVENT_POP, REFERENCE_DATA_NAVIGATION_ACTION,
                                                    nil] autorelease];
                
                // Don't set 'KeyToUpdate' fields as in the other reference data view controllers
                // as this is set by the SignOffViewController, rather than via the standard Reference View Controller workflow
                ReferenceDataViewController *referenceData = [[ReferenceDataViewController alloc] init];
                referenceData.delegate = self;
                referenceData.allData = data;
                referenceData.idKey = TABLE_REFERENCE_ID;
                referenceData.displayKey = TABLE_REFERENCE_NAME;
                referenceData.selectedId = [self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID];
                referenceData.scrollToId = [engineerFromLoggedInUser objectForKey:TABLE_ENGINEER_COLUMN_ID];
                referenceData.customData = customData;
                
                [self.navigationController pushViewController:referenceData animated:YES];
            }
            
            // Witness signatory
            if ([[rows objectAtIndex:indexPath.row] isEqualToString:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME])
            {
                // Load a reference data view to allow the user to select a witness signatory type
                // This will then make a call to the appropriate reference data view controller to actually select the witness signatory
                TestSessionWitnessSignatorySelectionViewController *testSessionWitnessSignatorySelection = [[TestSessionWitnessSignatorySelectionViewController alloc] init];
                testSessionWitnessSignatorySelection.delegate = self;
                testSessionWitnessSignatorySelection.equipmentData = self.equipmentData;
                testSessionWitnessSignatorySelection.testSessionData = self.testSessionData;
                [self.navigationController pushViewController:testSessionWitnessSignatorySelection animated:YES];
            }
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger testsIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_TESTS];
    NSInteger photosIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_PHOTOS];

    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

        _selectedIndex = indexPath.row;
        
        if (testsIndex != NSNotFound && indexPath.section == testsIndex)
        {
            // Delete test
            
            // Show confirmation dialogue to user
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_DELETE_TEST", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_NO", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {}];
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_YES", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                // Delete the test
                NSDictionary *test = [self.tests objectAtIndex:_selectedIndex];
                NSDictionary *document = [databaseManager getDocumentById:[test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]];
                
                // Delete document and database record
                if ([document count])
                    [databaseManager deleteDocumentById:[document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID] includingFile:YES];
                
                // Delete test database record
                [databaseManager deleteTestSessionTestById:[test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_ID]];
                
                // Refresh the tests data and table array
                [self refreshTestSession];
                [_tableArray replaceObjectAtIndex:[self tableSectionIndexForName:TESTS_TABLE_SECTION_TESTS] withObject:[self tableSectionDictionaryTests]];

                // Delete table row then reload the new row at that index, to update canEditRowAtIndexPath delegate result
                // See second answer in http://stackoverflow.com/questions/18394816/at-caneditrowatindexpath-method-reloaddata-of-uitableview-not-work-properly
                [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];

                NSInteger signOffIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_SIGN_OFF];
                if (signOffIndex != NSNotFound)
                    [tableView reloadSections:[NSIndexSet indexSetWithIndex:signOffIndex] withRowAnimation:NO];

                [appDelegate updateSyncBadgeCount];
            }];
            [alert addAction:cancelAction];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
    
        if (photosIndex != NSNotFound && indexPath.section == photosIndex)
        {
            NSDictionary *document = [self.photos objectAtIndex:indexPath.row];
            
            // Delete document data in database
            [databaseManager deleteDocumentsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil filePath:[document objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] includingFiles:YES];
            
            // Refresh the photos collection and table array
            [self refreshPhotos];
            [_tableArray replaceObjectAtIndex:[self tableSectionIndexForName:TESTS_TABLE_SECTION_PHOTOS] withObject:[self tableSectionDictionaryPhotos]];

            // If we have just removed the last photo, delete table row
            if ([self.photos count] == 0) {
                // Delete table row then reload the new row at that index, to update canEditRowAtIndexPath delegate result
                // See second answer in http://stackoverflow.com/questions/18394816/at-caneditrowatindexpath-method-reloaddata-of-uitableview-not-work-properly
                [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                NSInteger signOffIndex = [self tableSectionIndexForName:TESTS_TABLE_SECTION_SIGN_OFF];
                if (signOffIndex != NSNotFound)
                    [tableView reloadSections:[NSIndexSet indexSetWithIndex:signOffIndex] withRowAnimation:NO];
            }
            [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];

            [appDelegate updateSyncBadgeCount];
        }
    }
}

#pragma mark - PDFDocumentDelegate

- (void)pdfDocumentWillAppear:(FSPDFDoc *)pdfDocument
{
    // Enforce form field values from model data
    [self setFormFieldsInTestDocument:pdfDocument withDateString:[self.selectedTestData nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_START_DATE]];

    [self hideProgressIcon];    
}

- (void)didFinishEditingPdfDocument:(FSPDFDoc *)pdfDocument
{
    // The user has finished editing the PDF document

    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Enforce form field values from model data
    [self setFormFieldsInTestDocument:pdfDocument withDateString:[self.selectedTestData nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_START_DATE]];
    
    // Get the current file path for the test document, and a new incremented file path
    // We have to save a new version of the file then remove the old one, as the SDK won't allow an open document to be saved over
    NSDictionary *document = [databaseManager getDocumentById:[self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]];
    NSDictionary *documentType = [databaseManager getDocumentTypeById:[document objectForKey:TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID]];
    NSString *oldFilePath = [self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_FILE_PATH];
    NSString *newFilePath = [self incrementedTestDocumentFilePathForFilePath:[self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_FILE_PATH] testSessionId:[self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID] documentType:documentType];
    
    // Save a new version of the file and update the associated database record
    if ([self updateTestDocument:pdfDocument withNewFilePath:newFilePath forDocumentId:[self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]])
    {
        // File save successful
        
        // Remove old file
        [fileManager removeItemAtPath:[oldFilePath stringByPrependingDocumentsDirectoryFilepath] error:nil];

        // Update associated test data
        
        // Although the document was opened for a specific test, there may be other tests that share it
        // We need to identify and update all relevant tests together
        NSArray *tests = [databaseManager getTestSessionTestsForDocumentId:[self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]];
        
        for (NSDictionary *test in tests)
        {
            NSMutableDictionary *testData = [NSMutableDictionary dictionaryWithDictionary:test];
            NSDictionary *testType = [databaseManager getTestTypeById:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID]];
            
            // Set test end date
            [testData setObject:[NSDate date] forKey:TABLE_TEST_SESSION_TEST_COLUMN_END_DATE];
            
            // Read the instrument reference directly from the PDF document data
            // This is always the standard InstRef field name with the test number appended
            NSString *instrumentReference = [pdfDocument getValueForFormField:[NSString stringWithFormat:@"%@%@", FORM_FIELD_INST_REF, [testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NUMBER]] fieldIndex:0];
            
            // Set the instrument reference property in the test data dictionary
            if ([instrumentReference length] > 0) {
                if ([instrumentReference length] >= 255) instrumentReference = [instrumentReference substringToIndex:255];  // Only get first 255 characters
                [testData setObject:instrumentReference forKey:TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE];
            }
            else
                [testData removeObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE];
            
            // Read the voltage directly from the PDF document data
            // This is always the standard Voltage field name with the test number appended
            NSString *voltage = [pdfDocument getValueForFormField:[NSString stringWithFormat:@"%@%@", FORM_FIELD_VOLTAGE, [testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NUMBER]] fieldIndex:0];
            
            // If the voltage contains an underscore, we only want the value up to that point
            // This is because if another radio button elsewhere has the same value, an underscore and index number is appended
            NSRange rangeBeforeUnderscore = [voltage rangeOfString:@"_"];
            if (rangeBeforeUnderscore.length > 0)
                voltage = [voltage substringToIndex:rangeBeforeUnderscore.location];
            
            // Set the voltage property in the test data dictionary
            if ([voltage length] > 0 && ![voltage isEqualToString:FORM_FIELD_VOLTAGE_VALUE_OFF])
                [testData setObject:voltage forKey:TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE];
            else
                [testData removeObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE];
            
            // Read the circuit breaker reference directly from the PDF document data
            NSString *circuitBreakerReference = [pdfDocument getValueForFormField:FORM_FIELD_CIRCUIT_BREAKER_NUMBER fieldIndex:0];
            
            // Set the circuit breaker reference property in the test data dictionary
            if ([circuitBreakerReference length] > 0)
                [testData setObject:[NSString stringWithFormat:@"%@", circuitBreakerReference] forKey:TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE];
            else
                [testData removeObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE];
            
            // Set the start date for all tests that use the document
            [testData setObject:[self.selectedTestData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_START_DATE] forKey:TABLE_TEST_SESSION_TEST_COLUMN_START_DATE];
            
            // If this is a QMF 139 document, get the IBAR Installation Test Metadata and store it in the database
            if ([[testData nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE] isEqualToString:TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE_VALUE_QMF_139])
            {
                // Retrieve the existing IBAR Installation Test Metadatas from the database
                // This is always created upon activation of an IBAR Installation test
                NSArray *ibarInstallationTestMetadatas = [databaseManager getIbarInstallationTestMetadatasForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
                
                // Note although the ibarInstallationTestMetadatas database manager call returned an array, we expect only one so simply load the first result
                NSMutableDictionary *ibarInstallationTestMetadata = [NSMutableDictionary dictionaryWithDictionary:[ibarInstallationTestMetadatas objectAtIndex:0]];
                
                // Update the metadata from the form
                
                NSNumber *adjoiningSectionsLevel = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_ADJOINING_SECTIONS_LEVEL fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];

                NSNumber *supportBracketsInstalled = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_SUPPORT_BRACKETS_INSTALLED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];

                NSNumber *supportBracketsFixingBoltsSecure = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];

                NSNumber *jointsInstalled = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_JOINTS_INSTALLED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];

                NSNumber *coversSecurelyInstalled = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_COVERS_SECURELY_INSTALLED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];

                [ibarInstallationTestMetadata setValue:adjoiningSectionsLevel forKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ADJOINING_SECTIONS_LEVEL];
                [ibarInstallationTestMetadata setValue:supportBracketsInstalled forKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_INSTALLED];
                [ibarInstallationTestMetadata setValue:supportBracketsFixingBoltsSecure forKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE];
                [ibarInstallationTestMetadata setValue:jointsInstalled forKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_JOINTS_INSTALLED];
                [ibarInstallationTestMetadata setValue:coversSecurelyInstalled forKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COVERS_SECURELY_INSTALLED];
                
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_DUCTOR_TEST_INSTRUMENT_ID_NUMBER fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1 fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER];
                [ibarInstallationTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_COMMENTS fieldIndex:0] forKey: TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COMMENTS];

                // Update the IBAR Installation Test Metadata record in the database
                [databaseManager updateIbarInstallationTestMetadataWithRow:ibarInstallationTestMetadata];
                
                // Delete any IBAR Installation Test Metadata Continuity Run Ductor Test objects for the active document
                // We always recreate these fresh, as the engineers could conceivably remove data from the document as well as add it
                [databaseManager deleteIbarInstallationTestMetadataContinuityRunDuctorTestsForIbarInstallationTestMetadataId:[ibarInstallationTestMetadata nullableObjectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]];
   
                // Get a count of the total sections in the document
                int sections = 0;
                int count = 1;
                int fieldCount;
                do {
                    fieldCount = [pdfDocument getFieldCountForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_FROM stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", count]]];
                    if (fieldCount > 0) sections = sections + 1;
                    count++;
                } while (fieldCount > 0);
                
                // Iterate each section
                int group = 0;
                int groupCount = 0;
                int groupSize = 6;
                for (int i = 1; i < (sections + 1); i++)
                {
                    // Create a new IBAR Installation Test Metadata Continuity Run Ductor Test record from the form data
                    
                    int groupStart = (1 + (group * groupSize));
                    int groupEnd = ((group + 1) * groupSize);
                    
                    NSString *ibarInstallationTestMetadataId = [ibarInstallationTestMetadata nullableObjectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID];

                    NSString *from = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_FROM stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *to = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];

                    NSString *conductorPair1 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_1 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair1LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_1_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair1ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_1_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair2 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_2 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair2LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_2_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair2ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_2_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair3 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_3 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair3LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_3_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair3ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_3_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair4 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_4 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair4LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_4_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair4ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_4_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair5 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_5 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair5LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_5_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair5ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_5_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair6 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_6 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair6LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_6_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair6ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_6_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair7 = [[pdfDocument getValueForFormField:[[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_TO_Y_CONDUCTOR_PAIR_7 stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", groupStart]] stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_Y withString:[NSString stringWithFormat:@"%d", groupEnd]] fieldIndex:0] trimmed];
                    NSString *conductorPair7LinkMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_7_LINK_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];
                    NSString *conductorPair7ResultMilliohms = [[pdfDocument getValueForFormField:[FORM_FIELD_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_X_CONDUCTOR_PAIR_7_RESULT_MILLIOHMS stringByReplacingOccurrencesOfString:FORM_FIELD_PLACEHOLDER_X withString:[NSString stringWithFormat:@"%d", i]] fieldIndex:0] trimmed];

                    NSMutableDictionary *ibarInstallationTestMetadataContinuityRunDuctorTest = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        ibarInstallationTestMetadataId, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID,
                        from, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_FROM,
                        to, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_TO,
                        conductorPair1, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1,
                        conductorPair1LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1_LINK_MILLIOHMS,
                        conductorPair1ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1_RESULT_MILLIOHMS,
                        conductorPair2, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2,
                        conductorPair2LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2_LINK_MILLIOHMS,
                        conductorPair2ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2_RESULT_MILLIOHMS,
                        conductorPair3, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3,
                        conductorPair3LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3_LINK_MILLIOHMS,
                        conductorPair3ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3_RESULT_MILLIOHMS,
                        conductorPair4, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4,
                        conductorPair4LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4_LINK_MILLIOHMS,
                        conductorPair4ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4_RESULT_MILLIOHMS,
                        conductorPair5, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5,
                        conductorPair5LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5_LINK_MILLIOHMS,
                        conductorPair5ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5_RESULT_MILLIOHMS,
                        conductorPair6, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6,
                        conductorPair6LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6_LINK_MILLIOHMS,
                        conductorPair6ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6_RESULT_MILLIOHMS,
                        conductorPair7, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7,
                        conductorPair7LinkMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7_LINK_MILLIOHMS,
                        conductorPair7ResultMilliohms, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7_RESULT_MILLIOHMS,
                        nil
                        ];

                    // We only want to persist the record if any values are not blank
                    BOOL hasData = ((
                                    [from length] + [to length] +
                                    [conductorPair1LinkMilliohms length] + [conductorPair1ResultMilliohms length] +
                                    [conductorPair2LinkMilliohms length] + [conductorPair2ResultMilliohms length] +
                                    [conductorPair3LinkMilliohms length] + [conductorPair3ResultMilliohms length] +
                                    [conductorPair4LinkMilliohms length] + [conductorPair4ResultMilliohms length] +
                                    [conductorPair5LinkMilliohms length] + [conductorPair5ResultMilliohms length] +
                                    [conductorPair6LinkMilliohms length] + [conductorPair6ResultMilliohms length] +
                                    [conductorPair7LinkMilliohms length] + [conductorPair7ResultMilliohms length]
                                    ) > 0);

                    // Create the IBAR Installation Test Metadata Continuity Run Ductor Test record in the database
                    if (hasData)
                        [databaseManager createIbarInstallationTestMetadataContinuityRunDuctorTestWithRow: ibarInstallationTestMetadataContinuityRunDuctorTest];

                    groupCount++;
                    if (groupCount == groupSize) {
                        groupCount = 0;
                        group++;
                    }
                }
            }

            // If this is a QMF 139_2 document, get the IBAR Installation Joint Test Metadata and store it in the database
            if ([[testData nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE] isEqualToString:TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE_VALUE_QMF_139_2])
            {
                // Retrieve the existing IBAR Installation Joint Test Metadatas from the database
                // This is always created upon activation of an IBAR Installation Joint test
                NSArray *ibarInstallationJointTestMetadatas = [databaseManager getIbarInstallationJointTestMetadatasForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
                
                // Note although the ibarInstallationJointTestMetadatas database manager call returned an array, we expect only one so simply load the first result
                NSMutableDictionary *ibarInstallationJointTestMetadata = [NSMutableDictionary dictionaryWithDictionary:[ibarInstallationJointTestMetadatas objectAtIndex:0]];
                
                // Update the metadata from the form
                
                NSNumber *belleVilleWashersSeated = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_BELLEVILLE_WASHERS_SEATED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];
                NSNumber *nutOuterHeadsShearedOff = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_NUT_OUTER_HEADS_SHEARED_OFF fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];
                NSNumber *nutsMarked = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_NUTS_MARKED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];
                NSNumber *coversInstalled = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_COVERS_INSTALLED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];
                NSNumber *boltsTorqueChecked = [NSNumber numberWithBool:
                                                ([[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_BOLTS_TORQUE_CHECKED fieldIndex:0] isEqualToString:FORM_FIELD_RESULT_VALUE_PASS])
                                                ? YES : NO
                                                ];

                [ibarInstallationJointTestMetadata setValue:belleVilleWashersSeated forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BELLEVILLE_WASHERS_SEATED];
                [ibarInstallationJointTestMetadata setValue:nutOuterHeadsShearedOff forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUT_OUTER_HEADS_SHEARED_OFF];
                [ibarInstallationJointTestMetadata setValue:nutsMarked forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUTS_MARKED];
                [ibarInstallationJointTestMetadata setValue:coversInstalled forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COVERS_INSTALLED];
                [ibarInstallationJointTestMetadata setValue:boltsTorqueChecked forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BOLTS_TORQUE_CHECKED];
                
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_TORQUE_WRENCH_ID_NUMBER fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TORQUE_WRENCH_ID_NUMBER];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_EARTH fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2 fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1 fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2 fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3 fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_DUCTOR_TEST_INSTRUMENT_ID_NUMBER fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER];
                [ibarInstallationJointTestMetadata setValue:[pdfDocument getValueForFormField:FORM_FIELD_IBAR_INSTALLATION_JOINT_TEST_METADATA_COMMENTS fieldIndex:0] forKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COMMENTS];

                // Update the IBAR Installation Joint Test Metadata record in the database
                [databaseManager updateIbarInstallationJointTestMetadataWithRow:ibarInstallationJointTestMetadata];
            }
            
            // If any of the following are true, display a validation warning
            // * Any IBAR Installation Joint Test ductor resistance fields are incomplete
            // * Any IBAR Installation Joint Test ductor resistance fields contain invalid values
            // * Any IBAR Installation Joint Test ductor resistance fields are not within tolerance
            // * The equipment location is incomplete, if it is required for sign off
            
            // Get the ductor field validation dictionaries
            // Note these will be empty by default for any test sessions for which this type of data is not relevant
            NSDictionary *ductorFieldsIncomplete = [self ibarInstallationJointTestDuctorResistanceFieldsRequiredButIncomplete];
            NSDictionary *ductorFieldsInvalid = [self ibarInstallationJointTestDuctorResistanceFieldsContainingInvalidCharacters];
            NSDictionary *ductorFieldsNotWithinTolerance = [self ibarInstallationJointTestDuctorResistanceFieldsNotWithinTolerance];
            NSNumber *ductorFieldCount2PE = [self ibarInstallationJointTestDuctorResistance2PEFieldCount];
            NSInteger ductorFieldErrors = ([[ductorFieldsIncomplete allKeys] count] + [[ductorFieldsInvalid allKeys] count] + [[ductorFieldsNotWithinTolerance allKeys] count]);
            
            // We only want to warn the user if any of the above validations have failed
            if (ductorFieldErrors > 0 || (ductorFieldCount2PE != nil && [ductorFieldCount2PE intValue] != 2) || [self equipmentLocationRequiredButMissing])
            {
                // Begin building the warning message
                NSString *validationMessage = NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_ERRORS_MUST_BE_CORRECTED", nil);

                // Include warning if equipment location is required but missing
                if ([self equipmentLocationRequiredButMissing])
                {
                    NSString *equipmentString = ([self.equipmentData hasParentEquipment]) ? NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_COMPONENT", nil) : NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_EQUIPMENT", nil);
                    validationMessage = [validationMessage stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_EQUIPMENT_LOCATION_NOT_SET", nil), equipmentString]];
                }
                
                // If we have any ductor field errors, we process each field separately by name
                // but only include a warning for that field if it has any errors
                if (ductorFieldErrors > 0)
                {
                    NSString *conductorConfiguration = NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_UNKNOWN", nil);
                    if ([self.equipmentData hasParentEquipment]) {
                        NSDictionary *parentEquipmentData = [databaseManager getEquipmentById:[self.equipmentData objectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]];
                        conductorConfiguration = [parentEquipmentData nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_NAME];

                    }

                    for (NSString *fieldName in [self ibarInstallationJointTestDuctorResistanceFieldNames])
                    {
                        if ([ductorFieldsIncomplete objectForKey:fieldName] != nil || [ductorFieldsInvalid objectForKey:fieldName] != nil || [ductorFieldsNotWithinTolerance objectForKey:fieldName] != nil)
                        {
                            // Field has a validation error, so begin building a message segment for that field
                            
                            NSString *fieldValidationMessage = [NSString stringWithFormat:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_CONDUCTOR", nil), [self ibarInstallationJointTestDuctorResistanceFormFieldFromDatabaseField: fieldName]];
                            
                            // Field required but incomplete
                            if ([ductorFieldsIncomplete objectForKey:fieldName] != nil) {
                                fieldValidationMessage = [fieldValidationMessage stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_RESISTANCE_VALUE_REQUIRED", nil), conductorConfiguration]];
                            }

                            // Field contains invalid value
                            else if ([ductorFieldsInvalid objectForKey:fieldName] != nil) {
                                NSString *invalidValue = ([self ibarInstallationJointTestDuctorResistanceValueIsEmpty:[ductorFieldsInvalid nullableObjectForKey:fieldName]]) ? NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_EMPTY", nil) : [ductorFieldsInvalid nullableObjectForKey:fieldName];
                                fieldValidationMessage = [fieldValidationMessage stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_INVALID_RESISTANCE_VALUE", nil), invalidValue]];
                                // If the field has a non-empty value but is expected to be empty for the bar's conductor configuration,
                                // display an additional helper message for this specific scenario
                                if ([[self ibarInstallationJointTestDuctorResistanceFieldsWithRequired:NO notRequired:YES] objectForKey:fieldName] != nil && ![self ibarInstallationJointTestDuctorResistanceValueIsEmpty:[ductorFieldsInvalid objectForKey:fieldName]])
                                    fieldValidationMessage = [fieldValidationMessage stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_EXPECTED_EMPTY_VALUE_FOR_CONFIGURATION", nil), conductorConfiguration]];
                            }

                            // Field contains value not within tolerance
                            else if ([ductorFieldsNotWithinTolerance objectForKey:fieldName] != nil) {
                                fieldValidationMessage = [fieldValidationMessage stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_RESISTANCE_VALUE_OUTSIDE_TOLERANCE", nil), [ductorFieldsNotWithinTolerance nullableObjectForKey:fieldName]]];
                            }

                            validationMessage = [validationMessage stringByAppendingString:fieldValidationMessage];
                        }
                    }
                }
                
                if (ductorFieldCount2PE != nil)
                {
                    // Include warning if the bar has a 2P&E configuration and too few of the required permutation fields are complete
                    if ([ductorFieldCount2PE intValue] < 2)
                        validationMessage = [validationMessage stringByAppendingString:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_TOO_FEW_2PE_FIELDS_COMPLETED", nil)];

                    // Include warning if the bar has a 2P&E configuration and too many of the required permutation fields are complete
                    if ([ductorFieldCount2PE intValue] > 2)
                        validationMessage = [validationMessage stringByAppendingString:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_TOO_MANY_2PE_FIELDS_COMPLETED", nil)];
                }

                validationMessage = [validationMessage stringByAppendingString:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_FOR_ADVICE_CONTACT_TECHNICAL_LEAD", nil)];

                // Display warning to the user
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:validationMessage preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                [alert addAction:defaultAction];
                [self presentViewController:alert animated:YES completion:nil];
            }

            // If the test type requires a result, read the test result directly from the PDF document data
            if ([[testType objectForKey:TABLE_TEST_TYPE_COLUMN_REQUIRES_RESULT] boolValue])
            {
                // Clear test result initially
                NSString *resultName = nil;
                [testData setObject:[NSNull null] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
                [testData setObject:[NSNull null] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME];

                // First we look for the Result field name with the test number appended (with no underscore), e.g. Result4, Result5
                // This can be the case on composite forms
                NSString *resultPdf = [pdfDocument getValueForFormField:[NSString stringWithFormat:@"%@%@", FORM_FIELD_RESULT, [testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NUMBER]] fieldIndex:0];
                
                if ([resultPdf length] > 0)
                {
                    // Valid result found, so get the corresponding result name from the value selected
                    resultName = [self getPdfResultNameFromFieldValue:resultPdf];
                }
                else
                {
                    // No valid result found, so look for standard result fields instead
                    // This is usually a single field named Result, or a collection of duplicate fields named Result with incremental indexed suffixes (with underscores), e.g. Result, Result_2, Result_3
                    // For the latter, all result fields must be completed in order to return a test result, and a single failing result field will return a failing test result
                    NSArray *resultsPdf = [pdfDocument getValuesForFormFields:FORM_FIELD_RESULT];
                    
                    if ([resultsPdf count] == 1) {
                        // Single Result field, so simply get the corresponding result name from the value selected
                        resultPdf = [resultsPdf objectAtIndex:0];
                        resultName = [self getPdfResultNameFromFieldValue:resultPdf];
                    }
                    if ([resultsPdf count] > 1)
                    {
                        // Multiple Result fields, so we need to derive the overall result based on the combination of field values
                        // Begin with a default test result of Pass
                        resultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS;
                        
                        for (NSString *resultPdfItem in resultsPdf) {
                            if ([resultPdfItem length] >= 4 && [[resultPdfItem substringToIndex:4] isEqual:FORM_FIELD_RESULT_VALUE_FAIL])
                                // If any result fields are set to fail, set test result to Fail
                                resultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL;
                            if (
                                !([resultPdfItem length] >= 4 && ([resultPdfItem isEqualToString:FORM_FIELD_RESULT_VALUE_PASS] || [resultPdfItem isEqualToString:FORM_FIELD_RESULT_VALUE_FAIL]))
                                && !([resultPdfItem length] >= 2 && [[[resultPdfItem stringByReplacingOccurrencesOfString:@"/" withString:@""] substringToIndex:2] isEqual:FORM_FIELD_RESULT_VALUE_NOT_APPLICABLE])
                                )
                            {
                                // If any result fields are not yet completed, clear the test result and exit the loop
                                resultName = nil;
                                break;
                            }
                        }
                    }
                }
                
                // If this is an STF 05 document, get all the ethernet gateway field values
                if ([[testData nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE] isEqualToString:TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE_VALUE_STF_05])
                {
                    // Firstly, get the 'ethernet gateway configured as default/no' checkbox value
                    NSString *ethernetGatewayConfiguredAsDefaultNo = [pdfDocument getValueForFormField:FORM_FIELD_ETHERNET_GATEWAY_CONFIGURED_AS_DEFAULT_NO fieldIndex:0];
                    
                    // We are going to create an array of sub-arrays, each containg all values for each type of field
                    NSArray *ethernetGatewayValues = [[NSArray alloc] initWithObjects:
                                                      [pdfDocument getValuesForFormFields:FORM_FIELD_GATEWAY_REFERENCE],
                                                      [pdfDocument getValuesForFormFields:FORM_FIELD_IP_ADDRESS],
                                                      [pdfDocument getValuesForFormFields:FORM_FIELD_SUBNET_MASK],
                                                      [pdfDocument getValuesForFormFields:FORM_FIELD_DEFAULT_GATEWAY],
                                                      [pdfDocument getValuesForFormFields:FORM_FIELD_BAUD_RATE],
                                                      [pdfDocument getValuesForFormFields:FORM_FIELD_PARITY],
                                                      nil];
                    
                    BOOL ethernetGatewayValuesCompleted = YES;
                    
                    // We now loop through each collection of values, and we expect to find at least one complete value for each type
                    for (NSArray *values in ethernetGatewayValues) {
                        NSInteger valueCount = 0;
                        for (NSString *value in values) {
                            // For every non-empty, non-whitespace character, increase the value count
                            if (value && ![(NSNull *)value isEqual:[NSNull null]] && ![value isEqualToString: @""] && [[value trimmed] length] > 0)
                                valueCount ++;
                        }
                        // If the value count for any of the field type value collections is zero, set the completed flag to NO
                        if (valueCount == 0) ethernetGatewayValuesCompleted = NO;
                    }
                    
                    [ethernetGatewayValues release];
                    
                    // If at least one of each type of field was not completed, and a non-default configuration has been indicated, clear the test result and display a warning to the user
                    if (ethernetGatewayValuesCompleted == NO && [ethernetGatewayConfiguredAsDefaultNo isEqualToString:FORM_FIELD_ETHERNET_GATEWAY_CONFIGURED_AS_DEFAULT_NO_VALUE_ON])
                    {
                        resultName = nil;
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_WARNING", nil) message:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_ETHERNET_GATEWAY_FIELDS_INCOMPLETE", nil) preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                        [alert addAction:defaultAction];
                        [self presentViewController:alert animated:YES completion:nil];
                    }
                }

                // In-document validation
                
                // If any of the following are true, we do not set a result
                // * Any IBAR Installation Joint Test ductor resistance fields are incomplete
                // * Any IBAR Installation Joint Test ductor resistance fields contain invalid values
                // * Any IBAR Installation Joint Test ductor resistance fields are not within tolerance
                BOOL ductorFieldsValidated = (
                                              [[[self ibarInstallationJointTestDuctorResistanceFieldsRequiredButIncomplete] allKeys] count] +
                                              [[[self ibarInstallationJointTestDuctorResistanceFieldsContainingInvalidCharacters] allKeys] count] +
                                              [[[self ibarInstallationJointTestDuctorResistanceFieldsNotWithinTolerance] allKeys] count]
                                              ) == 0;
                
                // For IBAR Installation Joint Test certificates with configuration 2P&E, only 2 valid conductors must be complete before the test can be passed
                BOOL ductorFields2PeValidated = ([self ibarInstallationJointTestDuctorResistance2PEFieldCount] == nil || [[self ibarInstallationJointTestDuctorResistance2PEFieldCount] intValue] == 2);

                // If any in-document validation has failed, clear the test result
                if (!ductorFieldsValidated || !ductorFields2PeValidated || [self equipmentLocationRequiredButMissing])
                    resultName = nil;
                
                // Final result
                
                // If we have a valid result, set the result property in the test data dictionary
                if (resultName) {
                    NSDictionary *result = [databaseManager getTestResultByName:resultName];
                    [testData setObject:[result objectForKey:TABLE_TEST_RESULT_COLUMN_ID] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
                    [testData setObject:[result objectForKey:TABLE_TEST_RESULT_COLUMN_NAME] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME];
                }
            }
            
            // Update the test record in the database
            [databaseManager updateTestSessionTestWithRow:testData];
        }
        
        [self keepDatabaseUpdated];
        
        // Refresh view
        [self refreshDisplay];
    }
}

- (void)setFormFieldsInTestDocument:(FSPDFDoc *)testDocument withDateString:(NSString *)dateString
{
    // Enforces form field values from model data
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    NSDictionary *branchData = [databaseManager getBranchById:[self.equipmentData nullableObjectforKeyFromEquipmentOrParentEquipment:TABLE_EQUIPMENT_COLUMN_BRANCH_ID]];

    [testDocument setCoreFormFieldValuesWithDateString:dateString forceOverwrite:YES];
    [testDocument setFormFieldValuesForEquipmentData:self.equipmentData forceOverwrite:YES];
    [testDocument setFormFieldValuesForBranchData:branchData forceOverwrite:YES];
    [testDocument setFormFieldValuesForTestSessionData:self.testSessionData forceOverwrite:YES];
}

- (NSString *)getPdfResultNameFromFieldValue:(NSString *)fieldValue
{
    // Returns the corresponding result name from the value selected in a pdf Result field
    
    NSString *resultName = nil;
    
    if ([fieldValue length] >= 2 && [[[fieldValue stringByReplacingOccurrencesOfString:@"/" withString:@""] substringToIndex:2] isEqual:FORM_FIELD_RESULT_VALUE_NOT_APPLICABLE])
        resultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_NOT_APPLICABLE;
    if ([fieldValue length] >= 4 && [[fieldValue substringToIndex:4] isEqual:FORM_FIELD_RESULT_VALUE_PASS])
        resultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_PASS;
    if ([fieldValue length] >= 4 && [[fieldValue substringToIndex:4] isEqual:FORM_FIELD_RESULT_VALUE_FAIL])
        resultName = TABLE_TEST_RESULT_COLUMN_NAME_VALUE_FAIL;
    
    return resultName;
}

#pragma mark - ApiDelegate

- (void)didGetParsedData:(id)parsedData apiMethod:(apiMethods)apiMethod httpMethod:(httpMethods)httpMethod
{
    // Delegate method called when the Api returns data
    
    // Get data from Api response
    if (![parsedData isKindOfClass:[NSDictionary class]] || ![parsedData objectForKey:API_RESPONSE_DATA]) {
        [self didFailToGetParsedData];
        return;
    }
    id data = [parsedData objectForKey:API_RESPONSE_DATA];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    databaseManager.delegate = nil;
    AlertManager *alertManager = [AlertManager sharedInstance];
    
    [self hideProgressIcon];
    
    if ([data isKindOfClass:[NSDictionary class]] && [data objectForKey:TABLE_TEST_SESSION_COLUMN_ID])
    {
        // Parsed data is a fully formed array with at least one valid dictionary, so proceed
        
        // Recreate test session data in local database
        BOOL result = [databaseManager deleteTestSessionById:[data objectForKey:TABLE_TEST_SESSION_COLUMN_ID] withTestsAndDocuments:YES];
        if (result)
            result = [databaseManager addRowsToTestSession:[NSArray arrayWithObject:data]];
        
        if (result)
        {
            // Update successful, so inform user
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_INFORMATION", nil) message:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_SUCCESSFULLY_ABANDONED_TEST_SESSION", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
            
            // Refresh view
            [self refreshDisplay];
        }
        else
            [alertManager showAlertForErrorType:UpdateTestSessionFromApi withError:nil];
    }
    else
        [self didFailToGetParsedData];
    
    [appDelegate updateSyncBadgeCount];
}

- (void)didFailToGetParsedData
{
    // Api download failure
    
    [self hideProgressIcon];
    
    // Alert user
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:UpdateTestSessionViaApi withError:nil];
}

- (void)invalidApiMethod
{
    // Api method unrecognised
    
    [self hideProgressIcon];
    
    // Alert user
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:UpdateTestSessionViaApi withError:nil];
}

- (void)apiIsUnreachable
{
    // Api cannot be contacted
    
    [self hideProgressIcon];
    
    // Alert user
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:UpdateTestSessionViaApi withError:nil];
}

- (void)didReceiveUnsuccessfulStatusCode
{
    // Api returned unsuccessful status code
    
    [self hideProgressIcon];
    
    // Alert user
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:UnsuccessfulApiStatusCode withError:nil];
}

- (void)networkConnectionLostWithError:(NSError *)error apiMethod:(apiMethods)apiMethod
{
    // Api reported network connection drop
    
    [self hideProgressIcon];
    
    // Display alert
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:NetworkConnectionUnavailable withError:error];
}

- (void)didReportConflictWithData:(id)parsedData
{
    // Api reported a conflict
    
    [self hideProgressIcon];
    
    // Display alert
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:AbandonTestSessionConflict withError:nil];
}

#pragma mark - TestSessionActivationManagerDelegate

- (void)didCompleteActivationWithResultCount:(NSInteger)resultCount
{
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];

    [self hideProgressIcon];
    
    // Set Unit Rating of new test session to match equipment rating
    NSString *unitRating = [self.equipmentData nullableObjectforKeyFromEquipmentOrParentEquipment:TABLE_EQUIPMENT_COLUMN_RATING_NAME];
    if (unitRating)
        [self.testSessionData setObject:unitRating forKey:TABLE_TEST_SESSION_COLUMN_UNIT_RATING];
    
    // Set specific fields to have default values of N/A if they are empty to begin with
    NSArray *keys = [NSArray arrayWithObjects:
                     TABLE_TEST_SESSION_COLUMN_AHF_RATING,
                     TABLE_TEST_SESSION_COLUMN_STS_RATING,
                     TABLE_TEST_SESSION_COLUMN_TX_RATING,
                     TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO,
                     TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO,
                     TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO,
                     nil];
    for (NSString *key in keys) {
        if ([self.testSessionData objectForKey:key] && ([[self.testSessionData nullableObjectForKey:key] isEqualToString:@""] || (NSNull *)[self.testSessionData objectForKey:key] == [NSNull null]))
            [self.testSessionData setObject:TABLE_COMMON_VALUE_N_A forKey:key];
    }
    
    [self keepDatabaseUpdated];
    
    // If this is an IBAR Installation Test, create an IBAR Installation Test Metadata record
    if ([[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_NAME] isEqualToString:TABLE_TEST_SESSION_TYPE_COLUMN_NAME_VALUE_IBAR_INSTALLATION_TEST]) {
        NSArray *ibarInstallationTests = [databaseManager getTestSessionTestsForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
        NSMutableDictionary *createIbarInstallationTestMetadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID], TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                [[ibarInstallationTests objectAtIndex:0] nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID], TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID,
                nil
                ];
        [databaseManager createIbarInstallationTestMetadataWithRow:createIbarInstallationTestMetadata];
    }

    // If this is an IBAR Installation Joint Test, create an IBAR Installation Joint Test Metadata record
    if ([[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_NAME] isEqualToString:TABLE_TEST_SESSION_TYPE_COLUMN_NAME_VALUE_IBAR_INSTALLATION_JOINT_TEST]) {
        NSArray *ibarInstallationJointTests = [databaseManager getTestSessionTestsForTestSessionId:[self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
        NSMutableDictionary *createIbarInstallationJointTestMetadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID], TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                [[ibarInstallationJointTests objectAtIndex:0] nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID], TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID,
                nil
                ];
        [databaseManager createIbarInstallationJointTestMetadataWithRow:createIbarInstallationJointTestMetadata];
    }

    // Refresh view
    [self refreshDisplay];
}

- (void)didFailActivation
{
    [self hideProgressIcon];
    
    self.buildLocationId = nil;
}

#pragma mark - TestSessionSignatureDelegate

- (void)didSetSignatory
{
    // The user has finished setting one of the signatories
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    // If the master document is a test document, set any tests with that document as requiring sync
    // This ensures that each test's document is then updated with the new signature information
    // This is needed because the documents are associated with those tests, and not with the test session documents (which are always updated by default)
    NSArray *documents = [databaseManager getMasterDocumentsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
    if (documents && [documents count])
    {
        for (NSDictionary *document in documents) {
            NSArray *tests = [databaseManager getTestSessionTestsForDocumentId:[document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID]];
            for (NSDictionary *testData in tests) {
                [databaseManager updateTestSessionTestWithRow:testData];
            }
        }
    }
    
    [self keepDatabaseUpdated];
}

#pragma mark - TextEditorDelegate

- (void)hasFinishedTextEditingWithText:(NSString *)text forKeyToUpdate:(NSString *)keyToUpdate
{
    // The user has finished editing text
    
    NSString *textToUpdate = [keyToUpdate isEqualToString:TABLE_TEST_SESSION_COLUMN_COMMENTS] ? [text stringByReplacingOccurrencesOfString:@"\n" withString:@""] : text;
    [self.testSessionData setValue:textToUpdate forKey:keyToUpdate];
    
    [self keepDatabaseUpdated];
}

#pragma mark - TestSessionWitnessSignatorySelectionDelegate
#pragma mark - TestSessionTestReferenceDataDelegate

- (void)didSelectReferenceDataItem:(NSDictionary *)selectedItem withCustomData:(NSDictionary *)customData withIdKey:(NSString *)idKey withDisplayKey:(NSString *)displayKey withIdKeyToUpdate:(NSString *)idKeyToUpdate withDisplayKeyToUpdate:(NSString *)displayKeyToUpdate
{
    // Note this delegate method is used by both the TestSessionWitnessSignatorySelectionDelegate and ReferenceDataDelegate
    // This is because the TestSessionWitnessSignatorySelectionViewController is itself a ReferenceDataDelegate
    // so it just passes the same delegate method through to this view controller
    
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    if ([customData objectForKey:TABLE_TEST_SESSION_TEST])
    {
        // Custom data contains an Identifier value for Test Session Test, meaning that the selected item is an individual test result
        
        NSMutableDictionary *testData = [NSMutableDictionary dictionaryWithDictionary:[databaseManager getTestSessionTestById:[customData objectForKey:TABLE_TEST_SESSION_TEST]]];
        
        // Set selected result for test
        [testData setObject:[selectedItem objectForKey:TABLE_REFERENCE_ID] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
        
        // Set test end date
        [testData setObject:[NSDate date] forKey:TABLE_TEST_SESSION_TEST_COLUMN_END_DATE];
        
        [databaseManager updateTestSessionTestWithRow:testData];
        [self keepDatabaseUpdated];
        
        [self refreshTestSession];
        [self.testSessionTableView reloadData];
    }
    else if ([[customData objectForKey:REFERENCE_DATA_IDENTIFIER] isEqual:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID] ||
             [[customData objectForKey:REFERENCE_DATA_IDENTIFIER] isEqual:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID] ||
             [[customData objectForKey:REFERENCE_DATA_IDENTIFIER] isEqual:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID])
    {
        // Signatory selected so go to sign-off form
        
        SignOffViewController *signature = [[SignOffViewController alloc] initWithParent:TestSessionDetails];
        signature.delegate = self;
        signature.data = self.testSessionData;
        signature.selectedSignatoryId = [selectedItem objectForKey:idKey];
        
        // Set Signature View Controller's dictionary key values based on signatory type selected
        if ([[customData objectForKey:REFERENCE_DATA_IDENTIFIER] isEqual:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID])
        {
            signature.signatoryIdKey = TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID;
            signature.signatoryNameKey = TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME;
            signature.signOffDateKey = TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE;
        }
        else if ([[customData objectForKey:REFERENCE_DATA_IDENTIFIER] isEqual:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID])
        {
            signature.signatoryIdKey = TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID;
            signature.signatoryNameKey = TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_NAME;
            signature.signOffDateKey = TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE;
        }
        else
        {
            signature.signatoryIdKey = TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID;
            signature.signatoryNameKey = TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME;
            signature.signOffDateKey = TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE;
        }
        
        // Push new view controller onto navigation stack
        [self.navigationController pushViewController:signature animated:YES];
        [signature release];
        
        [self keepDatabaseUpdated];
    }
    
    else
    {
        // Selected item is a straightforward property update on the test session model
        
        [self.testSessionData setValue:[selectedItem objectForKey:idKey] forKey:idKeyToUpdate];
        [self.testSessionData setValue:[selectedItem objectForKey:displayKey] forKey:displayKeyToUpdate];
        
        [self keepDatabaseUpdated];
    }
    
}

- (void)didFinishTextEditingWithText:(NSString *)text forKeyToUpdate:(NSString *)keyToUpdate withCustomData:(NSDictionary *)customData
{
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    
    if ([customData objectForKey:TABLE_TEST_SESSION_TEST])
    {
        // Custom data contains an Identifier value for Test Session Test, meaning that the selected item is an individual test result
        
        NSMutableDictionary *testData = [NSMutableDictionary dictionaryWithDictionary:[databaseManager getTestSessionTestById:[customData objectForKey:TABLE_TEST_SESSION_TEST]]];
        
        // Set modified text for test
        [testData setObject:text forKey:keyToUpdate];
        
        // If the instrument reference has been cleared and the 'enforce instrument reference' flag is set, we also reset the result selection
        BOOL enforceInstrumentReference = [[testData objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ENFORCE_INSTRUMENT_REFERENCE] boolValue];
        if ([keyToUpdate isEqualToString:TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE] && [text isEqualToString:@""] && enforceInstrumentReference) {
            [testData setValue:[NSNull null] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
            [testData setValue:[NSNull null] forKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME];
        }
        
        [databaseManager updateTestSessionTestWithRow:testData];
        [self keepDatabaseUpdated];
        
        [self refreshTestSession];
        [self.testSessionTableView reloadData];
    }
}

#pragma mark - AVCaptureDelegate

- (void)didSuccessfullyReadCode:(NSString *)code
{
    [self dismissViewControllerAnimated:YES completion:^(void) {
        [self.avCaptureViewController stopReading];
        _presentingModalViewController = NO;

        NSString *scannedCode = code;
        
        // Check for QR code match based on the format [{IdentifierType} = {Guid}]
        
        NSString *identifier = nil;
        NSString *value = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:REGEX_IDENTIFIER_EQUALS_GUID options:NSRegularExpressionCaseInsensitive error:nil];
        NSInteger regexMatches = [regex numberOfMatchesInString:scannedCode options:0 range:NSMakeRange(0, scannedCode.length)];
        
        if (regexMatches > 0)
        {
            // Retrieve the identifier type
            regex = [NSRegularExpression regularExpressionWithPattern:REGEX_BEFORE_EQUALS_GUID options:NSRegularExpressionCaseInsensitive error:nil];
            NSTextCheckingResult *regexMatch = [regex firstMatchInString:scannedCode options:0 range:NSMakeRange(0, scannedCode.length)];
            if (regexMatch)
                identifier = [scannedCode substringWithRange:[regexMatch rangeAtIndex:0]];
            
            // Retrieve the id value
            regex = [NSRegularExpression regularExpressionWithPattern:REGEX_AFTER_EQUALS options:NSRegularExpressionCaseInsensitive error:nil];
            regexMatch = [regex firstMatchInString:scannedCode options:0 range:NSMakeRange(0, scannedCode.length)];
            if (regexMatch)
                value = [scannedCode substringWithRange:[regexMatch rangeAtIndex:0]];
        }
        
        if ([[identifier lowercaseString] isEqualToString:[QR_CODE_PREFIX_BUILD_LOCATION_ID lowercaseString]] && value)
        {
            // We have successfully retrieved the build location id from the QR code
            // Update the data dictionary and proceed with the activation
            self.buildLocationId = value;
            [self activateTestSession];
        }
        else {
            // Report that an invalid location tag was scanned
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"COMMON_ALERT_TITLE_ERROR", nil) message:NSLocalizedString(@"TEST_SESSION_DETAILS_ALERT_LOCATION_TAG_NOT_VALID", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"COMMON_BUTTON_OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
            
            [self hideProgressIcon];
        }
    }];
}

- (void)didCancel
{
    // User has cancelled the scan

    self.buildLocationId = nil;
    
    [self hideProgressIcon];

    [self dismissViewControllerAnimated:YES completion:^(void) {
        [self.avCaptureViewController stopReading];
        _presentingModalViewController = NO;
    }];
}

- (void)didThrowError:(NSError *)error
{
    // The scan threw an error
    
    self.buildLocationId = nil;
    
    [self hideProgressIcon];
    
    [self dismissViewControllerAnimated:YES completion:^(void) {
        [self.avCaptureViewController stopReading];
        _presentingModalViewController = NO;
    }];
    
    AlertManager *alertManager = [AlertManager sharedInstance];
    [alertManager showAlertForErrorType:ScanFailed withError:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    // Photo taken or selected
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    DatabaseManager *databaseManager = [DatabaseManager sharedInstance];
    AlertManager *alertManager = [AlertManager sharedInstance];
    ImageManager *imageManager = [ImageManager sharedInstance];
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    
    // Save image
    NSString *fileName = [NSString stringWithFormat:@"%@ %@ %@ %@", NSLocalizedString(@"COMMON_FILE_NAME_TEXT_TEST_SESSION", nil), [self.testSessionData nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID], NSLocalizedString(@"COMMON_FILE_NAME_TEXT_PHOTO", nil), [[NSString stringWithUUID] lowercaseString]];
    NSString *filePath = [imageManager saveStandardImageToFile:image forDocumentType:TestSessionPhoto withImageFileName:fileName];
    [imageManager saveThumbnailImageToFile:image forDocumentType:TestSessionPhoto withImageFileName:fileName];
    
    // Create document dictionary and save it
    NSString *documentId = [[NSString stringWithUUID] lowercaseString];
    NSDictionary *document = [NSDictionary documentDictionaryWithDocumentTypeName:TABLE_DOCUMENT_TYPE_COLUMN_NAME_VALUE_TEST_SESSION_PHOTO qualityManagementSystemCode:nil documentTypeCategoryName:nil filePath:filePath mimeType:MIME_TYPE_JPEG documentId:documentId];
    
    // Delete any existing new profile images
    for (NSDictionary *existingDocument in self.photos) {
        if ([[existingDocument objectForKey:TABLE_COMMON_IS_NEW] boolValue])
            [databaseManager deleteDocumentsForTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil filePath:[existingDocument objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] includingFiles:YES];
    }
    
    DataWrapper *dataWrapper = [databaseManager createDocumentWithRow:document forTestSessionId:[self.testSessionData objectForKey:TABLE_TEST_SESSION_COLUMN_ID] setRequiresDataSync:YES];
    if (!dataWrapper.isValid) { [alertManager showAlertForErrorType:SaveTestSessionPhoto withError:nil]; return; }

    [self refreshDisplay];
    
    [appDelegate updateSyncBadgeCount];
}

#pragma mark - Deallocation

- (void) dealloc
{
    [_apiManager release];
    [_tableArray release];
    [_equipmentData release];
    [_testSessionData release];
    [_tests release];
    [_serviceDocuments release];
    [_photos release];
    [_testSessionTableView release];
    [_tableFooter release];
    [_activationControls release];
    [_notStarted release];
    [_notAuthorised release];
    [_activateButton release];
    [_avCaptureViewController release];
    [_selectedTestData release];
    [_buildLocationId release];
    [_pdfDocumentMaster release];

    [super dealloc];
}

@end
