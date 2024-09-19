//
//  main.swift
//  SourceMapper.Cli - srcmapcat
//
//  Licensed under MIT (https://github.com/johnfairh/SourceMapper/blob/main/LICENSE
//

import SourceMapper

#if canImport(Glibc)
@preconcurrency import Glibc
#endif
import Foundation

let args = ProcessInfo.processInfo.arguments
guard args.count == 2 else {
    fputs("Syntax: srcmapcat <srcmap file>\n", stderr)
    exit(1)
}

do {
    let srcmap = try SourceMap(Data(contentsOf: URL(fileURLWithPath: args[1])))
    print(srcmap.description)
    srcmap.sources.enumerated().forEach { n, src in
        let hasContent = srcmap.sources[n].content != nil ? " (has content)" : ""
        print("source[\(n)] \(srcmap.sources[n].url)\(hasContent)")
    }
    let unpacked = try UnpackedSourceMap(srcmap)
    print(unpacked.segmentsDescription)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(2)
}
