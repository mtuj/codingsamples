#import "ApiDefines.h"
#import "ApiManager.h"
#import "AppDelegate.h"
#import "AppSettings.h"
#import "EnumerateExtensions.h"
#import "NSCharacterSet+Extensions.h"
#import "NSNumber+Extensions.h"
#import "NSString+Extensions.h"
#import "OAuthManager.h"
#import "ReachabilityManager.h"
#import "RegisterUserViewController.h"
#import "SyncManager.h"
#import "UserManager.h"

@implementation ApiManager {
    NSInteger _statusCode;
    apiMethods _apiMethod;
    httpMethods _httpMethod;
}

@synthesize delegate = _delegate;
@synthesize responseData = _responseData;
@synthesize apiConnection = _apiConnection;

#pragma mark - Initialisation

- (id)init
{
    if (self = [super init]) {
        NSMutableData *responseData = [[NSMutableData alloc] init];
        self.responseData = responseData;
        [responseData release];
    }
    return self;
}

#pragma mark - Api methods

- (void)getDataFromApiMethod:(apiMethods)apiMethod withUrlSegments:(NSArray *)urlSegments withQueryString:(NSString *)queryString
{
    // Send a GET request using the API method and querystring parameter specified
    _apiMethod = apiMethod;
    _httpMethod = GET;
    [self genericApiMethod:apiMethod withUrlSegments:urlSegments withQueryString:queryString withPostData:nil];
}

- (void)postDataToApiMethod:(apiMethods)apiMethod withPostData:(id)postData
{
    // Send a POST request using the API method and post data specified
    _apiMethod = apiMethod;
    _httpMethod = POST;
    [self genericApiMethod:apiMethod withUrlSegments:nil withQueryString:nil withPostData:postData];
}

- (void)putDataToApiMethod:(apiMethods)apiMethod withUrlSegments:(NSArray *)urlSegments withPostData:(id)postData
{
    // Send a PUT request using the API method and post data specified
    _apiMethod = apiMethod;
    _httpMethod = PUT;
    [self genericApiMethod:apiMethod withUrlSegments:urlSegments withQueryString:nil withPostData:postData];
}

- (void)genericApiMethod:(apiMethods)apiMethod withUrlSegments:(NSArray *)urlSegments withQueryString:(NSString *)queryString withPostData:(id)postData
{
    // Generic API request generation method
    
    // Get the relevant API method from the app method parameter
    NSString *apiMethodToCall = [EnumerateExtensions apiMethodNameEnumToString:apiMethod];
    if (apiMethodToCall == nil)
        [self.delegate invalidApiMethod];
    
    // Check that the Api is reachable
    // Note we skip this check if the HTTP request originated from the Register Users view
    // as otherwise this creates a massive security hole by allowing the user straight in
    else if ([[ReachabilityManager sharedInstance] isTheApiReachable] == YES || [self.delegate isKindOfClass:[RegisterUserViewController class]])
    {
        AppSettings *appSettings = [AppSettings sharedInstance];
        UserManager *userManager = [UserManager sharedInstance];
        NSError *error = nil;
        
        // Build up additional segments
        NSString *normalisedUrlSegments = @"";
        if (urlSegments != nil && [urlSegments count] > 0)
            normalisedUrlSegments = [NSString stringWithFormat:@"/%@", [urlSegments componentsJoinedByString:@"/"]];
        
        // Build up query string
        NSString *fullQueryString = nil;
        NSString *normalisedQueryString = @"";
        if (queryString != nil)
            fullQueryString = queryString;
        
        // Add OData query string parameters if applicable
        NSString *oDataQueryString = postData == nil ? [EnumerateExtensions oDataGetQueryStringForApiMethodNameEnum:apiMethod] : [EnumerateExtensions oDataPostQueryStringForApiMethodNameEnum:apiMethod];
        if (oDataQueryString != nil) {
            fullQueryString = [NSString stringWithFormat:@"%@%@",
                                        fullQueryString != nil ? [NSString stringWithFormat:@"%@&", fullQueryString] : @"",
                                        oDataQueryString];
        }
        
        // This is normalising the sent in querystring parameters to include the ?
        normalisedQueryString = fullQueryString != nil ? [NSString stringWithFormat:@"?%@", fullQueryString] : @"";
        
        // Build up the full url for the API request
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",[appSettings apiBaseUrl], apiMethodToCall, normalisedUrlSegments, normalisedQueryString];
        NSString *urlStringEncoded = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet urlAllowedCharacterSet]];
        NSURL *url = [NSURL URLWithString:urlStringEncoded];

        NSLog(@"URL: %@", url);
        
        // Create the request object
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        [request setTimeoutInterval:(appSettings.apiTimeoutMinutes * 60)];
        
        // FOR EVERY REQUEST - Add the OAuth Authorization header
        OAuthManager *oAuthManager = [[OAuthManager alloc] init];
        NSString *authorizationHeaderValue = [oAuthManager generateAuthorizationHeaderValue:_httpMethod forUrl:url withQuerystring:fullQueryString];
        [oAuthManager release];
        [request setValue:authorizationHeaderValue forHTTPHeaderField:@"Authorization"];

        // FOR EVERY REQUEST - Add BearerToken header
        NSString *bearerToken = [NSString stringWithString: [NSString stringWithFormat:@"%@", [userManager getLoggedInUsersToken]]];
        [request setValue:bearerToken forHTTPHeaderField:@"BearerToken"];
        
        // FOR EVERY REQUEST - Set the content type we accept back from the API
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        // FOR EVERY REQUEST - Set HTTP method
        [request setHTTPMethod:[EnumerateExtensions httpMethodEnumToString:_httpMethod]];
        
        // For POST requests, add required data
        if (postData != nil)
        {
            // POST body data
            NSData *postBody = [NSJSONSerialization dataWithJSONObject:postData options:kNilOptions error:&error];
            [request setHTTPBody:postBody];
            
            // The content length for good practice
            NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postBody length]];
            [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        }

        // Create the URL session, delegate methods will handle response
        
        // We start by creating a session configuration object
        // The session configuration has properties like allowsCellularAccess and HTTPAdditionalHeaders
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        // Then we create a session object
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        
        // The last object we create is a task - this is analagous to the NSURLConnection
        // The difference is that rather than each individual connection having a separate
        // delegate and properties, all of the tasks are owned by the Session object, which has
        // a single delegate to handle the callbacks for all inflight tasks
        NSURLSessionTask *task = [session dataTaskWithRequest:request];
        
        // We tell the task to start doing work by sending it - resume
        // and then the tasks will delegate work back to the Session object as needed
        [task resume];
        
        [request release];
    }
    else 
    {
        [[ReachabilityManager sharedInstance] showUnreachableAlert];
        [self.delegate apiIsUnreachable];
    }
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    // Delegate method to handle HTTP response received from the API

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    _statusCode = [httpResponse statusCode];
    NSLog(@"Response Received: %ld", (long)[httpResponse statusCode]);
    [self.responseData setLength:0];
    
    // For successful SyncManager PUT (or equipment update) requests there is no response data, so pass on the status code only
    // Note this filters out Equipment create requests, for which we need to parse the returned object to obtain the new Id
    if ([self.delegate isKindOfClass:[SyncManager class]] && (_httpMethod == PUT || _apiMethod == EquipmentUploadUpdate) && [[NSNumber numberWithInteger:[httpResponse statusCode]] isHttpSuccessStatusCode])
    {
        [dataTask cancel];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *responseData = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:[httpResponse statusCode]] forKey:API_STATUS_CODE];
            [self.delegate didGetParsedData:responseData apiMethod:_apiMethod httpMethod:_httpMethod];
        });
        return;
    }

    // Check for a Forbidden response
    // Note we only invoke the app delegate's [unAuthorisedAccess] method if the HTTP request did NOT originate from the Register Users view
    // as that view actually relies on a forbidden response, to test whether or not the user has a valid bearer token in the system
    if ([httpResponse statusCode] == 403 || ([httpResponse statusCode] == 401 && ![self.delegate isKindOfClass:[RegisterUserViewController class]]))
    {
        // Cancel the connection and log the user out
        [dataTask cancel];
        dispatch_async(dispatch_get_main_queue(), ^{
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate unAuthorisedAccess];
        });
        return;
    }
    
    // Continue data task
    // This basically allows the other NSURLSession delegate methods to proceed
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // Delegate method to handle data received via an HTTP response from the API

    [self.responseData appendData:data];
    NSLog(@"Did Receive Data - size: %lu", (unsigned long)[self.responseData length]);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // Delegate method called when the data transfer is complete

    // As the data task runs on the background thread, we need to execute any code that modifies the Ui elements on the main thread
    // http://stackoverflow.com/questions/28302019/getting-a-this-application-is-modifying-the-autolayout-engine-error
    // https://stackoverflow.com/questions/35594376/this-application-is-modifying-the-autolayout-engine-from-a-background-thread-wh
    
    if (error)
    {
        NSLog(@"ERROR: %@", error.description);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error.code >= -1009 && error.code <= -1003)
                // Specific error for loss of network connection
                [self.delegate networkConnectionLostWithError:error apiMethod:_apiMethod];
            else
                [self.delegate didFailToGetParsedData];
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            id parsedData;
            NSError *jsonError = nil;
            // If we are calling the EngineerAppSqliteDatabase Api method, we only get the raw content, not JSON data
            if (_apiMethod == EngineerAppSqliteDatabase)
                parsedData = self.responseData;
            else
                parsedData = [NSJSONSerialization JSONObjectWithData:self.responseData options:kNilOptions error:&jsonError];
            
            // Call the relevant delegate method depending on whether the data transfer was successful or not
            if (parsedData == nil)
                [self.delegate didFailToGetParsedData];
            else {
                if (_statusCode && _statusCode == 409 && [self.delegate respondsToSelector:@selector(didReportConflictWithData:)])
                    // Conflict response and delegate responds to the conflict method, so call this
                    [self.delegate didReportConflictWithData:parsedData];
                else if (![[NSNumber numberWithInteger:_statusCode] isHttpSuccessStatusCode])
                    // Unsuccessful api response
                    [self.delegate didReceiveUnsuccessfulStatusCode];
                else
                    // Success response so call the standard data handling delegate method
                    [self.delegate didGetParsedData:parsedData apiMethod:_apiMethod httpMethod:_httpMethod];
            }
        });
    }
}

#pragma mark - Deallocation

- (void)dealloc
{
    [_responseData release];
    [_apiConnection release];

    [super dealloc];
}

@end
