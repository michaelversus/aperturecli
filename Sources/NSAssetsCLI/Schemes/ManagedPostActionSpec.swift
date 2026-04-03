import Foundation

struct ManagedPostActionSpec: Sendable {
    let title: String
    let actionType: String

    init(
        title: String = "NSAssetsCLI: Post Test Action",
        actionType: String = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"
    ) {
        self.title = title
        self.actionType = actionType
    }

    func scriptText(for schemeName: String, projectName: String) -> String {
        """
        (
          /opt/homebrew/bin/nsassetscli xcresult parse \
          --scheme "\(schemeName)" --project-name "\(projectName)" \
          --workspace-path "$WORKSPACE_PATH" \
          >> "$(cd "$(dirname "$WORKSPACE_PATH")/.." && pwd)/nsassets-artifacts/logs/\(schemeName).log" 2>&1
        ) &
        """
            + "\n"
    }
}
