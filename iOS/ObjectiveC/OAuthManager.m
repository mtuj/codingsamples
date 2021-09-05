#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import "AppSettings.h"
#import "EnumerateExtensions.h"
#import "NSData+Base64.h"
#import "NSString+Extensions.h"
#import "OAuthManager.h"

@implementation OAuthManager

- (NSString *)generateAuthorizationHeaderValue:(httpMethods)httpMethod forUrl:(NSURL *)url withQuerystring:(NSString *)clientQuerystring
{
    AppSettings *appSettings = [AppSettings sharedInstance];

    // Creates the user and OAuth querystring, this is only needed for the OAuth signature and is NOT to be added to the actual URLs querystring.
    NSDictionary *oAuthQuerystringDictionary = [self buildOAuthQuerystringDictionary:clientQuerystring];
    NSString *oAuthQuerystring = [self createOAuthQuerystring:oAuthQuerystringDictionary];

    // Get the OAuth signature
    NSString *signature = [self generateSignature:httpMethod forUrl:url withConsumerKey:[appSettings oAuthPublicKey] withConsumerSecret:[appSettings oAuthPrivateKey] withTokenSecret:@"" withTimestap:[oAuthQuerystringDictionary objectForKey:OAuthTimestampKey] withNonce:[oAuthQuerystringDictionary objectForKey:OAuthNonceKey] withquerystring:oAuthQuerystring];
    
    NSMutableString *authorizationHeaderValue = [[[NSMutableString alloc] initWithFormat:@"OAuth %@=%@", OAuthSignatureKey, [signature escapeUriDataStringRfc3986]] autorelease];
    [authorizationHeaderValue appendFormat:@",%@=%@", OAuthConsumerKeyKey, [oAuthQuerystringDictionary objectForKey:OAuthConsumerKeyKey]];
    [authorizationHeaderValue appendFormat:@",%@=%@", OAuthTimestampKey, [oAuthQuerystringDictionary objectForKey:OAuthTimestampKey]];
    [authorizationHeaderValue appendFormat:@",%@=%@", OAuthNonceKey, [oAuthQuerystringDictionary objectForKey:OAuthNonceKey]];
    [authorizationHeaderValue appendFormat:@",%@=%@", OAuthSignatureMethodKey, [oAuthQuerystringDictionary objectForKey:OAuthSignatureMethodKey]];
    [authorizationHeaderValue appendFormat:@",%@=%@", OAuthVersionKey, [oAuthQuerystringDictionary objectForKey:OAuthVersionKey]];

    return  authorizationHeaderValue;
}

- (NSString *) generateSignature:(httpMethods)forHttpMethod forUrl:(NSURL *)url withConsumerKey:(NSString *)consumerKey withConsumerSecret:(NSString *)consumerSecret withTokenSecret:(NSString *)tokenSecret withTimestap:(NSNumber *)timestamp withNonce:(NSString *)nonce withquerystring:(NSString *)oAuthQuerystring
{
    // Normalise the url.
    NSString *normalisedUrl = [NSString stringWithFormat:@"%@://%@%@", [url.scheme lowercaseString], [url.host lowercaseString], url.path];

    // Generate the signature base.
    NSMutableString *signatureBase = [[[NSMutableString alloc] init] autorelease];
    [signatureBase appendFormat:@"%@&", [EnumerateExtensions httpMethodEnumToString:forHttpMethod]];
    [signatureBase appendFormat:@"%@&", [normalisedUrl escapeUriDataStringRfc3986]];
    [signatureBase appendString: [oAuthQuerystring escapeUriDataStringRfc3986]];
    
    // Generate the crypto key.
    NSString *key = [NSString stringWithFormat:@"%@&%@", [consumerSecret escapeUriDataStringRfc3986], [tokenSecret escapeUriDataStringRfc3986]];

    // Next HMAC hash the signature base with the crypto key.
    NSString *hash = [self HMACSHA1HashBase64Encoded:key andData:signatureBase];

    return hash;
}

- (NSString *) HMACSHA1HashBase64Encoded :(NSString *) key andData: (NSString *) data
{
    // Key and data transformations.
    const char *cKey  = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];

    // To hold the hash.
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];

    // Lets create the hash now.
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);

    // Convert hash to bytes.
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];

    // base 64 encode now.
    NSString *hash = [HMAC base64EncodedString];
    [HMAC release];

    // return the base 64 encoded hash.
    return hash;
}

- (NSDictionary *) buildOAuthQuerystringDictionary:(NSString *)clientQuerystring
{
    AppSettings *appSettings = [AppSettings sharedInstance];

    // Notice there is no initialisation with the standard ? character.
    // This is because the OAuth querystring we are creating is not a true querystring.
    // It represents the querystring part of the url, but does not start with a ?
    // OAuth uses unescaped & twice, to create three parts to the Authorization header;
    // 1.  The verb
    // 2.  The host
    // 3.  The querystring
    NSMutableDictionary *oAuthQuerystringDictionary = [[[NSMutableDictionary alloc] init] autorelease];

    if (clientQuerystring != nil)
    {
        // Adding all the original client created querystring parameters first.
        NSArray *originalParts = [clientQuerystring componentsSeparatedByString:@"&"];
        for (NSString *part in originalParts)
        {
            NSArray *keyValues = [part componentsSeparatedByString:@"="];
            [oAuthQuerystringDictionary setObject:[keyValues objectAtIndex:1] forKey:[keyValues objectAtIndex:0]];
        }
    }

    // Now add all the OAuth parameters.
    NSString *encodedConsumerKey = [[NSString stringWithFormat:@"%@", [appSettings oAuthPublicKey]] escapeUriDataStringRfc3986];
    NSString *encodedNonce = [[NSString stringWithFormat:@"%@", [NSString stringWithUUID]] escapeUriDataStringRfc3986];
    
    [oAuthQuerystringDictionary setObject:encodedConsumerKey forKey:OAuthConsumerKeyKey];
    [oAuthQuerystringDictionary setObject:encodedNonce forKey:OAuthNonceKey];
    [oAuthQuerystringDictionary setObject:@"HMAC-SHA1" forKey:OAuthSignatureMethodKey];
    
    // do NOT change this format to from int to double.  OAuth needs an int.
    NSInteger timeStampKey = [[[[NSNumber alloc] initWithDouble:[[NSDate date] timeIntervalSince1970]] autorelease] integerValue];
    [oAuthQuerystringDictionary setObject:[NSString stringWithFormat:@"%ld", (long)timeStampKey] forKey:OAuthTimestampKey];// this is seconds.
    
    [oAuthQuerystringDictionary setObject:@"1.0" forKey:OAuthVersionKey];

    return oAuthQuerystringDictionary;
}

- (NSString *) createOAuthQuerystring:(NSDictionary *)querystringDictionary
{
    // Get an array of the ordered keys.
    // NB OAuth specifies the ordering should be a-z by key then for length for values.
    // Here only Key sorting is being performed.
    NSMutableArray *sortedKeys = [[NSMutableArray alloc] initWithArray:[querystringDictionary allKeys]];
    [sortedKeys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    // Read the notes in buildOAuthQuerystringDictionary to fully understand format.
    NSMutableString *returnOAuthQuerystring = [[[NSMutableString alloc] initWithString:@""] autorelease];

    // Loop around sorted keys and get the value from the dictionary and append to the querystring.
    for (NSString *key in sortedKeys)
    {
        // Apply URL encoding to both keys and values
        [returnOAuthQuerystring appendFormat:@"%@=%@&", [key escapeUriDataStringRfc3986], [[querystringDictionary objectForKey:key] escapeUriDataStringRfc3986]];
    }

    [sortedKeys release];

    // Remove last & from the loop adding parameters.
    return [returnOAuthQuerystring substringToIndex:[returnOAuthQuerystring length] - 1];
}

@end
