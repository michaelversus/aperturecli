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

        try updater.updatePostAction(at: path, schemeName: "MyScheme")

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.path == path)
        #expect(write.contents.contains("<PostActions>"))
        #expect(write.contents.contains("title=\"ApertureCLI: Post Test Action\""))
        #expect(
            write.contents.contains(
                "scriptText=\"/Users/m.karagiorgos/aperturecli/.build/debug/ApertureCLI xcresult parse --scheme &quot;MyScheme&quot; --project-name &quot;$PROJECT_NAME&quot;"
            )
        )
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

        try updater.updatePostAction(at: path, schemeName: "MyScheme")

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("title=\"User Action\""))
        #expect(write.contents.contains("title=\"ApertureCLI: Post Test Action\""))
        #expect(
            write.contents.contains(
                "scriptText=\"/Users/m.karagiorgos/aperturecli/.build/debug/ApertureCLI xcresult parse --scheme &quot;MyScheme&quot; --project-name &quot;$PROJECT_NAME&quot;"
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
            try updater.updatePostAction(at: path, schemeName: "MyScheme")
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
                          scriptText = "aperture xcresult parse --scheme &quot;MyScheme&quot; --project-name &quot;$PROJECT_NAME&quot; &#10;">
                        </ActionContent>
                      </ExecutionAction>
                    </PostActions>
                  </TestAction>
                </Scheme>
                """
            ]
        )
        let updater = SchemePostActionUpdater(fileSystem: fileSystem)

        try updater.updatePostAction(at: path, schemeName: "MyScheme")

        let write = try #require(fileSystem.writeOperations.first)
        #expect(write.contents.contains("title=\"ApertureCLI: Post Test Action\""))
        #expect(write.contents.contains("scriptText=\"aperture xcresult parse") == false)
        #expect(
            write.contents.contains(
                "scriptText=\"/Users/m.karagiorgos/aperturecli/.build/debug/ApertureCLI xcresult parse --scheme &quot;MyScheme&quot; --project-name &quot;$PROJECT_NAME&quot;"
            )
        )
    }
}
