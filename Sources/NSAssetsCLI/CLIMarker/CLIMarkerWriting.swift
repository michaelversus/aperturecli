import Foundation

/// Records which CLI touched a project, so NSAssets Studio can find out without launching a process.
protocol CLIMarkerWriting {
    /// Writes the marker for the project rooted at `rootPath`. Never fails the calling command.
    func write(atRootPath rootPath: String)
}
