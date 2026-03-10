import Foundation

enum SchemeSource: String, Sendable {
    case project
    case spm
}

struct SchemeReference: Sendable {
    let name: String
    let path: String
    let source: SchemeSource
}
