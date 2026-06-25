import Foundation

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

guard CommandLine.arguments.count == 3 else {
    fputs("usage: create_icns <iconset> <output.icns>\n", stderr)
    exit(2)
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for (type, name) in chunks {
    let payload = try Data(contentsOf: iconset.appendingPathComponent(name))
    body.append(contentsOf: type.utf8)
    appendUInt32(UInt32(payload.count + 8), to: &body)
    body.append(payload)
}

var result = Data("icns".utf8)
appendUInt32(UInt32(body.count + 8), to: &result)
result.append(body)
try result.write(to: output, options: .atomic)
