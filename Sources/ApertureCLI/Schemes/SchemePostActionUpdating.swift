import Foundation

protocol SchemePostActionUpdating {
    func updatePostAction(at schemePath: String, schemeName: String) throws
}

enum SchemePostActionUpdaterError: Error, Equatable {
    case invalidXML(path: String)
    case missingTestAction(path: String)
}

struct SchemePostActionUpdater: SchemePostActionUpdating {
    let fileSystem: FileSystemProvider
    let managedSpec: ManagedPostActionSpec

    init(
        fileSystem: FileSystemProvider,
        managedSpec: ManagedPostActionSpec = ManagedPostActionSpec()
    ) {
        self.fileSystem = fileSystem
        self.managedSpec = managedSpec
    }

    func updatePostAction(at schemePath: String, schemeName: String) throws {
        let xmlString = try fileSystem.readFile(atPath: schemePath)
        guard let data = xmlString.data(using: .utf8) else {
            throw SchemePostActionUpdaterError.invalidXML(path: schemePath)
        }

        let xmlDocument = try XMLDocument(data: data, options: [.nodePreserveAll])
        guard let scheme = xmlDocument.rootElement() else {
            throw SchemePostActionUpdaterError.invalidXML(path: schemePath)
        }
        guard let testAction = scheme.elements(forName: "TestAction").first else {
            throw SchemePostActionUpdaterError.missingTestAction(path: schemePath)
        }

        let postActions = testAction.elements(forName: "PostActions").first ?? {
            let element = XMLElement(name: "PostActions")
            testAction.addChild(element)
            return element
        }()

        removeExistingManagedActions(from: postActions)
        postActions.addChild(newManagedExecutionAction(for: schemeName))

        let updatedData = xmlDocument.xmlData(options: [.nodePrettyPrint])
        guard let updatedXML = String(data: updatedData, encoding: .utf8) else {
            throw SchemePostActionUpdaterError.invalidXML(path: schemePath)
        }
        try fileSystem.writeFile(updatedXML, toPath: schemePath)
    }

    private func removeExistingManagedActions(from postActions: XMLElement) {
        for executionAction in postActions.elements(forName: "ExecutionAction") {
            guard
                let actionContent = executionAction.elements(forName: "ActionContent").first,
                actionContent.attribute(forName: "title")?.stringValue == managedSpec.title
            else {
                continue
            }

            executionAction.detach()
        }
    }

    private func newManagedExecutionAction(for schemeName: String) -> XMLElement {
        let executionAction = XMLElement(name: "ExecutionAction")
        addAttribute(named: "ActionType", value: managedSpec.actionType, to: executionAction)

        let actionContent = XMLElement(name: "ActionContent")
        addAttribute(named: "title", value: managedSpec.title, to: actionContent)
        addAttribute(
            named: "scriptText",
            value: managedSpec.scriptText(for: schemeName),
            to: actionContent
        )
        executionAction.addChild(actionContent)

        return executionAction
    }

    private func addAttribute(named name: String, value: String, to element: XMLElement) {
        guard let attribute = XMLNode.attribute(withName: name, stringValue: value) as? XMLNode else {
            return
        }
        element.addAttribute(attribute)
    }
}
