import Foundation

struct IPAResult: Equatable {
    let transcription: String
    let unknownWords: [String]
}

final class IPAService: @unchecked Sendable {
    static let shared = IPAService()

    private let pronunciations: [String: [String]]
    private let wordRegex = try! NSRegularExpression(pattern: #"[A-Za-z]+(?:'[A-Za-z]+)?"#)

    init(dictionaryText: String? = nil) {
        if let dictionaryText {
            pronunciations = Self.parse(dictionaryText)
        } else if let url = Bundle.main.url(forResource: "cmudict", withExtension: "dict")
                    ?? Bundle.module.url(forResource: "cmudict", withExtension: "dict", subdirectory: "Pronunciation")
                    ?? Bundle.module.url(forResource: "cmudict", withExtension: "dict"),
                  let content = try? String(contentsOf: url, encoding: .utf8) {
            pronunciations = Self.parse(content)
            FileLogger.shared.info(.app, "pronunciation_dictionary_loaded entries=\(pronunciations.count)")
        } else {
            pronunciations = [:]
            FileLogger.shared.error(.app, "pronunciation_dictionary_missing")
        }
    }

    func transcribe(_ text: String) -> IPAResult {
        let nsText = text as NSString
        let matches = wordRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return IPAResult(transcription: "", unknownWords: []) }
        var output = ""
        var cursor = 0
        var unknown: [String] = []
        for match in matches {
            if match.range.location > cursor {
                output += nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            }
            let word = nsText.substring(with: match.range)
            let key = word.lowercased()
            if let phonemes = pronunciations[key] {
                output += Self.convertToIPA(phonemes)
            } else {
                output += "[\(word) ?]"
                if !unknown.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
                    unknown.append(word)
                }
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < nsText.length {
            output += nsText.substring(from: cursor)
        }
        return IPAResult(transcription: "/\(output)/", unknownWords: unknown)
    }

    private static func parse(_ text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        text.enumerateLines { line, _ in
            guard !line.isEmpty, !line.hasPrefix(";;;"), !line.hasPrefix("#") else { return }
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard fields.count > 1 else { return }
            let rawWord = fields[0].lowercased()
            let word = rawWord.replacingOccurrences(of: #"\(\d+\)$"#, with: "", options: .regularExpression)
            if result[word] == nil {
                result[word] = Array(fields.dropFirst())
            }
        }
        return result
    }

    private static func convertToIPA(_ phonemes: [String]) -> String {
        phonemes.map { raw in
            let stress = raw.last.flatMap { $0.isNumber ? Int(String($0)) : nil }
            let base = raw.trimmingCharacters(in: .decimalDigits)
            let ipa = phonemeMap[base] ?? base.lowercased()
            switch stress {
            case 1: return "ˈ" + ipa
            case 2: return "ˌ" + ipa
            default: return ipa
            }
        }.joined()
    }

    private static let phonemeMap: [String: String] = [
        "AA": "ɑ", "AE": "æ", "AH": "ə", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ",
        "EH": "ɛ", "ER": "ɝ", "EY": "eɪ", "IH": "ɪ", "IY": "i", "OW": "oʊ",
        "OY": "ɔɪ", "UH": "ʊ", "UW": "u", "B": "b", "CH": "tʃ", "D": "d",
        "DH": "ð", "F": "f", "G": "ɡ", "HH": "h", "JH": "dʒ", "K": "k",
        "L": "l", "M": "m", "N": "n", "NG": "ŋ", "P": "p", "R": "ɹ",
        "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "V": "v", "W": "w",
        "Y": "j", "Z": "z", "ZH": "ʒ"
    ]
}
