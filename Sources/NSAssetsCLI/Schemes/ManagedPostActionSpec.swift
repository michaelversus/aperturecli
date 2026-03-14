import Foundation

struct ManagedPostActionSpec: Sendable {
    let title: String
    let actionType: String

    init(
        title: String = "nsassets: Post Test Action",
        actionType: String = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"
    ) {
        self.title = title
        self.actionType = actionType
    }

    func scriptText(for schemeName: String, projectName: String) -> String {
        """
        (
          REPO_ROOT="$(cd "$(dirname "$WORKSPACE_PATH")/.." && pwd)"
          "$REPO_ROOT/.build/debug/nsassets" xcresult parse \
          --scheme "\(schemeName)" --project-name "\(projectName)" \
          --workspace-path "$WORKSPACE_PATH" \
          >> "$REPO_ROOT/nsassets-artifacts/logs/\(schemeName).log" 2>&1
        ) &
        """
            + "\n"
    }
}
