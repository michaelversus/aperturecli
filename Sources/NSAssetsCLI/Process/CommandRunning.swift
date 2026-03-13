import Foundation

protocol CommandRunning {
    func run(executable: String, arguments: [String]) throws -> String
}
