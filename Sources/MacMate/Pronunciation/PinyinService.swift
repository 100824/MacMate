import CoreFoundation
import Foundation

enum PinyinService {
    static func transcribe(_ text: String) -> String {
        let value = NSMutableString(string: text)
        guard CFStringTransform(value, nil, kCFStringTransformMandarinLatin, false) else {
            return ""
        }
        return value as String
    }
}
