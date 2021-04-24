//
//  JSON.swift
//  SourceMapper
//
//  Copyright 2021 SourceMapper contributors
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
    /// - parameter checkMappings: Whether to validate the mappings part of the source map.  By default
    ///   this is `false` meaning that the mappings are only validated if `getSegments()` is called later on.
    ///   Mappings validation is somewhat costly in time and memory and is not necessary for all uses.
    /// - throws: If the JSON is bad, the version is bad, or if mandatory fields are missing.  Some error if
    ///   `checkMappings` is set and the mappings are invalid.
    public convenience init(data: Data, checkMappings: Bool = false) throws {
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
            Source(url: $0, content: $1)
        }

        self.names = decoded.names

        self.mappings = decoded.mappings
        self.mappingsValid = true
        self.segments = nil

        if checkMappings {
            _ = try getSegments()
        }
    }

    /// Decode a source map from a JSON string.
    ///
    /// See `init(data:checkMappings:)`.
    public convenience init(string: String, checkMappings: Bool = false) throws {
        try self.init(data: string.data(using: .utf8)!, checkMappings: checkMappings)
    }

    /// Validate any customizations and encode the source map as JSON
    ///
    /// - parameter continueOnError: If `false` then any inconsistencies in the mappings
    ///   cause an error to be thrown, otherwise they are passed through to the JSON format.
    ///
    ///   The default is `true` which is probably right when working with existing source maps,
    ///   but if you're creating from scratch it may be more useful to set `false` to catch bugs
    ///   in your generation code.
    ///
    /// - throws: If `continueOnError` is `false` and there is an error; or if JSON
    ///   encoding fails for some reason.
    public func encode(continueOnError: Bool = true) throws -> Data {
        if !mappingsValid {
            try encodeMappings(continueOnError: continueOnError)
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
    /// See `encode(continueOnError:)`.
    public func encodeString(continueOnError: Bool = true) throws -> String {
        String(data: try encode(continueOnError: continueOnError), encoding: .utf8)!
    }
}
