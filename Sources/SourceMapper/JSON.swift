//
//  JSON.swift
//  SourceMapper
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation

fileprivate struct SerializedSourceMap: Codable {
    let version: Int
    let file: String?
    let sourceRoot: String?
    let sources: [String]
    let sourcesContent: [String?]?
    let names: [String]
    let mappings: String
}

extension SourceMap {
    /// Decode a source map from JSON `Data`.
    /// - parameter data: The source map JSON.
    /// - throws: If the JSON is bad, the version is bad, or if mandatory fields are missing.
    public init(data: Data) throws {
        let decoded = try JSONDecoder().decode(SerializedSourceMap.self, from: data)
        if decoded.version != SourceMap.VERSION {
            throw SourceMapError.invalidFormat(decoded.version)
        }
        self.init(version: decoded.version)
        self.file = decoded.file
        self.sourceRoot = decoded.sourceRoot

        let contents: [String?]
        if let decodedContents = decoded.sourcesContent {
            guard decodedContents.count == decoded.sources.count else {
                throw SourceMapError.inconsistentSources(sourcesCount: decoded.sources.count,
                                                         sourcesContentCount: decodedContents.count)
            }
            contents = decodedContents
        } else {
            contents = .init(repeating: nil, count: decoded.sources.count)
        }

        self.sources = zip(decoded.sources, contents).map {
            SourceMap.Source(url: $0, content: $1)
        }

        self.names = decoded.names

        self.mappings = decoded.mappings
    }

    /// Decode a source map from a JSON string.
    ///
    /// See `init(data:)`.
    public init(string: String) throws {
        try self.init(data: string.data(using: .utf8)!)
    }

    /// Encode the source map as JSON
    ///
    /// - throws: If JSON encoding fails for some reason.
    public func encode() throws -> Data {
        var anyContent = false
        let sourceLists: ([String], [String?]) = sources.reduce(into: ([], [])) { r, s in
            r.0.append(s.url)
            r.1.append(s.content)
            if s.content != nil {
                anyContent = true
            }
        }
        let serialized = SerializedSourceMap(version: version,
                                             file: file,
                                             sourceRoot: sourceRoot,
                                             sources: sourceLists.0,
                                             sourcesContent: anyContent ? sourceLists.1 : nil,
                                             names: names,
                                             mappings: mappings)

        let encoder = JSONEncoder()
        if #available(macOS 10.13, iOS 11.0, *) {
            encoder.outputFormatting = .sortedKeys
        }
        // The #available above doesn't fire on Windows...
        #if os(Windows)
        encoder.outputFormatting = .sortedKeys
        #endif
        return try encoder.encode(serialized)
    }

    /// Encode the source map as JSON in a string
    ///
    /// See `encode()`.
    public func encodeString() throws -> String {
        String(data: try encode(), encoding: .utf8)!
    }
}
