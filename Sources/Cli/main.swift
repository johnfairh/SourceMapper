import SourceMapper
import Foundation

let args = ProcessInfo.processInfo.arguments
guard args.count == 2 else {
    fputs("Syntax: srcmapcat <srcmap file>\n", stderr)
    exit(1)
}


do {
    let srcmap = try SourceMap(data: Data(contentsOf: URL(fileURLWithPath: args[1])))
    print(srcmap.description)
    srcmap.sources.enumerated().forEach { n, src in
        let hasContent = srcmap.sources[n].content != nil ? " (has content)" : ""
        print("source[\(n)] \(srcmap.sources[n].url)\(hasContent)")
    }
    print(try srcmap.getSegmentsDescription())
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(2)
}
