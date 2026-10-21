import Foundation

/// Appels à l'exécutable mame. `run` est bloquant : à appeler hors du fil principal.
enum MAMERunner {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static func makeProcess(_ args: [String]) throws -> Process {
        let exe = Prefs.mameURL
        guard FileManager.default.isExecutableFile(atPath: exe.path) else {
            throw Failure(message: String(localized: "mame introuvable : \(exe.path). Indiquez son emplacement dans les réglages."))
        }
        try Prefs.prepareUserData()
        let p = Process()
        p.executableURL = exe
        p.arguments = args
        // Lancé dans le dossier utilisateur : ce que mame écrit sans qu'on
        // le lui demande atterrit là, jamais sur le disque des jeux.
        p.currentDirectoryURL = Prefs.userDataRoot
        p.standardError = FileHandle.nullDevice
        return p
    }

    /// Lance mame et rend sa sortie standard (ou l'écrit dans `output`).
    static func run(_ args: [String], output: URL? = nil) throws -> String {
        let p = try makeProcess(args)
        let pipe = Pipe()
        var file: FileHandle?
        if let output {
            FileManager.default.createFile(atPath: output.path, contents: nil)
            file = try FileHandle(forWritingTo: output)
            p.standardOutput = file
        } else {
            p.standardOutput = pipe
        }
        try p.run()
        let data = output == nil ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        p.waitUntilExit()
        try file?.close()
        return String(decoding: data, as: UTF8.self)
    }

    /// Lance mame et passe chaque ligne de sortie à `onLine` au fil de l'eau.
    /// Annuler la tâche arrête mame.
    static func stream(_ args: [String], onLine: (String) -> Void) async throws {
        let p = try makeProcess(args)
        let pipe = Pipe()
        p.standardOutput = pipe
        try Task.checkCancellation()
        try p.run()
        try await withTaskCancellationHandler {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                onLine(line)
            }
            p.waitUntilExit()
        } onCancel: {
            p.terminate()
        }
        try Task.checkCancellation()
    }

    /// « 0.289 (mame0289) » → « 0.289 ».
    static func version() throws -> String {
        let v = try run(["-version"]).trimmingCharacters(in: .whitespacesAndNewlines)
        return v.split(separator: " ").first.map(String.init) ?? v
    }

    static func listXML(progress: @escaping (Int) -> Void) throws -> [Machine] {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("borne-listxml.xml")
        defer { try? FileManager.default.removeItem(at: tmp) }
        _ = try run(["-listxml"], output: tmp)
        return try ListXMLParser(progress: progress).parse(tmp)
    }

    /// Une ligne « romset 1942a [1942] is best available » de -verifyroms.
    static func parseAuditLine<S: StringProtocol>(_ line: S) -> (String, AuditResult)? {
        guard line.hasPrefix("romset ") else { return nil }
        let words = line.split(separator: " ")
        guard words.count >= 3 else { return nil }
        let name = String(words[1])
        if line.hasSuffix("is good") { return (name, .good) }
        if line.hasSuffix("is best available") { return (name, .bestAvailable) }
        if line.hasSuffix("is bad") { return (name, .bad) }
        return nil
    }

    static func parseAudit(_ out: String) -> [String: AuditResult] {
        var result: [String: AuditResult] = [:]
        for line in out.split(separator: "\n") {
            if let (name, r) = parseAuditLine(line) { result[name] = r }
        }
        return result
    }
}
