import Foundation
import Testing
@testable import NSAssetsCLI

private let schemePath = "/repo/MyScheme.xcscheme"

struct SchemePostActionUpdaterTests {
    @Test
    func addsPostActionsWhenMissing() throws {
        let fileSystem = makeFileSystem(withContentsAt: schemePath, xml: emptyTestActionSchemeXML)
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: schemePath,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == schemePath)
        #expect(write.contents.contains("<PostActions>"))
        #expect(write.contents.contains("title=\"NSAssetsCLI: Post Test Action\""))
        #expect(write.contents.contains("WORKSPACE_PATH"))
        #expect(
            write.contents.contains(
                "--workspace-path &quot;$WORKSPACE_PATH&quot;"
            )
        )
        #expect(write.contents.contains("/nsassets-artifacts/logs/MyScheme.log"))
        #expect(write.contents.contains("nsassetscli "))
        #expect(write.contents.contains("2&gt;&amp;1"))
        #expect(write.contents.contains(") &amp;"))
        #expect(write.contents.contains("LOG_PATH") == false)
    }

    @Test
    func addsEnvironmentBuildableWhenBuildableReferenceExists() throws {
        let fileSystem = makeFileSystem(withContentsAt: schemePath, xml: macroExpansionSchemeXML)
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: schemePath,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("<EnvironmentBuildable>"))
        #expect(write.contents.contains("BlueprintIdentifier=\"ABC123\""))
        #expect(write.contents.contains("ReferencedContainer=\"container:MyApp.xcodeproj\""))
    }

    @Test
    func preservesUserPostActionsAndReplacesManagedOne() throws {
        let fileSystem = makeFileSystem(withContentsAt: schemePath, xml: mixedPostActionsSchemeXML)
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: schemePath,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("title=\"User Action\""))
        #expect(write.contents.contains("title=\"NSAssetsCLI: Post Test Action\""))
        #expect(write.contents.contains("WORKSPACE_PATH"))
        #expect(write.contents.contains("/nsassets-artifacts/logs/MyScheme.log"))
        #expect(write.contents.contains(" nsassetscli "))
        #expect(write.contents.contains("2&gt;&amp;1"))
        #expect(write.contents.contains(") &amp;"))
        #expect(write.contents.contains("LOG_PATH") == false)
        #expect(
            write.contents.contains(
                "--workspace-path &quot;$WORKSPACE_PATH&quot;"
            )
        )
        #expect(write.contents.contains("scriptText=\"echo old") == false)
    }

    @Test
    func throwsWhenTestActionIsMissing() throws {
        let fileSystem = makeFileSystem(withContentsAt: schemePath, xml: missingTestActionSchemeXML)
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        #expect(throws: SchemePostActionUpdaterError.missingTestAction(path: schemePath)) {
            try updater.updatePostAction(
                at: schemePath,
                schemeName: "MyScheme",
                projectName: "MyApp"
            )
        }
        #expect(fileSystem.writeOperations.isEmpty)
    }

    @Test
    func throwsWhenSchemeXMLIsMalformed() throws {
        let fileSystem = makeFileSystem(withContentsAt: schemePath, xml: malformedSchemeXML)
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        #expect(throws: SchemePostActionUpdaterError.invalidXML(path: schemePath)) {
            try updater.updatePostAction(
                at: schemePath,
                schemeName: "MyScheme",
                projectName: "MyApp"
            )
        }
    }

    @Test
    func throwsWhenParsedDocumentHasNoRootElement() throws {
        let updater = SchemePostActionUpdater(fileSystem: MockFileSystem())
        let xmlDocument = XMLDocument(kind: .document, options: .nodePreserveAll)

        #expect(throws: SchemePostActionUpdaterError.invalidXML(path: schemePath)) {
            _ = try updater.schemeRoot(in: xmlDocument, schemePath: schemePath)
        }
    }

    @Test
    func replacesOldManagedXCResultCommandWhenRerunningSetup() throws {
        let fileSystem = makeFileSystem(withContentsAt: schemePath, xml: modernManagedPostActionSchemeXML)
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: schemePath,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("title=\"NSAssetsCLI: Post Test Action\""))
        #expect(write.contents.contains("--project-name &quot;$PROJECT_NAME&quot;") == false)
        #expect(write.contents.contains("WORKSPACE_PATH"))
        #expect(write.contents.contains("/nsassets-artifacts/logs/MyScheme.log"))
        #expect(write.contents.contains("nsassetscli"))
        #expect(write.contents.contains("2&gt;&amp;1"))
        #expect(write.contents.contains(") &amp;"))
        #expect(write.contents.contains("LOG_PATH") == false)
        #expect(
            write.contents.contains(
                "--workspace-path &quot;$WORKSPACE_PATH&quot;"
            )
        )
    }

}

private func makeFileSystem(withContentsAt path: String, xml: String) -> MockFileSystem {
    MockFileSystem(fileContentsByPath: [path: xml])
}

private let emptyTestActionSchemeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme version = "1.7">
   <TestAction buildConfiguration = "Debug">
   </TestAction>
</Scheme>
"""

private let macroExpansionSchemeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme version = "1.7">
  <TestAction buildConfiguration = "Debug">
    <MacroExpansion>
      <BuildableReference
        BuildableIdentifier = "primary"
        BlueprintIdentifier = "ABC123"
        BuildableName = "MyApp.app"
        BlueprintName = "MyApp"
        ReferencedContainer = "container:MyApp.xcodeproj">
      </BuildableReference>
    </MacroExpansion>
  </TestAction>
</Scheme>
"""

private let mixedPostActionsSchemeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme version = "1.7">
  <TestAction buildConfiguration = "Debug">
    <PostActions>
      <ExecutionAction
        ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
        <ActionContent title = "User Action" scriptText = "echo user&#10;">
        </ActionContent>
      </ExecutionAction>
      <ExecutionAction
        ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
        <ActionContent title = "NSAssetsCLI: Post Test Action" scriptText = "echo old&#10;">
        </ActionContent>
      </ExecutionAction>
    </PostActions>
  </TestAction>
</Scheme>
"""

private let missingTestActionSchemeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme version = "1.7">
  <LaunchAction></LaunchAction>
</Scheme>
"""

private let malformedSchemeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme version = "1.7">
  <TestAction buildConfiguration = "Debug">
</Scheme>
"""

private let modernManagedPostActionSchemeXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme version = "1.7">
  <TestAction buildConfiguration = "Debug">
    <PostActions>
      <ExecutionAction
        ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
        <ActionContent
          title = "NSAssetsCLI: Post Test Action"
          scriptText = "nsassets xcresult parse --scheme &quot;MyScheme&quot; \
          --project-name &quot;$PROJECT_NAME&quot; &#10;">
        </ActionContent>
      </ExecutionAction>
    </PostActions>
  </TestAction>
</Scheme>
"""
