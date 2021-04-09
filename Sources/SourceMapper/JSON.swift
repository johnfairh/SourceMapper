//
//  JSON.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import Foundation

fileprivate struct SerializedSourceMap: Codable {
    let version: UInt
    let file: String?
    let sourceRoot: String?
    let sources: [String]
    let sourcesContent: [String?]?
    let names: [String]
    let mappings: String
}

extension SourceMap {
    /// Decode a source map from a JSON string as `Data`.
    public convenience init(data: Data) throws {
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
            if let sourceContent = $1 {
                return .inline(url: $0, content: sourceContent)
            }
            return .remote(url: $0)
        }

        self.names = decoded.names

        self.mappings = decoded.mappings
        self.mappingsValid = true
        self.mappingSegments = nil
    }

    /// Decode a source map from a JSON string.
    ///
    /// - throws: If the JSON is bad, the version is bad, or if mandatory fields are missing.
    ///   The mappings aren't decoded until accessed.
    public convenience init(string: String) throws {
        try self.init(data: string.data(using: .utf8)!)
    }

    /// Validate any customizations and encode the source map as JSON
    ///
    /// - parameter continueOnError: Set the error handling policy.  If `false` then
    ///   any inconsistencies in the mapping data cause an error to be thrown, otherwise they
    ///   are passed through to the JSON format.
    ///
    ///   The default is `true` which is probably right when working with existing sourcemaps,
    ///   but if you're creating from scratch it may be more useful to set `false` to catch bugs
    ///   in your generation code.
    ///
    /// - throws: If `continueOnError` is `false` and there is an error; or if JSON
    ///   encoding fails for some reason.
    public func encode(continueOnError: Bool = true) throws -> Data {
        if !mappingsValid {
            try updateMappings(continueOnError: continueOnError)
        }
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

        return try JSONEncoder().encode(serialized)
    }

    /// Validate any customizations and encode the source map as JSON in a string
    ///
    /// See `encode(contineOnError:)`.
    public func encodeString(continueOnError: Bool = true) throws -> String {
        String(data: try encode(continueOnError: continueOnError), encoding: .utf8)!
    }

    private func updateMappings(continueOnError: Bool) throws {
        precondition(mappingsValid)
    }
}
