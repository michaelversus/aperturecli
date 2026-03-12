import Foundation

struct ManagedPostActionSpec: Sendable {
    let title: String
    let actionType: String

    init(
        title: String = "ApertureCLI: Post Test Action",
        actionType: String = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"
    ) {
        self.title = title
        self.actionType = actionType
    }

    func scriptText(for schemeName: String, projectName: String) -> String {
        """
        /Users/m.karagiorgos/aperturecli/.build/debug/ApertureCLI xcresult parse \
        --scheme "\(schemeName)" --project-name "\(projectName)"
        """
            + "\n"
    }
}
