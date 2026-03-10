import ArgumentParser

extension ApertureCLI {
    struct Initial: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "CLI setup wizard")

        func run() async throws {
            
        }
    }
}
