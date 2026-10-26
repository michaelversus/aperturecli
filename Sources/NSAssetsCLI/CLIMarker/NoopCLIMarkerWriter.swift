import Foundation

struct NoopCLIMarkerWriter: CLIMarkerWriting {
    func write(atRootPath rootPath: String) {}
}
