import Foundation

struct PlistHelper {
    static func getvalueFromInfoPlist(withKey key: String) -> String? {
        return getvalueFromInfoPlist(withKey: key, plistName: "Info")
    }
    
    static func getvalueFromInfoPlist(withKey key: String, plistName: String) -> String? {
        if  let path = Bundle.main.path(forResource: plistName, ofType: "plist"),
            let keyValue = NSDictionary(contentsOfFile: path)?.value(forKey: key) as? String {
            return keyValue
        }
        return nil
    }
    
    static func getBoolFromInfoPlist(withKey key: String, plistName: String) -> Bool? {
        if  let path = Bundle.main.path(forResource: plistName, ofType: "plist"),
            let keyValue = NSDictionary(contentsOfFile: path)?.value(forKey: key) as? Bool {
            return keyValue
        }
        return nil
    }

}
