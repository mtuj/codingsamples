import CommonCrypto
import Foundation

class OAuthManager {

    func generateAuthorizationHeaderValue(httpMethod: HttpMethod, url: NSURL, queryString: String?) -> String {
        
        let appSettings = AppSettings()
        
        // Creates the user and OAuth querystring, this is only needed for the OAuth signature and is NOT to be added to the actual URLs querystring.
        let oAuthQueryStringDictionary = self.buildOAuthQuerystringDictionary(clientQueryString: queryString)
        let oAuthQueryString = self.createOAuthQuerystring(queryStringDictionary: oAuthQueryStringDictionary)
        
        // Get the OAuth signature
        let signature = self.generateSignature(httpMethod: httpMethod, url: url, consumerKey: appSettings.oAuthPublicKey, consumerSecret: appSettings.oAuthPrivateKey, tokenSecret: "", timeStamp: oAuthQueryStringDictionary[OAuthDefinitions.TimeStampKey] as! Int64, nonce: oAuthQueryStringDictionary[OAuthDefinitions.NonceKey] as! String, queryString: oAuthQueryString)

        var authorizationHeaderValue = "OAuth \(OAuthDefinitions.SignatureKey)=\(signature.escapeUriDataStringRfc3986)"
        authorizationHeaderValue += ",\(OAuthDefinitions.ConsumerKeyKey)=\(oAuthQueryStringDictionary[OAuthDefinitions.ConsumerKeyKey] ?? "")"
        authorizationHeaderValue += ",\(OAuthDefinitions.TimeStampKey)=\(oAuthQueryStringDictionary[OAuthDefinitions.TimeStampKey] ?? "")"
        authorizationHeaderValue += ",\(OAuthDefinitions.NonceKey)=\(oAuthQueryStringDictionary[OAuthDefinitions.NonceKey] ?? "")"
        authorizationHeaderValue += ",\(OAuthDefinitions.SignatureMethodKey)=\(oAuthQueryStringDictionary[OAuthDefinitions.SignatureMethodKey] ?? "")"
        authorizationHeaderValue += ",\(OAuthDefinitions.VersionKey)=\(oAuthQueryStringDictionary[OAuthDefinitions.VersionKey] ?? "")"
        
        return authorizationHeaderValue
    }
    
    func generateSignature(httpMethod: HttpMethod, url: NSURL, consumerKey: String, consumerSecret: String, tokenSecret: String, timeStamp: Int64, nonce: String, queryString: String) -> String {

        // Normalise the url.
        guard let scheme = url.scheme?.lowercased(),
            let host = url.host?.lowercased(),
                let path = url.path else {
            return ""
        }
        let normalisedUrl = "\(scheme)://\(host)\(path)"

        // Generate the signature base.
        var signatureBase = ""
        signatureBase += "\(httpMethod.method)&"
        signatureBase += "\(normalisedUrl.escapeUriDataStringRfc3986)&"
        signatureBase += queryString.escapeUriDataStringRfc3986

        // Generate the crypto key.
        let key = "\(consumerSecret.escapeUriDataStringRfc3986)&\(tokenSecret.escapeUriDataStringRfc3986)"

        // Next HMAC hash the signature base with the crypto key.
        let hash = self.HMACSHA1HashBase64Encoded(key:key, data:signatureBase)
 
        return hash;
    }
    
    func HMACSHA1HashBase64Encoded(key: String, data: String) -> String {
        // https://ios.developreference.com/article/19597072/Implementing+HMAC+and+SHA1+encryption+in+swift
        
        // Key and data transformations.
        let cKey = key.cString(using: String.Encoding.utf8)
        let cData = data.cString(using: String.Encoding.utf8)
        
        // To hold the hash.
        var result = [CUnsignedChar](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        // Lets create the hash now.
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), cKey!, Int(strlen(cKey!)), cData!, Int(strlen(cData!)), &result)
        
        // Convert hash to bytes.
        let hmacData:NSData = NSData(bytes: result, length: (Int(CC_SHA1_DIGEST_LENGTH)))

        // Base 64 encode now.
        let hmacBase64 = hmacData.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength76Characters)
        
        // Return the base 64 encoded hash.
        return hmacBase64
    }

    func buildOAuthQuerystringDictionary(clientQueryString: String?) -> [String : Any] {
        let appSettings = AppSettings()
        
        // Notice there is no initialisation with the standard ? character.
        // This is because the OAuth querystring we are creating is not a true querystring.
        // It represents the querystring part of the url, but does not start with a ?
        // OAuth uses unescaped & twice, to create three parts to the Authorization header:
        // 1.  The verb
        // 2.  The host
        // 3.  The querystring
        
        var oAuthQuerystringDictionary = [String : Any]()

        if let clientQueryString = clientQueryString {
            // Adding all the original client created querystring parameters first.
            let originalParts = clientQueryString.components(separatedBy: "&")
            for part in originalParts {
                let keyValues = part.components(separatedBy: "=")
                oAuthQuerystringDictionary[keyValues[0]] = keyValues[1]
            }
        }

        // Now add all the OAuth parameters.
        let encodedConsumerKey = appSettings.oAuthPublicKey.escapeUriDataStringRfc3986
        let encodedNonce = UUID().uuidString.escapeUriDataStringRfc3986
        let encodedSignatureMethod = OAuthDefinitions.SignatureMethodHmacSha1.escapeUriDataStringRfc3986
        oAuthQuerystringDictionary[OAuthDefinitions.ConsumerKeyKey] = encodedConsumerKey
        oAuthQuerystringDictionary[OAuthDefinitions.NonceKey] = encodedNonce
        oAuthQuerystringDictionary[OAuthDefinitions.SignatureMethodKey] = encodedSignatureMethod

        // Do NOT change this format to from int to double. OAuth needs an int.
        let timeStamp = Int64(Date().timeIntervalSince1970)
        oAuthQuerystringDictionary[OAuthDefinitions.TimeStampKey] = timeStamp
        
        oAuthQuerystringDictionary[OAuthDefinitions.VersionKey] = OAuthDefinitions.Version1

        return oAuthQuerystringDictionary
    }

    func createOAuthQuerystring(queryStringDictionary: [String : Any]) -> String {

        // Get an array of the ordered keys.
        // NB OAuth specifies the ordering should be a-z by key then for length for values.
        // Here only Key sorting is being performed.
        var sortedKeys = [String](queryStringDictionary.keys)        
        sortedKeys.sort { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }

        // Read the notes in buildOAuthQuerystringDictionary to fully understand format.
        var returnOAuthQuerystring = ""

        // Loop around sorted keys and get the value from the dictionary and append to the querystring.
        for key in sortedKeys {
            // Apply URL encoding to both keys and values.
            let keyString = key.escapeUriDataStringRfc3986
            var valueString = ""
            if let value = queryStringDictionary[key] {
                valueString = "\(value)".escapeUriDataStringRfc3986
            }
            returnOAuthQuerystring += "\(keyString)=\(valueString)&"
        }
 
        // Remove last & from the loop adding parameters.
        return String(returnOAuthQuerystring.dropLast())
    }
}
