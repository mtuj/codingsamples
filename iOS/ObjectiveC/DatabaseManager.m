#import "AlertManager.h"
#import "AppDelegate.h"
#import "AppSettings.h"
#import "DatabaseDataDefines.h"
#import "DatabaseDefines.h"
#import "DatabaseManager.h"
#import "DataWrapper.h"
#import "FileSystemDefines.h"
#import "FMDatabase.h"
#import "ImageManager.h"
#import "JSONDefines.h"
#import "LocalNotificationsScheduler.h"
#import "NSArray+Extensions.h"
#import "NSData+Base64.h"
#import "NSDate+Extensions.h"
#import "NSDictionary+Extensions.h"
#import "NSString+Base64.h"
#import "NSString+Extensions.h"
#import "UserManager.h"

static DatabaseManager *sharedInstance = nil;

@implementation DatabaseManager

@synthesize delegate = _delegate;
@synthesize successFlag = _successFlag; // Needed for setting a success indicator inside an FMDatabase block

#pragma mark - Singleton

+ (DatabaseManager *)sharedInstance
{
    // Creates a single instance of the database manager, which is shared across the entire application
    
    @synchronized(self) {
        if (sharedInstance == nil)
            sharedInstance = [[DatabaseManager alloc] init];
    }
    
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone
{
    // Creates a zone-specific single instance of the database manager, which is shared across the entire application
    
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance; //Assignment and return on first allocation
        }
    }
    return nil; //On subsequent allocation attempts return nil
}

#pragma mark - Initialisation

- (id)init
{
    self = [super init];
    
    return self;
}

#pragma mark -
#pragma mark - Raw database and helpers

- (FMDatabaseQueue *)getDatabaseQueue
{
    return [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
}

- (NSString *)getDatabasePath
{
    AppSettings *appSettings = [AppSettings sharedInstance];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsPath = [paths objectAtIndex:0];
    return [docsPath stringByAppendingPathComponent:appSettings.databaseName];
}

- (FMDatabase *)getDatabase
{
    // Returns the app's local database
    
    FMDatabase *database = ([FMDatabase databaseWithPath:[self getDatabasePath]]);
    [database setMaxBusyRetryTimeInterval:5];
    //database.traceExecution = YES;
    return database;
}

- (BOOL)verifyDatabase
{
    // Verifies the database is valid and can be accessed
    
    NSArray *verify = [self executeSelectAll:@"sqlite_master" withSelect:@"*" withWhere:@"type='table'" withOrderBy:nil];
    
    if ([verify count])
        return YES;
    return NO;
}

- (BOOL)executeUpdate:(NSString *)sql
{
    // Executes the sql UPDATE/INSERT query against the app's local database
    
    FMDatabase *database = [self getDatabase];
    [database open];
    
    BOOL result = [database executeUpdate:sql];
    
    if (result)
        NSLog(@"executeUpdate using - %@", sql);
    else
        NSLog(@"Failed executeUpdate using - %@", sql);
    
    //[database close];
    return  result;
}

- (BOOL)executeUpdate:(NSString *)sql withParameterDictionary:(NSDictionary *)parameters
{
    // Executes the sql UPDATE/INSERT query against the app's local database
    // Replaces any placeholders of the format [:parameter] with property with the same name from the dictionary
    
    FMDatabase *database = [self getDatabase];
    [database open];
    
    // Set dictionary date formats to long date/time Utc
    parameters = [parameters convertDatesToLongDateTimeUtcString];
    
    BOOL result = [database executeUpdate:sql withParameterDictionary:parameters];
    
    if (result)
        NSLog(@"executeUpdate using - %@", sql);
    else
        NSLog(@"Failed executeUpdate using - %@", sql);
    
    //[database close];
    return result;
}

- (NSDictionary *)executeSelectSingle:(NSString *)forTable withSelect:(NSString *)select withWhere:(NSString *)where
{
    // Builds and executes a sql SELECT statement, returning a single row
    
    NSString *selectSql = [NSString stringWithFormat:@" SELECT %@ ", select];
    NSString *whereSql = (where == nil) ? @"" : [NSString stringWithFormat:@" WHERE %@ ", where];
    NSString *sql = [NSString stringWithFormat:@"%@ FROM %@ %@", selectSql, forTable, whereSql];
    
    FMResultSet *results = [self executeQuery:sql];
    NSDictionary *resultDictionary;
    if ([results next])
        resultDictionary = [results resultDictionary];
    else
        resultDictionary = [NSDictionary dictionary];
    
    [results close];
    
    return resultDictionary;
}

- (NSArray *)executeSelectAll:(NSString *)forTable withSelect:(NSString *)select withWhere:(NSString *)where withOrderBy:(NSString *)orderBy
{
    // Builds and executes a sql SELECT statement, returning a collection of rows
    
    NSString *selectSql = [NSString stringWithFormat:@" SELECT %@ ", select];
    NSString *whereSql = (where == nil) ? @"" : [NSString stringWithFormat:@" WHERE %@ ", where];
    NSString *orderBySql = (orderBy == nil) ? @"" : [NSString stringWithFormat:@" ORDER BY %@ ", orderBy];
    NSString *sql = [NSString stringWithFormat:@"%@ FROM %@ %@ %@", selectSql, forTable, whereSql, orderBySql];
    
    //NSLog(@"Execute SQL - %@", sql);
    
    FMResultSet *results = [self executeQuery:sql];
    
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    while ([results next]) {
        [resultsArray addObject: [results resultDictionary]];
    }
    NSArray *returnArray = [NSArray arrayWithArray:resultsArray];
    [resultsArray release];
    [results close];
    return returnArray;
}

- (FMResultSet *)executeQuery:(NSString *)sql
{
    // Executes the sql query against the app's local database
    
    FMDatabase *database = [self getDatabase];
    [database open];
    FMResultSet *results = [database executeQuery:sql];
    
    // Don't close results here ... the consumer needs them
    //[database close];
    return results;
}

- (FMResultSet *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)parameters
{
    // Executes the sql query against the app's local database
    // Replaces any placeholders of the format [:parameter] with property with the same name from the dictionary
    
    FMDatabase *database = [self getDatabase];
    [database open];
    
    // Set dictionary date formats to long date/time Utc
    parameters = [parameters convertDatesToLongDateTimeUtcString];
    
    FMResultSet *results = [database executeQuery:sql withParameterDictionary:parameters];
    
    // Don't close results here ... the consumer needs them.
    //[database close];
    return results;
}

- (NSInteger)executeCount:(NSString *)forTable withWhere:(NSString *)where
{
    // Executes a sql COUNT query against the app's local database
    
    NSString *whereSql = (where == nil) ? @"" : [NSString stringWithFormat:@" WHERE %@ ", where];
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ %@", forTable, whereSql];
    
    FMDatabase *database = [self getDatabase];
    [database open];
    FMResultSet *results = [database executeQuery:sql];
    
    NSInteger totalCount = 0;
    
    if ([results next])
        totalCount = [results intForColumnIndex:0];
    
    [results close];
    return totalCount;
}

- (BOOL)executeDelete:(NSString *)forTable withWhere:(NSString *)where
{
    // Executes the sql DELETE query against the app's local database
    
    NSString *whereSql = (where == nil) ? @"" : [NSString stringWithFormat:@" WHERE %@ ", where];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@", forTable, whereSql];
    return [self executeUpdate:sql];
}

- (BOOL)executeDelete:(NSString *)forTable withWhere:(NSString *)where withDatabase:(FMDatabase *)database
{
    // Executes the sql DELETE query against the app's local database
    
    NSString *whereSql = (where == nil) ? @"" : [NSString stringWithFormat:@" WHERE %@ ", where];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@", forTable, whereSql];
    return [database executeUpdate:sql];
}

- (BOOL)executeModifyFlag:(NSString *)flag withValue:(BOOL)value forTable:(NSString *)table withWhere:(NSString *)where
{
    // Sets the required value for the specified flag of the specified table
    
    NSString *valueString = value ? @"1" : @"0";
    NSString *sql= [NSString stringWithFormat:@"UPDATE %@ SET %@ = %@", table, flag, valueString];
    
    return [self executeUpdate:sql];
}

- (BOOL)executeModifyFlag:(NSString *)flag withValue:(BOOL)value forTable:(NSString *)table forIdKey:(NSString *)idKey forIdValue:(id)idValue
{
    // Sets the required value for the specified flag of the specified table and id key field for the id value supplied
    
    NSString *valueString = value ? @"1" : @"0";
    NSString *sql;
    if ([table isEqualToString:TABLE_EQUIPMENT])
        sql= [NSString stringWithFormat:@"UPDATE %@ SET %@ = %@ WHERE %@ = %lld", table, flag, valueString, idKey, [idValue longLongValue]];
    else
        sql= [NSString stringWithFormat:@"UPDATE %@ SET %@ = %@ WHERE %@ = '%@'", table, flag, valueString, idKey, idValue];
    
    return [self executeUpdate:sql];
}

#pragma mark - Sync data

- (NSInteger)totalNumberOfUnsyncedItems
{
    // Returns the total number of records in the app's local database that have not yet been synced up to the server
    
    NSInteger total = 0;
    
    total += [self numberOfUnsyncedItemsForTable:TABLE_EQUIPMENT];
    total += [self numberOfUnsyncedItemsForTable:TABLE_DOCUMENT_EQUIPMENT];
    total += [self numberOfUnsyncedItemsForTable:TABLE_SITE_VISIT_REPORT];
    total += [self numberOfUnsyncedItemsForTable:TABLE_SITE_VISIT_REPORT_SIGNATORY];
    total += [self numberOfUnsyncedItemsForTable:TABLE_DOCUMENT_SITE_VISIT_REPORT];
    total += [self numberOfUnsyncedItemsForTable:TABLE_TEST_SESSION];
    total += [self numberOfUnsyncedItemsForTable:TABLE_TEST_SESSION_TEST];
    total += [self numberOfUnsyncedItemsForTable:TABLE_DOCUMENT_TEST_SESSION];
    total += [self numberOfUnsyncedItemsForTable:TABLE_SITE_TIME_LOG];

    return total;
}

- (NSInteger)numberOfUnsyncedItemsForTable:(NSString *)table
{
    // Returns the number of records in the specified table in the app's local database that have not yet been synced up to the server
    
    if ([table isEqualToString:TABLE_DOCUMENT_EQUIPMENT] || [table isEqualToString:TABLE_DOCUMENT_SITE_VISIT_REPORT] || [table isEqualToString:TABLE_DOCUMENT_TEST_SESSION]) {
        NSString *tables = [NSString stringWithFormat:@" %@ INNER JOIN %@ ON %@.%@ = %@.%@ ", TABLE_DOCUMENT, table, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, table, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID];
        if ([table isEqualToString:TABLE_DOCUMENT_TEST_SESSION]) {
            tables = [tables stringByAppendingFormat:@" INNER JOIN %@ ON %@.%@ = %@.%@ INNER JOIN (SELECT DISTINCT dt.%@ FROM %@ dt LEFT JOIN %@ dtc ON dt.%@ = dtc.%@ WHERE UPPER(dt.%@) IN ('%@') OR UPPER(dtc.%@) IN ('%@')) t ON %@.%@ = t.%@ ", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID, TABLE_DOCUMENT_TYPE_COLUMN_ID, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_COLUMN_DOCUMENT_TYPE_CATEGORY_ID, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_ID, TABLE_DOCUMENT_TYPE_COLUMN_NAME, [TABLE_DOCUMENT_TYPE_COLUMN_NAME_VALUE_TEST_SESSION_PHOTO uppercaseString], TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME, [TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME_VALUE_TEST_SESSION_DOCUMENT uppercaseString], TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID, TABLE_DOCUMENT_TYPE_COLUMN_ID];
        }
        NSString *where =  [NSString stringWithFormat:@" %@.%@ = 1 ", TABLE_DOCUMENT, TABLE_COMMON_REQUIRES_DATA_SYNC];
        return [self executeCount:tables withWhere:where];
    } else {
        NSString *where =  [NSString stringWithFormat:@" %@ = 1 ", TABLE_COMMON_REQUIRES_DATA_SYNC];
        return [self executeCount:table withWhere:where];
    }
}

- (void)resetDataSyncFlagAll
{
    // Resets the RequiresDataSync flag of the relevant tables in the app's local database
    
    NSString *documentsWhere = @"";
    
    // Only reset the following tables if Test Documents mode is enabled
    if ([AppSettings sharedInstance].testDocumentsEnabled)
    {
        [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_TEST_SESSION withWhere:nil];
        [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_TEST_SESSION_TEST withWhere:nil];
        
        // Also build documents where clause to ignore all those associated with a test session
        NSArray *testSessionDocumentIds = [self executeSelectAll:TABLE_DOCUMENT_TEST_SESSION withSelect:TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID withWhere:nil withOrderBy:nil];
        NSArray *testDocumentIds = [self executeSelectAll:TABLE_TEST_SESSION_TEST withSelect:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID withWhere:[NSString stringWithFormat:@"%@ IS NOT NULL AND %@ <> ''", TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID] withOrderBy:nil];
        NSArray *documentIds = [testSessionDocumentIds arrayByAddingObjectsFromArray:testDocumentIds];
        documentsWhere= [NSString stringWithFormat:@"UPPER(%@) NOT IN (%@)", TABLE_DOCUMENT_COLUMN_ID, [documentIds componentsJoinedByString:@","]];
    }
    
    [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_EQUIPMENT withWhere:nil];
    [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_SITE_VISIT_REPORT_SIGNATORY withWhere:nil];
    [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_SITE_VISIT_REPORT withWhere:nil];
    [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_SITE_TIME_LOG withWhere:nil];
    [self executeModifyFlag:TABLE_COMMON_REQUIRES_DATA_SYNC withValue:NO forTable:TABLE_DOCUMENT withWhere:documentsWhere];
}

- (NSArray *)getPreservedData
{
    // Populates an array with database records to be preserved prior to a sync
    // Each array item is a dictionary with a subarray representing one table
    
    // Construct test session test and document data
    NSMutableArray *testSessionRows = [NSMutableArray array];
    NSMutableArray *documentsRows = [NSMutableArray array];
    NSMutableArray *documentTestSessionsRows = [NSMutableArray array];
    NSMutableArray *ibarInstallationTestMetadataRows = [NSMutableArray array];
    NSMutableArray *ibarInstallationTestMetadataContinuityRunDuctorTestRows = [NSMutableArray array];
    NSMutableArray *ibarInstallationJointTestMetadataRows = [NSMutableArray array];
    NSArray *equipmentScanHistoryRows = [NSArray array];
    for (NSDictionary *testSession in [self getTestSessionsInProgressOnThisDeviceIncludingPreActivated:NO])
    {
        NSMutableDictionary *testSessionWithTests = [NSMutableDictionary dictionaryWithDictionary:testSession];
        [testSessionWithTests setObject:
         [NSArray arrayWithArray:[self getTestSessionTestsForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]]
                                 forKey:JSON_TESTS];
        [testSessionRows addObject:testSessionWithTests];
        [documentsRows addObjectsFromArray:[NSArray arrayWithArray:[self getDocumentsForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:NO]]];
        [documentsRows addObjectsFromArray:[NSArray arrayWithArray:[self getTestDocumentsForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]]];
        [documentTestSessionsRows addObjectsFromArray:[NSArray arrayWithArray:[self getDocumentTestSessionsForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]]];
        [ibarInstallationTestMetadataRows addObjectsFromArray:[NSArray arrayWithArray:[self getIbarInstallationTestMetadatasForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]]];
        for (NSDictionary *ibarInstallationTestMetadataRow in ibarInstallationTestMetadataRows) {
            [ibarInstallationTestMetadataContinuityRunDuctorTestRows addObjectsFromArray:[NSArray arrayWithArray:[self getIbarInstallationTestMetadataContinuityRunDuctorTestsForIbarInstallationTestMetadataId:[ibarInstallationTestMetadataRow objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]]]];
        }
        [ibarInstallationJointTestMetadataRows addObjectsFromArray:[NSArray arrayWithArray:[self getIbarInstallationJointTestMetadatasForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID]]]];
    }
    
    // Replace all document dictionaries with shapes expected by the addRowsToDocument method
    NSArray *documentsToModify = [NSArray arrayWithArray:documentsRows];
    for (NSDictionary *documentToModify in documentsToModify) {
        NSMutableDictionary *document = [NSMutableDictionary dictionaryWithDictionary:documentToModify];
        NSDictionary *latestRevision = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [documentToModify objectForKey:TABLE_DOCUMENT_COLUMN_FILE_NAME], TABLE_DOCUMENT_COLUMN_FILE_NAME,
                                        [documentToModify objectForKey:TABLE_DOCUMENT_COLUMN_MIME_TYPE], TABLE_DOCUMENT_COLUMN_MIME_TYPE,
                                        [documentToModify objectForKey:TABLE_DOCUMENT_COLUMN_DATE_CREATED], JSON_LATEST_REVISION_ATTRIBUTE_CREATED_DATE_UTC,
                                        nil];
        [document setObject:latestRevision forKey:JSON_LATEST_REVISION];
        [documentsRows addObject:document];
        [documentsRows removeObject:documentToModify];
    }
    
    // Registered users
    NSDictionary *registeredUsers = [NSDictionary dictionaryWithObjectsAndKeys:
                                     TABLE_REGISTERED_USER, PRESERVED_DATA_KEY_TABLE_NAME,
                                     [self getRegisteredUsers], PRESERVED_DATA_KEY_ROWS,
                                     nil];
    
    // Test sessions
    NSDictionary *testSessions = [NSDictionary dictionaryWithObjectsAndKeys:
                                  TABLE_TEST_SESSION, PRESERVED_DATA_KEY_TABLE_NAME,
                                  [NSArray arrayWithArray:testSessionRows], PRESERVED_DATA_KEY_ROWS,
                                  nil];
    
    // Documents
    NSDictionary *documents = [NSDictionary dictionaryWithObjectsAndKeys:
                               TABLE_DOCUMENT, PRESERVED_DATA_KEY_TABLE_NAME,
                               [NSArray arrayWithArray:documentsRows], PRESERVED_DATA_KEY_ROWS,
                               nil];
    
    // Document test sessions
    NSDictionary *documentTestSessions = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TABLE_DOCUMENT_TEST_SESSION, PRESERVED_DATA_KEY_TABLE_NAME,
                                          [NSArray arrayWithArray:documentTestSessionsRows], PRESERVED_DATA_KEY_ROWS,
                                          nil];

    // Ibar installation test metadatas
    NSDictionary *ibarInstallationTestMetadatas = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TABLE_IBAR_INSTALLATION_TEST_METADATA, PRESERVED_DATA_KEY_TABLE_NAME,
                                          [NSArray arrayWithArray:ibarInstallationTestMetadataRows], PRESERVED_DATA_KEY_ROWS,
                                          nil];

    // Ibar installation test metadata continuity run ductor tests
    NSDictionary *ibarInstallationTestMetadataContinuityRunDuctorTests = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST, PRESERVED_DATA_KEY_TABLE_NAME,
                                          [NSArray arrayWithArray:ibarInstallationTestMetadataContinuityRunDuctorTestRows], PRESERVED_DATA_KEY_ROWS,
                                          nil];

    // Ibar installation joint test metadatas
    NSDictionary *ibarInstallationJointTestMetadatas = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA, PRESERVED_DATA_KEY_TABLE_NAME,
                                          [NSArray arrayWithArray:ibarInstallationJointTestMetadataRows], PRESERVED_DATA_KEY_ROWS,
                                          nil];

    // Equipment scan history
    if ([AppSettings sharedInstance].preserveScanHistoryDuringSync)
        equipmentScanHistoryRows = [self getEquipmentScanHistory];
    
    NSDictionary *equipmentScanHistory = [NSDictionary dictionaryWithObjectsAndKeys:
                                     TABLE_EQUIPMENT_SCAN_HISTORY, PRESERVED_DATA_KEY_TABLE_NAME,
                                     [NSArray arrayWithArray:equipmentScanHistoryRows], PRESERVED_DATA_KEY_ROWS,
                                     nil];

    // Return all data arrays
    return [NSArray arrayWithObjects:registeredUsers, testSessions, documentTestSessions, documents, ibarInstallationTestMetadatas, ibarInstallationTestMetadataContinuityRunDuctorTests, ibarInstallationJointTestMetadatas, equipmentScanHistory, nil];
}

- (BOOL)writePreservedDataBackToDatabase:(NSArray *)preservedData
{
    // Writes data preserved in the supplied array back to the database following a sync
    // Each array item is a dictionary with a subarray representing one table
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    BOOL success = YES;
    NSPredicate *predicate;

    // Retrieve all original preserved data
    NSArray *registeredUsers = [NSArray array];
    NSArray *testSessions = [NSArray array];
    NSArray *documents = [NSArray array];
    NSArray *documentTestSessions = [NSArray array];
    NSArray *ibarInstallationTestMetadatas = [NSMutableArray array];
    NSArray *ibarInstallationTestMetadataContinuityRunDuctorTests = [NSMutableArray array];
    NSArray *ibarInstallationJointTestMetadatas = [NSMutableArray array];
    NSArray *equipmentScanHistory = [NSArray array];
    for (NSDictionary *table in preservedData) {
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_REGISTERED_USER])
            registeredUsers = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_TEST_SESSION])
            testSessions = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_DOCUMENT])
            documents = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_DOCUMENT_TEST_SESSION])
            documentTestSessions = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_IBAR_INSTALLATION_TEST_METADATA])
            ibarInstallationTestMetadatas = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST])
            ibarInstallationTestMetadataContinuityRunDuctorTests = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA])
            ibarInstallationJointTestMetadatas = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
        if ([[table nullableObjectForKey:PRESERVED_DATA_KEY_TABLE_NAME] isEqualToString:TABLE_EQUIPMENT_SCAN_HISTORY])
            equipmentScanHistory = [table objectForKey:PRESERVED_DATA_KEY_ROWS];
    }

    // RESTORE REGISTERED USERS DATA
    if (success)
        success = [self addRowsToRegisteredUsers:registeredUsers];
    
    // RESTORE TEST SESSION DATA

    // Before we write any test session data back to the database, we firstly filter down the list of preserved test sessions to remove any that are now marked as 'Completed'
    // This is to avoid data from test sessions previously marked as 'In Progress', but now set as 'Completed' by the Api, from incorrectly being persisted
    // We also remove any that no longer appear in the download list (as strictly speaking any that are set as 'Completed' should not actually get synced down)
    NSMutableArray *testSessionsToPreserve = [NSMutableArray array];
    for (NSDictionary *testSession in testSessions) {
        NSDictionary *updatedTestSession = [self getTestSessionById:[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
        
        // If no test session with a matching Id was returned in the data download, we create the record locally
        // This can happen if the download data generation is out of sync or running on a delay
        if (![updatedTestSession count])
            updatedTestSession = [self createTestSessionWithRow:[NSMutableDictionary dictionaryWithDictionary:testSession]].dataDictionary;
        
        if (
            [updatedTestSession count] &&
            ![[updatedTestSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqualToString:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_COMPLETED] &&
            ![[updatedTestSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqualToString:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_ABANDONED] &&
            ![[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqualToString:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_COMPLETED] &&
            ![[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME] isEqualToString:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_ABANDONED]
            )
            [testSessionsToPreserve addObject:testSession];

        // Ensure the test session device and tester are correctly set
        NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID], TABLE_TEST_SESSION_COLUMN_ID,
                                    [testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TESTER_ID], TABLE_TEST_SESSION_COLUMN_TESTER_ID,
                                    nil
                                    ];
        NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = '%@', %@ = :%@ WHERE UPPER(%@) = UPPER(:%@)",
                           TABLE_TEST_SESSION,
                           TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED,
                           [appDelegate deviceUniqueIdentifier],
                           TABLE_TEST_SESSION_COLUMN_TESTER_ID,
                           TABLE_TEST_SESSION_COLUMN_TESTER_ID,
                           TABLE_TEST_SESSION_COLUMN_ID,
                           TABLE_TEST_SESSION_COLUMN_ID
                           ];
        [self executeUpdate:query withParameterDictionary:parameters];
    }
    testSessions = [NSArray arrayWithArray:testSessionsToPreserve];

    // Note we only call the addRowsToTestSessionTest method here, as the test session itself will have already been synced back down
    if (success)
        success = [self addRowsToTestSessionTest:[NSArray arrayWithArray:testSessions]];
    
    // RESTORE DOCUMENT TEST SESSION DATA

    // Filter down the list of test session documents to only include those test sessions not yet marked as 'Complete'
    NSArray *includeList = [testSessions valueForKey:TABLE_TEST_SESSION_COLUMN_ID];
    predicate = [NSPredicate predicateWithFormat: @"%@ CONTAINS[c] %K", includeList, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID];
    documentTestSessions = [documentTestSessions filteredArrayUsingPredicate:predicate];
    
    if (success)
        success = [self addRowsToDocumentTestSession:documentTestSessions];
    
    // RESTORE IBAR INSTALLATION TEST METADATA DATA
    includeList = [testSessions valueForKey:TABLE_TEST_SESSION_COLUMN_ID];
    predicate = [NSPredicate predicateWithFormat: @"%@ CONTAINS[c] %K", includeList, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID];
    ibarInstallationTestMetadatas = [ibarInstallationTestMetadatas filteredArrayUsingPredicate:predicate];
    for (NSDictionary *ibarInstallationTestMetadata in ibarInstallationTestMetadatas) {
        [self createIbarInstallationTestMetadataWithRow:[NSMutableDictionary dictionaryWithDictionary:ibarInstallationTestMetadata]];
    }
    
    // RESTORE IBAR INSTALLATION TEST METADATA CONTINUITY RUN DUCTOR TEST DATA
    includeList = [ibarInstallationTestMetadatas valueForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID];
    predicate = [NSPredicate predicateWithFormat: @"%@ CONTAINS[c] %K", includeList, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID];
    ibarInstallationTestMetadataContinuityRunDuctorTests = [ibarInstallationTestMetadataContinuityRunDuctorTests filteredArrayUsingPredicate:predicate];
    for (NSDictionary *ibarInstallationTestMetadataContinuityRunDuctorTest in ibarInstallationTestMetadataContinuityRunDuctorTests) {
        [self createIbarInstallationTestMetadataContinuityRunDuctorTestWithRow:[NSMutableDictionary dictionaryWithDictionary:ibarInstallationTestMetadataContinuityRunDuctorTest]];
    }

    // RESTORE IBAR INSTALLATION JOINT TEST METADATA DATA
    includeList = [testSessions valueForKey:TABLE_TEST_SESSION_COLUMN_ID];
    predicate = [NSPredicate predicateWithFormat: @"%@ CONTAINS[c] %K", includeList, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID];
    ibarInstallationJointTestMetadatas = [ibarInstallationJointTestMetadatas filteredArrayUsingPredicate:predicate];
    for (NSDictionary *ibarInstallationJointTestMetadata in ibarInstallationJointTestMetadatas) {
        [self createIbarInstallationJointTestMetadataWithRow:[NSMutableDictionary dictionaryWithDictionary:ibarInstallationJointTestMetadata]];
    }

    // RESTORE DOCUMENT DATA
    
    // Filter down the list of documents to only include those associated with test sessions not yet marked as 'Complete'
    NSArray *documentIds = [documentTestSessions valueForKey:TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID];
    for (NSDictionary *testSession in testSessions) {
        NSArray *testSessionTests = [self getTestSessionTestsForTestSessionId:[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
        documentIds = [documentIds arrayByAddingObjectsFromArray:[testSessionTests valueForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]];
    }
    predicate = [NSPredicate predicateWithFormat: @"%@ CONTAINS[c] %K", documentIds, TABLE_DOCUMENT_COLUMN_ID];
    documents = [documents filteredArrayUsingPredicate:predicate];

    if (success)
        success = [self addRowsToDocument:documents withEquipmentId:nil fileSystemDirectory:nil];
    
    // RESTORE EQUIPMENT SCAN HISTORY DATA
    if (success)
        success = [self addRowsToEquipmentScanHistory:equipmentScanHistory];
 
    return success;
}

#pragma mark - Permissions

- (NSString *)getSubcontractorWorksOrderIdFilterForLoggedInUser
{
    // Returns the IN part of the standard SQL WHERE clause for filtering data by works order Ids
    // for only those works orders that the logged in user has permissions, where the user is a subcontractor
    
    UserManager *userManager = [UserManager sharedInstance];

    return [NSString stringWithFormat:@"SELECT ewo1.%@ FROM %@ AS ewo1 INNER JOIN %@ AS ewoe1 ON ewo1.%@ = ewoe1.%@ INNER JOIN %@ AS ewoo1 ON ewoe1.%@ = ewoo1.%@ WHERE ewoe1.%@ = '%@' AND ewoo1.%@ = '%@'", TABLE_ENGINEER_WORKS_ORDER_COLUMN_WORKS_ORDER_ID, TABLE_ENGINEER_WORKS_ORDER, TABLE_ENGINEER, TABLE_ENGINEER_WORKS_ORDER_COLUMN_ENGINEER_ID, TABLE_ENGINEER_COLUMN_ID, TABLE_ORGANISATION, TABLE_ENGINEER_COLUMN_ORGANISATION_ID, TABLE_ORGANISATION_COLUMN_ID, TABLE_ENGINEER_COLUMN_EMAIL, [userManager getLoggedInUsersUsername], TABLE_ORGANISATION_COLUMN_NAME, TABLE_ORGANISATION_COLUMN_NAME_VALUE_SUBCONTRACTOR_ANORD_MARDIX];
}

- (NSString *)getSubcontractorBlockingFilterForLoggedInUser
{
    // Returns the standard SQL WHERE clause for blocking all data where the user is a subcontractor
    
    UserManager *userManager = [UserManager sharedInstance];

    return [NSString stringWithFormat:@" NOT EXISTS (SELECT ewoe1.%@ FROM %@ AS ewoe1 INNER JOIN %@ AS ewoo1 ON ewoe1.%@ = ewoo1.%@ WHERE ewoe1.%@ = '%@' AND ewoo1.%@ = '%@')", TABLE_ENGINEER_COLUMN_ID, TABLE_ENGINEER, TABLE_ORGANISATION, TABLE_ENGINEER_COLUMN_ORGANISATION_ID, TABLE_ORGANISATION_COLUMN_ID, TABLE_ENGINEER_COLUMN_EMAIL, [userManager getLoggedInUsersUsername], TABLE_ORGANISATION_COLUMN_NAME, TABLE_ORGANISATION_COLUMN_NAME_VALUE_SUBCONTRACTOR_ANORD_MARDIX];
}

- (BOOL)loggedInUserIsSubcontractor
{
    // Returns true or false indicating whether the logged in user is a subcontractor

    return ([self executeCount:TABLE_ENGINEER withWhere:[self getSubcontractorBlockingFilterForLoggedInUser]] == 0) ? YES : NO;
}

#pragma mark -
#pragma mark - Branch

- (NSString *)getBranchSelect
{
    return [NSString stringWithFormat:@"%@.*", TABLE_BRANCH];
}

- (NSString *)getBranchTables
{
    return [NSString stringWithFormat:@"%@", TABLE_BRANCH];
}

- (NSDictionary *)getBranchById:(NSNumber *)branchId
{
    // Returns the record from the Branch table matching the filter on the Id field
    
    NSString *select = [self getBranchSelect];
    NSString *tables = [self getBranchTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = %ld", TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID, (long)[branchId integerValue]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)searchBranchesByText:(NSString *)searchText
{
    // Returns all records from the Branch table matching the search filter
    
    NSString *select = [self getBranchSelect];
    NSString *tables = [self getBranchTables];
    NSString *where = [NSString stringWithFormat:@" LENGTH('%@') > 0 AND  %@ <> '' AND %@ IS NOT NULL AND (%@ LIKE '%@%@%@' OR %@ LIKE '%@%@%@' OR %@ LIKE '%@%@%@' OR %@ LIKE '%@%@%@' OR %@ LIKE '%@%@%@' OR %@ LIKE '%@%@%@' OR %@ LIKE '%@%@%@') %@ ", searchText, TABLE_BRANCH_COLUMN_CLIENT_NAME, TABLE_BRANCH_COLUMN_CLIENT_NAME, TABLE_BRANCH_COLUMN_CLIENT_NAME, @"%", searchText, @"%", TABLE_BRANCH_COLUMN_NAME, @"%", searchText, @"%", TABLE_BRANCH_COLUMN_ADDRESS_LINE_1, @"%", searchText, @"%", TABLE_BRANCH_COLUMN_ADDRESS_LINE_2, @"%", searchText, @"%", TABLE_BRANCH_COLUMN_ADDRESS_LINE_3, @"%", searchText, @"%", TABLE_BRANCH_COLUMN_ADDRESS_LINE_4, @"%", searchText, @"%", TABLE_BRANCH_COLUMN_ADDRESS_LINE_5, @"%", searchText, @"%",
            [self loggedInUserIsSubcontractor]
                 ? [NSString stringWithFormat:@" AND %@.%@ IN (SELECT b.%@ FROM %@ AS b INNER JOIN %@ AS e ON b.%@ = e.%@ WHERE e.%@ IN (%@)) ", TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID, TABLE_BRANCH_COLUMN_ID, TABLE_BRANCH, TABLE_EQUIPMENT, TABLE_BRANCH_COLUMN_ID, TABLE_EQUIPMENT_COLUMN_BRANCH_ID, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                 : @""
        ];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@) ASC", TABLE_BRANCH_COLUMN_CLIENT_NAME, TABLE_BRANCH_COLUMN_NAME];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

#pragma mark - Branch - Service Contract

- (NSArray *)getServiceContractsForBranchId:(NSNumber *)branchId
{
    // Returns all records from the Branch_ServiceContract table matching the filter on the Branch_id field
    
    NSString *select = [NSString stringWithFormat:@"DISTINCT %@.*", TABLE_SERVICE_CONTRACT];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@ ", TABLE_SERVICE_CONTRACT, TABLE_BRANCH_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_ID, TABLE_BRANCH_SERVICE_CONTRACT, TABLE_BRANCH_SERVICE_CONTRACT_COLUMN_SERVICE_CONTRACT_ID];
    NSString *where = [NSString stringWithFormat:@" %@.%@ = %ld ", TABLE_BRANCH_SERVICE_CONTRACT, TABLE_BRANCH_SERVICE_CONTRACT_COLUMN_BRANCH_ID, (long)[branchId integerValue]];
    NSString *orderBy = [NSString stringWithFormat:@" %@.%@ ASC", TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

#pragma mark - Commission Status

- (NSArray *)getCommissionStatuses
{
    // Returns all records from the CommissionStatus table
    
    return [self executeSelectAll:TABLE_COMMISSION_STATUS withSelect:@"*" withWhere:nil  withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_COMMISSION_STATUS_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getCommissionStatusById:(NSNumber *)commissionStatusId
{
    // Returns the record from the CommissionStatus table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"%@ = %ld", TABLE_COMMISSION_STATUS_COLUMN_ID, (long)[commissionStatusId integerValue]];
    return [self executeSelectSingle:TABLE_COMMISSION_STATUS withSelect:@"*" withWhere:where];
}

#pragma mark - Conductor Configuration

- (NSDictionary *)getConductorConfigurationById:(NSString *)conductorConfigurationId
{
    // Returns the record from the ConductorConfiguration table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_CONDUCTOR_CONFIGURATION_COLUMN_ID, [conductorConfigurationId uppercaseString]];
    return [self executeSelectSingle:TABLE_CONDUCTOR_CONFIGURATION withSelect:@"*" withWhere:where];
}

#pragma mark - Country

- (NSDictionary *)getCountryByIso2Alpha:(NSString *)iso2Alpha
{
    // Returns the record from the Country table matching the filter on the ISO2Alpha field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_COUNTRY, TABLE_COUNTRY_COLUMN_ISO2_ALPHA, [iso2Alpha uppercaseString]];
    return [self executeSelectSingle:TABLE_COUNTRY withSelect:@"*" withWhere:where];
}

- (NSArray *)getCountries
{
    // Returns all records from the Country table
    
    return [self executeSelectAll:TABLE_COUNTRY withSelect:@"*" withWhere:nil  withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_COUNTRY_COLUMN_NAME]];
}

#pragma mark - Database Configuration

- (NSDictionary *)getDatabaseConfigurationValueFor:(NSString *)key
{
    // Returns the record from the Database Configuration table matching the filter on the Name field
    
    NSString *where = [NSString stringWithFormat:@"%@ = '%@'", TABLE_DATABASE_CONFIGURATION_COLUMN_NAME, key];
    return [self executeSelectSingle:TABLE_DATABASE_CONFIGURATION withSelect:@"*" withWhere:where];
}

- (BOOL)createDatabaseConfigurationValue:(NSString *)value forKey:(NSString *)name
{
    // Inserts a record into the Database Configuration table, using the values supplied
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', '%@')", TABLE_DATABASE_CONFIGURATION, [name withDoubleApostrophes], [value withDoubleApostrophes]];
    
    BOOL result = [self executeUpdate:query];
    return result;
}

#pragma mark - Document

- (BOOL)addRowsToDocument:(NSArray *)rows withEquipmentId:(NSNumber *)equipmentId fileSystemDirectory:(NSString *)fileSystemDirectory
{
    // Inserts a number of records into the Document table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        for (NSDictionary *row in rows)
        {
            // Add document row
            if (![self addRowToDocument:row fileSystemDirectory:fileSystemDirectory isNew:NO requiresDataSync:NO withDatabase:database]) {
                self.successFlag = NO;
                break;
            }
            
            if (equipmentId)
            {
                NSArray *unsyncedDocuments = [self executeSelectAll:TABLE_DOCUMENT withSelect:@"*" withWhere:[NSString stringWithFormat:@" %@ = 1 ", TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:nil];
                
                // Delete any existing document rows for this equipment item, where the document does not exist in the updated list from the server
                if (![self deleteDocumentsForEquipmentId:equipmentId whereDocumentsNotIn:[rows arrayByAddingObjectsFromArray:unsyncedDocuments] withDatabase:database])
                {
                    self.successFlag = NO;
                    break;
                }
                
                // Delete any existing document link rows for this equipment item, where the document does not exist in the updated list from the server
                if (![self deleteDocumentEquipmentForEquipmentId:equipmentId whereDocumentsNotIn:[rows arrayByAddingObjectsFromArray:unsyncedDocuments] withDatabase:database])
                {
                    self.successFlag = NO;
                    break;
                }
                
                // Delete any existing link row for this document and equipment item
                if (![self deleteDocumentEquipmentForEquipmentId:equipmentId document:row withDatabase:database])
                {
                    self.successFlag = NO;
                    break;
                }
                
                // Add document equipment link
                if (![self addRowToDocumentEquipment:row withEquipmentId:equipmentId withDatabase:database]) {
                    self.successFlag = NO;
                    break;
                }
            }
        }
        
        if (self.successFlag == YES)
            [self.delegate databaseOperationSucceeded];
        else
            [self.delegate databaseOperationFailed];
    }];
    
    return self.successFlag;
}

- (BOOL)addRowsToDocument:(NSArray *)rows siteVisitReportId:(NSString *)siteVisitReportId fileSystemDirectory:(NSString *)fileSystemDirectory
{
    // Inserts a number of records into the Document table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        for (NSDictionary *row in rows)
        {
            // Add document row
            if (![self addRowToDocument:[row objectForKey:JSON_DOCUMENT] fileSystemDirectory:fileSystemDirectory isNew:NO requiresDataSync:NO withDatabase:database]) {
                self.successFlag = NO;
                break;
            }
            
            if (siteVisitReportId)
            {
                // Delete any existing link row for this document and site visit report
                if (![self deleteDocumentSiteVisitReportForSiteVisitReportId:siteVisitReportId document:[row objectForKey:JSON_DOCUMENT] withDatabase:database])
                {
                    self.successFlag = NO;
                    break;
                }
                
                // Add document site visit report link
                NSNumber *createdById = nil;
                if ([row keyIsNotMissingOrNull:JSON_CREATED_BY])
                    createdById = [[row objectForKey:JSON_CREATED_BY] objectForKey:TABLE_ENGINEER_COLUMN_ID];
                NSNumber *equipmentId = nil;
                if ([row keyIsNotMissingOrNull:JSON_SITE_VISIT_REPORT_EQUIPMENT]) {
                    if ([[row objectForKey:JSON_SITE_VISIT_REPORT_EQUIPMENT] count]) {
                        equipmentId = [[[[row objectForKey:JSON_SITE_VISIT_REPORT_EQUIPMENT] objectAtIndex:0] objectForKey:JSON_EQUIPMENT] objectForKey:TABLE_EQUIPMENT_COLUMN_ID];    // We assume only one equipment item per service document
                    }
                }
                if (![self addRowToDocumentSiteVisitReport:[row objectForKey:JSON_DOCUMENT] withSiteVisitReportId:siteVisitReportId withEquipmentId:equipmentId withCreatedById:createdById withDatabase:database]) {
                    self.successFlag = NO;
                    break;
                }
            }
        }
        
        if (self.successFlag == YES)
            [self.delegate databaseOperationSucceeded];
        else
            [self.delegate databaseOperationFailed];
    }];
    
    return self.successFlag;
}

- (BOOL)addRowToDocument:(NSDictionary *)row fileSystemDirectory:(NSString *)fileSystemDirectory isNew:(BOOL)isNew requiresDataSync:(BOOL)requiresDataSync withDatabase:(FMDatabase *)database
{
    // Inserts a record into the Document table, using the data in the dictionary supplied
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    AlertManager *alertManager = [AlertManager sharedInstance];
    BOOL result = YES;
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    
    // Get all the nested JSON objects
    
    NSDictionary *latestRevision = [row keyIsNotMissingOrNull:JSON_LATEST_REVISION] ? [row objectForKey:JSON_LATEST_REVISION] : [NSDictionary dictionary];
    
    // Type
    NSString *documentTypeId = [row keyIsNotMissingOrNull:TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID] ? [row objectForKey:TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_TYPE])
        documentTypeId = [[row objectForKey:JSON_TYPE] nullableObjectForKey:TABLE_DOCUMENT_TYPE_COLUMN_ID];
    NSDictionary *documentTypeDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(documentTypeId == nil) ? [NSNull null] : documentTypeId, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, nil];
    [parameters addEntriesFromDictionary:documentTypeDictionary];
    [documentTypeDictionary release];
    
    // Filename (strip leading backslashes from original value)
    NSString *fileName = [latestRevision nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_NAME];
    fileName = [fileName stringByRemovingIllegalFilenameCharacters];
    [parameters setObject:fileName forKey:TABLE_DOCUMENT_COLUMN_FILE_NAME];
    
    // Mime type
    NSString *mimeType = [latestRevision keyIsNotMissingOrNull:TABLE_DOCUMENT_COLUMN_MIME_TYPE] ? [latestRevision objectForKey:TABLE_DOCUMENT_COLUMN_MIME_TYPE] : [NSNull null];
    [parameters setObject:mimeType forKey:TABLE_DOCUMENT_COLUMN_MIME_TYPE];
    
    // Date created
    NSString *dateCreated = [latestRevision keyIsNotMissingOrNull:JSON_LATEST_REVISION_ATTRIBUTE_CREATED_DATE_UTC] ? [latestRevision objectForKey:JSON_LATEST_REVISION_ATTRIBUTE_CREATED_DATE_UTC] : [NSNull null];
    [parameters setObject:dateCreated forKey:TABLE_DOCUMENT_COLUMN_DATE_CREATED];
    
    // File path
    NSString *filePath = [row keyIsNotMissingOrNull: TABLE_DOCUMENT_COLUMN_FILE_PATH] ? [NSString stringWithFormat:@"'%@'", [row nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH]] : nil;
    if (fileSystemDirectory && !filePath)
    {
        // If a file system directory has been specified, we attempt to save the document to that directory then update the file path
        
        // Firstly check whether the file system directory exists, and if not create it
        result = [appDelegate createDirectoryAtPath:fileSystemDirectory];
        // Get or generate the file name
        if ([fileName isEqualToString:@""]) fileName = [row nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID];
        // Construct the full file path and attempt to save the document
        filePath = [NSString stringWithFormat:@"%@/%@", fileSystemDirectory, fileName];
        if ([latestRevision keyIsNotMissingOrNull:JSON_CONTENT]){
            NSString *fileData = [[latestRevision objectForKey:JSON_CONTENT] objectForKey:JSON_CONTENT_ATTRIBUTE_CONTENT];
            if (result) {
                result = [[fileData base64DecodedData] writeToFile:filePath atomically:YES];
                if (!result) [alertManager showAlertForErrorType:WriteServiceDocumentTemplateToFile withError:nil];
            }
        }
        filePath = [NSString stringWithFormat:@"'%@'", [filePath stringByRemovingDocumentsDirectoryFilepath]];
    }
    if (!filePath) filePath = @"NULL";
    
    NSString *where = [NSString stringWithFormat:@"NOT EXISTS (SELECT %@ FROM %@ WHERE UPPER(%@) = UPPER(:%@))", TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_COLUMN_ID];
    NSString *dataSyncFlag = requiresDataSync ? @"1" : @"0";
    NSString *isNewFlag = isNew ? @"1" : @"0";
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ SELECT :%@, :%@, :%@, :%@, :%@, :%@, %@, %@, %@ WHERE %@", TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_COLUMN_FILE_NAME, TABLE_DOCUMENT_COLUMN_MIME_TYPE, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT_COLUMN_COMMENTS, filePath, dataSyncFlag, isNewFlag, where];
    
    if (result) result = [database executeUpdate:query withParameterDictionary:[parameters convertDatesToLongDateTimeUtcString]];
    
    [parameters release];
    return result;
}

- (NSString *)getDocumentSelect
{
    return [NSString stringWithFormat:@"%@.*, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@",
            TABLE_DOCUMENT,
            TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME,
            TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE,
            TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_CATEGORY_NAME
            ];
}

- (NSString *)getDocumentTables
{
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@",
            TABLE_DOCUMENT,
            TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID,
            TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_DOCUMENT_TYPE_CATEGORY_ID, TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_ID
            ];
}

- (NSDictionary *)getDocumentById:(NSString *)documentId
{
    // Returns the record from the Document table matching the filter on the Id field
    
    NSString *select = [self getDocumentSelect];
    NSString *tables = [self getDocumentTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, [documentId uppercaseString]];
    
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSDictionary *)getDocumentByFilePath:(NSString *)filePath includeThumbnail:(BOOL)includeThumbnail
{
    // Returns the record from the Document table matching the filter on the FilePath field
    
    if (includeThumbnail)
        filePath = [filePath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@.", IMAGE_THUMBNAIL_SUFFIX] withString:@"."];
    
    NSString *select = [self getDocumentSelect];
    NSString *tables = [self getDocumentTables];
    NSString *where = [NSString stringWithFormat:@"LOWER(%@.%@) = '%@'", TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_FILE_PATH, [filePath lowercaseString]];
    
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getDocumentsByDocumentTypeId:(NSString *)documentTypeId
{
    // Returns all records from the Document table matching the filter on the DocumentType_id field
    
    NSString *select = [self getDocumentSelect];
    NSString *tables = [self getDocumentTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID, [documentTypeId uppercaseString]];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
}

- (DataWrapper *)createDocumentWithRow:(NSDictionary *)row isNew:(BOOL)isNew requiresDataSync:(BOOL)requiresDataSync;
{
    // Inserts a record into the Document table, using the data in the dictionary supplied
    
    NSString *uuid;
    if ([row keyIsNotMissingNullOrEmpty:TABLE_DOCUMENT_COLUMN_ID])
        uuid = [row nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID];
    else
        uuid = [[NSString stringWithUUID] lowercaseString];
    
    // Set record creation date
    NSMutableDictionary *parameters = [[[NSMutableDictionary alloc] initWithDictionary:row] autorelease];
    [parameters setObject:[NSDate date] forKey:TABLE_DOCUMENT_COLUMN_DATE_CREATED];
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_DOCUMENT_COLUMN_FILE_NAME,
                      TABLE_DOCUMENT_COLUMN_MIME_TYPE,
                      TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID,
                      TABLE_DOCUMENT_COLUMN_COMMENTS,
                      TABLE_DOCUMENT_COLUMN_FILE_PATH,
                      nil] autorelease];
    parameters = [parameters addNullValuesForKeys:keys];
    NSString *dataSyncFlag = requiresDataSync ? @"1" : @"0";
    NSString *isNewFlag = isNew ? @"1" : @"0";
    
    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, %@, %@)", TABLE_DOCUMENT, uuid, TABLE_DOCUMENT_COLUMN_FILE_NAME, TABLE_DOCUMENT_COLUMN_MIME_TYPE, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT_COLUMN_COMMENTS, TABLE_DOCUMENT_COLUMN_FILE_PATH, dataSyncFlag, isNewFlag];
    BOOL result = [self executeUpdate:query withParameterDictionary:parameters];
    NSDictionary *data = [self getDocumentById:uuid];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (DataWrapper *)updateDocumentWithRow:(NSDictionary *)row requiresDataSync:(BOOL)requiresDataSync
{
    // Updates a record in the Document table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_DOCUMENT_COLUMN_FILE_NAME, TABLE_DOCUMENT_COLUMN_MIME_TYPE, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT_COLUMN_FILE_PATH,
                      nil] autorelease];
    NSMutableDictionary *parameters = [row addNullValuesForKeys:keys];
    NSString *setRequiresDataSync = requiresDataSync ? [NSString stringWithFormat:@", %@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC] : @"";
    
    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@ %@ WHERE %@ = :%@",
                       TABLE_DOCUMENT,
                       TABLE_DOCUMENT_COLUMN_FILE_NAME, TABLE_DOCUMENT_COLUMN_FILE_NAME,
                       TABLE_DOCUMENT_COLUMN_MIME_TYPE, TABLE_DOCUMENT_COLUMN_MIME_TYPE,
                       TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID,
                       TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT_COLUMN_DATE_CREATED,
                       TABLE_DOCUMENT_COLUMN_COMMENTS, TABLE_DOCUMENT_COLUMN_COMMENTS,
                       TABLE_DOCUMENT_COLUMN_FILE_PATH, TABLE_DOCUMENT_COLUMN_FILE_PATH,
                       setRequiresDataSync,
                       TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_COLUMN_ID];
    
    BOOL result = [self executeUpdate:query withParameterDictionary:parameters];
    NSDictionary *data = [self getDocumentById:[parameters objectForKey:TABLE_DOCUMENT_COLUMN_ID]];

    // If operation has succeeded and a sync is required, schedule a sync pending notification
    if (result && requiresDataSync)
        [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];

    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (BOOL)deleteDocumentById:(NSString *)documentId includingFile:(BOOL)includingFile;
{
    // Deletes a record from the Document table matching the filter on the Id field
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    ImageManager *imageManager = [ImageManager sharedInstance];
    
    NSString *filePath = [[self getDocumentById:documentId] nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
    NSString *thumbnailFilePath = [imageManager getThumbnailFilePathForStandardImageFilePath:filePath];
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_DOCUMENT_COLUMN_ID, [documentId uppercaseString]];
    BOOL result = [self executeDelete:TABLE_DOCUMENT withWhere:where];
    
    // If the delete operation was successful, also delete the file itself
    if (result && includingFile && ![filePath isEqualToString:@""] && [fileManager fileExistsAtPath:[filePath stringByPrependingDocumentsDirectoryFilepath]]) {
        result = [fileManager removeItemAtPath:[filePath stringByPrependingDocumentsDirectoryFilepath] error:nil];
    }
    
    // Also delete thumbnail version of the file, if one exists
    if (result && includingFile && thumbnailFilePath && ![thumbnailFilePath isEqualToString:@""] && [fileManager fileExistsAtPath:[thumbnailFilePath stringByPrependingDocumentsDirectoryFilepath]]) {
        result = [fileManager removeItemAtPath:[thumbnailFilePath stringByPrependingDocumentsDirectoryFilepath] error:nil];
    }
    
    return result;
}

#pragma mark - Document Type

- (NSString *)getDocumentTypeSelect
{
    return [NSString stringWithFormat:@"%@.*, %@.%@ AS %@", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME, TABLE_DOCUMENT_TYPE_COLUMN_DOCUMENT_TYPE_CATEGORY_NAME];
}

- (NSString *)getDocumentTypeTables
{
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_DOCUMENT_TYPE_CATEGORY_ID, TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_ID];
}

- (NSDictionary *)getDocumentTypeByName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode documentTypeCategoryName:(NSString *)documentTypeCategoryName
{
    // Returns the record from the DocumentType table matching the filters on the Name field and the DocumentTypeCategory table Name field
    
    NSString *select = [self getDocumentTypeSelect];
    NSString *tables = [self getDocumentTypeTables];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@",
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@.%@ = '%@'", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@.%@ = '%@'", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       documentTypeCategoryName == nil ? @"" : [NSString stringWithFormat:@"AND %@.%@ = '%@'", TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME, documentTypeCategoryName]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSDictionary *)getDocumentTypeById:(NSString *)documentTypeId
{
    // Returns the record from the DocumentType table matching the filter on the Id field
    
    NSString *select = [self getDocumentTypeSelect];
    NSString *tables = [self getDocumentTypeTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID, [documentTypeId uppercaseString]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getDocumentTypesForDocumentTypeCategoryName:(NSString *)documentTypeCategoryName
{
    // Returns all records from the DocumentType table matching the filter on the DocumentTypeCategory table Name field
    
    NSString *select = [self getDocumentTypeSelect];
    NSString *tables = [self getDocumentTypeTables];
    NSString *where = [NSString stringWithFormat:@"%@ = '%@'", TABLE_DOCUMENT_TYPE_COLUMN_DOCUMENT_TYPE_CATEGORY_NAME, documentTypeCategoryName];
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:[NSString stringWithFormat:@"UPPER(%@.%@)", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME]];
}

#pragma mark - Document Type Category

- (NSDictionary *)getDocumentTypeCategoryByName:(NSString *)documentTypeCategoryName
{
    // Returns the record from the DocumentTypeCategory table matching the filter on the Name field
    
    NSString *where = [NSString stringWithFormat:@"%@ = '%@'", TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME, documentTypeCategoryName];
    return [self executeSelectSingle:TABLE_DOCUMENT_TYPE_CATEGORY withSelect:@"*" withWhere:where];
}

- (NSDictionary *)getDocumentTypeCategoryById:(NSString *)documentTypeCategoryId
{
    // Returns the record from the DocumentTypeCategory table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_ID, [documentTypeCategoryId uppercaseString]];
    return [self executeSelectSingle:TABLE_DOCUMENT_TYPE_CATEGORY withSelect:@"*" withWhere:where];
}

#pragma mark - Document - Equipment

- (BOOL)addRowToDocumentEquipment:(NSDictionary *)row withEquipmentId:(NSNumber *)equipmentId withDatabase:(FMDatabase *)database
{
    // Inserts a record into the Document_Equipment table, using the data in the dictionary supplied
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    
    // Document Id
    NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[parameters objectForKey:TABLE_DOCUMENT_COLUMN_ID], TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, nil];
    [parameters addEntriesFromDictionary:documentDictionary];
    [documentDictionary release];
    
    // Equipment Id
    NSDictionary *equipmentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(NSNumber *)equipmentId, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, nil];
    [parameters addEntriesFromDictionary:equipmentDictionary];
    [equipmentDictionary release];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID];
    
    BOOL result = [database executeUpdate:query withParameterDictionary:[parameters convertDatesToLongDateTimeUtcString]];
    [parameters release];
    
    return result;
}

- (BOOL)deleteDocumentEquipmentForEquipmentId:(NSNumber *)equipmentId document:(NSDictionary *)document withDatabase:(FMDatabase *)database
{
    // Deletes all records from the DocumentEquipment table matching the filter on the Equipment_id and Document_id fields
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@' AND %@ = %lld", TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, [[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString], TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]];
    
    BOOL result;
    if (database == nil)
        result = [self executeDelete:TABLE_DOCUMENT_EQUIPMENT withWhere:where];
    else
        result = [self executeDelete:TABLE_DOCUMENT_EQUIPMENT withWhere:where withDatabase:database];
    
    return result;
}

- (BOOL)deleteDocumentEquipmentForEquipmentId:(NSNumber *)equipmentId whereDocumentsNotIn:(NSArray *)documents withDatabase:(FMDatabase *)database
{
    // Deletes all records from the Document_Equipment table matching the filter on the Equipment_id field, where the associated documents do not exist in the supplied array
    
    if (!documents || [documents count] == 0)
        return YES;
    
    NSMutableArray *documentIds = [NSMutableArray array];
    for (NSDictionary *document in documents) {
        [documentIds addObject:[NSString stringWithFormat:@"'%@'", [[document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString]]];
    }
    
    NSString *where = [NSString stringWithFormat:@"%@ = %lld AND UPPER(%@) NOT IN (%@)", TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, [documentIds componentsJoinedByString:@","]];
    
    return [self executeDelete:TABLE_DOCUMENT_EQUIPMENT withWhere:where withDatabase:database];
}

- (NSArray *)getDocumentsForEquipmentId:(NSNumber *)equipmentId documentTypeName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode filterForRequiresDataSync:(BOOL)filterForRequiresDataSync withDatabase:(FMDatabase *)database
{
    // Returns all records from the Document table, matching the filters on the DocumentType_Name field, and the Equipment_Id field in the Document_Equipment table
    
    NSString *select = [NSString stringWithFormat:@"%@, %@.%@", [self getDocumentSelect], TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@", [self getDocumentTables], TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@ %@",
                       equipmentId == nil ? @"" : [NSString stringWithFormat:@"AND %@.%@ = %lld", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]],
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       !filterForRequiresDataSync ? @"" : [NSString stringWithFormat:@"AND %@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC]];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ ASC, %@.%@ DESC, %@.%@ ASC", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_FILE_NAME];
    
    NSArray *result;
    if (database == nil)
        result = [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
    else {
        NSString *sql = [NSString stringWithFormat:@"%@ FROM %@ %@ %@", select, tables, where, orderBy];
        FMResultSet *results = [database executeQuery:sql];
        NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
        while ([results next]) [resultsArray addObject: [results resultDictionary]];
        result = [NSArray arrayWithArray:resultsArray];
        [resultsArray release];
        [results close];
    }
    
    return result;
}

- (NSArray *)getEquipmentForDocumentId:(NSString *)documentId
{
    // Returns all records from the Equipment table, that have a corresponding record in the Document_Equipment table linking them to the specified document
    
    NSString *tables = [NSString stringWithFormat:@"(SELECT * FROM %@) e INNER JOIN %@ ON e.%@ = %@.%@", [self getEquipmentTables], TABLE_DOCUMENT_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
    
    return [self executeSelectAll:tables withSelect:@"e.*" withWhere:where withOrderBy:nil];
}

- (DataWrapper *)createDocumentWithRow:(NSDictionary *)row forEquipmentId:(NSNumber *)equipmentId
{
    // Inserts a record into the Document table, and a record in the associated Document_Equipment table, using the data in the dictionary supplied
    
    // First, attempt the creation of the document record
    DataWrapper *dataWrapper = [self createDocumentWithRow:row isNew:YES requiresDataSync:YES];
    
    // If this succeeds, create the record in the Document_Equipment table
    if (dataWrapper.isValid)
    {
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        
        // Document Id
        NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[dataWrapper.dataDictionary objectForKey:TABLE_DOCUMENT_COLUMN_ID], TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, nil];
        [parameters addEntriesFromDictionary:documentDictionary];
        [documentDictionary release];
        
        // Equipment Id
        NSDictionary *equipmentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:equipmentId, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, nil];
        [parameters addEntriesFromDictionary:equipmentDictionary];
        [equipmentDictionary release];
        
        NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID];
        dataWrapper.isValid = [self executeUpdate:query withParameterDictionary:parameters];
        
        [parameters release];
    }
    
    // If both operations have succeeded, schedule a sync pending notification
    if (dataWrapper.isValid)
        [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return dataWrapper;
}

- (BOOL)deleteDocumentsForEquipmentId:(NSNumber *)equipmentId documentTypeName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode filePath:(NSString *)filePath includingFiles:(BOOL)includingFiles
{
    // Deletes all records from the Document table, and all associated records from the Document_Equipment table, matching all filters supplied
    // Possible filter parameters are equipment Id, document type name, and file path
    
    BOOL result = YES;
    
    // Get all document records matching the filters
    NSString *select = [self getDocumentSelect];
    NSString *tables = [NSString stringWithFormat:@"%@ %@",
                        [self getDocumentTables],
                        equipmentId == nil ? @"" : [NSString stringWithFormat:@"INNER JOIN %@ ON %@.%@ = %@.%@", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID]];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@ %@",
                       equipmentId == nil ? @"" : [NSString stringWithFormat:@"AND %@.%@ = %lld", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]],
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       filePath == nil ? @"" : [NSString stringWithFormat:@"AND LOWER(%@) = '%@'", TABLE_DOCUMENT_COLUMN_FILE_PATH, [filePath lowercaseString]]];
    NSArray *documents = [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
    
    // Attempt to delete the document records, and associated join records, for each document identified
    for (NSDictionary *document in documents)
    {
        if (result)
            result = [self deleteDocumentById:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] includingFile:includingFiles];
        
        if (result) {
            where = [NSString stringWithFormat:@"UPPER(%@) = '%@' %@",
                               TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, [[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString],
                               equipmentId == nil ? @"" : [NSString stringWithFormat:@"AND %@ = %lld", TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]]];
            result = [self executeDelete:TABLE_DOCUMENT_EQUIPMENT withWhere:where];
        }
    }
    
    return result;
}

- (BOOL)deleteDocumentsForEquipmentId:(NSNumber *)equipmentId whereDocumentsNotIn:(NSArray *)documents withDatabase:(FMDatabase *)database
{
    // Deletes all records from the Document table matching the filter on the Document_Equipment table Equipment_id field, where the associated documents do not exist in the supplied array
    
    if (!documents || [documents count] == 0)
        return YES;
    
    NSMutableArray *documentIds = [NSMutableArray array];
    for (NSDictionary *document in documents) {
        [documentIds addObject:[NSString stringWithFormat:@"'%@'", [[document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString]]];
    }
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) IN (SELECT UPPER(%@) FROM %@ WHERE %@ = %lld) AND UPPER(%@) NOT IN (%@)",
                       TABLE_DOCUMENT_COLUMN_ID,
                       TABLE_DOCUMENT_EQUIPMENT_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue],
                       TABLE_DOCUMENT_COLUMN_ID, [documentIds componentsJoinedByString:@","]];
    
    return [self executeDelete:TABLE_DOCUMENT withWhere:where withDatabase:database];
}

#pragma mark - Document - Site Visit Report

- (BOOL)addRowToDocumentSiteVisitReport:(NSDictionary *)row withSiteVisitReportId:(NSString *)siteVisitReportId withEquipmentId:(NSNumber *)equipmentId withCreatedById:(NSNumber *)createdById withDatabase:(FMDatabase *)database
{
    // Inserts a record into the Document_SiteVisitReport table, using the data in the dictionary supplied
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    
    // Document Id
    NSString *documentId = [row objectForKey:TABLE_DOCUMENT_COLUMN_ID];
    NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(documentId == nil) ? [NSNull null] : documentId, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, nil];
    [parameters addEntriesFromDictionary:documentDictionary];
    [documentDictionary release];
    
    // Equipment Id
    NSDictionary *equipmentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(equipmentId == nil) ? [NSNull null] : equipmentId, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, nil];
    [parameters addEntriesFromDictionary:equipmentDictionary];
    [equipmentDictionary release];
    
    // Created By Id
    NSDictionary *createdByDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(createdById == nil) ? [NSNull null] : createdById, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_ID, nil];
    [parameters addEntriesFromDictionary:createdByDictionary];
    [createdByDictionary release];
    
    // SiteVisitReport Id
    NSDictionary *siteVisitReportDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:siteVisitReportId, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, nil];
    [parameters addEntriesFromDictionary:siteVisitReportDictionary];
    [siteVisitReportDictionary release];
    
    // Query is different depending on whether or not we have an incoming Dean Id
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@)", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_ID];
    
    BOOL result = [database executeUpdate:query withParameterDictionary:[parameters convertDatesToLongDateTimeUtcString]];
    [parameters release];
    
    return result;
}

- (BOOL)deleteDocumentSiteVisitReportForSiteVisitReportId:(NSString *)siteVisitReportId document:(NSDictionary *)document withDatabase:(FMDatabase *)database
{
    // Deletes all records from the Document_SiteVisitReport table matching the filter on the SiteVisitReport_id and Document_id fields
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@' AND UPPER(%@) = '%@'", TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, [[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString], TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, [siteVisitReportId uppercaseString]];
    
    BOOL result;
    if (database == nil)
        result = [self executeDelete:TABLE_DOCUMENT_SITE_VISIT_REPORT withWhere:where];
    else
        result = [self executeDelete:TABLE_DOCUMENT_SITE_VISIT_REPORT withWhere:where withDatabase:database];
    
    return result;
}

- (NSArray *)getDocumentsForSiteVisitReportId:(NSString *)siteVisitReportId documentId:(NSString *)documentId documentTypeName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode documentTypeCategoryName:(NSString *)documentTypeCategoryName filterForRequiresDataSync:(BOOL)filterForRequiresDataSync
{
    // Returns all records from the Document table, matching the filters on the DocumentType_Name field, and the SiteVisitReport_Id field in the Document_SiteVisitReport table
    
    NSString *select = [NSString stringWithFormat:@"%@, %@.%@, %@.%@, %@.%@ AS %@, %@.%@ AS %@",
                        [self getDocumentSelect],
                        TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID,
                        TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID,
                        TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_SERVICE_TAG_NUMBER,
                        TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_NAME, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_NAME
                        ];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@",
                        [self getDocumentTables],
                        TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID,
                        TABLE_EQUIPMENT, TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID,
                        TABLE_ENGINEER, TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_ID, TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_ID
                        ];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@ %@ %@ %@",
                       siteVisitReportId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, [siteVisitReportId uppercaseString]],
                       documentId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@.%@) = '%@'", TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, [documentId uppercaseString]],
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       documentTypeCategoryName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_CATEGORY_NAME, documentTypeCategoryName],
                       !filterForRequiresDataSync ? @"" : [NSString stringWithFormat:@"AND %@.%@ = 1", TABLE_DOCUMENT, TABLE_COMMON_REQUIRES_DATA_SYNC]];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ ASC, %@.%@ ASC", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_FILE_NAME];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getSiteVisitReportsForDocumentId:(NSString *)documentId
{
    // Returns all records from the SiteVisitReport table, that have a corresponding record in the Document_SiteVisitReport table linking them to the specified document
    
    NSString *select = [NSString stringWithFormat:@"s.*, %@.*", TABLE_DOCUMENT_SITE_VISIT_REPORT];
    NSString *tables = [NSString stringWithFormat:@"(SELECT * FROM %@) s INNER JOIN %@ ON s.%@ = %@.%@", [self getSiteVisitReportTables], TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
}

- (DataWrapper *)createDocumentWithRow:(NSDictionary *)row forSiteVisitReportId:(NSString *)siteVisitReportId equipmentId:(NSNumber *)equipmentId engineerId:(NSNumber *)engineerId setRequiresDataSync:(BOOL)setRequiresDataSync
{
    // Inserts a record into the Document table, and a record in the associated Document_SiteVisitReport table, using the data in the dictionary supplied
    
    // First, attempt the creation of the document record
    DataWrapper *dataWrapper = [self createDocumentWithRow:row isNew:YES requiresDataSync:setRequiresDataSync];
    
    // If this succeeds, create the record in the Document_SiteVisitReport table
    if (dataWrapper.isValid)
    {
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        
        // Document Id
        NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[dataWrapper.dataDictionary objectForKey:TABLE_DOCUMENT_COLUMN_ID], TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, nil];
        [parameters addEntriesFromDictionary:documentDictionary];
        [documentDictionary release];
        
        // Site Visit Report Id
        NSDictionary *siteVisitReportDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:siteVisitReportId, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, nil];
        [parameters addEntriesFromDictionary:siteVisitReportDictionary];
        [siteVisitReportDictionary release];
        
        // Equipment Id
        NSDictionary *equipmentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(equipmentId == nil) ? [NSNull null] : equipmentId, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, nil];
        [parameters addEntriesFromDictionary:equipmentDictionary];
        [equipmentDictionary release];
        
        // Engineer Id
        NSDictionary *engineerDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(engineerId == nil) ? [NSNull null] : engineerId, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_ID, nil];
        [parameters addEntriesFromDictionary:engineerDictionary];
        [engineerDictionary release];
        
        NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@)", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_ID];
        dataWrapper.isValid = [self executeUpdate:query withParameterDictionary:parameters];
        
        [parameters release];
    }
    
    // If both operations have succeeded, update data wrapper to contain full data dictionary and schedule a sync pending notification
    if (dataWrapper.isValid) {
        NSDictionary *dataDictionary = [[self getDocumentsForSiteVisitReportId:siteVisitReportId documentId:[dataWrapper.dataDictionary nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:NO] objectAtIndex:0];
        dataWrapper.dataDictionary = dataDictionary;
        [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    }
    
    return dataWrapper;
}

- (BOOL)deleteDocumentsForSiteVisitReportId:(NSString *)siteVisitReportId documentTypeName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode documentTypeCategoryName:(NSString *)documentTypeCategoryName filePath:(NSString *)filePath includingFiles:(BOOL)includingFiles
{
    // Deletes all records from the Document table, and all associated records from the Document_SiteVisitReport table, matching all filters supplied
    // Possible filter parameters are site visit report Id, document type name, and file path
    
    BOOL result = YES;
    
    // Get all document records matching the filters
    NSString *select = [self getDocumentSelect];
    NSString *tables = [NSString stringWithFormat:@"%@ %@",
                        [self getDocumentTables],
                        siteVisitReportId == nil ? @"" : [NSString stringWithFormat:@"INNER JOIN %@ ON %@.%@ = %@.%@", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID]];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@ %@ %@",
                       siteVisitReportId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, [siteVisitReportId uppercaseString]],
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       documentTypeCategoryName == nil ? @"" : [NSString stringWithFormat:@"AND %@.%@ = '%@'", TABLE_DOCUMENT_TYPE_CATEGORY, TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME, documentTypeCategoryName],
                       filePath == nil ? @"" : [NSString stringWithFormat:@"AND LOWER(%@) = '%@'", TABLE_DOCUMENT_COLUMN_FILE_PATH, [filePath lowercaseString]]];
    NSArray *documents = [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
    
    // Attempt to delete the document records, and associated join records, for each document identified
    for (NSDictionary *document in documents)
    {
        if (result)
            result = [self deleteDocumentById:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] includingFile:includingFiles];
        
        if (result) {
            where = [NSString stringWithFormat:@"UPPER(%@) = '%@' %@",
                               TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_DOCUMENT_ID, [[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString],
                               siteVisitReportId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@) = '%@'", TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_SITE_VISIT_REPORT_ID, [siteVisitReportId uppercaseString]]];
            result = [self executeDelete:TABLE_DOCUMENT_SITE_VISIT_REPORT withWhere:where];
        }
    }
    
    return result;
}

#pragma mark - Document - Test Session

- (BOOL)addRowsToDocumentTestSession:(NSArray *)rows
{
    // Inserts a number of records into the Document_TestSession table table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        for (NSDictionary *row in rows)
        {
            if (![self addRowToDocumentTestSession:row withDatabase:database])
            {
                self.successFlag = NO;
                break;
            }
        }
    }];
    
    return self.successFlag;
}

- (BOOL)addRowToDocumentTestSession:(NSDictionary *)row withDatabase:(FMDatabase *)database
{
    // Inserts a record into the Document_TestSession table, using the data in the dictionary supplied
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID];
    BOOL result = [database executeUpdate:query withParameterDictionary:[parameters convertDatesToLongDateTimeUtcString]];
    [parameters release];
    
    return result;
}

- (BOOL)addRowToDocumentTestSession:(NSDictionary *)row withTestSessionId:(NSString *)testSessionId withDatabase:(FMDatabase *)database
{
    // Inserts a record into the Document_TestSession table, using the data in the dictionary supplied
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    
    // Document Id
    NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[parameters objectForKey:TABLE_DOCUMENT_COLUMN_ID], TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, nil];
    [parameters addEntriesFromDictionary:documentDictionary];
    [documentDictionary release];
    
    // Test Session Id
    NSDictionary *testSessionDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(NSString *)testSessionId, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, nil];
    [parameters addEntriesFromDictionary:testSessionDictionary];
    [testSessionDictionary release];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID];
    
    BOOL result = [database executeUpdate:query withParameterDictionary:[parameters convertDatesToLongDateTimeUtcString]];
    [parameters release];
    
    return result;
}

- (NSArray *)getDocumentTestSessionsForTestSessionId:(NSString *)testSessionId;
{
    // Returns all records from the Document_TestSession table matching the filter on the TestSession_Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    return [self executeSelectAll:TABLE_DOCUMENT_TEST_SESSION withSelect:@"*" withWhere:where withOrderBy:nil];
}

- (BOOL)deleteDocumentTestSessionForTestSessionId:(NSString *)testSessionId
{
    // Deletes all records from the DocumentTestSession table matching the filter on the TestSession_Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    BOOL result = [self executeDelete:TABLE_DOCUMENT_TEST_SESSION withWhere:where];
    
    return result;
}

- (NSArray *)getDocumentsForTestSessionId:(NSString *)testSessionId documentTypeName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode documentTypeCategoryName:(NSString *)documentTypeCategoryName filterForRequiresDataSync:(BOOL)filterForRequiresDataSync
{
    // Returns all records from the Document table, matching the filters on the DocumentType_Name field, and the TestSession_Id field in the Document_TestSession table
    
    NSString *select = [self getDocumentSelect];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@", [self getDocumentTables], TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@ %@ %@",
                       testSessionId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]],
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       documentTypeCategoryName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_CATEGORY_NAME, documentTypeCategoryName],
                       !filterForRequiresDataSync ? @"" : [NSString stringWithFormat:@"AND %@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC]];
    // File name used in ordering if dates are identical
    // Ordering is reflected in Api to provide consistency
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ ASC, %@.%@ ASC, %@.%@ ASC", TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_FILE_NAME];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getTestSessionsForDocumentId:(NSString *)documentId
{
    // Returns all records from the TestSession table, that have a corresponding record in the Document_TestSession table linking them to the specified document
    
    NSString *select = [NSString stringWithFormat:@"t.*, %@.*", TABLE_DOCUMENT_TEST_SESSION];
    NSString *tables = [NSString stringWithFormat:@"(SELECT * FROM %@) t INNER JOIN %@ ON t.%@ = %@.%@", [self getTestSessionTables], TABLE_DOCUMENT_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_ID, TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
}

- (NSArray *)getTestDocumentsForTestSessionId:(NSString *)testSessionId
{
    // Returns all records from the Document table matching the filter on the Document_Id field in the TestSessionTest table
    // Note: Although strictly speaking this is not related to to the Document_TestSession table, this seemed the most appropriate section in which to locate the method
    
    NSString *where = [NSString stringWithFormat:@"%@ IN (SELECT %@ FROM %@ WHERE UPPER(%@) = '%@') ", TABLE_DOCUMENT_COLUMN_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    
    return [self executeSelectAll:TABLE_DOCUMENT withSelect:@"*" withWhere:where withOrderBy:nil];
}

- (NSArray *)getMasterDocumentsForTestSessionId:(NSString *)testSessionId
{
    // Returns the document record for the test session's master document
    // This can exist either in the test session's documents collection, or as the test document for one of the child tests
    
    // Firstly get the test session type, from which we can obtain the test session's master document type
    NSDictionary *testSession = [self getTestSessionById:testSessionId];
    NSDictionary *testSessionType = [self getTestSessionTypeById:[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
    
    // If any documents matching the master document type exist in the test session's documents collection, return these
    NSArray *testSessionDocuments = [self getDocumentsForTestSessionId:testSessionId documentTypeName:nil qualityManagementSystemCode:[testSessionType nullableObjectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE] documentTypeCategoryName:nil filterForRequiresDataSync:NO];
    if ([testSessionDocuments count])
        return testSessionDocuments;
    
    // Otherwise, if any documents matching the master document type exist as the test document for any of the child tests, return these
    NSArray *testDocuments = [self getTestDocumentsForTestSessionId:testSessionId];
    NSArray *testDocumentsForType = [testDocuments documentsArrayFilteredByDocumentTypeId:[testSessionType nullableObjectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_ID] documentTypeName:nil documentTypeCategoryName:nil];
    if ([testDocumentsForType count])
        return testDocumentsForType;
    
    return nil;
}

- (DataWrapper *)createDocumentWithRow:(NSDictionary *)row forTestSessionId:(NSString *)testSessionId setRequiresDataSync:(BOOL)setRequiresDataSync
{
    // Inserts a record into the Document table, and a record in the associated Document_TestSession table, using the data in the dictionary supplied
    
    // First, attempt the creation of the document record
    DataWrapper *dataWrapper = [self createDocumentWithRow:row isNew:YES requiresDataSync:setRequiresDataSync];
    
    // If this succeeds, create the record in the Document_TestSession table
    if (dataWrapper.isValid)
    {
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        
        // Document Id
        NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[dataWrapper.dataDictionary objectForKey:TABLE_DOCUMENT_COLUMN_ID], TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, nil];
        [parameters addEntriesFromDictionary:documentDictionary];
        [documentDictionary release];
        
        // Test Session Id
        NSDictionary *testSessionDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:testSessionId, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, nil];
        [parameters addEntriesFromDictionary:testSessionDictionary];
        [testSessionDictionary release];
        
        NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID];
        dataWrapper.isValid = [self executeUpdate:query withParameterDictionary:parameters];
        
        [parameters release];
    }
    
    // If both operations have succeeded, schedule a sync pending notification
    if (dataWrapper.isValid)
        [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return dataWrapper;
}

- (BOOL)deleteDocumentsForTestSessionId:(NSString *)testSessionId documentTypeName:(NSString *)documentTypeName qualityManagementSystemCode:(NSString *)qualityManagementSystemCode filePath:(NSString *)filePath includingFiles:(BOOL)includingFiles
{
    // Deletes all records from the Document table, and all associated records from the Document_TestSession table, matching all filters supplied
    // Possible filter parameters are test session Id, document type name, and file path
    
    BOOL result = YES;
    
    // Get all document records matching the filters
    NSString *select = [self getDocumentSelect];
    NSString *tables = [NSString stringWithFormat:@"%@ %@",
                        [self getDocumentTables],
                        testSessionId == nil ? @"" : [NSString stringWithFormat:@"INNER JOIN %@ ON %@.%@ = %@.%@", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID]];
    NSString *where = [NSString stringWithFormat:@"1 = 1 %@ %@ %@ %@",
                       testSessionId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@.%@) = '%@'", TABLE_DOCUMENT_TEST_SESSION, TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]],
                       documentTypeName == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_NAME, documentTypeName],
                       qualityManagementSystemCode == nil ? @"" : [NSString stringWithFormat:@"AND %@ = '%@'", TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE, qualityManagementSystemCode],
                       filePath == nil ? @"" : [NSString stringWithFormat:@"AND LOWER(%@) = '%@'", TABLE_DOCUMENT_COLUMN_FILE_PATH, [filePath lowercaseString]]];
    NSArray *documents = [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
    
    // Attempt to delete the document records, and associated join records, for each document identified
    for (NSDictionary *document in documents)
    {
        if (result)
            result = [self deleteDocumentById:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] includingFile:includingFiles];
        
        if (result) {
            where = [NSString stringWithFormat:@"UPPER(%@) = '%@' %@",
                               TABLE_DOCUMENT_TEST_SESSION_COLUMN_DOCUMENT_ID, [[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] uppercaseString],
                               testSessionId == nil ? @"" : [NSString stringWithFormat:@"AND UPPER(%@) = '%@'", TABLE_DOCUMENT_TEST_SESSION_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]]];
            result = [self executeDelete:TABLE_DOCUMENT_TEST_SESSION withWhere:where];
        }
    }
    
    return result;
}

- (BOOL)deleteTestDocumentsForTestSessionId:(NSString *)testSessionId
{
    // Deletes all records from the Document table matching the filter on the Document_Id field in the TestSessionTest table
    // Note: Although strictly speaking this is not related to to the Document_TestSession table, this seemed the most appropriate section in which to locate the method
    
    NSString *where = [NSString stringWithFormat:@"%@ IN (SELECT %@ FROM %@ WHERE UPPER(%@) = '%@') ", TABLE_DOCUMENT_COLUMN_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    return [self executeDelete:TABLE_DOCUMENT withWhere:where];
}

#pragma mark - Engineer

- (NSArray *)getEngineersWithSVRs
{
    // Returns all records from the Engineer table where the engineer has SVRs assigned
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@", TABLE_ENGINEER, TABLE_SITE_VISIT_REPORT, TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_ID,TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID];
    
    return [self executeSelectAll:tables withSelect:[NSString stringWithFormat:@"DISTINCT %@.*", TABLE_ENGINEER] withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_ENGINEER_COLUMN_NAME]];
}

- (NSArray *)getUnarchivedEngineers
{
    // Returns all records from the Engineer table where the engineer is unarchived
    
    NSString *where = [NSString stringWithFormat:@"%@ IS NOT NULL AND TRIM(%@) <> '' AND %@ <> 1", TABLE_ENGINEER_COLUMN_NAME, TABLE_ENGINEER_COLUMN_NAME, TABLE_ENGINEER_COLUMN_ARCHIVED];
    return [self executeSelectAll:TABLE_ENGINEER withSelect:@"*" withWhere:where withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_ENGINEER_COLUMN_NAME]];
}

- (NSDictionary *)getEngineerById:(NSNumber *)engineerId
{
    // Returns the record from the Engineer table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"%@ = %ld", TABLE_ENGINEER_COLUMN_ID, (long)[engineerId integerValue]];
    return [self executeSelectSingle:TABLE_ENGINEER withSelect:@"*" withWhere:where];
}

- (NSDictionary *)getEngineerByEmail:(NSString *)engineerEmail
{
    // Returns the record from the Engineer table matching the filter on the Email field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_ENGINEER_COLUMN_EMAIL, [engineerEmail uppercaseString]];
    return [self executeSelectSingle:TABLE_ENGINEER withSelect:@"*" withWhere:where];
}

- (DataWrapper *)updateEngineerWithRow:(NSMutableDictionary *)row
{
    // Updates a record in the Engineer table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_ENGINEER_COLUMN_EMAIL,
                      TABLE_ENGINEER_COLUMN_ARCHIVED,
                      TABLE_ENGINEER_COLUMN_NAME,
                      TABLE_ENGINEER_COLUMN_ORGANISATION_ID,
                      TABLE_ENGINEER_COLUMN_CURRENT_LOCATION_ID,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@ WHERE %@ = :%@",
                       TABLE_ENGINEER,
                       TABLE_ENGINEER_COLUMN_EMAIL, TABLE_ENGINEER_COLUMN_EMAIL,
                       TABLE_ENGINEER_COLUMN_ARCHIVED, TABLE_ENGINEER_COLUMN_ARCHIVED,
                       TABLE_ENGINEER_COLUMN_NAME, TABLE_ENGINEER_COLUMN_NAME,
                       TABLE_ENGINEER_COLUMN_ORGANISATION_ID, TABLE_ENGINEER_COLUMN_ORGANISATION_ID,
                       TABLE_ENGINEER_COLUMN_CURRENT_LOCATION_ID, TABLE_ENGINEER_COLUMN_CURRENT_LOCATION_ID,
                       TABLE_ENGINEER_COLUMN_ID, TABLE_ENGINEER_COLUMN_ID];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getEngineerById:[row objectForKey:TABLE_ENGINEER_COLUMN_ID]];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

#pragma mark - Equipment

- (NSString *)getEquipmentSelect
{
    // Returns the SELECT part of the standard SQL SELECT query for Equipment
    
    NSString *equipmentSelects = [NSString stringWithFormat:@"%@.*", TABLE_EQUIPMENT];
    
    NSString *organisationSelects = [NSString stringWithFormat:@"m.%@ AS '%@'", TABLE_ORGANISATION_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_MANUFACTURER_NAME];
    
    NSString *commissionStatusSelects = [NSString stringWithFormat:@"%@.%@ AS '%@'", TABLE_COMMISSION_STATUS, TABLE_COMMISSION_STATUS_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_NAME];
    
    NSString *branchSelects = [NSString stringWithFormat:@"%@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@'",
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_BRANCH_NAME,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_LINE_1, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_LINE_1,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_LINE_2, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_LINE_2,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_LINE_3, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_LINE_3,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_LINE_4, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_LINE_4,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_LINE_5, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_LINE_5,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_TOWN, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_TOWN,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_COUNTY, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_COUNTY,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_ADDRESS_POST_CODE, TABLE_EQUIPMENT_COLUMN_BRANCH_ADDRESS_POST_CODE,
                               TABLE_BRANCH, TABLE_BRANCH_COLUMN_COUNTRY_ID, TABLE_EQUIPMENT_COLUMN_BRANCH_COUNTRY_ID
                               ];
    
    NSString *worksOrderSelects = [NSString stringWithFormat:@"%@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@'", TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_WO_NUMBER, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_WO_NUMBER, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_PROJECT_NAME, TABLE_EQUIPMENT_COLUMN_PROJECT_NAME, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_PROJECT_MANAGER_NAME, TABLE_EQUIPMENT_COLUMN_PROJECT_MANAGER, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_PHOTOGRAPHY_NOT_ALLOWED_ON_SITE, TABLE_EQUIPMENT_COLUMN_PROJECT_PHOTOGRAPHY_NOT_ALLOWED_ON_SITE];
    
    NSString *equipmentTypeSelects = [NSString stringWithFormat:@"%@.%@ AS '%@'", TABLE_EQUIPMENT_TYPE, TABLE_EQUIPMENT_TYPE_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME];
    
    NSString *serviceProviderSelects = [NSString stringWithFormat:@"sp.%@ AS '%@'", TABLE_ORGANISATION_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_SERVICE_PROVIDER_NAME];
    
    NSString *floorSelects = [NSString stringWithFormat:@"%@.%@ AS '%@'", TABLE_FLOOR, TABLE_FLOOR_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_FLOOR_NAME];
    
    NSString *ratingSelects = [NSString stringWithFormat:@"%@.%@ AS '%@'", TABLE_RATING, TABLE_RATING_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_RATING_NAME];
    
    NSString *conductorConfigurationSelects = [NSString stringWithFormat:@"%@.%@ AS '%@'", TABLE_CONDUCTOR_CONFIGURATION, TABLE_CONDUCTOR_CONFIGURATION_COLUMN_NAME, TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_NAME];

    return [NSString stringWithFormat:@"%@, %@, %@, %@, %@, %@, %@, %@, %@, %@", equipmentSelects, organisationSelects, commissionStatusSelects, branchSelects, worksOrderSelects, equipmentTypeSelects, serviceProviderSelects, floorSelects, ratingSelects, conductorConfigurationSelects];
}

- (NSString *)getEquipmentTables
{
    // Returns the FROM part of the standard SQL SELECT query for Equipment
    
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ AS m ON %@.%@ = m.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ AS sp ON sp.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ AS pe ON %@.%@ = pe.%@", TABLE_EQUIPMENT, TABLE_ORGANISATION, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_MANUFACTURER_ID, TABLE_ORGANISATION_COLUMN_ID, TABLE_COMMISSION_STATUS, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_ID, TABLE_COMMISSION_STATUS, TABLE_COMMISSION_STATUS_COLUMN_ID, TABLE_WORKS_ORDER, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_ID, TABLE_EQUIPMENT_TYPE, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_ID, TABLE_EQUIPMENT_TYPE, TABLE_EQUIPMENT_TYPE_COLUMN_ID, TABLE_BRANCH, TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_BRANCH_ID, TABLE_ORGANISATION, TABLE_ORGANISATION_COLUMN_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_PROVIDER_ID, TABLE_FLOOR, TABLE_FLOOR, TABLE_FLOOR_COLUMN_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_FLOOR_ID, TABLE_RATING, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_RATING_ID, TABLE_RATING, TABLE_RATING_COLUMN_ID, TABLE_CONDUCTOR_CONFIGURATION, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_ID, TABLE_CONDUCTOR_CONFIGURATION, TABLE_CONDUCTOR_CONFIGURATION_COLUMN_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT_COLUMN_ID];
}

- (NSDictionary *)getEquipmentById:(NSNumber *)equipmentId
{
    // Returns the record from the Equipment table matching the filter on the Id field
    
    NSString *select = [self getEquipmentSelect];
    NSString *tables = [self getEquipmentTables];
    NSString *where = [NSString stringWithFormat:@" %@.%@ = %lld ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, [equipmentId longLongValue]];
    
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSDictionary *)getEquipmentByServiceTag:(NSString *)serviceTag filterByUserPermissions:(BOOL)filterByUserPermissions
{
    // Returns the record from the Equipment table matching the filter on the ServiceTagNumber field
    
    NSString *select = [self getEquipmentSelect];
    NSString *tables = [self getEquipmentTables];
    NSString *where = [NSString stringWithFormat:@" %@.%@ = '%@' %@", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, serviceTag,
                       (filterByUserPermissions && [self loggedInUserIsSubcontractor])
                            ? [NSString stringWithFormat:@" AND (%@.%@ IN (%@) OR pe.%@ IN (%@)) ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser], TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                            : @""
                       ];

    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getEquipmentForParentEquipmentId:(NSNumber *)parentEquipmentId
{
    // Returns the records from the Equipment table matching the filter on the ParentEquipment_id field
    
    NSString *select = [self getEquipmentSelect];
    NSString *tables = [self getEquipmentTables];
    NSString *where = [NSString stringWithFormat:@" %@.%@ = %lld ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, [parentEquipmentId longLongValue]];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getEquipmentForBranchId:(NSNumber *)branchId woNumber:(NSNumber *)woNumber
{
    // Returns the records from the Equipment table matching the filter on the Branch_id field
    
    // The ServiceTag != 0 Where clause is to filter out a few invalid service tags of 0
    NSString *select = [self getEquipmentSelect];
    NSString *tables = [self getEquipmentTables];
    NSString *where = [NSString stringWithFormat:@" %@.%@ = %li AND (%@.%@ IS NULL OR LENGTH(%@.%@) = 0) AND (%@.%@ IS NULL OR (%@.%@ IS NOT NULL AND %@.%@ != 0 )) %@", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_BRANCH_ID, (long)[branchId integerValue], TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER,
                       [self loggedInUserIsSubcontractor]
                            ? [NSString stringWithFormat:@" AND (%@.%@ IN (%@) OR pe.%@ IN (%@)) ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser], TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                            : @""
        ];
    if (woNumber)
        where = [where stringByAppendingFormat:@" AND %@.%@ = %li ", TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_WO_NUMBER, (long)[woNumber integerValue]];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSInteger)getNextAvailableEquipmentId
{
    // Returns the next available Id based on the values in the Equipment table
    
    NSArray *result = [self executeSelectAll:TABLE_EQUIPMENT withSelect:TABLE_EQUIPMENT_COLUMN_ID withWhere:nil withOrderBy:[NSString stringWithFormat:@"%@ DESC LIMIT 1", TABLE_EQUIPMENT_COLUMN_ID]];
    return [result count] ? (NSInteger)[((NSNumber *)[[result objectAtIndex:0] objectForKey:TABLE_EQUIPMENT_COLUMN_ID]) integerValue] + 1 : 0;
}

- (NSInteger)getComponentInstalledCountForParentEquipmentId:(NSNumber *)parentEquipmentId
{
    // Returns the count of installed components for a parent equipment item based on the values in the Equipment table
    
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@ = %lld AND %@ = 1", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, [parentEquipmentId longLongValue], TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN];
    
    FMDatabase *database = [self getDatabase];
    [database open];
    FMResultSet *results = [database executeQuery:sql];
    
    NSInteger totalCount = 0;
    
    if ([results next])
        totalCount = [results intForColumnIndex:0];
    
    [results close];
    return totalCount;
}

- (double)getComponentInstalledLengthForParentEquipmentId:(NSNumber *)parentEquipmentId
{
    // Returns the combined length in metres of installed components for a parent equipment item based on the values in the Equipment table
    
    NSString *sql = [NSString stringWithFormat:@"SELECT SUM(%@) FROM %@ WHERE %@ = %lld AND %@ = 1", TABLE_EQUIPMENT_COLUMN_LENGTH_M, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, [parentEquipmentId longLongValue], TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN];
    
    FMDatabase *database = [self getDatabase];
    [database open];
    FMResultSet *results = [database executeQuery:sql];
    
    double totalLength = 0;
    
    if ([results next])
        totalLength = [results doubleForColumnIndex:0];
    
    [results close];
    return totalLength;
}

- (BOOL)createEquipmentWithRow:(NSMutableDictionary *)row
{
    // Inserts a record into the Equipment table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID,
                      TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER,
                      TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER,
                      TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID,
                      TABLE_EQUIPMENT_COLUMN_BRANCH_ID,
                      TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_ID,
                      TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE,
                      TABLE_EQUIPMENT_COLUMN_UNIT_DESCRIPTION,
                      TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION,
                      TABLE_EQUIPMENT_COLUMN_MANUFACTURER_ID,
                      TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_ID,
                      TABLE_EQUIPMENT_COLUMN_COMMISSIONED_DATE,
                      TABLE_EQUIPMENT_COLUMN_UNIT_DRAWING_REF,
                      TABLE_EQUIPMENT_COLUMN_ELECTRICAL_SCHEMATIC_DRAWING_REF,
                      TABLE_EQUIPMENT_COLUMN_SERVICE_PROVIDER_ID,
                      TABLE_EQUIPMENT_COLUMN_LAST_SERVICED_DATE,
                      TABLE_EQUIPMENT_COLUMN_DELIVERED_DATE,
                      TABLE_EQUIPMENT_COLUMN_IN_WARRANTY,
                      TABLE_EQUIPMENT_COLUMN_FLOOR_ID,
                      TABLE_EQUIPMENT_COLUMN_ROOM_AREA,
                      TABLE_EQUIPMENT_COLUMN_M0,
                      TABLE_EQUIPMENT_COLUMN_HAS_PROFILE_IMAGE,
                      TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_ID,
                      TABLE_EQUIPMENT_COLUMN_RATING_ID,
                      TABLE_EQUIPMENT_COLUMN_MAXIMUM_DUCTOR_RESISTANCE_MICROOHMS,
                      TABLE_EQUIPMENT_COLUMN_CREATED_BY_ID,
                      TABLE_EQUIPMENT_COLUMN_LENGTH_M,
                      TABLE_EQUIPMENT_COLUMN_QMF_LENGTH_M,
                      TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN,
                      TABLE_EQUIPMENT_COLUMN_TOTAL_COMPONENT_COUNT,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, 1, 1)", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, TABLE_EQUIPMENT_COLUMN_BRANCH_ID, TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_ID, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE, TABLE_EQUIPMENT_COLUMN_UNIT_DESCRIPTION, TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION, TABLE_EQUIPMENT_COLUMN_MANUFACTURER_ID, TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_ID, TABLE_EQUIPMENT_COLUMN_COMMISSIONED_DATE, TABLE_EQUIPMENT_COLUMN_UNIT_DRAWING_REF, TABLE_EQUIPMENT_COLUMN_ELECTRICAL_SCHEMATIC_DRAWING_REF, TABLE_EQUIPMENT_COLUMN_SERVICE_PROVIDER_ID, TABLE_EQUIPMENT_COLUMN_LAST_SERVICED_DATE, TABLE_EQUIPMENT_COLUMN_DELIVERED_DATE, TABLE_EQUIPMENT_COLUMN_IN_WARRANTY, TABLE_EQUIPMENT_COLUMN_FLOOR_ID, TABLE_EQUIPMENT_COLUMN_ROOM_AREA, TABLE_EQUIPMENT_COLUMN_M0, TABLE_EQUIPMENT_COLUMN_HAS_PROFILE_IMAGE, TABLE_EQUIPMENT_COLUMN_CONDUCTOR_CONFIGURATION_ID, TABLE_EQUIPMENT_COLUMN_RATING_ID, TABLE_EQUIPMENT_COLUMN_MAXIMUM_DUCTOR_RESISTANCE_MICROOHMS, TABLE_EQUIPMENT_COLUMN_CREATED_BY_ID, TABLE_EQUIPMENT_COLUMN_LENGTH_M, TABLE_EQUIPMENT_COLUMN_QMF_LENGTH_M, TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN, TABLE_EQUIPMENT_COLUMN_TOTAL_COMPONENT_COUNT];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [self executeUpdate:query withParameterDictionary:row];
}

- (BOOL)updateEquipmentWithRow:(NSMutableDictionary *)row
{
    // Updates a record in the Equipment table, using the data in the dictionary supplied
    
    NSString *serialNumber = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER]];
    NSString *parentEquipmentId = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]];
    NSString *equipmentTypeId = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_ID]];
    NSString *manufacturerId = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_MANUFACTURER_ID]];
    NSString *commissionStatusId = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_ID]];
    NSString *unitLocation = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION]];
    NSString *unitReference = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE]];
    NSString *unitDescription = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_UNIT_DESCRIPTION]];
    NSString *floorId = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_FLOOR_ID]];
    NSString *roomAreaText = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_ROOM_AREA]];
    NSString *installedToRun = [row keyIsNotMissingNullOrEmpty:TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN]
    ? [[row objectForKey:TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN] boolValue] ? @"1" : @"0"
        : @"0";

    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = '%@', %@ = %@, %@ = 1 WHERE %@ = %@", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERIAL_NUMBER, serialNumber, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, parentEquipmentId, TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_ID, equipmentTypeId, TABLE_EQUIPMENT_COLUMN_MANUFACTURER_ID, manufacturerId, TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_ID, commissionStatusId, TABLE_EQUIPMENT_COLUMN_UNIT_LOCATION, [unitLocation withDoubleApostrophes], TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE, [unitReference withDoubleApostrophes], TABLE_EQUIPMENT_COLUMN_UNIT_DESCRIPTION, [unitDescription withDoubleApostrophes], TABLE_EQUIPMENT_COLUMN_FLOOR_ID, floorId, TABLE_EQUIPMENT_COLUMN_ROOM_AREA, [roomAreaText withDoubleApostrophes], TABLE_EQUIPMENT_COLUMN_INSTALLED_TO_RUN, installedToRun, TABLE_COMMON_REQUIRES_DATA_SYNC, TABLE_EQUIPMENT_COLUMN_ID, [row objectForKey:TABLE_EQUIPMENT_COLUMN_ID]];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [self executeUpdate:query];
}

- (NSArray *)searchEquipmentForEquipmentByServiceTag:(NSString *)searchText
{
    // Returns all equipment records from the Equipment table matching the search filter
    
    NSString *select = [self getEquipmentSelect];
    NSString *tables =  [self getEquipmentTables];
    NSString *where = [NSString stringWithFormat:@" (%@.%@ IS NULL OR LENGTH(%@.%@) = 0) AND LENGTH('%@') > 0 AND %@.%@ LIKE '%@%@%@' %@ ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, searchText, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, @"%", searchText, @"%",
            [self loggedInUserIsSubcontractor]
                 ? [NSString stringWithFormat:@" AND %@.%@ IN (%@) ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                 : @""
        ];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)searchEquipmentForComponentsByServiceTag:(NSString *)searchText
{
    // Returns all component records from the Equipment table matching the search filter
    
    NSString *select = [self getEquipmentSelect];
    NSString *tables =  [self getEquipmentTables];
    NSString *where = [NSString stringWithFormat:@" %@.%@ IS NOT NULL AND LENGTH(%@.%@) > 0 AND LENGTH('%@') > 0 AND %@.%@ LIKE '%@%@%@' %@ ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, searchText, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, @"%", searchText, @"%",
            [self loggedInUserIsSubcontractor]
                 ? [NSString stringWithFormat:@" AND pe.%@ IN (%@) ", TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                 : @""
        ];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (BOOL)assignEquipmentId:(NSNumber *)equipmentId forServiceTag:(NSString *)serviceTag
{
    // Updates all records in the Equipment and associated tables for the specified service tag, to give all the records the new specified unique identifier
    
    NSString *sql;
    NSNumber *oldEquipmentId = nil;
    BOOL result = YES;
    
    // Firstly, retrieve the old equipment id
    NSDictionary *equipment = [self getEquipmentByServiceTag:serviceTag filterByUserPermissions:NO];
    result = [equipment keyIsNotMissingOrNull:TABLE_EQUIPMENT_COLUMN_ID];
    if (result)
        oldEquipmentId = [NSNumber numberWithLongLong:[[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_ID] longLongValue]];
    
    // Update equipment record to give it a new id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, [equipmentId longLongValue], TABLE_EQUIPMENT_COLUMN_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    // Update child equipment records with the new equipment id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    // Update associated test session records with the new equipment id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    // Update associated site visit report equipment records with the new equipment id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    // Update associated document equipment records with the new equipment id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_DOCUMENT_EQUIPMENT, TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_DOCUMENT_EQUIPMENT_COLUMN_EQUIPMENT_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    // Update associated document site visit report records with the new equipment id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_DOCUMENT_SITE_VISIT_REPORT, TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    // Update associated equipment scan history records with the new equipment id
    if (result) {
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = %lld WHERE %@ = %lld", TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue], TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID, [oldEquipmentId longLongValue]];
        result = [self executeUpdate:sql];
    }
    
    return result;
}

- (NSArray *)requiresSyncDataForEquipment
{
    // Returns all records from the Equipment table that have not yet been synced up to the server
    
    NSMutableArray *allEquipment = [[NSMutableArray alloc] initWithArray: [self executeSelectAll:TABLE_EQUIPMENT withSelect:@"*" withWhere:[NSString stringWithFormat:@"%@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:[NSString stringWithFormat:@"%@ DESC", TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID]]];
    
    // Add separate dictionaries for the foreign keys
    for (NSMutableDictionary *equipment in allEquipment)
    {
        // Parent Equipment
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_PARENT_EQUIPMENT_ID];
        
        // Manufacturer
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_MANUFACTURER_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_MANUFACTURER_ID];
        
        // Floor
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_FLOOR_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_FLOOR_ID];
        
        // Equipment Type
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_EQUIPMENT_TYPE_ID];
        
        // Commission Status
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_COMMISSION_STATUS_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_COMMISSION_STATUS_ID];
        
        // Service Contract
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_SERVICE_CONTRACT_ID];

        // Branch
        [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_BRANCH_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_BRANCH_ID];
        
        // Created By
        if ([equipment keyIsNotMissingNullOrEmpty:TABLE_EQUIPMENT_COLUMN_CREATED_BY_ID])
            [equipment setObject:[equipment objectForKey:TABLE_EQUIPMENT_COLUMN_CREATED_BY_ID] forKey:JSON_EQUIPMENT_ATTRIBUTE_CREATED_BY_ID];
    }
    
    NSArray *returnArray = [NSArray arrayWithArray:allEquipment];
    [allEquipment release];
    
    return returnArray;
}

- (NSArray *)requiresSyncDataForEquipmentDocuments
{
    // Returns all Equipment Documents that have not yet been synced up to the server
    
    NSArray *documents = [self getDocumentsForEquipmentId:nil documentTypeName:nil qualityManagementSystemCode:nil filterForRequiresDataSync:YES withDatabase:nil];
    NSMutableArray *equipmentDocuments = [NSMutableArray array];
    
    // Build up sync object
    for (NSDictionary *document in documents)
    {
        NSMutableDictionary *equipmentDocument = [NSMutableDictionary dictionary];
        
        // Id
        [equipmentDocument setObject:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] forKey:TABLE_COMMON_ID];
        
        // Document
        [equipmentDocument setObject:document forKey:JSON_DOCUMENT];
        
        // Equipment
        @autoreleasepool {
            NSArray *equipment = [self getEquipmentForDocumentId:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID]];
            [equipmentDocument setObject:[equipment valueForKey:TABLE_EQUIPMENT_COLUMN_ID] forKey:JSON_EQUIPMENT_DOCUMENT_ATTRIBUTE_EQUIPMENT_IDS];
        }
        [equipmentDocuments addObject:equipmentDocument];
    }
    
    return [NSArray arrayWithArray:equipmentDocuments];
}

#pragma mark - Equipment Scan History

- (BOOL)addRowsToEquipmentScanHistory:(NSArray *)rows
{
    // Inserts a number of records into the EquipmentScanHistory table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        for (NSDictionary *row in rows)
        {
            if (![self addRowToEquipmentScanHistory:row withDatabase:database])
            {
                self.successFlag = NO;
                break;
            }
        }
    }];
    
    return self.successFlag;
}

- (BOOL)addRowToEquipmentScanHistory:(NSDictionary *)row withDatabase:(FMDatabase *)database
{
    // Inserts a record into the EquipmentScanHistory table, using the data in the dictionary supplied
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_DATE_TIME];
    BOOL result = [database executeUpdate:query withParameterDictionary:row];
    return result;
}

- (NSArray *)getEquipmentScanHistory
{
    // Returns all records from the EquipmentScanHistory table
    
    return [self executeSelectAll:TABLE_EQUIPMENT_SCAN_HISTORY withSelect:@"*" withWhere:nil withOrderBy:nil];
}

- (NSArray *)getEquipmentScanHistoryForEquipment
{
    // Returns all records from the EquipmentScanHistory table for equipment items
    
    NSString *select = [NSString stringWithFormat:@"%@, %@.*", [self getEquipmentSelect], TABLE_EQUIPMENT_SCAN_HISTORY];
    NSString *tables =  [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@", [self getEquipmentTables], TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID];
    NSString *where = [NSString stringWithFormat:@" (%@.%@ IS NULL OR LENGTH(%@.%@) = 0) %@ ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID,
            [self loggedInUserIsSubcontractor]
                 ? [NSString stringWithFormat:@" AND %@.%@ IN (%@) ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                 : @""
        ];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getEquipmentScanHistoryForComponents
{
    // Returns all records from the EquipmentScanHistory table for components
    
    NSString *select = [NSString stringWithFormat:@"%@, %@.*", [self getEquipmentSelect], TABLE_EQUIPMENT_SCAN_HISTORY];
    NSString *tables =  [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@", [self getEquipmentTables], TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID];
    NSString *where = [NSString stringWithFormat:@" %@.%@ IS NOT NULL AND LENGTH(%@.%@) > 0 %@ ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID,
            [self loggedInUserIsSubcontractor]
                 ? [NSString stringWithFormat:@" AND pe.%@ IN (%@) ", TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                 : @""
        ];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getEquipmentScanHistoryForBranchId:(NSNumber *)branchId
{
    // Returns the record from the EquipmentScanHistory table matching the filter on the Equipment table Branch_id field
    
    NSString *select = [NSString stringWithFormat:@"%@, %@.*", [self getEquipmentSelect], TABLE_EQUIPMENT_SCAN_HISTORY];
    NSString *tables =  [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@", [self getEquipmentTables], TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID];
    NSString *where = [NSString stringWithFormat:@" (%@.%@ IS NULL OR LENGTH(%@.%@) = 0) AND %@.%@ = %li", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_PARENT_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_BRANCH_ID, (long)[branchId integerValue]];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (BOOL)addEquipmentToEquipmentScanHistory:(NSNumber *)equipmentId
{
    // Updates or inserts a record into the EquipmentScanHistory table using the value supplied
    
    NSString *dateNow = [[NSDate date] toLongDateTimeUtcString];
    NSString *query;
    
    if ([self equipmentIdExistsInEquipmentScanHistory:equipmentId])
        query = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ = %lld", TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_DATE_TIME, dateNow, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]];
    else
        query = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@) VALUES (%lld, '%@')", TABLE_EQUIPMENT_SCAN_HISTORY, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_DATE_TIME, [equipmentId longLongValue], dateNow];
    
    BOOL result = [self executeUpdate:query];
    return result;
}

- (void)deleteEquipmentScanHistory
{
    // Deletes all records from the EquipmentScanHistory table
    
    [self executeDelete:TABLE_EQUIPMENT_SCAN_HISTORY withWhere:nil];
}

- (BOOL)equipmentIdExistsInEquipmentScanHistory:(NSNumber *)equipmentId
{
    // Returns true or false indicating whether the Equipment Id supplied has an entry in the EquipmentScanHistory table
    
    NSString *where = [NSString stringWithFormat:@" %@ = %lld ", TABLE_EQUIPMENT_SCAN_HISTORY_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]];
    return ([self executeCount:TABLE_EQUIPMENT_SCAN_HISTORY withWhere:where] == 0) ? NO : YES;
}

#pragma mark - Equipment Type

- (NSArray *)getEquipmentTypes
{
    // Returns all records from the EquipmentType table
    
    return [self executeSelectAll:TABLE_EQUIPMENT_TYPE withSelect:@"*" withWhere:nil withOrderBy:[NSString stringWithFormat:@"%@ ASC", TABLE_EQUIPMENT_TYPE_COLUMN_NAME]];
}

#pragma mark - Floor

- (NSArray *)getFloors
{
    // Returns all records from the Floor table
    
    return [self executeSelectAll:TABLE_FLOOR withSelect:@"*" withWhere:nil withOrderBy:[NSString stringWithFormat:@"%@ ASC", TABLE_FLOOR_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getFloorById:(NSNumber *)floorId
{
    // Returns the record from the Floor table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"%@ = %li", TABLE_FLOOR_COLUMN_ID, (long)[floorId integerValue]];
    return [self executeSelectSingle:TABLE_FLOOR withSelect:@"*" withWhere:where];
}

#pragma mark - IBAR Installation Joint Test Metadata

- (NSDictionary *)getIbarInstallationJointTestMetadataById:(NSString *)ibarInstallationJointTestMetadataId
{
    // Returns all records from the IbarInstallationJointTestMetadata table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID, [ibarInstallationJointTestMetadataId uppercaseString]];
    
    return [self executeSelectSingle:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA withSelect:@"*" withWhere:where];
}

- (NSArray *)getIbarInstallationJointTestMetadatasForTestSessionId:(NSString *)testSessionId
{
    // Returns all records from the IbarInstallationJointTestMetadata table matching the filter on the TestSession_id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    
    return [self executeSelectAll:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA withSelect:@"*" withWhere:where withOrderBy:nil];
}

- (DataWrapper *)createIbarInstallationJointTestMetadataWithRow:(NSMutableDictionary *)row
{
    // Inserts a record into the IbarInstallationJointTestMetadata table, using the data in the dictionary supplied
    
    // Assign an Id to the Ibar installation joint test metadata if it does not already have one
    NSString *uuid = ([row keyIsNotMissingNullOrEmpty:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID])
        ? [row valueForKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID]
        : [[NSString stringWithUUID] lowercaseString];

    // Set null values for any required fields that are currently missing
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BELLEVILLE_WASHERS_SEATED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUT_OUTER_HEADS_SHEARED_OFF,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUTS_MARKED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COVERS_INSTALLED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BOLTS_TORQUE_CHECKED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TORQUE_WRENCH_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COMMENTS,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@)",
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA,
                       uuid,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BELLEVILLE_WASHERS_SEATED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUT_OUTER_HEADS_SHEARED_OFF,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUTS_MARKED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COVERS_INSTALLED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BOLTS_TORQUE_CHECKED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TORQUE_WRENCH_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COMMENTS
                       ];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getIbarInstallationJointTestMetadataById:uuid];

    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (DataWrapper *)updateIbarInstallationJointTestMetadataWithRow:(NSMutableDictionary *)row
{
    // Updates a record in the IbarInstallationJointTestMetadata table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BELLEVILLE_WASHERS_SEATED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUT_OUTER_HEADS_SHEARED_OFF,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUTS_MARKED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COVERS_INSTALLED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BOLTS_TORQUE_CHECKED,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TORQUE_WRENCH_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COMMENTS,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@ WHERE %@ = :%@",
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BELLEVILLE_WASHERS_SEATED, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BELLEVILLE_WASHERS_SEATED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUT_OUTER_HEADS_SHEARED_OFF, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUT_OUTER_HEADS_SHEARED_OFF,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUTS_MARKED, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_NUTS_MARKED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COVERS_INSTALLED, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COVERS_INSTALLED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BOLTS_TORQUE_CHECKED, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_BOLTS_TORQUE_CHECKED,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TORQUE_WRENCH_ID_NUMBER, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TORQUE_WRENCH_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_EARTH,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_NEUTRAL_2,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L1,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L2,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_RESISTANCE_MICROOHMS_PHASE_L3,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COMMENTS, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_COMMENTS,
                       TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID
                       ];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getIbarInstallationJointTestMetadataById:[row objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]];

    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

#pragma mark - IBAR Installation Test Metadata

- (NSDictionary *)getIbarInstallationTestMetadataById:(NSString *)ibarInstallationTestMetadataId
{
    // Returns all records from the IbarInstallationTestMetadata table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID, [ibarInstallationTestMetadataId uppercaseString]];
    
    return [self executeSelectSingle:TABLE_IBAR_INSTALLATION_TEST_METADATA withSelect:@"*" withWhere:where];
}

- (NSArray *)getIbarInstallationTestMetadatasForTestSessionId:(NSString *)testSessionId
{
    // Returns all records from the IbarInstallationTestMetadata table matching the filter on the TestSession_id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    
    return [self executeSelectAll:TABLE_IBAR_INSTALLATION_TEST_METADATA withSelect:@"*" withWhere:where withOrderBy:nil];
}

- (DataWrapper *)createIbarInstallationTestMetadataWithRow:(NSMutableDictionary *)row
{
    // Inserts a record into the IbarInstallationTestMetadata table, using the data in the dictionary supplied
    
    // Assign an Id to the Ibar installation test metadata if it does not already have one
    NSString *uuid = ([row keyIsNotMissingNullOrEmpty:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID])
        ? [row valueForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]
        : [[NSString stringWithUUID] lowercaseString];

    // Set null values for any required fields that are currently missing
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ADJOINING_SECTIONS_LEVEL,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_INSTALLED,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_JOINTS_INSTALLED,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COVERS_SECURELY_INSTALLED,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COMMENTS,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@)",
                       TABLE_IBAR_INSTALLATION_TEST_METADATA,
                       uuid,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ADJOINING_SECTIONS_LEVEL,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_INSTALLED,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_JOINTS_INSTALLED,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COVERS_SECURELY_INSTALLED,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COMMENTS
                       ];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getIbarInstallationTestMetadataById:uuid];

    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (DataWrapper *)updateIbarInstallationTestMetadataWithRow:(NSMutableDictionary *)row
{
    // Updates a record in the IbarInstallationTestMetadata table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ADJOINING_SECTIONS_LEVEL,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_INSTALLED,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_JOINTS_INSTALLED,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COVERS_SECURELY_INSTALLED,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER,
                      TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COMMENTS,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@ WHERE %@ = :%@",
                       TABLE_IBAR_INSTALLATION_TEST_METADATA,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ADJOINING_SECTIONS_LEVEL, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ADJOINING_SECTIONS_LEVEL,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_INSTALLED, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_INSTALLED,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_SUPPORT_BRACKETS_FIXING_BOLTS_SECURE,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_JOINTS_INSTALLED, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_JOINTS_INSTALLED,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COVERS_SECURELY_INSTALLED, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COVERS_SECURELY_INSTALLED,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DUCTOR_TEST_INSTRUMENT_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_E,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_N,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_PE_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_N,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_E_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_N_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L1_TO_L2,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L2_TO_L3,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_RESULT_MEGAOHMS_L3_TO_L1,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_INSULATION_RESISTANCE_TEST_INSTRUMENT_ID_NUMBER,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COMMENTS, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_COMMENTS,
                       TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID
                       ];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getIbarInstallationTestMetadataById:[row objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]];

    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

#pragma mark - IBAR Installation Test Metadata Continuity Run Ductor Test

- (NSDictionary *)getIbarInstallationTestMetadataContinuityRunDuctorTestById:(NSString *)ibarInstallationTestMetadataContinuityRunDuctorTestId
{
    // Returns all records from the IbarInstallationTestMetadataContinuityRunDuctorTest table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID, [ibarInstallationTestMetadataContinuityRunDuctorTestId uppercaseString]];
    
    return [self executeSelectSingle:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST withSelect:@"*" withWhere:where];
}

- (NSArray *)getIbarInstallationTestMetadataContinuityRunDuctorTestsForIbarInstallationTestMetadataId:(NSString *)ibarInstallationTestMetadataId
{
    // Returns all records from the IbarInstallationTestMetadataContinuityRunDuctorTest table matching the filter on the IbarInstallationTestMetadata_id field
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID, [ibarInstallationTestMetadataId uppercaseString]];
    NSString *orderBy = [NSString stringWithFormat:@" %@ ASC", TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_FROM];
    
    return [self executeSelectAll:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST withSelect:@"*" withWhere:where withOrderBy:orderBy];
}

- (DataWrapper *)createIbarInstallationTestMetadataContinuityRunDuctorTestWithRow:(NSMutableDictionary *)row
{
        // Inserts a record into the IbarInstallationTestMetadataContinuityRunDuctorTest table, using the data in the dictionary supplied
        
        // Assign an Id to the Ibar installation test metadata ductor test if it does not already have one
        NSString *uuid = ([row keyIsNotMissingNullOrEmpty:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID])
            ? [row valueForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID]
            : [[NSString stringWithUUID] lowercaseString];
    
        // Set null values for any required fields that are currently missing
        NSArray *keys = [[[NSArray alloc] initWithObjects:
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_FROM,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_TO,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1_RESULT_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2_RESULT_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3_RESULT_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4_RESULT_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5_RESULT_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6_RESULT_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7_LINK_MILLIOHMS,
                          TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7_RESULT_MILLIOHMS,
                          nil] autorelease];
        row = [row addNullValuesForKeys:keys];
        
        NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@)",
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST,
                           uuid,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_FROM,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_TO,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_1_RESULT_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_2_RESULT_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_3_RESULT_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_4_RESULT_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_5_RESULT_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_6_RESULT_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7_LINK_MILLIOHMS,
                           TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_CONDUCTOR_PAIR_7_RESULT_MILLIOHMS
                           ];
        BOOL result = [self executeUpdate:query withParameterDictionary:row];
        NSDictionary *data = [self getIbarInstallationTestMetadataContinuityRunDuctorTestById:uuid];
    
        return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (BOOL)deleteIbarInstallationTestMetadataContinuityRunDuctorTestsForIbarInstallationTestMetadataId:(NSString *)ibarInstallationTestMetadataId
{
        // Deletes all records from the IbarInstallationTestMetadataContinuityRunDuctorTest table matching the filter on the IbarInstallationTestMetadata_id field
    
        NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID, [ibarInstallationTestMetadataId uppercaseString]];
        return [self executeDelete:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST withWhere:where];
}

#pragma mark - Organisation

- (NSArray *)getOrganisations
{
    // Returns all records from the Organisation table
    
    return [self executeSelectAll:TABLE_ORGANISATION withSelect:@"*" withWhere:nil withOrderBy:[NSString stringWithFormat:@"%@ ASC", TABLE_ORGANISATION_COLUMN_NAME]];
}

#pragma mark - Registered User

- (BOOL)addRowsToRegisteredUsers:(NSArray *)rows
{
    // Inserts a number of records into the RegisteredUser table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        for (NSDictionary *row in rows)
        {
            // If a registered user wants to register again ... knock yourself out
            if (![self deleteRegisteredUser:[row objectForKey:TABLE_REGISTERED_USER_COLUMN_USER_NAME] withDatabase:database])
            {
                self.successFlag = NO;
                break;
            }
            
            if (![self addRowToRegisteredUsers:row withDatabase:database])
            {
                self.successFlag = NO;
                break;
            }
        }
    }];
    
    return self.successFlag;
}

- (BOOL)addRowToRegisteredUsers:(NSDictionary *)row withDatabase:(FMDatabase *)database
{
    // Inserts a record into the RegisteredUser table, using the data in the dictionary supplied
    
    // Create UUID value
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[[NSString stringWithUUID] lowercaseString], TABLE_REGISTERED_USER_COLUMN_ID, nil];
    [parameters addEntriesFromDictionary:row];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@)", TABLE_REGISTERED_USER, TABLE_REGISTERED_USER_COLUMN_ID, TABLE_REGISTERED_USER_COLUMN_USER_NAME];
    BOOL result = [database executeUpdate:query withParameterDictionary:parameters];
    [parameters release];
    return result;
}

- (NSArray *)getRegisteredUsers
{
    // Returns all records from the RegisteredUser table
    
    NSString *orderBy = [NSString stringWithFormat:@" %@ ASC ", TABLE_REGISTERED_USER_COLUMN_USER_NAME];
    return [self executeSelectAll:TABLE_REGISTERED_USER withSelect:@"*" withWhere:nil withOrderBy:orderBy];
}

- (BOOL)deleteRegisteredUser:(NSString *)username withDatabase:(FMDatabase *)database
{
    // Deletes a record from the RegisteredUser table matching the filter on the Username field
    
    BOOL result;
    
    NSString *where = [NSString stringWithFormat:@"%@ = '%@'", TABLE_REGISTERED_USER_COLUMN_USER_NAME, username];
    
    if (database == nil)
        result = [self executeDelete:TABLE_REGISTERED_USER withWhere:where];
    else
        result = [self executeDelete:TABLE_REGISTERED_USER withWhere:where withDatabase:database];
    
    return result;
}

#pragma mark - Service Contract

- (NSArray *)getDistinctServiceContractNumbers
{
    // Returns all unique service contract numbers from the ServiceContract table
    
    return [self executeSelectAll:TABLE_SERVICE_CONTRACT withSelect:[NSString stringWithFormat:@"DISTINCT %@.%@", TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER] withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER]];
}

- (NSArray *)searchServiceContractByEmNumber:(NSString *)searchText
{
    // Returns all records from the ServiceContract table matching the search filter
    
    NSString *select = [NSString stringWithFormat:@"DISTINCT %@.%@, %@.*", TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER, TABLE_BRANCH];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@ INNER JOIN %@ ON %@.%@ = %@.%@", TABLE_SERVICE_CONTRACT, TABLE_BRANCH_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_ID, TABLE_BRANCH_SERVICE_CONTRACT, TABLE_BRANCH_SERVICE_CONTRACT_COLUMN_SERVICE_CONTRACT_ID, TABLE_BRANCH, TABLE_BRANCH_SERVICE_CONTRACT, TABLE_BRANCH_SERVICE_CONTRACT_COLUMN_BRANCH_ID, TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID];
    NSString *where = [NSString stringWithFormat:@" LENGTH('%@') > 0 AND %@.%@ LIKE '%@%@%@' AND %@ ", searchText, TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER, @"%", searchText, @"%", [self getSubcontractorBlockingFilterForLoggedInUser]];
    NSString *orderBy = [NSString stringWithFormat:@" %@.%@ ASC", TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

#pragma mark - Site Time Log

- (NSString *)getSiteTimeLogSelect
{
    // Returns the SELECT part of the standard SQL SELECT query for SiteTimeLog
    
    return [NSString stringWithFormat:@"DISTINCT %@.*, %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@', %@.%@ AS '%@'",
            TABLE_SITE_TIME_LOG,
            TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME, TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_NAME,
            TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_NAME, TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_NAME,
            TABLE_COUNTRY, TABLE_COUNTRY_COLUMN_NAME, TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_NAME,
            TABLE_COUNTRY, TABLE_COUNTRY_COLUMN_ISO2_ALPHA, TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ISO2_ALPHA,
            TABLE_BRANCH, TABLE_BRANCH_COLUMN_NAME, TABLE_SITE_TIME_LOG_COLUMN_SITE_NAME,
            TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_WO_NUMBER, TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_WO_NUMBER,
            TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_PROJECT_NAME, TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_PROJECT_NAME,
            TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_SERVICE_TAG_NUMBER
            ];
}

- (NSString *)getSiteTimeLogTables
{
    // Returns the FROM part of the standard SQL SELECT query for SiteTimeLog

    return [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@ INNER JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@",
            TABLE_SITE_TIME_LOG,
            TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID, TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_ID,
            TABLE_ENGINEER, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID, TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_ID,
            TABLE_COUNTRY, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID, TABLE_COUNTRY, TABLE_COUNTRY_COLUMN_ID,
            TABLE_BRANCH, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_SITE_ID, TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID,
            TABLE_WORKS_ORDER, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_ID,
            TABLE_EQUIPMENT, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID
            ];
}

- (NSDictionary *)getSiteTimeLogById:(NSString *)siteTimeLogId
{
    // Returns the record from the SiteTimeLog table matching the filter on the Id field
    
    NSString *select = [self getSiteTimeLogSelect];
    NSString *tables = [self getSiteTimeLogTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_ID, [siteTimeLogId uppercaseString]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getSiteTimeLogsForEngineerId:(NSNumber *)engineerId
{
    // Returns all records from the SiteTimeLog table matching the filter on the Engineer_id field
    
    NSString *select = [self getSiteTimeLogSelect];
    NSString *tables = [self getSiteTimeLogTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = %ld", TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_ID, (long)[engineerId integerValue]];
    NSString *orderBy = [NSString stringWithFormat:@"REPLACE(IFNULL(%@.%@, %@.%@), 'T', ' ') DESC", TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_FINISH_DATE_TIME_UTC];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getCountryArrivalSiteTimeLogsByDateDescendingForEngineerId:(NSNumber *)engineerId
{
    // Returns all records from the SiteTimeLog table matching the filter on the Engineer_id field
    
    NSString *select = [self getSiteTimeLogSelect];
    NSString *tables = [self getSiteTimeLogTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = '%@' AND %@.%@ IS NOT NULL AND %@.%@ = %ld", TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME_VALUE_COUNTRY_VISIT, TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC, TABLE_ENGINEER, TABLE_ENGINEER_COLUMN_ID, (long)[engineerId integerValue]];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ DESC", TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (DataWrapper *)createSiteTimeLogWithRow:(NSMutableDictionary *)row
{
    // Inserts a record into the SiteTimeLog table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_SITE_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC,
                      TABLE_SITE_TIME_LOG_COLUMN_FINISH_DATE_TIME_UTC,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, 1, 1)", TABLE_SITE_TIME_LOG, TABLE_SITE_TIME_LOG_COLUMN_ID, TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID, TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID, TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID, TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID, TABLE_SITE_TIME_LOG_COLUMN_SITE_ID, TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID, TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC, TABLE_SITE_TIME_LOG_COLUMN_FINISH_DATE_TIME_UTC];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getSiteTimeLogById:[row nullableObjectForKey:TABLE_SITE_TIME_LOG_COLUMN_ID]];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (DataWrapper *)updateSiteTimeLogWithRow:(NSMutableDictionary *)row
{
    // Updates a record in the SiteTimeLog table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_SITE_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID,
                      TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC,
                      TABLE_SITE_TIME_LOG_COLUMN_FINISH_DATE_TIME_UTC,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = 1 WHERE %@ = :%@",
                       TABLE_SITE_TIME_LOG,
                       TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID, TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID,
                       TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID, TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID,
                       TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID, TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID,
                       TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID, TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID,
                       TABLE_SITE_TIME_LOG_COLUMN_SITE_ID, TABLE_SITE_TIME_LOG_COLUMN_SITE_ID,
                       TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID, TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID,
                       TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC, TABLE_SITE_TIME_LOG_COLUMN_START_DATE_TIME_UTC,
                       TABLE_SITE_TIME_LOG_COLUMN_FINISH_DATE_TIME_UTC, TABLE_SITE_TIME_LOG_COLUMN_FINISH_DATE_TIME_UTC,
                       TABLE_COMMON_REQUIRES_DATA_SYNC,
                       TABLE_SITE_TIME_LOG_COLUMN_ID, TABLE_SITE_TIME_LOG_COLUMN_ID];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getSiteTimeLogById:[row objectForKey:TABLE_SITE_TIME_LOG_COLUMN_ID]];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (NSArray *)requiresSyncDataForSiteTimeLogs
{
    // Returns all records from the SiteTimeLog table that have not yet been synced up to the server
    
    NSMutableArray *allSiteTimeLogs = [[NSMutableArray alloc] initWithArray: [self executeSelectAll:TABLE_SITE_TIME_LOG withSelect:@"*" withWhere:[NSString stringWithFormat:@"%@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:nil]];
    
    // Add separate dictionaries for the foreign keys
    for (NSMutableDictionary *siteTimeLog in allSiteTimeLogs)
    {
        // Site Time Log Type
        [siteTimeLog setObject:[siteTimeLog objectForKey:TABLE_SITE_TIME_LOG_COLUMN_SITE_TIME_LOG_TYPE_ID] forKey:JSON_SITE_TIME_LOG_ATTRIBUTE_SITE_TIME_LOG_TYPE_ID];
        
        // Engineer
        [siteTimeLog setObject:[siteTimeLog objectForKey:TABLE_SITE_TIME_LOG_COLUMN_ENGINEER_ID] forKey:JSON_SITE_TIME_LOG_ATTRIBUTE_EMPLOYEE_ID];
        
        // Country
        if ([siteTimeLog keyIsNotMissingNullOrEmpty:TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID])
            [siteTimeLog setObject:[siteTimeLog objectForKey:TABLE_SITE_TIME_LOG_COLUMN_COUNTRY_ID] forKey:JSON_SITE_TIME_LOG_ATTRIBUTE_COUNTRY_ID];

        // Works Order
        if ([siteTimeLog keyIsNotMissingNullOrEmpty:TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID])
            [siteTimeLog setObject:[siteTimeLog objectForKey:TABLE_SITE_TIME_LOG_COLUMN_WORKS_ORDER_ID] forKey:JSON_SITE_TIME_LOG_ATTRIBUTE_WORKS_ORDER_ID];

        // Site
        if ([siteTimeLog keyIsNotMissingNullOrEmpty:TABLE_SITE_TIME_LOG_COLUMN_SITE_ID])
            [siteTimeLog setObject:[siteTimeLog objectForKey:TABLE_SITE_TIME_LOG_COLUMN_SITE_ID] forKey:JSON_SITE_TIME_LOG_ATTRIBUTE_SITE_ID];

        // Equipment
        if ([siteTimeLog keyIsNotMissingNullOrEmpty:TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID])
            [siteTimeLog setObject:[siteTimeLog objectForKey:TABLE_SITE_TIME_LOG_COLUMN_EQUIPMENT_ID] forKey:JSON_SITE_TIME_LOG_ATTRIBUTE_EQUIPMENT_ID];
    }
    
    NSArray *returnArray = [NSArray arrayWithArray:allSiteTimeLogs];
    [allSiteTimeLogs release];
    
    return returnArray;
}

#pragma mark - Site Time Log Type

- (NSString *)getSiteTimeLogTypeSelect
{
    // Returns the SELECT part of the standard SQL SELECT query for SiteTimeLogType
    
    return [NSString stringWithFormat:@"DISTINCT %@.*, %@.%@ AS '%@'",
            TABLE_SITE_TIME_LOG_TYPE,
            TABLE_SITE_TIME_LOG_TYPE_CATEGORY, TABLE_SITE_TIME_LOG_TYPE_CATEGORY_COLUMN_NAME, TABLE_SITE_TIME_LOG_TYPE_COLUMN_SITE_TIME_LOG_TYPE_CATEGORY_NAME
            ];
}

- (NSString *)getSiteTimeLogTypeTables
{
    // Returns the FROM part of the standard SQL SELECT query for SiteTimeLogType

    return [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@",
            TABLE_SITE_TIME_LOG_TYPE,
            TABLE_SITE_TIME_LOG_TYPE_CATEGORY, TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_SITE_TIME_LOG_TYPE_CATEGORY_ID, TABLE_SITE_TIME_LOG_TYPE_CATEGORY, TABLE_SITE_TIME_LOG_TYPE_CATEGORY_COLUMN_ID
            ];
}

- (NSArray *)getSiteTimeLogTypesForAdditionalProjectTime
{
    // Returns all records from the SiteTimeLogType table relevant to the 'Additional Project Type' selection
    
    NSString *select = [self getSiteTimeLogTypeSelect];
    NSString *tables = [self getSiteTimeLogTypeTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = '%@' AND %@.%@ NOT IN ('%@')", TABLE_SITE_TIME_LOG_TYPE_CATEGORY, TABLE_SITE_TIME_LOG_TYPE_CATEGORY_COLUMN_NAME, TABLE_SITE_TIME_LOG_TYPE_CATEGORY_COLUMN_NAME_VALUE_PROJECT_TIME, TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME_VALUE_SERVICE];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ ASC", TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_SORT_ORDER];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getSiteTimeLogTypesForNonProjectTime
{
    // Returns all records from the SiteTimeLogType table relevant to the 'Non-Project Type' selection
    
    NSString *select = [self getSiteTimeLogTypeSelect];
    NSString *tables = [self getSiteTimeLogTypeTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = '%@' AND %@.%@ NOT IN ('%@', '%@')", TABLE_SITE_TIME_LOG_TYPE_CATEGORY, TABLE_SITE_TIME_LOG_TYPE_CATEGORY_COLUMN_NAME, TABLE_SITE_TIME_LOG_TYPE_CATEGORY_COLUMN_NAME_VALUE_NON_PROJECT_TIME, TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME_VALUE_COUNTRY_VISIT, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME_VALUE_SITE_ATTENDANCE];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ ASC", TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_SORT_ORDER];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSDictionary *)getSiteTimeLogTypeByName:(NSString *)siteTimeLogTypeName
{
    // Returns the record from the SiteTimeLogType table matching the filter on the Name field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_SITE_TIME_LOG_TYPE, TABLE_SITE_TIME_LOG_TYPE_COLUMN_NAME, [siteTimeLogTypeName uppercaseString]];
    return [self executeSelectSingle:[self getSiteTimeLogTypeTables] withSelect:[self getSiteTimeLogTypeSelect] withWhere:where];
}

- (BOOL)deleteSiteTimeLogById:(NSString *)siteTimeLogId
{
    // Deletes a record from the SiteTimeLog table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_SITE_TIME_LOG_COLUMN_ID, [siteTimeLogId uppercaseString]];
    return [self executeDelete:TABLE_SITE_TIME_LOG withWhere:where];
}

#pragma mark - Site Visit Report

- (NSString *)getSiteVisitReportSelect
{
    // Returns the SELECT part of the standard SQL SELECT query for SiteVisitReport
    
    return [NSString stringWithFormat:@"DISTINCT %@.*, %@.%@ AS '%@', e1.%@ AS '%@', e2.%@ AS '%@', %@.%@ ||' '|| %@.%@ AS '%@', %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@",
            TABLE_SITE_VISIT_REPORT,
            TABLE_SITE_VISIT_REPORT_TYPE, TABLE_SITE_VISIT_REPORT_TYPE_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_NAME,
            TABLE_ENGINEER_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_NAME,
            TABLE_ENGINEER_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_NAME,
            TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_FORENAME, TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_SURNAME, TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_NAME,
            TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_NAME,
            TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_EM_NUMBER, TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_EM_NUMBER,
            TABLE_BRANCH, TABLE_BRANCH_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_NAME];
}

- (NSString *)getSiteVisitReportTables
{
    // Returns the FROM part of the standard SQL SELECT query for SiteVisitReport
    
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ e1 ON %@.%@ = e1.%@ LEFT JOIN %@ e2 ON %@.%@ = e2.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ ",
            TABLE_SITE_VISIT_REPORT,
            TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_ID, TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_SITE_VISIT_REPORT_ID,
            TABLE_SITE_VISIT_REPORT_TYPE, TABLE_SITE_VISIT_REPORT_TYPE, TABLE_SITE_VISIT_REPORT_TYPE_COLUMN_ID, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_ID,
            TABLE_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID,
            TABLE_ENGINEER, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID, TABLE_ENGINEER_COLUMN_ID,
            TABLE_ENGINEER, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID, TABLE_ENGINEER_COLUMN_ID,
            TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID, TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ID,
            TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID, TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_ID,
            TABLE_BRANCH, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID, TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID,
            TABLE_SERVICE_CONTRACT, TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID, TABLE_SERVICE_CONTRACT, TABLE_SERVICE_CONTRACT_COLUMN_ID];
}

- (NSDictionary *)getSiteVisitReportById:(NSString *)siteVisitReportId
{
    // Returns the record from the SiteVisitReport table matching the filter on the Id field
    
    NSString *select = [self getSiteVisitReportSelect];
    NSString *tables = [self getSiteVisitReportTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_ID, [siteVisitReportId uppercaseString]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getSiteVisitReportsForEquipmentId:(NSNumber *)equipmentId
{
    // Returns all records from the SiteVisitReport table, that have associated Equipment matching the filter on the Id field
    
    NSString *select = [self getSiteVisitReportSelect];
    NSString *tables = [self getSiteVisitReportTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = %lld AND %@ ", TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID, [equipmentId longLongValue], [self getSubcontractorBlockingFilterForLoggedInUser]];
    NSString *orderBy = [NSString stringWithFormat:@"%@ DESC", TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getSiteVisitReportsForBranchId:(NSNumber *)branchId
{
    // Returns all records from the SiteVisitReport table matching the filter on the Branch_id field
    
    NSString *select = [self getSiteVisitReportSelect];
    NSString *tables = [self getSiteVisitReportTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = %ld AND %@ ", TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID, (long)[branchId integerValue], [self getSubcontractorBlockingFilterForLoggedInUser]];
    NSString *orderBy = [NSString stringWithFormat:@"%@ DESC", TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (DataWrapper *)createSiteVisitReportWithRow:(NSMutableDictionary *)row
{
    // Inserts a record into the SiteVisitReport table, using the data in the dictionary supplied
    
    // Set record creation date
    [row setObject:[NSDate date] forKey:TABLE_SITE_VISIT_REPORT_COLUMN_CREATION_DATE];
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_SITE_VISIT_REPORT_COLUMN_JOBS_OUTSTANDING,
                      TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM,
                      TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_TO,
                      TABLE_SITE_VISIT_REPORT_COLUMN_WORK_COMPLETED,
                      TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SCOPE_OF_WORKS,
                      TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGN_OFF_DATE,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SIGN_OFF_DATE,
                      TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, 1, 1)", TABLE_SITE_VISIT_REPORT, TABLE_SITE_VISIT_REPORT_COLUMN_ID, TABLE_SITE_VISIT_REPORT_COLUMN_CREATION_DATE, TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID, TABLE_SITE_VISIT_REPORT_COLUMN_SCOPE_OF_WORKS, TABLE_SITE_VISIT_REPORT_COLUMN_WORK_COMPLETED, TABLE_SITE_VISIT_REPORT_COLUMN_JOBS_OUTSTANDING, TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM, TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_TO, TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID, TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_ID, TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGN_OFF_DATE, TABLE_SITE_VISIT_REPORT_COLUMN_SIGN_OFF_DATE, TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID, TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID, TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID, TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getSiteVisitReportById:[row nullableObjectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ID]];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (DataWrapper *)updateSiteVisitReportWithRow:(NSMutableDictionary *)row
{
    // Updates a record in the SiteVisitReport table, using the data in the dictionary supplied
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_SITE_VISIT_REPORT_COLUMN_JOBS_OUTSTANDING,
                      TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM,
                      TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_TO,
                      TABLE_SITE_VISIT_REPORT_COLUMN_WORK_COMPLETED,
                      TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SCOPE_OF_WORKS,
                      TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGN_OFF_DATE,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SIGN_OFF_DATE,
                      TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID,
                      TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = 1 WHERE %@ = :%@",
                       TABLE_SITE_VISIT_REPORT,
                       TABLE_SITE_VISIT_REPORT_COLUMN_CREATION_DATE, TABLE_SITE_VISIT_REPORT_COLUMN_CREATION_DATE,
                       TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID, TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID,
                       TABLE_SITE_VISIT_REPORT_COLUMN_SCOPE_OF_WORKS, TABLE_SITE_VISIT_REPORT_COLUMN_SCOPE_OF_WORKS,
                       TABLE_SITE_VISIT_REPORT_COLUMN_WORK_COMPLETED, TABLE_SITE_VISIT_REPORT_COLUMN_WORK_COMPLETED,
                       TABLE_SITE_VISIT_REPORT_COLUMN_JOBS_OUTSTANDING, TABLE_SITE_VISIT_REPORT_COLUMN_JOBS_OUTSTANDING,
                       TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM, TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM,
                       TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_TO, TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_TO,
                       TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID, TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID,
                       TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_ID, TABLE_SITE_VISIT_REPORT_COLUMN_TYPE_ID,
                       TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGN_OFF_DATE, TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGN_OFF_DATE,
                       TABLE_SITE_VISIT_REPORT_COLUMN_SIGN_OFF_DATE, TABLE_SITE_VISIT_REPORT_COLUMN_SIGN_OFF_DATE,
                       TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID, TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID,
                       TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID, TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID,
                       TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID, TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID,
                       TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID, TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID,
                       TABLE_COMMON_REQUIRES_DATA_SYNC,
                       TABLE_SITE_VISIT_REPORT_COLUMN_ID, TABLE_SITE_VISIT_REPORT_COLUMN_ID];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getSiteVisitReportById:[row objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ID]];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (BOOL)deleteSiteVisitReportById:(NSString *)siteVisitReportId
{
    // Deletes a record from the SiteVisitReport table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_SITE_VISIT_REPORT_COLUMN_ID, [siteVisitReportId uppercaseString]];
    return [self executeDelete:TABLE_SITE_VISIT_REPORT withWhere:where];
}

- (NSArray *)searchSiteVisitReportByStatusConsolidatedName:(NSString *)statusConsolidatedName engineerId:(NSNumber *)engineerId serviceContractNumber:(NSNumber *)serviceContractNumber
{
    // Returns all records from the SiteVisitReport table matching the search filter
    
    NSString *select = [[[NSString alloc] initWithFormat:@"%@, %@.%@ AS %@", [self getSiteVisitReportSelect],  TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CONSOLIDATED_NAME, TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_CONSOLIDATED_NAME] autorelease];
    
    NSString *tables =  [self getSiteVisitReportTables];
    NSString *orderBy = [NSString stringWithFormat:@" %@ DESC", TABLE_SITE_VISIT_REPORT_COLUMN_VISIT_FROM];
    
    NSMutableString *where = [[[NSMutableString alloc] initWithString:@"1 = 1 "] autorelease];
    if (statusConsolidatedName != nil)
        [where setString:[where stringByAppendingString:[[[NSString alloc] initWithFormat:@"AND %@ = '%@' ", TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_CONSOLIDATED_NAME, statusConsolidatedName] autorelease]]];
    if (engineerId != nil)
        [where setString:[where stringByAppendingString:[[[NSString alloc] initWithFormat:@"AND %@ = %li ", TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID, (long)[engineerId integerValue]] autorelease]]];
    if (serviceContractNumber != nil)
        [where setString:[where stringByAppendingString:[[[NSString alloc] initWithFormat:@"AND %@ = %li ", TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_EM_NUMBER, (long)[serviceContractNumber integerValue]] autorelease]]];
    [where setString:[where stringByAppendingString:[[[NSString alloc] initWithFormat:@"AND %@ ", [self getSubcontractorBlockingFilterForLoggedInUser]] autorelease]]];

    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)requiresSyncDataForSiteVisitReports
{
    // Returns all records from the SiteVisitReport table that have not yet been synced up to the server
    
    NSMutableArray *allSiteVisitReports = [[NSMutableArray alloc] initWithArray: [self executeSelectAll:TABLE_SITE_VISIT_REPORT withSelect:@"*" withWhere:[NSString stringWithFormat:@"%@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:nil]];
    
    // Add separate dictionaries for the foreign keys
    for (NSMutableDictionary *siteVisitReport in allSiteVisitReports)
    {
        // Engineer
        [siteVisitReport setObject:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ENGINEER_ID] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_ENGINEER_ID];
        
        // Mardix Signatory
        [siteVisitReport setObject:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_MARDIX_SIGNATORY_ID] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_MARDIX_SIGNATORY_ID];
        
        // Witness Signatory
        if ([siteVisitReport keyIsNotMissingNullOrEmpty:TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID]) {
            @autoreleasepool {
                NSDictionary *signatory = [self getSiteVisitReportSignatoryById:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_ID]];
                [siteVisitReport setObject:[signatory objectForKey:TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_EMAIL] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_SIGNATORY_EMAIL];
            }
        }
        
        // Branch
        [siteVisitReport setObject:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_BRANCH_ID] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_BRANCH_ID];
        
        // Service Contract
        if ([siteVisitReport keyIsNotMissingNullOrEmpty:TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID])
            [siteVisitReport setObject:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_SERVICE_CONTRACT_ID] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_SERVICE_CONTRACT_ID];
        
        // Mardix Signature
        @autoreleasepool {
            NSArray *signatures = [self getDocumentsForSiteVisitReportId:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ID] documentId:nil documentTypeName:TABLE_DOCUMENT_TYPE_COLUMN_NAME_VALUE_SITE_VISIT_REPORT_MARDIX_SIGNATURE qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:NO];
            if ([signatures count])
            {
                NSDictionary *document = [signatures objectAtIndex:0];
                UIImage *image = [UIImage imageWithContentsOfFile:[[document objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] stringByPrependingDocumentsDirectoryFilepath]];
                NSData *imageData = UIImageJPEGRepresentation(image, 1);
                [siteVisitReport setObject:[imageData base64EncodedString] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_MARDIX_SIGNATURE_IMAGE];
            }
        }
        
        // Witness Signature
        @autoreleasepool {
            NSArray *signatures = [self getDocumentsForSiteVisitReportId:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ID] documentId:nil documentTypeName:TABLE_DOCUMENT_TYPE_COLUMN_NAME_VALUE_SITE_VISIT_REPORT_SIGNATURE qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:NO];
            if ([signatures count])
            {
                NSDictionary *document = [signatures objectAtIndex:0];
                UIImage *image = [UIImage imageWithContentsOfFile:[[document objectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] stringByPrependingDocumentsDirectoryFilepath]];
                NSData *imageData = UIImageJPEGRepresentation(image, 1);
                [siteVisitReport setObject:[imageData base64EncodedString] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_SIGNATURE_IMAGE];
            }
        }
        
        // Equipment
        @autoreleasepool {
            NSArray *equipment = [self getEquipmentForSiteVisitReportId:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ID]];
            [siteVisitReport setObject:[equipment valueForKey:TABLE_EQUIPMENT_COLUMN_ID] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_EQUIPMENT_IDS];
        }
        
        // Status
        [siteVisitReport setObject:[siteVisitReport objectForKey:TABLE_SITE_VISIT_REPORT_COLUMN_STATUS_ID] forKey:JSON_SITE_VISIT_REPORT_ATTRIBUTE_STATUS_ID];
    }
    
    NSArray *returnArray = [NSArray arrayWithArray:allSiteVisitReports];
    [allSiteVisitReports release];
    
    return returnArray;
}

- (NSArray *)requiresSyncDataForSiteVisitReportDocuments
{
    // Returns all Site Visit Report Documents that have not yet been synced up to the server
    
    NSArray *documents = [self getDocumentsForSiteVisitReportId:nil documentId:nil documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:YES];
    NSMutableArray *siteVisitReportDocuments = [NSMutableArray array];
    
    // Build up sync object
    for (NSDictionary *document in documents)
    {
        NSMutableDictionary *siteVisitReportDocument = [NSMutableDictionary dictionary];
        
        // Id
        [siteVisitReportDocument setObject:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] forKey:TABLE_COMMON_ID];
        
        // Document
        [siteVisitReportDocument setObject:document forKey:JSON_DOCUMENT];
        
        // Site Visit Report/Equipment/Engineer
        @autoreleasepool {
            NSDictionary *siteVisitReport = [[self getSiteVisitReportsForDocumentId:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID]] objectAtIndex:0];   // There should only be one site visit report for this document
            [siteVisitReportDocument setObject:[siteVisitReport valueForKey:TABLE_SITE_VISIT_REPORT_COLUMN_ID] forKey:JSON_SITE_VISIT_REPORT_DOCUMENT_ATTRIBUTE_REPORT_ID];
            // At this point in time there should only ever be one equipment item per site visit report document
            NSArray *equipmentIds = [siteVisitReport keyIsNotMissingNullOrEmpty:TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID]
            ? [NSArray arrayWithObject:[siteVisitReport valueForKey:TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_EQUIPMENT_ID]]
            : [NSArray array];
            [siteVisitReportDocument setObject:equipmentIds forKey:JSON_SITE_VISIT_REPORT_DOCUMENT_ATTRIBUTE_EQUIPMENT_IDS];
            [siteVisitReportDocument setObject:[siteVisitReport valueForKey:TABLE_DOCUMENT_SITE_VISIT_REPORT_COLUMN_CREATED_BY_ID] forKey:JSON_SITE_VISIT_REPORT_DOCUMENT_ATTRIBUTE_CREATED_BY_ID];
        }
        [siteVisitReportDocuments addObject:siteVisitReportDocument];
    }
    
    return [NSArray arrayWithArray:siteVisitReportDocuments];
}

#pragma mark - Site Visit Report Signatory

// Inserts a number of records into the SiteVisitReportSignatory table, using the collection of dictionaries supplied

- (NSDictionary *)getSiteVisitReportSignatoryById:(NSString *)signatoryId
{
    // Returns the record from the SiteVisitReportSignatory table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ID, [signatoryId uppercaseString]];
    return [self executeSelectSingle:TABLE_SITE_VISIT_REPORT_SIGNATORY withSelect:@"*" withWhere:where];
}

- (NSArray *)getSiteVisitReportSignatoriesForOrganisationId:(NSNumber *)organisationId
{
    // Returns the record from the SiteVisitReportSignatory table matching the filter on the Organisation_id field
    
    NSString *where = [NSString stringWithFormat:@"%@ = %li", TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ORGANISATION_ID, (long)[organisationId integerValue]];
    return [self executeSelectAll:TABLE_SITE_VISIT_REPORT_SIGNATORY withSelect:[NSString stringWithFormat:@"*, %@ ||' '|| %@ AS %@", TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_FORENAME, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_SURNAME, TABLE_SITE_VISIT_REPORT_COLUMN_SIGNATORY_NAME] withWhere:where withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_FORENAME]];
}

- (DataWrapper *)createSiteVisitReportSignatoryWithRow:(NSDictionary *)row
{
    // Inserts a record into the SiteVisitReportSignatory table, using the data in the dictionary supplied
    
    NSString *uuid = [[NSString stringWithUUID] lowercaseString];
    
    // Set null values for any required fields that are currently missing
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_FORENAME,
                      TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_SURNAME,
                      TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_EMAIL,
                      TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_POSITION,
                      TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_TELEPHONE,
                      TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_TITLE,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, :%@, 1)", TABLE_SITE_VISIT_REPORT_SIGNATORY, uuid, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_FORENAME, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_SURNAME, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ORGANISATION_ID, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_EMAIL, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_POSITION, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_TELEPHONE, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_TITLE];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getSiteVisitReportSignatoryById:uuid];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (NSArray *)requiresSyncDataForSiteVisitReportSignatories
{
    // Returns all records from the SiteVisitReportSignatory table that have not yet been synced up to the server
    
    NSMutableArray *allSignatories = [[NSMutableArray alloc] initWithArray: [self executeSelectAll:TABLE_SITE_VISIT_REPORT_SIGNATORY withSelect:@"*" withWhere:[NSString stringWithFormat:@"%@ = 1", TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:nil]];
    
    // Add separate dictionaries for the foreign keys
    for (NSMutableDictionary *signatory in allSignatories)
    {
        // Organisation
        [signatory setObject:[signatory objectForKey:TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ORGANISATION_ID] forKey:JSON_SITE_VISIT_REPORT_SIGNATORY_ATTRIBUTE_ORGANISATION_ID];
    }
    
    NSArray *returnArray = [NSArray arrayWithArray:allSignatories];
    [allSignatories release];
    
    return returnArray;
}

#pragma mark - Site Visit Report Status

- (NSArray *)getSiteVisitReportStatuses
{
    // Returns all records from the SiteVisitReportStatus table
    
    return [self executeSelectAll:TABLE_SITE_VISIT_REPORT_STATUS withSelect:@"*" withWhere:nil withOrderBy:nil];
}

- (NSDictionary *)getSiteVisitReportStatusById:(NSString *)siteVisitReportStatusId
{
    // Returns the record from the SiteVisitReportStatus table matching the filter on the Id field
    
    NSString *select = [NSString stringWithFormat:@"s.*, CASE WHEN a.%@ IS NULL THEN s.%@ ELSE a.%@ END AS %@", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CLIENT_ALTERNATIVE_NAME];
    
    NSString *tables = [NSString stringWithFormat:@"%@ s LEFT JOIN %@ a ON s.%@ = a.%@ ", TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CLIENT_ALTERNATIVE, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_ID];
    
    NSString *where = [NSString stringWithFormat:@"UPPER(s.%@) = '%@'", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_ID, [siteVisitReportStatusId uppercaseString]];
    
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getSiteVisitReportStatusByVisitTypeId:(NSString *)siteVisitReportTypeId
{
    // Returns the record from the SiteVisitReportStatus table matching the filter on the SiteVisitReportType_id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_SITE_VISIT_REPORT_TYPE_ID, [siteVisitReportTypeId uppercaseString]];
    return [self executeSelectAll:TABLE_SITE_VISIT_REPORT_STATUS withSelect:@"*" withWhere:where withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME]];
}

- (NSDictionary *)getSiteVisitReportStatusByVisitTypeId:(NSString *)siteVisitReportTypeId forStatusName:(NSString *)statusName
{
    // Returns the record from the SiteVisitReportStatus table matching the filter on the SiteVisitReportType_id and Name fields
    
    NSString *select = [NSString stringWithFormat:@"s.*, CASE WHEN a.%@ IS NULL THEN s.%@ ELSE a.%@ END AS %@", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CLIENT_ALTERNATIVE_NAME];
    
    NSString *tables = [NSString stringWithFormat:@"%@ s LEFT JOIN %@ a ON s.%@ = a.%@ ", TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CLIENT_ALTERNATIVE, TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_ID];
    
    NSString *where = [NSString stringWithFormat:@"UPPER(s.%@) = '%@' AND s.%@ = '%@'", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_SITE_VISIT_REPORT_TYPE_ID, [siteVisitReportTypeId uppercaseString], TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_NAME, statusName];
    
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getSiteVisitReportStatusDistinctConsolidatedNames
{
    // Returns a distinct list of values from the ConsolidatedName field in the SiteVisitReportStatus table
    
    return [self executeSelectAll:TABLE_SITE_VISIT_REPORT_STATUS withSelect:[NSString stringWithFormat:@"DISTINCT %@", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CONSOLIDATED_NAME] withWhere:nil withOrderBy:[NSString stringWithFormat:@"%@ ASC", TABLE_SITE_VISIT_REPORT_STATUS_COLUMN_CONSOLIDATED_NAME]];
}

#pragma mark - Site Visit Report Type

- (NSArray *)getSiteVisitReportTypes
{
    // Returns all records from the SiteVisitReportType table
    
    return [self executeSelectAll:TABLE_SITE_VISIT_REPORT_TYPE withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_SITE_VISIT_REPORT_TYPE_COLUMN_NAME]];
}

#pragma mark - Site Visit Report - Equipment

- (NSArray *)getEquipmentForSiteVisitReportId:(NSString *)siteVisitReportId
{
    // Returns all records from the SiteVisitReport_Equipment table matching the filter on the SiteVisitReport_id field
    
    // Actually return the full EQUIPMENT object for the associated equipment item
    NSString *select = [self getEquipmentSelect];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@ ", [self getEquipmentTables], TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID];
    NSString *where = [NSString stringWithFormat:@" UPPER(%@.%@) = '%@' ", TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_SITE_VISIT_REPORT_ID, [siteVisitReportId uppercaseString]];
    NSString *orderBy = [NSString stringWithFormat:@" UPPER(%@) ASC, UPPER(%@.%@) ASC", TABLE_EQUIPMENT_COLUMN_EQUIPMENT_TYPE_NAME, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_UNIT_REFERENCE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (BOOL)updateSiteVisitReportEquipmentWithEquipmentRows:(NSArray *)equipmentRows forSiteVisitReportId:(NSString *)siteVisitReportId
{
    // Inserts a number of records into the SiteVisitReport_Equipment table, using the data supplied
    
    // Rather than worry about INSERT or DELETE for this linking table, just delete all associated equipments and then INSERT
    // The API will handle any resultant deletes
    
    BOOL succeeded = [self deleteSiteVisitReportEquipmentForSiteVisitReportId:siteVisitReportId];
    if (succeeded == NO)
        return NO;
    
    for (NSDictionary *row in equipmentRows)
    {
        if (![self updateSiteVisitReportEquipmentWithEquipmentRow:row forSiteVisitReportId:siteVisitReportId]) {
            succeeded = NO;
            break;
        }
    }
    
    return succeeded;
}

- (BOOL)updateSiteVisitReportEquipmentWithEquipmentRow:(NSDictionary *)row forSiteVisitReportId:(NSString *)siteVisitReportId
{
    // Inserts a record into the SiteVisitReport_Equipment table, using the data supplied
    
    // The AssociatedEquipment object contains a full Equipment object, so build up parameters using Equipment references but recreate
    // keys as per the SiteVisitReport_Equipment column names
    
    NSNumber *equipmentId = (NSNumber *)[row objectForKey:TABLE_EQUIPMENT_COLUMN_ID];
    NSMutableDictionary *parameters = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:siteVisitReportId, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_SITE_VISIT_REPORT_ID, equipmentId, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_EQUIPMENT_ID, nil] autorelease];
    
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, 1)", TABLE_SITE_VISIT_REPORT_EQUIPMENT, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_SITE_VISIT_REPORT_ID, TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_EQUIPMENT_ID];
    
    BOOL result = [self executeUpdate:query withParameterDictionary:parameters];
    //[parameters release];
    
    return result;
}

- (BOOL)deleteSiteVisitReportEquipmentForSiteVisitReportId:(NSString *)siteVisitReportId
{
    // Deletes a record from the SiteVisitReport_Equipment table matching the filter on the SiteVisitReport_id field
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_SITE_VISIT_REPORT_EQUIPMENT_COLUMN_SITE_VISIT_REPORT_ID, [siteVisitReportId uppercaseString]];
    return [self executeDelete:TABLE_SITE_VISIT_REPORT_EQUIPMENT withWhere:where];
}

#pragma mark - Test Result

- (NSArray *)getTestResults
{
    // Returns all records from the TestResult table
    
    return [self executeSelectAll:TABLE_TEST_RESULT withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_TEST_RESULT_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getTestResultByName:(NSString *)testResultName
{
    // Returns the record from the TestResult table matching the filter on the Name field
    
    NSString *where = [NSString stringWithFormat:@"%@ = '%@'", TABLE_TEST_RESULT_COLUMN_NAME, testResultName];
    return [self executeSelectSingle:TABLE_TEST_RESULT withSelect:@"*" withWhere:where];
}

- (NSDictionary *)getTestResultById:(NSString *)testResultId
{
    // Returns the record from the TestResult table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_TEST_RESULT_COLUMN_ID, [testResultId uppercaseString]];
    return [self executeSelectSingle:TABLE_TEST_RESULT withSelect:@"*" withWhere:where];
}

#pragma mark - Test Session

- (BOOL)addRowsToTestSession:(NSArray *)rows
{
    // Inserts a number of records into the TestSession table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    // Filter down the list of test sessions to remove those that are currently marked as 'In Progress' on this device
    NSArray *ignoreList = [[self getTestSessionsInProgressOnThisDeviceIncludingPreActivated:NO] valueForKey:TABLE_TEST_SESSION_STATUS_COLUMN_ID];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"NONE %@ CONTAINS[c] %K", ignoreList, TABLE_TEST_SESSION_COLUMN_ID];
    rows = [[rows filteredArrayUsingPredicate:predicate] retain];
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        BOOL succeeded = YES;
        for (NSDictionary *row in rows) {
            if (![self addRowToTestSession:row withDatabase:database]) {
                [self.delegate databaseOperationFailed];
                succeeded = NO;
                break;
            }
        }
        
        // Add test session test rows
        if (succeeded == YES)
            succeeded = [self addRowsToTestSessionTest:rows];
        
        if (succeeded == YES)
            [self.delegate databaseOperationSucceeded];
        else
            [self.delegate databaseOperationFailed];
        
        self.successFlag = succeeded;
    }];
    
    return self.successFlag;
}

- (BOOL)addRowToTestSession:(NSDictionary *)row withDatabase:(FMDatabase *)database
{
    // Inserts a record into the TestSession table, using the data in the dictionary supplied
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    
    // Get all the nested JSON objects
    
    // Equipment
    NSNumber *equipmentId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_EQUIPMENT])
        equipmentId = (NSNumber *)[[row objectForKey:JSON_EQUIPMENT] nullableObjectForKey:TABLE_EQUIPMENT_COLUMN_ID];
    NSDictionary *equipmentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(equipmentId == nil) ? [NSNull null] : equipmentId, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, nil];
    [parameters addEntriesFromDictionary:equipmentDictionary];
    [equipmentDictionary release];
    
    // Tester
    NSNumber *testerId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_TESTER_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_TESTER_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_TESTER])
        testerId = (NSNumber *)[[row objectForKey:JSON_TESTER] nullableObjectForKey:TABLE_ENGINEER_COLUMN_ID];
    NSDictionary *testerDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(testerId == nil) ? [NSNull null] : testerId, TABLE_TEST_SESSION_COLUMN_TESTER_ID, nil];
    [parameters addEntriesFromDictionary:testerDictionary];
    [testerDictionary release];
    
    // Test Session Type
    NSString *testSessionTypeId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_TEST_SESSION_TYPE])
        testSessionTypeId = [[row objectForKey:JSON_TEST_SESSION_TYPE] nullableObjectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_ID];
    NSDictionary *testSessionTypeDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(testSessionTypeId == nil) ? [NSNull null] : testSessionTypeId, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID, nil];
    [parameters addEntriesFromDictionary:testSessionTypeDictionary];
    [testSessionTypeDictionary release];
    
    // Test Session Location
    NSString *testSessionLocationId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_TEST_SESSION_LOCATION])
        testSessionLocationId = [[row objectForKey:JSON_TEST_SESSION_LOCATION] nullableObjectForKey:TABLE_TEST_SESSION_LOCATION_COLUMN_ID];
    NSDictionary *testSessionLocationDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(testSessionLocationId == nil) ? [NSNull null] : testSessionLocationId, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID, nil];
    [parameters addEntriesFromDictionary:testSessionLocationDictionary];
    [testSessionLocationDictionary release];
    
    // Electrical Supply System
    NSString *electricalSupplySystemId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_ELECTRICAL_SUPPLY_SYSTEM])
        electricalSupplySystemId = [[row objectForKey:JSON_ELECTRICAL_SUPPLY_SYSTEM] nullableObjectForKey:TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM_COLUMN_ID];
    NSDictionary *electricalSupplySystemDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(electricalSupplySystemId == nil) ? [NSNull null] : electricalSupplySystemId, TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID, nil];
    [parameters addEntriesFromDictionary:electricalSupplySystemDictionary];
    [electricalSupplySystemDictionary release];
    
    // Trip Unit Check Outcome
    NSString *tripUnitCheckOutcomeId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_TRIP_UNIT_CHECK_OUTCOME])
        tripUnitCheckOutcomeId = [[row objectForKey:JSON_TRIP_UNIT_CHECK_OUTCOME] nullableObjectForKey:TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_ID];
    NSDictionary *tripUnitCheckOutcomeDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(tripUnitCheckOutcomeId == nil) ? [NSNull null] : tripUnitCheckOutcomeId, TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID, nil];
    [parameters addEntriesFromDictionary:tripUnitCheckOutcomeDictionary];
    [tripUnitCheckOutcomeDictionary release];
    
    // Mardix Signatory
    NSNumber *mardixSignatoryId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_MARDIX_SIGNATORY])
        mardixSignatoryId = (NSNumber *)[[row objectForKey:JSON_MARDIX_SIGNATORY] nullableObjectForKey:TABLE_ENGINEER_COLUMN_ID];
    NSDictionary *mardixSignatoryDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(mardixSignatoryId == nil) ? [NSNull null] : mardixSignatoryId, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID, nil];
    [parameters addEntriesFromDictionary:mardixSignatoryDictionary];
    [mardixSignatoryDictionary release];
    
    // Mardix Witness Signatory
    NSNumber *mardixWitnessSignatoryId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_MARDIX_WITNESS_SIGNATORY])
        mardixWitnessSignatoryId = (NSNumber *)[[row objectForKey:JSON_MARDIX_WITNESS_SIGNATORY] nullableObjectForKey:TABLE_ENGINEER_COLUMN_ID];
    NSDictionary *mardixWitnessSignatoryDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(mardixWitnessSignatoryId == nil) ? [NSNull null] : mardixWitnessSignatoryId, TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID, nil];
    [parameters addEntriesFromDictionary:mardixWitnessSignatoryDictionary];
    [mardixWitnessSignatoryDictionary release];
    
    // Client Witness Signatory
    NSString *clientWitnessSignatoryId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_CLIENT_WITNESS_SIGNATORY])
        clientWitnessSignatoryId = [[row objectForKey:JSON_CLIENT_WITNESS_SIGNATORY] nullableObjectForKey:TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ID];
    NSDictionary *clientWitnessSignatoryDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(clientWitnessSignatoryId == nil) ? [NSNull null] : clientWitnessSignatoryId, TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID, nil];
    [parameters addEntriesFromDictionary:clientWitnessSignatoryDictionary];
    [clientWitnessSignatoryDictionary release];
    
    // Test Session Status
    NSString *testSessionStatusId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_STATUS])
        testSessionStatusId = [[row objectForKey:JSON_STATUS] nullableObjectForKey:TABLE_TEST_SESSION_STATUS_COLUMN_ID];
    NSDictionary *testSessionStatusDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(testSessionStatusId == nil) ? [NSNull null] : testSessionStatusId, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, nil];
    [parameters addEntriesFromDictionary:testSessionStatusDictionary];
    [testSessionStatusDictionary release];
    
    // Result
    NSString *resultId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID] ? [row objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_RESULT])
        resultId = [[row objectForKey:JSON_RESULT] nullableObjectForKey:TABLE_TEST_RESULT_COLUMN_ID];
    NSDictionary *resultDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(resultId == nil) ? [NSNull null] : resultId, TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID, nil];
    [parameters addEntriesFromDictionary:resultDictionary];
    [resultDictionary release];
    
    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, NULL, 0)", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_ID, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, TABLE_TEST_SESSION_COLUMN_TESTER_ID, TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED, TABLE_TEST_SESSION_COLUMN_START_DATE, TABLE_TEST_SESSION_COLUMN_END_DATE, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID, TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID, TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID, TABLE_TEST_SESSION_COLUMN_COMMENTS, TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION, TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE, TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID, TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_UNIT_RATING, TABLE_TEST_SESSION_COLUMN_TX_RATING, TABLE_TEST_SESSION_COLUMN_STS_RATING, TABLE_TEST_SESSION_COLUMN_AHF_RATING];
    
    BOOL result = YES;
    
    // First, attempt to save the associated documents if any exist
    if ([row keyIsNotMissingOrNull:JSON_DOCUMENTS] && result)
    {
        if ([[row objectForKey:JSON_DOCUMENTS] isKindOfClass:[NSArray class]] && [[row objectForKey:JSON_DOCUMENTS] count])
        {
            // Delete any existing documents for this test session
            if (result)
                result = [self deleteDocumentsForTestSessionId:[parameters objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil filePath:nil includingFiles:YES];
            
            for (NSDictionary *document in [row objectForKey:JSON_DOCUMENTS])
            {
                if ([document keyIsNotMissingOrNull:TABLE_DOCUMENT_COLUMN_ID])
                {
                    // Save the document
                    if (result)
                        result = [self addRowToDocument:document fileSystemDirectory:nil isNew:YES requiresDataSync:NO withDatabase:database];
                    if (result)
                        result = [self addRowToDocumentTestSession:document withTestSessionId:[parameters objectForKey:TABLE_TEST_SESSION_COLUMN_ID] withDatabase:database];
                    if (!result) break;
                }
            }
        }
    }
    
    // Next, save the test session itself
    if (result)
        result = [database executeUpdate:query withParameterDictionary:[parameters convertDatesToLongDateTimeUtcString]];
    
    [parameters release];
    return result;
}

- (NSString *)getTestSessionSelect
{
    return [NSString stringWithFormat:@"%@.*, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, engineer1.%@ AS %@, engineer2.%@ AS %@, engineer3.%@ AS %@, %@.%@ ||' '|| %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@",
            TABLE_TEST_SESSION,
            TABLE_TEST_SESSION_TYPE, TABLE_TEST_SESSION_TYPE_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_NAME,
            TABLE_TEST_SESSION_LOCATION, TABLE_TEST_SESSION_LOCATION_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_NAME,
            TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_SERVICE_TAG_NUMBER, TABLE_TEST_SESSION_COLUMN_SERVICE_TAG_NUMBER,
            TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM, TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_NAME,
            TABLE_TEST_SESSION_CHECK_OUTCOME, TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_NAME,
            TABLE_ENGINEER_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_ENGINEER_NAME,
            TABLE_ENGINEER_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_NAME,
            TABLE_ENGINEER_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_NAME,
            TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_FORENAME, TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_SURNAME, TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_NAME,
            TABLE_TEST_SESSION_STATUS, TABLE_TEST_SESSION_STATUS_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_NAME,
            TABLE_TEST_RESULT, TABLE_TEST_RESULT_COLUMN_NAME, TABLE_TEST_SESSION_COLUMN_TEST_RESULT_NAME
            ];
}

- (NSString *)getTestSessionTables
{
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ AS engineer1 ON %@.%@ = engineer1.%@ LEFT JOIN %@ AS engineer2 ON %@.%@ = engineer2.%@ LEFT JOIN %@ AS engineer3 ON %@.%@ = engineer3.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@",
            TABLE_TEST_SESSION,
            TABLE_TEST_SESSION_TYPE, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID, TABLE_TEST_SESSION_TYPE, TABLE_TEST_SESSION_TYPE_COLUMN_ID,
            TABLE_TEST_SESSION_LOCATION, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID, TABLE_TEST_SESSION_LOCATION, TABLE_TEST_SESSION_LOCATION_COLUMN_ID,
            TABLE_EQUIPMENT, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_ID,
            TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID, TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM, TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM_COLUMN_ID,
            TABLE_TEST_SESSION_CHECK_OUTCOME, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID, TABLE_TEST_SESSION_CHECK_OUTCOME, TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_ID,
            TABLE_ENGINEER, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TESTER_ID, TABLE_ENGINEER_COLUMN_ID,
            TABLE_ENGINEER, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID, TABLE_ENGINEER_COLUMN_ID,
            TABLE_ENGINEER, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID, TABLE_ENGINEER_COLUMN_ID,
            TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID, TABLE_SITE_VISIT_REPORT_SIGNATORY, TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_ID,
            TABLE_TEST_SESSION_STATUS, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, TABLE_TEST_SESSION_STATUS, TABLE_TEST_SESSION_STATUS_COLUMN_ID,
            TABLE_TEST_RESULT, TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID, TABLE_TEST_RESULT, TABLE_TEST_RESULT_COLUMN_ID
            ];
}

- (NSDictionary *)getTestSessionById:(NSString *)testSessionId
{
    // Returns the record from the TestSession table matching the filter on the Id field
    
    NSString *select = [self getTestSessionSelect];
    NSString *tables = [self getTestSessionTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_ID, [testSessionId uppercaseString]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSDictionary *)getTestSessionForTestSessionTestId:(NSString *)testSessionTestId
{
    // Returns the record from the TestSession table matching the filter on the Id field in the TestSessionTest table
    
    NSString *select = [self getTestSessionSelect];
    NSString *tables = [self getTestSessionTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ IN (SELECT %@ FROM %@ WHERE UPPER(%@) = '%@')", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_ID, [testSessionTestId uppercaseString]];
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getTestSessionsByTestSessionStatusName:(NSString *)testSessionStatusName
{
    // Returns the record from the TestSession table matching the filter on the Name field in the TestSessionStatus table
    
    NSString *select = [self getTestSessionSelect];
    NSString *tables = [self getTestSessionTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = '%@'", TABLE_TEST_SESSION_STATUS, TABLE_TEST_SESSION_STATUS_COLUMN_NAME, testSessionStatusName];
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
}

- (NSArray *)getTestSessionsInProgressOnThisDeviceIncludingPreActivated:(BOOL)includingPreActivated
{
    // Returns all records from the TestSession table, where the test session is marked as 'In Progress', and the last device used is the current device
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NSString *select = [self getTestSessionSelect];
    NSString *tables = [self getTestSessionTables];
    NSString *wherePreActivated = includingPreActivated ? [NSString stringWithFormat:@"OR UPPER(%@.%@) = '%@'", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, [TABLE_TEST_SESSION_STATUS_COLUMN_ID_VALUE_PRE_ACTIVATED uppercaseString]] : @"";
    NSString *where = [NSString stringWithFormat:@"(UPPER(%@.%@) <> '%@' AND UPPER(%@.%@) <> '%@' AND %@.%@ = '%@') %@", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, [TABLE_TEST_SESSION_STATUS_COLUMN_ID_VALUE_COMPLETED uppercaseString], TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, [TABLE_TEST_SESSION_STATUS_COLUMN_ID_VALUE_ABANDONED uppercaseString], TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED, [appDelegate deviceUniqueIdentifier], wherePreActivated];
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:nil];
}

- (NSArray *)getTestSessionsForEquipmentId:(NSNumber *)equipmentId
{
    // Returns all records from the TestSession table matching the filter on the Equipment_id field
    
    NSString *select = [self getTestSessionSelect];
    NSString *tables = [self getTestSessionTables];
    NSString *where = [NSString stringWithFormat:@"%@.%@ = %lld", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, [equipmentId longLongValue]];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@ DESC", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_START_DATE];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (DataWrapper *)createTestSessionWithRow:(NSMutableDictionary *)row
{
    // Inserts a record into the TestSession table, using the data in the dictionary supplied
    
    // Assign an Id to the test session if it does not already have one
    NSString *uuid = ([row keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_ID])
        ? [row valueForKey:TABLE_TEST_SESSION_COLUMN_ID]
        : [[NSString stringWithUUID] lowercaseString];
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID,
                      TABLE_TEST_SESSION_COLUMN_TESTER_ID,
                      TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED,
                      TABLE_TEST_SESSION_COLUMN_START_DATE,
                      TABLE_TEST_SESSION_COLUMN_END_DATE,
                      TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID,
                      TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID,
                      TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID,
                      TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID,
                      TABLE_TEST_SESSION_COLUMN_COMMENTS,
                      TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION,
                      TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION,
                      TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID,
                      TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE,
                      TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID,
                      TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID,
                      TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE,
                      TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID,
                      TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID,
                      TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO,
                      TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO,
                      TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO,
                      TABLE_TEST_SESSION_COLUMN_UNIT_RATING,
                      TABLE_TEST_SESSION_COLUMN_TX_RATING,
                      TABLE_TEST_SESSION_COLUMN_STS_RATING,
                      TABLE_TEST_SESSION_COLUMN_AHF_RATING,
                      TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    // Execute
    // Note we set RequiresDataSync to 0, as this record is only retained if the subsequent Api call to update it on the server is successful
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, 0)", TABLE_TEST_SESSION, uuid, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, TABLE_TEST_SESSION_COLUMN_TESTER_ID, TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED, TABLE_TEST_SESSION_COLUMN_START_DATE, TABLE_TEST_SESSION_COLUMN_END_DATE, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID, TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID, TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID, TABLE_TEST_SESSION_COLUMN_COMMENTS, TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION, TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE, TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID, TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_UNIT_RATING, TABLE_TEST_SESSION_COLUMN_TX_RATING, TABLE_TEST_SESSION_COLUMN_STS_RATING, TABLE_TEST_SESSION_COLUMN_AHF_RATING, TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getTestSessionById:uuid];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (DataWrapper *)updateTestSessionWithRow:(NSMutableDictionary *)row requiresDataSync:(BOOL)requiresDataSync
{
    // Updates a record in the TestSession table, using the data in the dictionary supplied
    
    NSString *lastDeviceUsed = [NSString stringWithFormat:@"%@", [row nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED]];
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID,
                      TABLE_TEST_SESSION_COLUMN_TESTER_ID,
                      TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED,
                      TABLE_TEST_SESSION_COLUMN_START_DATE,
                      TABLE_TEST_SESSION_COLUMN_END_DATE,
                      TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID,
                      TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID,
                      TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID,
                      TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID,
                      TABLE_TEST_SESSION_COLUMN_COMMENTS,
                      TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION,
                      TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION,
                      TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID,
                      TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE,
                      TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID,
                      TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID,
                      TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE,
                      TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID,
                      TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID,
                      TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO,
                      TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO,
                      TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO,
                      TABLE_TEST_SESSION_COLUMN_UNIT_RATING,
                      TABLE_TEST_SESSION_COLUMN_TX_RATING,
                      TABLE_TEST_SESSION_COLUMN_STS_RATING,
                      TABLE_TEST_SESSION_COLUMN_AHF_RATING,
                      TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    NSString *dataSyncFlag = requiresDataSync ? @"1" : @"0";

    // Execute
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = '%@', %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = %@ WHERE %@ = :%@",
                       TABLE_TEST_SESSION,
                       TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID, TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID,
                       TABLE_TEST_SESSION_COLUMN_TESTER_ID, TABLE_TEST_SESSION_COLUMN_TESTER_ID,
                       TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED, [lastDeviceUsed withDoubleApostrophes],
                       TABLE_TEST_SESSION_COLUMN_START_DATE, TABLE_TEST_SESSION_COLUMN_START_DATE,
                       TABLE_TEST_SESSION_COLUMN_END_DATE, TABLE_TEST_SESSION_COLUMN_END_DATE,
                       TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID,
                       TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID,
                       TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID, TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID,
                       TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID, TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID,
                       TABLE_TEST_SESSION_COLUMN_COMMENTS, TABLE_TEST_SESSION_COLUMN_COMMENTS,
                       TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION, TABLE_TEST_SESSION_COLUMN_TESTED_TO_GENERAL_ARRANGEMENT_DRAWING_REVISION,
                       TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION, TABLE_TEST_SESSION_COLUMN_TESTED_TO_ELECTRICAL_SCHEMATIC_DRAWING_REVISION,
                       TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID,
                       TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE, TABLE_TEST_SESSION_COLUMN_MARDIX_SIGN_OFF_DATE,
                       TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID,
                       TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID, TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID,
                       TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE, TABLE_TEST_SESSION_COLUMN_WITNESS_SIGN_OFF_DATE,
                       TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID, TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID,
                       TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID, TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID,
                       TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_TX_SERIAL_NO,
                       TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_STS_SERIAL_NO,
                       TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO, TABLE_TEST_SESSION_COLUMN_AHF_SERIAL_NO,
                       TABLE_TEST_SESSION_COLUMN_UNIT_RATING, TABLE_TEST_SESSION_COLUMN_UNIT_RATING,
                       TABLE_TEST_SESSION_COLUMN_TX_RATING, TABLE_TEST_SESSION_COLUMN_TX_RATING,
                       TABLE_TEST_SESSION_COLUMN_STS_RATING, TABLE_TEST_SESSION_COLUMN_STS_RATING,
                       TABLE_TEST_SESSION_COLUMN_AHF_RATING, TABLE_TEST_SESSION_COLUMN_AHF_RATING,
                       TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID, TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID,
                       TABLE_COMMON_REQUIRES_DATA_SYNC, dataSyncFlag,
                       TABLE_TEST_SESSION_COLUMN_ID, TABLE_TEST_SESSION_COLUMN_ID];
    
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    NSDictionary *data = [self getTestSessionById:[row objectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return [[[DataWrapper alloc] initWithIsValid:result andDataDictionary:data] autorelease];
}

- (BOOL)deleteTestSessionById:(NSString *)testSessionId withTestsAndDocuments:(BOOL)withTestsAndDocuments
{
    // Deletes a record from the TestSession table matching the filter on the Id field
    
    BOOL result = YES;
    
    // Delete associated test and document records if specified
    if (withTestsAndDocuments) {
        if (result)
            result = [self deleteDocumentsForTestSessionId:testSessionId documentTypeName:nil qualityManagementSystemCode:nil filePath:nil includingFiles:YES];
        if (result)
            result = [self deleteTestDocumentsForTestSessionId:testSessionId];
        if (result)
            result = [self deleteTestSessionTestsForTestSessionId:testSessionId];
    }
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_TEST_SESSION_COLUMN_ID, [testSessionId uppercaseString]];
    if (result)
        result = [self executeDelete:TABLE_TEST_SESSION withWhere:where];
    
    return result;
}

- (BOOL)testSessionInProgressOnThisDeviceForTestSessionId:(NSString *)testSessionId
{
    // Returns YES if the test session with the specified id is marked as 'In Progress' and the last device used is the current device, or NO if not

    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    NSDictionary *testSession = [self getTestSessionById:testSessionId];
    NSDictionary *statusInProgress = [self getTestSessionStatusByName:TABLE_TEST_SESSION_STATUS_COLUMN_NAME_VALUE_IN_PROGRESS];
    
    if ([[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED] isEqual:[appDelegate deviceUniqueIdentifier]] &&
        [[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID] isEqual:[statusInProgress objectForKey:TABLE_TEST_SESSION_STATUS_COLUMN_ID]])
        return YES;
    else
        return NO;
}

- (BOOL)assignNewIdentityForTestSessionId:(NSString *)testSessionId
{
    // Updates all records in the TestSession, TestSessionTest and Document_TestSession tables for the specified test session, to give all the records new unique identifiers
    // Any associated file paths are also modified to ensure complete individuality between the old and new test sessions and all their dependencies
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *sql;
    NSRange range;
    NSString *documentId;
    NSString *newDocumentId;
    NSString *documentFilePath;
    NSMutableString *newDocumentFilePath;
    NSString *newTestSessionId = [[NSString stringWithUUID] lowercaseString];
    BOOL result = YES;
    
    NSArray *testSessionDocuments = [self getDocumentsForTestSessionId:testSessionId documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:NO];
    NSArray *tests = [self getTestSessionTestsForTestSessionId:testSessionId];
    NSArray *ibarInstallationTestMetadatas = [self getIbarInstallationTestMetadatasForTestSessionId:testSessionId];
    NSArray *ibarInstallationJointTestMetadatas = [self getIbarInstallationJointTestMetadatasForTestSessionId:testSessionId];

    // Give each test session document a new Id and updated file path
    [self deleteDocumentTestSessionForTestSessionId:testSessionId];
    NSSet *testSessionDocumentsDistinct = [NSSet setWithArray:[testSessionDocuments valueForKey:TABLE_DOCUMENT_COLUMN_ID]];
    for (NSString *testSessionDocumentId in testSessionDocumentsDistinct)
    {
        NSDictionary *document = [self getDocumentById:testSessionDocumentId];
        documentId = [document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID];
        documentFilePath = [document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
        
        newDocumentId = [[NSString stringWithUUID] lowercaseString];
        
        // Derive new file path by substituting new test session Id for old one
        newDocumentFilePath = [NSMutableString stringWithString:documentFilePath];
        range = [[newDocumentFilePath lowercaseString] rangeOfString:[testSessionId lowercaseString]];
        if (range.length > 0)
            [newDocumentFilePath replaceCharactersInRange:range withString:newTestSessionId];
        
        // Delete old document record
        if (result)
            result = [self deleteDocumentById:documentId includingFile:NO];

        // Update document dictionary to give it a new Id and file path
        [document setValue:newDocumentId forKey:TABLE_DOCUMENT_COLUMN_ID];
        [document setValue:newDocumentFilePath forKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
        
        // Create new document and document test session record
        if (result)
            result = [self createDocumentWithRow:document forTestSessionId:newTestSessionId setRequiresDataSync:YES].isValid;
        
        // Rename the document itself
        if (result && ![[documentFilePath lowercaseString] isEqualToString:[newDocumentFilePath lowercaseString]])
            result = [fileManager moveItemAtPath:[documentFilePath stringByPrependingDocumentsDirectoryFilepath] toPath:[newDocumentFilePath stringByPrependingDocumentsDirectoryFilepath] error:nil];
    }
    
    // Give each test document a new Id and updated file path
    NSSet *testDocumentsDistinct = [NSSet setWithArray:[tests valueForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]];
    for (NSString *testDocumentId in testDocumentsDistinct)
    {
        if (![testDocumentId isEqual:[NSNull null]])
        {
            NSDictionary *document = [self getDocumentById:testDocumentId];
            documentId = [document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID];
            documentFilePath = [document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH];
            
            newDocumentId = [[NSString stringWithUUID] lowercaseString];
            
            // Derive new file path by substituting new test session Id for old one
            newDocumentFilePath = [NSMutableString stringWithString:documentFilePath];
            range = [[newDocumentFilePath lowercaseString] rangeOfString:[testSessionId lowercaseString]];
            if (range.length > 0)
                [newDocumentFilePath replaceCharactersInRange:range withString:newTestSessionId];
            
            // Update document record to give it a new Id and file path
            sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = '%@' WHERE UPPER(%@) = '%@'", TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID, newDocumentId, TABLE_DOCUMENT_COLUMN_FILE_PATH, newDocumentFilePath, TABLE_DOCUMENT_COLUMN_ID, [documentId uppercaseString]];
            if (result)
                result = [self executeUpdate:sql];
            
            // Update test session test record with new document Id
            sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = 1 WHERE UPPER(%@) = '%@'", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, newDocumentId, TABLE_COMMON_REQUIRES_DATA_SYNC, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
            if (result)
                result = [self executeUpdate:sql];
            
            // Update Ibar installation test metadata record with new document Id
            sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_TEST_METADATA, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID, newDocumentId, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
            if (result)
                result = [self executeUpdate:sql];
            
            // Update Ibar installation joint test metadata record with new document Id
            sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID, newDocumentId, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
            if (result)
                result = [self executeUpdate:sql];
            
            // Rename the document itself
            if (result && ![[documentFilePath lowercaseString] isEqualToString:[newDocumentFilePath lowercaseString]])
                result = [fileManager moveItemAtPath:[documentFilePath stringByPrependingDocumentsDirectoryFilepath] toPath:[newDocumentFilePath stringByPrependingDocumentsDirectoryFilepath] error:nil];
        }
    }
    
    // Update test session Id in TestSession table
    sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = 1 WHERE UPPER(%@) = '%@'", TABLE_TEST_SESSION, TABLE_TEST_SESSION_COLUMN_ID, newTestSessionId, TABLE_COMMON_REQUIRES_DATA_SYNC, TABLE_TEST_SESSION_COLUMN_ID, [testSessionId uppercaseString]];
    if (result)
        result = [self executeUpdate:sql];
    
    // Checked to here
    
    // Update test session Id in TestSessionTest table, and give each test a new unique identifier
    for (NSDictionary *test in tests)
    {
        NSString *testId = [test nullableObjectForKey:TABLE_TEST_SESSION_TEST_COLUMN_ID];
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = '%@', %@ = 1 WHERE UPPER(%@) = '%@'", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_ID, [[NSString stringWithUUID] lowercaseString], TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, newTestSessionId, TABLE_COMMON_REQUIRES_DATA_SYNC, TABLE_TEST_SESSION_TEST_COLUMN_ID, [testId uppercaseString]];
        if (result)
            result = [self executeUpdate:sql];
    }
    
    // Update test session Id in IbarInstallationTestMetadata table, and give each IbarInstallationTestMetadata a new unique identifier
    for (NSDictionary *ibarInstallationTestMetadata in ibarInstallationTestMetadatas)
    {
        NSArray *ibarInstallationTestMetadataContinuityRunDuctorTests = [self getIbarInstallationTestMetadataContinuityRunDuctorTestsForIbarInstallationTestMetadataId:[ibarInstallationTestMetadata nullableObjectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]];
        NSString *ibarInstallationTestMetadataId = [ibarInstallationTestMetadata nullableObjectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID];
        NSString *newIbarInstallationTestMetadataId = [[NSString stringWithUUID] lowercaseString];
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = '%@' WHERE UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_TEST_METADATA, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID, newIbarInstallationTestMetadataId, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID, newTestSessionId, TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID, [ibarInstallationTestMetadataId uppercaseString]];
        if (result)
            result = [self executeUpdate:sql];
        // Update Ibar installation test metadata Id in IbarInstallationTestMetadataContinuityRunDuctorTest table, and give each IbarInstallationTestMetadataContinuityRunDuctorTest a new unique identifier
        for (NSDictionary *ibarInstallationTestMetadataContinuityRunDuctorTest in ibarInstallationTestMetadataContinuityRunDuctorTests)
        {
            NSString *ibarInstallationTestMetadataContinuityRunDuctorTestId = [ibarInstallationTestMetadataContinuityRunDuctorTest nullableObjectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID];
            sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = '%@' WHERE UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID, [[NSString stringWithUUID] lowercaseString], TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID, newIbarInstallationTestMetadataId, TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_ID, [ibarInstallationTestMetadataContinuityRunDuctorTestId uppercaseString]];
            if (result)
                result = [self executeUpdate:sql];
        }
    }
    
    // Update test session Id in IbarInstallationJointTestMetadata table, and give each IbarInstallationJointTestMetadata a new unique identifier
    for (NSDictionary *ibarInstallationJointTestMetadata in ibarInstallationJointTestMetadatas)
    {
        NSString *ibarInstallationJointTestMetadataId = [ibarInstallationJointTestMetadata nullableObjectForKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID];
        NSString *newIbarInstallationJointTestMetadataId = [[NSString stringWithUUID] lowercaseString];
        sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = '%@' WHERE UPPER(%@) = '%@'", TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID, newIbarInstallationJointTestMetadataId, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID, newTestSessionId, TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_ID, [ibarInstallationJointTestMetadataId uppercaseString]];
        if (result)
            result = [self executeUpdate:sql];
    }
    
    return result;
}

- (NSArray *)requiresSyncDataForTestSessions
{
    // Returns all records from the TestSession table that have not yet been synced up to the server
    
    NSMutableArray *allTestSessions = [[NSMutableArray alloc] initWithArray: [self executeSelectAll:[self getTestSessionTables] withSelect:[self getTestSessionSelect] withWhere:[NSString stringWithFormat:@"%@.%@ = 1", TABLE_TEST_SESSION, TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:nil]];
    
    for (NSMutableDictionary *testSession in [[allTestSessions copy] autorelease])
    {
        // Add separate dictionaries for the foreign keys
        [allTestSessions replaceObjectAtIndex:[allTestSessions indexOfObject:testSession] withObject:[self addDataSyncJsonObjectsToTestSession:testSession]];
    }
    
    NSArray *returnArray = [NSArray arrayWithArray:allTestSessions];
    [allTestSessions release];
    
    return returnArray;
}

- (NSMutableDictionary *)addDataSyncJsonObjectsToTestSession:(NSMutableDictionary *)testSession
{
    // Adds all the Json objects required by a test session dictionary, prior to syncing up to the server
    
    // Equipment Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_EQUIPMENT_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_EQUIPMENT_ID];
    
    // Tester Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TESTER_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TESTER_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_TESTER_ID];
    
    // Test Session Type Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_TEST_SESSION_TYPE_ID];
    
    // Test Session Location Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_LOCATION_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_TEST_SESSION_LOCATION_ID];
    
    // Electrical Supply System Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ELECTRICAL_SUPPLY_SYSTEM_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_ELECTRICAL_SUPPLY_SYSTEM_ID];
    
    // Trip Unit Check Outcome Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TRIP_UNIT_CHECK_OUTCOME_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_TRIP_UNIT_CHECK_OUTCOME_ID];
    
    // Mardix Signatory Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_SIGNATORY_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_MARDIX_SIGNATORY_ID];
    
    // Mardix Witness Signatory Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_MARDIX_WITNESS_SIGNATORY_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_MARDIX_WITNESS_SIGNATORY_ID];
    
    // Client Witness Signatory Id
    if ([testSession keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID]) {
        @autoreleasepool {
            NSDictionary *clientWitnessSignatory = [self getSiteVisitReportSignatoryById:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_CLIENT_WITNESS_SIGNATORY_ID]];
            [testSession setObject:[clientWitnessSignatory objectForKey:TABLE_SITE_VISIT_REPORT_SIGNATORY_COLUMN_EMAIL] forKey:JSON_TEST_SESSION_ATTRIBUTE_CLIENT_WITNESS_SIGNATORY_EMAIL];
        }
    }
    
    // Status Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_STATUS_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_STATUS_ID];
    
    // Result Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_RESULT_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_RESULT_ID];
    
    // Build Location Id
    if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID])
        [testSession setObject:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_BUILD_LOCATION_ID] forKey:JSON_TEST_SESSION_ATTRIBUTE_BUILD_LOCATION_ID];
    
    // Core Documents
    @autoreleasepool {
        NSMutableArray *documents = [NSMutableArray array];
        // Add master document
        if ([testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]) {
            NSDictionary *testSessionType = [self getTestSessionTypeById:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_TEST_SESSION_TYPE_ID]];
            if ([testSessionType count] && [testSessionType keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_NAME]) {
                NSString *masterDocumentTypeQualityManagementSystemCode = [testSessionType nullableObjectForKey:TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE];
                [documents addObjectsFromArray:[self getDocumentsForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:masterDocumentTypeQualityManagementSystemCode documentTypeCategoryName:nil filterForRequiresDataSync:NO]];
            }
        }
        // Add signature documents
        [documents addObjectsFromArray:[self getDocumentsForTestSessionId:[testSession objectForKey:TABLE_TEST_SESSION_COLUMN_ID] documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME_VALUE_SIGNATURE filterForRequiresDataSync:NO]];
        for (NSDictionary *document in [[documents copy] autorelease])
        {
            if ([[document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] isEqualToString:@""])
                [documents removeObjectAtIndex:[documents indexOfObject:document]];
        }
        [testSession setObject:[NSArray arrayWithArray:documents] forKey:JSON_CORE_DOCUMENTS];
    }
    
    // IBAR Installation Test Metadata
    @autoreleasepool {
        NSArray *metadatas = [self getIbarInstallationTestMetadatasForTestSessionId:[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
        NSMutableArray *ibarInstallationTestMetadatas = [NSMutableArray array];

        for (NSDictionary *metadata in metadatas)
        {
            NSMutableDictionary *ibarInstallationTestMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata];

            // Test Session Id
            if ([ibarInstallationTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID])
                [ibarInstallationTestMetadata setObject:[ibarInstallationTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_TEST_SESSION_ID] forKey:JSON_IBAR_INSTALLATION_TEST_METADATA_ATTRIBUTE_TEST_SESSION_ID];
            
            // Document Id
            if ([ibarInstallationTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID])
                [ibarInstallationTestMetadata setObject:[ibarInstallationTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_DOCUMENT_ID] forKey:JSON_IBAR_INSTALLATION_TEST_METADATA_ATTRIBUTE_DOCUMENT_ID];

            // IBAR Installation Test Metadata Continuity Run Ductor Test
            @autoreleasepool {
                NSArray *continuityRunDuctorTests = [self getIbarInstallationTestMetadataContinuityRunDuctorTestsForIbarInstallationTestMetadataId:[ibarInstallationTestMetadata nullableObjectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_COLUMN_ID]];
                NSMutableArray *ibarInstallationTestMetadataContinuityRunDuctorTests = [NSMutableArray array];

                for (NSDictionary *continuityRunDuctorTest in continuityRunDuctorTests)
                {
                    NSMutableDictionary *ibarInstallationTestMetadataContinuityRunDuctorTest = [NSMutableDictionary dictionaryWithDictionary:continuityRunDuctorTest];

                    // IBAR Installation Test Metadata Id
                    if ([ibarInstallationTestMetadataContinuityRunDuctorTest objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID])
                        [ibarInstallationTestMetadataContinuityRunDuctorTest setObject:[ibarInstallationTestMetadataContinuityRunDuctorTest objectForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_IBAR_INSTALLATION_TEST_METADATA_ID] forKey:JSON_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_ATTRIBUTE_IBAR_INSTALLATION_TEST_METADATA_ID];

                    // From/To fields
                    // These have differet names in the database schema as the reserved SQL word 'From' cannot be used as a field name
                    [ibarInstallationTestMetadataContinuityRunDuctorTest setObject:[ibarInstallationTestMetadataContinuityRunDuctorTest valueForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_FROM] forKey:JSON_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_ATTRIBUTE_FROM];
                    [ibarInstallationTestMetadataContinuityRunDuctorTest setObject:[ibarInstallationTestMetadataContinuityRunDuctorTest valueForKey:TABLE_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_COLUMN_TO] forKey:JSON_IBAR_INSTALLATION_TEST_METADATA_CONTINUITY_RUN_DUCTOR_TEST_ATTRIBUTE_TO];

                    [ibarInstallationTestMetadataContinuityRunDuctorTests addObject:[NSDictionary dictionaryWithDictionary:ibarInstallationTestMetadataContinuityRunDuctorTest]];
                }
                
                [ibarInstallationTestMetadata setObject:[NSArray arrayWithArray:ibarInstallationTestMetadataContinuityRunDuctorTests] forKey:JSON_CONTINUITY_RUN_DUCTOR_TESTS];
            }
            
            [ibarInstallationTestMetadatas addObject:[NSDictionary dictionaryWithDictionary:ibarInstallationTestMetadata]];
        }
        
        [testSession setObject:[NSArray arrayWithArray:ibarInstallationTestMetadatas] forKey:JSON_IBAR_INSTALLATION_TEST_METADATAS];
    }

    // IBAR Installation Joint Test Metadata
    @autoreleasepool {
        NSArray *jointMetadatas = [self getIbarInstallationJointTestMetadatasForTestSessionId:[testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_ID]];
        NSMutableArray *ibarInstallationJointTestMetadatas = [NSMutableArray array];

        for (NSDictionary *jointMetadata in jointMetadatas)
        {
            NSMutableDictionary *ibarInstallationJointTestMetadata = [NSMutableDictionary dictionaryWithDictionary:jointMetadata];

            // Test Session Id
            if ([ibarInstallationJointTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID])
                [ibarInstallationJointTestMetadata setObject:[ibarInstallationJointTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_TEST_SESSION_ID] forKey:JSON_IBAR_INSTALLATION_JOINT_TEST_METADATA_ATTRIBUTE_TEST_SESSION_ID];
            
            // Document Id
            if ([ibarInstallationJointTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID])
                [ibarInstallationJointTestMetadata setObject:[ibarInstallationJointTestMetadata objectForKey:TABLE_IBAR_INSTALLATION_JOINT_TEST_METADATA_COLUMN_DOCUMENT_ID] forKey:JSON_IBAR_INSTALLATION_JOINT_TEST_METADATA_ATTRIBUTE_DOCUMENT_ID];
            
            [ibarInstallationJointTestMetadatas addObject:[NSDictionary dictionaryWithDictionary:ibarInstallationJointTestMetadata]];
        }
        
        [testSession setObject:[NSArray arrayWithArray:ibarInstallationJointTestMetadatas] forKey:JSON_IBAR_INSTALLATION_JOINT_TEST_METADATAS];
    }

    return testSession;
}

- (NSArray *)requiresSyncDataForTestSessionDocuments
{
    // Returns all Test Session Documents that have not yet been synced up to the server
    
    NSMutableArray *documents = [NSMutableArray array];
    [documents addObjectsFromArray:[self getDocumentsForTestSessionId:nil documentTypeName:nil qualityManagementSystemCode:nil documentTypeCategoryName:TABLE_DOCUMENT_TYPE_CATEGORY_COLUMN_NAME_VALUE_TEST_SESSION_DOCUMENT filterForRequiresDataSync:YES]];
    [documents addObjectsFromArray:[self getDocumentsForTestSessionId:nil documentTypeName:TABLE_DOCUMENT_TYPE_COLUMN_NAME_VALUE_TEST_SESSION_PHOTO qualityManagementSystemCode:nil documentTypeCategoryName:nil filterForRequiresDataSync:YES]];

    NSMutableArray *testSessionDocuments = [NSMutableArray array];
    
    // Build up sync object
    for (NSDictionary *document in documents)
    {
        NSMutableDictionary *testSessionDocument = [NSMutableDictionary dictionary];
        
        // Id
        [testSessionDocument setObject:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID] forKey:TABLE_COMMON_ID];
        
        // Document
        [testSessionDocument setObject:document forKey:JSON_DOCUMENT];
        
        // Test Session Id and Last Device Used
        @autoreleasepool {
            NSDictionary *testSession = [[self getTestSessionsForDocumentId:[document objectForKey:TABLE_DOCUMENT_COLUMN_ID]] objectAtIndex:0];   // There should only be one test session for this document
            [testSessionDocument setObject:[testSession valueForKey:TABLE_TEST_SESSION_COLUMN_ID] forKey:JSON_TEST_SESSION_DOCUMENT_ATTRIBUTE_TEST_SESSION_ID];
            NSString *lastDeviceUsed = [testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED];
            [testSessionDocument setObject:lastDeviceUsed forKey:JSON_TEST_SESSION_DOCUMENT_ATTRIBUTE_LAST_DEVICE_USED];
        }

        [testSessionDocuments addObject:testSessionDocument];
    }
    
    return [NSArray arrayWithArray:testSessionDocuments];
}

#pragma mark - Test Session Check Outcome

- (NSArray *)getTestSessionCheckOutcomes
{
    // Returns all records from the TestSessionCheckOutcome table
    
    return [self executeSelectAll:TABLE_TEST_SESSION_CHECK_OUTCOME withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getTestSessionCheckOutcomeById:(NSString *)testSessionCheckOutcomeId
{
    // Returns the record from the TestSessionCheckOutcome table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_TEST_SESSION_CHECK_OUTCOME_COLUMN_ID, [testSessionCheckOutcomeId uppercaseString]];
    return [self executeSelectSingle:TABLE_TEST_SESSION_CHECK_OUTCOME withSelect:@"*" withWhere:where];
}

#pragma mark - Test Session Electrical Supply System

- (NSArray *)getTestSessionElectricalSupplySystems
{
    // Returns all records from the TestSessionElectricalSupplySystem table
    
    return [self executeSelectAll:TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getTestSessionElectricalSupplySystemById:(NSString *)testSessionElectricalSupplySystemId
{
    // Returns the record from the TestSessionElectricalSupplySystem table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM_COLUMN_ID, [testSessionElectricalSupplySystemId uppercaseString]];
    return [self executeSelectSingle:TABLE_TEST_SESSION_ELECTRICAL_SUPPLY_SYSTEM withSelect:@"*" withWhere:where];
}

#pragma mark - Test Session Location

- (NSArray *)getTestSessionLocations
{
    // Returns all records from the TestSessionLocation table
    
    return [self executeSelectAll:TABLE_TEST_SESSION_LOCATION withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_TEST_SESSION_LOCATION_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getTestSessionLocationById:(NSString *)testSessionLocationId
{
    // Returns the record from the TestSessionLocation table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_TEST_SESSION_LOCATION_COLUMN_ID, [testSessionLocationId uppercaseString]];
    return [self executeSelectSingle:TABLE_TEST_SESSION_LOCATION withSelect:@"*" withWhere:where];
}

#pragma mark - Test Session Status

- (NSArray *)getTestSessionStatuses
{
    // Returns all records from the TestSessionStatus table
    
    return [self executeSelectAll:TABLE_TEST_SESSION_STATUS withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_TEST_SESSION_STATUS_COLUMN_NAME]];
}

- (NSDictionary *)getTestSessionStatusByName:(NSString *)testSessionStatusName
{
    // Returns the record from the TestSessionStatus table matching the filter on the Name field
    
    NSString *where = [NSString stringWithFormat:@"%@ = '%@'", TABLE_TEST_SESSION_STATUS_COLUMN_NAME, testSessionStatusName];
    return [self executeSelectSingle:TABLE_TEST_SESSION_STATUS withSelect:@"*" withWhere:where];
}

- (NSDictionary *)getTestSessionStatusById:(NSString *)testSessionStatusId
{
    // Returns the record from the TestSessionStatus table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_TEST_SESSION_STATUS_COLUMN_ID, [testSessionStatusId uppercaseString]];
    return [self executeSelectSingle:TABLE_TEST_SESSION_STATUS withSelect:@"*" withWhere:where];
}

#pragma mark - Test Session Test

- (BOOL)addRowsToTestSessionTest:(NSArray *)rows
{
    // Inserts a number of records into the TestSessionTest table, using the collection of dictionaries supplied
    
    self.successFlag = YES;
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self getDatabasePath]];
    [queue inDatabase:^(FMDatabase *database) {
        for (NSDictionary *row in rows) // this is actually test session rows we are looping
        {
            if ([row keyIsNotMissingOrNull:JSON_TESTS])
            {
                // Extract the tests from the test session row
                NSArray *tests = [NSArray arrayWithArray:[row objectForKey:JSON_TESTS]];
                for (NSDictionary *test in tests) {
                    if ([test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_ID]) {
                        if (![self addRowToTestSessionTest:test forTestSessionId:[row objectForKey:TABLE_TEST_SESSION_COLUMN_ID] withDatabase:database])
                        {
                            self.successFlag = NO;
                            break;
                        }
                    }
                }
            }
            // If there are no tests, which is possible & correct, then do nothing
        }
    }];
    
    return self.successFlag;
}

- (BOOL)addRowToTestSessionTest:(NSDictionary *)row forTestSessionId:(NSString *)testSessionId withDatabase:(FMDatabase *)database
{
    // Inserts a record into the TestSessionTest table, using the data in the dictionary supplied
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] initWithDictionary:row];
    
    // Get all the nested JSON objects
    
    // Test Session
    NSDictionary *testSessionDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:testSessionId, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, nil];
    [parameters addEntriesFromDictionary:testSessionDictionary];
    [testSessionDictionary release];
    
    // Test Type
    NSString *testTypeId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID] ? [row objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_TEST_TYPE])
        testTypeId = [[row objectForKey:JSON_TEST_TYPE] nullableObjectForKey:TABLE_TEST_TYPE_COLUMN_ID];
    NSDictionary *testTypeDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(testTypeId == nil) ? [NSNull null] : testTypeId, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID, nil];
    [parameters addEntriesFromDictionary:testTypeDictionary];
    [testTypeDictionary release];
    
    // Document
    NSString *documentId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID] ? [row objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_DOCUMENT])
        documentId = [[row objectForKey:JSON_DOCUMENT] nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID];
    NSDictionary *documentDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(documentId == nil) ? [NSNull null] : documentId, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, nil];
    [parameters addEntriesFromDictionary:documentDictionary];
    [documentDictionary release];
    
    // Result
    NSString *resultId = [row keyIsNotMissingOrNull: TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID] ? [row objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID] : nil;
    if ([row keyIsNotMissingOrNull:JSON_RESULT])
        resultId = [[row objectForKey:JSON_RESULT] nullableObjectForKey:TABLE_TEST_RESULT_COLUMN_ID];
    NSDictionary *resultDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(resultId == nil) ? [NSNull null] : resultId, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID, nil];
    [parameters addEntriesFromDictionary:resultDictionary];
    [resultDictionary release];
    
    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES (:%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, 0, 0, 0)", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE, TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_START_DATE, TABLE_TEST_SESSION_TEST_COLUMN_END_DATE, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID];
    
    BOOL result = YES;
    
    // Set null values for any missing fields required by the db insert
    NSArray *keys = [[[NSArray alloc] initWithObjects: TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, nil] autorelease];
    
    // First, attempt to save the associated document if one exists, and this document has not already been added for another test
    if ([row keyIsNotMissingOrNull:JSON_DOCUMENT] && [[row objectForKey:JSON_DOCUMENT] keyIsNotMissingOrNull:TABLE_DOCUMENT_COLUMN_ID] && result)
    {
        NSDictionary *existingDocument = [self getDocumentById:[[row objectForKey:JSON_DOCUMENT] nullableObjectForKey:TABLE_DOCUMENT_COLUMN_ID]];
        if (![existingDocument count])
        {
            result = [self addRowToDocument:[row objectForKey:JSON_DOCUMENT] fileSystemDirectory:nil isNew:YES requiresDataSync:NO withDatabase:database];
        }
    }
    
    // Next, save the test itself
    if (result)
        result = [database executeUpdate:query withParameterDictionary:[[parameters addNullValuesForKeys:keys] convertDatesToLongDateTimeUtcString]];
    
    [parameters release];
    return result;
}

- (NSString *)getTestSessionTestSelect
{
    return [NSString stringWithFormat:@"%@.*, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@, %@.%@ AS %@",
            TABLE_TEST_SESSION_TEST,
            TABLE_TEST_TYPE, TABLE_TEST_TYPE_COLUMN_NUMBER, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NUMBER,
            TABLE_TEST_TYPE, TABLE_TEST_TYPE_COLUMN_NAME, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_NAME,
            TABLE_TEST_TYPE, TABLE_TEST_TYPE_COLUMN_ENFORCE_INSTRUMENT_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ENFORCE_INSTRUMENT_REFERENCE,
            TABLE_TEST_RESULT, TABLE_TEST_RESULT_COLUMN_NAME, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_NAME,
            TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_FILE_PATH, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_FILE_PATH,
            TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_NAME,
            TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE];
}

- (NSString *)getTestSessionTestTables
{
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@ LEFT JOIN %@ ON %@.%@ = %@.%@",
            TABLE_TEST_SESSION_TEST,
            TABLE_TEST_TYPE, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID, TABLE_TEST_TYPE, TABLE_TEST_TYPE_COLUMN_ID,
            TABLE_TEST_RESULT, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID, TABLE_TEST_RESULT, TABLE_TEST_RESULT_COLUMN_ID,
            TABLE_DOCUMENT, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID,
            TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID];
}

- (NSDictionary *)getTestSessionTestById:(NSString *)testSessionTestId
{
    // Returns the record from the TestSessionTest table matching the filter on the Id field
    
    NSString *select = [self getTestSessionTestSelect];
    NSString *tables = [self getTestSessionTestTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_ID, [testSessionTestId uppercaseString]];
    
    return [self executeSelectSingle:tables withSelect:select withWhere:where];
}

- (NSArray *)getTestSessionTestsForTestSessionId:(NSString *)testSessionId
{
    // Returns all records from the TestSessionTest table matching the filter on the TestSession_id field
    
    NSString *select = [self getTestSessionTestSelect];
    NSString *tables = [self getTestSessionTestTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@, %@.%@, %@.%@", TABLE_TEST_TYPE, TABLE_TEST_TYPE_COLUMN_NUMBER, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DATE_CREATED];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (NSArray *)getTestSessionTestsForDocumentId:(NSString *)documentId
{
    // Returns all records from the TestSessionTest table matching the filter on the Document_id field
    
    NSString *select = [self getTestSessionTestSelect];
    NSString *tables = [self getTestSessionTestTables];
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, [documentId uppercaseString]];
    NSString *orderBy = [NSString stringWithFormat:@"%@.%@", TABLE_TEST_TYPE, TABLE_TEST_TYPE_COLUMN_NUMBER];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

- (BOOL)createTestSessionTestWithRow:(NSMutableDictionary *)row requiresDataSync:(BOOL)requiresDataSync
{
    // Inserts a record into the TestSessionTest table, using the data in the dictionary supplied
    
    NSString *uuid = [[NSString stringWithUUID] lowercaseString];
    
    // Set null values for any missing fields required by the db insert
    // Strictly speaking the extension is for NSDictionary, but it can be applied to an NSMutableDictionary too
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID,
                      TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID,
                      TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID,
                      TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE,
                      TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE,
                      TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE,
                      TABLE_TEST_SESSION_TEST_COLUMN_START_DATE,
                      TABLE_TEST_SESSION_TEST_COLUMN_END_DATE,
                      TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    NSString *dataSyncFlag = requiresDataSync ? @"1" : @"0";

    // Execute
    NSString *query = [NSString stringWithFormat:@"INSERT INTO %@ VALUES ('%@', :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, :%@, 0, %@, 1)", TABLE_TEST_SESSION_TEST, uuid, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE, TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_START_DATE, TABLE_TEST_SESSION_TEST_COLUMN_END_DATE, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID, dataSyncFlag];
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    
    // If operation has succeeded and a sync is required, schedule a sync pending notification
    if (result && requiresDataSync)
        [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return result;
}

- (BOOL)updateTestSessionTestWithRow:(NSDictionary *)row
{
    // Updates a record in the TestSessionTest table, using the data in the dictionary supplied
    
    NSArray *keys = [[[NSArray alloc] initWithObjects:
                      TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE,
                      TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE,
                      TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE,
                      nil] autorelease];
    row = [row addNullValuesForKeys:keys];
    
    NSString *query = [NSString stringWithFormat: @"UPDATE %@ SET %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = :%@, %@ = 1 WHERE %@ = :%@", TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_INSTRUMENT_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE, TABLE_TEST_SESSION_TEST_COLUMN_VOLTAGE, TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_CIRCUIT_BREAKER_REFERENCE, TABLE_TEST_SESSION_TEST_COLUMN_START_DATE, TABLE_TEST_SESSION_TEST_COLUMN_START_DATE, TABLE_TEST_SESSION_TEST_COLUMN_END_DATE, TABLE_TEST_SESSION_TEST_COLUMN_END_DATE, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID, TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID, TABLE_COMMON_REQUIRES_DATA_SYNC, TABLE_TEST_SESSION_TEST_COLUMN_ID, TABLE_TEST_SESSION_TEST_COLUMN_ID];
    
    BOOL result = [self executeUpdate:query withParameterDictionary:row];
    
    [[LocalNotificationsScheduler sharedInstance] scheduleSyncPendingNotification];
    
    return result;
}

- (BOOL)deleteTestSessionTestById:(NSString *)testSessionTestId
{
    // Deletes a record from the TestSessionTest table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_TEST_SESSION_TEST_COLUMN_ID, [testSessionTestId uppercaseString]];
    return [self executeDelete:TABLE_TEST_SESSION_TEST withWhere:where];
}

- (BOOL)deleteTestSessionTestsForTestSessionId:(NSString *)testSessionId
{
    // Deletes all records from the TestSessionTest table matching the filter on the TestSession_Id field
    
    NSString *where = [NSString stringWithFormat:@" UPPER(%@) = '%@' ", TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID, [testSessionId uppercaseString]];
    return [self executeDelete:TABLE_TEST_SESSION_TEST withWhere:where];
}

- (NSArray *)requiresSyncDataForTestSessionTests
{
    // Returns all records from the TestSessionTest table that have not yet been synced up to the server
    
    NSMutableArray *allTests = [[NSMutableArray alloc] initWithArray: [self executeSelectAll:[NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@", TABLE_TEST_SESSION_TEST, TABLE_DOCUMENT, TABLE_TEST_SESSION_TEST, TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_ID] withSelect:[NSString stringWithFormat:@"%@.*, %@.%@", TABLE_TEST_SESSION_TEST, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DATE_CREATED] withWhere:[NSString stringWithFormat:@"%@.%@ = 1", TABLE_TEST_SESSION_TEST, TABLE_COMMON_REQUIRES_DATA_SYNC] withOrderBy:[NSString stringWithFormat:@"%@.%@ ASC, %@.%@ ASC", TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_DATE_CREATED, TABLE_DOCUMENT, TABLE_DOCUMENT_COLUMN_FILE_NAME]]];
    // File name used in ordering if dates are identical
    // Ordering is reflected in Api to provide consistency

    
    for (NSMutableDictionary *test in allTests)
    {
        // Test Session Id
        if ([test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID])
            [test setObject:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID] forKey:JSON_TEST_SESSION_TEST_ATTRIBUTE_TEST_SESSION_ID];
        
        // Test Type Id
        if ([test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID])
            [test setObject:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_TYPE_ID] forKey:JSON_TEST_SESSION_TEST_ATTRIBUTE_TEST_TYPE_ID];
        
        // Result Id
        if ([test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID])
            [test setObject:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_RESULT_ID] forKey:JSON_TEST_SESSION_TEST_ATTRIBUTE_RESULT_ID];
        
        // Last Device Used
        @autoreleasepool {
            NSDictionary *testSession = [self getTestSessionById:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_TEST_SESSION_ID]];
            NSString *lastDeviceUsed = [testSession nullableObjectForKey:TABLE_TEST_SESSION_COLUMN_LAST_DEVICE_USED];
            [test setObject:lastDeviceUsed forKey:JSON_TEST_SESSION_TEST_ATTRIBUTE_LAST_DEVICE_USED];
        }
        
        // Document
        if ([test keyIsNotMissingNullOrEmpty:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID])
        {
            // Autoreleasepool required here because the getDocumentById: call opens the sqlite database each time
            // Even though the dictionaryWithDictionary: method using this implicitly creates an autoreleased dictionary object,
            // as we are currently within a loop, the autorelease is not called until the full loop has completed
            // This means that after 78 documents, iOS's internal limit of open files is reached
            // The autorelease simply flushes the autoreleasepool immediately, releasing the database file each time
            @autoreleasepool {
                NSDictionary *document = [self getDocumentById:[test objectForKey:TABLE_TEST_SESSION_TEST_COLUMN_DOCUMENT_ID]];
                
                if (![[document nullableObjectForKey:TABLE_DOCUMENT_COLUMN_FILE_PATH] isEqualToString:@""])
                    [test setObject:document forKey:JSON_DOCUMENT];
            }
        }
    }
    
    NSArray *returnArray = [NSArray arrayWithArray:allTests];
    [allTests release];
    
    return returnArray;
}

#pragma mark - Test Session Type

- (NSString *)getTestSessionTypeSelect
{
    // Returns the SELECT part of the standard SQL SELECT query for TestSessionType
    
    return [NSString stringWithFormat:@"%@.*, %@.%@ AS '%@', %@.%@ AS '%@'", TABLE_TEST_SESSION_TYPE, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_NAME, TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_NAME, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_QUALITY_MANAGEMENT_SYSTEM_CODE, TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_QUALITY_MANAGEMENT_SYSTEM_CODE];
}

- (NSString *)getTestSessionTypeTables
{
    // Returns the FROM part of the standard SQL SELECT query for TestSessionType
    
    return [NSString stringWithFormat:@"%@ LEFT JOIN %@ ON %@.%@ = %@.%@", TABLE_TEST_SESSION_TYPE, TABLE_DOCUMENT_TYPE, TABLE_TEST_SESSION_TYPE, TABLE_TEST_SESSION_TYPE_COLUMN_MASTER_DOCUMENT_TYPE_ID, TABLE_DOCUMENT_TYPE, TABLE_DOCUMENT_TYPE_COLUMN_ID];
}

- (NSArray *)getTestSessionTypes
{
    // Returns all records from the TestSessionType table
    
    return [self executeSelectAll:[self getTestSessionTypeTables] withSelect:[self getTestSessionTypeSelect] withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_TEST_SESSION_TYPE_COLUMN_SORT_ORDER]];
}

- (NSDictionary *)getTestSessionTypeById:(NSString *)testSessionTypeId
{
    // Returns the record from the TestSessionType table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@.%@) = '%@'", TABLE_TEST_SESSION_TYPE, TABLE_TEST_SESSION_TYPE_COLUMN_ID, [testSessionTypeId uppercaseString]];
    return [self executeSelectSingle:[self getTestSessionTypeTables] withSelect:[self getTestSessionTypeSelect] withWhere:where];
}

#pragma mark - Test Type

- (NSDictionary *)getTestTypeById:(NSString *)testTypeId
{
    // Returns the record from the TestType table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"UPPER(%@) = '%@'", TABLE_TEST_TYPE_COLUMN_ID, [testTypeId uppercaseString]];
    return [self executeSelectSingle:TABLE_TEST_TYPE withSelect:@"*" withWhere:where];
}

#pragma mark - Works Order

- (NSDictionary *)getWorksOrderById:(NSNumber *)woNumber
{
    // Returns the record from the WorksOrder table matching the filter on the Id field
    
    NSString *where = [NSString stringWithFormat:@"%@ = %ld", TABLE_WORKS_ORDER_COLUMN_ID, [woNumber longValue]];
    return [self executeSelectSingle:TABLE_WORKS_ORDER withSelect:@"*" withWhere:where];
}

- (NSDictionary *)getWorksOrderByWoNumber:(NSNumber *)woNumber
{
    // Returns the record from the WorksOrder table matching the filter on the woNumber field
    
    NSString *where = [NSString stringWithFormat:@"%@ = %ld", TABLE_WORKS_ORDER_COLUMN_WO_NUMBER, [woNumber longValue]];
    return [self executeSelectSingle:TABLE_WORKS_ORDER withSelect:@"*" withWhere:where];
}

- (NSArray *)getWorksOrders
{
    // Returns all records from the WorksOrder table
    
    return [self executeSelectAll:TABLE_WORKS_ORDER withSelect:@"*" withWhere:nil withOrderBy: [NSString stringWithFormat:@"%@ ASC", TABLE_WORKS_ORDER_COLUMN_WO_NUMBER]];
}

- (NSArray *)searchWorksOrderByWorksOrderNumber:(NSString *)searchText
{
    // Returns all records from the WorksOrder table matching the search filter
    
    NSString *select = [NSString stringWithFormat:@"DISTINCT %@.%@, %@.%@, %@.*", TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_ID, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_WO_NUMBER, TABLE_BRANCH];
    NSString *tables = [NSString stringWithFormat:@"%@ INNER JOIN %@ ON %@.%@ = %@.%@ INNER JOIN %@ ON %@.%@ = %@.%@", TABLE_WORKS_ORDER, TABLE_EQUIPMENT, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_ID, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_WORKS_ORDER_ID, TABLE_BRANCH, TABLE_EQUIPMENT, TABLE_EQUIPMENT_COLUMN_BRANCH_ID, TABLE_BRANCH, TABLE_BRANCH_COLUMN_ID];
    NSString *where = [NSString stringWithFormat:@" LENGTH('%@') > 0 AND %@.%@ LIKE '%@%@%@' %@ ", searchText, TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_WO_NUMBER, @"%", searchText, @"%",
            [self loggedInUserIsSubcontractor]
                 ? [NSString stringWithFormat:@" AND %@.%@ IN (%@) ", TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_ID, [self getSubcontractorWorksOrderIdFilterForLoggedInUser]]
                 : @""
        ];
    NSString *orderBy = [NSString stringWithFormat:@" %@.%@ ASC", TABLE_WORKS_ORDER, TABLE_WORKS_ORDER_COLUMN_WO_NUMBER];
    
    return [self executeSelectAll:tables withSelect:select withWhere:where withOrderBy:orderBy];
}

@end
