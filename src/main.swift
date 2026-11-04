import Foundation
import Darwin

let home = FileManager.default.homeDirectoryForCurrentUser
let profile = home.appendingPathComponent("Library/Application Support/Joplin-Institute")
let original = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/JoplinCore")

do {
    let fm = FileManager.default
    guard fm.isExecutableFile(atPath: original.path) else {
        throw NSError(domain: "JoplinInstitute", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The bundled Joplin 3.5.5 executable is missing."])
    }
    try fm.createDirectory(at: profile, withIntermediateDirectories: true)
    let settingsURL = profile.appendingPathComponent("settings.json")
    var settings: [String: Any] = [:]
    if fm.fileExists(atPath: settingsURL.path) {
        settings = try JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? [String: Any] ?? [:]
    }
    if settings["autoUpdateEnabled"] as? Bool != false {
        settings["autoUpdateEnabled"] = false
        try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            .write(to: settingsURL, options: .atomic)
    }
    var forwarded: [String] = []
    let supplied = Array(CommandLine.arguments.dropFirst())
    var index = 0
    while index < supplied.count {
        let argument = supplied[index]
        if argument == "--profile" || argument == "--alt-instance-id" {
            index += 2
            continue
        }
        if !argument.hasPrefix("--profile=") && !argument.hasPrefix("--alt-instance-id=") && argument != "--no-welcome" {
            forwarded.append(argument)
        }
        index += 1
    }
    let arguments = [original.path] + forwarded + ["--profile", profile.path,
        "--alt-instance-id", "institute", "--no-welcome"]
    var pointers = arguments.map { strdup($0) }
    pointers.append(nil)
    pointers.withUnsafeMutableBufferPointer { buffer in
        _ = execv(original.path, buffer.baseAddress!)
    }
    let failure = errno
    for pointer in pointers { free(pointer) }
    throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure))
} catch {
    fputs("Cannot start Joplin Institute: \(error.localizedDescription)\n", stderr)
    exit(1)
}
