import Foundation
import Testing
@testable import ApertureCLI

struct SchemePostActionUpdaterTests {
    @Test
    func addsPostActionsWhenMissing() throws {
        let path = "/repo/MyScheme.xcscheme"
        let fileSystem = MockFileSystem(
            fileContentsByPath: [
                path: """
                <?xml version="1.0" encoding="UTF-8"?>
                <Scheme version = "1.7">
                   <TestAction buildConfiguration = "Debug">
                   </TestAction>
                </Scheme>
                """
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: path,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == path)
        #expect(write.contents.contains("<PostActions>"))
        #expect(write.contents.contains("title=\"ApertureCLI: Post Test Action\""))
        #expect(write.contents.contains("WORKSPACE_PATH"))
        #expect(
            write.contents.contains(
                "--workspace-path &quot;$WORKSPACE_PATH&quot;"
            )
        )
        #expect(write.contents.contains("/aperture-artifacts/logs/MyScheme.log"))
        #expect(write.contents.contains("ApertureCLI test executed"))
        #expect(write.contents.contains("2&gt;&amp;1"))
    }

    @Test
    func addsEnvironmentBuildableWhenBuildableReferenceExists() throws {
        let path = "/repo/MyScheme.xcscheme"
        let fileSystem = MockFileSystem(
            fileContentsByPath: [
                path: """
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
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: path,
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
        let path = "/repo/MyScheme.xcscheme"
        let fileSystem = MockFileSystem(
            fileContentsByPath: [
                path: """
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
                        <ActionContent title = "ApertureCLI: Post Test Action" scriptText = "echo old&#10;">
                        </ActionContent>
                      </ExecutionAction>
                    </PostActions>
                  </TestAction>
                </Scheme>
                """
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: path,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("title=\"User Action\""))
        #expect(write.contents.contains("title=\"ApertureCLI: Post Test Action\""))
        #expect(write.contents.contains("WORKSPACE_PATH"))
        #expect(write.contents.contains("/aperture-artifacts/logs/MyScheme.log"))
        #expect(write.contents.contains("ApertureCLI test executed"))
        #expect(write.contents.contains("2&gt;&amp;1"))
        #expect(
            write.contents.contains(
                "--workspace-path &quot;$WORKSPACE_PATH&quot;"
            )
        )
        #expect(write.contents.contains("scriptText=\"echo old") == false)
    }

    @Test
    func throwsWhenTestActionIsMissing() throws {
        let path = "/repo/MyScheme.xcscheme"
        let fileSystem = MockFileSystem(
            fileContentsByPath: [
                path: """
                <?xml version="1.0" encoding="UTF-8"?>
                <Scheme version = "1.7">
                  <LaunchAction></LaunchAction>
                </Scheme>
                """
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        #expect(throws: SchemePostActionUpdaterError.missingTestAction(path: path)) {
            try updater.updatePostAction(
                at: path,
                schemeName: "MyScheme",
                projectName: "MyApp"
            )
        }
        #expect(fileSystem.writeOperations.isEmpty)
    }

    @Test
    func throwsWhenSchemeXMLIsMalformed() throws {
        let path = "/repo/MyScheme.xcscheme"
        let fileSystem = MockFileSystem(
            fileContentsByPath: [
                path: """
                <?xml version="1.0" encoding="UTF-8"?>
                <Scheme version = "1.7">
                  <TestAction buildConfiguration = "Debug">
                </Scheme>
                """
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        #expect(throws: SchemePostActionUpdaterError.invalidXML(path: path)) {
            try updater.updatePostAction(
                at: path,
                schemeName: "MyScheme",
                projectName: "MyApp"
            )
        }
    }

    @Test
    func throwsWhenParsedDocumentHasNoRootElement() throws {
        let path = "/repo/MyScheme.xcscheme"
        let updater = SchemePostActionUpdater(fileSystem: MockFileSystem())
        let xmlDocument = XMLDocument(kind: .document, options: .nodePreserveAll)

        #expect(throws: SchemePostActionUpdaterError.invalidXML(path: path)) {
            _ = try updater.schemeRoot(in: xmlDocument, schemePath: path)
        }
    }

    @Test
    func replacesOldManagedXCResultCommandWhenRerunningSetup() throws {
        let path = "/repo/MyScheme.xcscheme"
        let fileSystem = MockFileSystem(
            fileContentsByPath: [
                path: """
                <?xml version="1.0" encoding="UTF-8"?>
                <Scheme version = "1.7">
                  <TestAction buildConfiguration = "Debug">
                    <PostActions>
                      <ExecutionAction
                        ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
                        <ActionContent
                          title = "ApertureCLI: Post Test Action"
                          scriptText = "aperture xcresult parse --scheme &quot;MyScheme&quot; \
                          --project-name &quot;$PROJECT_NAME&quot; &#10;">
                        </ActionContent>
                      </ExecutionAction>
                    </PostActions>
                  </TestAction>
                </Scheme>
                """
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(
            at: path,
            schemeName: "MyScheme",
            projectName: "MyApp"
        )

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("title=\"ApertureCLI: Post Test Action\""))
        #expect(write.contents.contains("--project-name &quot;$PROJECT_NAME&quot;") == false)
        #expect(write.contents.contains("WORKSPACE_PATH"))
        #expect(write.contents.contains("/aperture-artifacts/logs/MyScheme.log"))
        #expect(write.contents.contains("ApertureCLI test executed"))
        #expect(write.contents.contains("2&gt;&amp;1"))
        #expect(
            write.contents.contains(
                "--workspace-path &quot;$WORKSPACE_PATH&quot;"
            )
        )
    }
}
