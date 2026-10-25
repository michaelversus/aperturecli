/// The generated entry file, and where the app's entry expression sits in it.
struct HarnessEntrySource: Equatable {
    let text: String
    let firstExpressionLine: Int
    let expressionLineCount: Int
}
