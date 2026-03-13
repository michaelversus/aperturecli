import Foundation

protocol SchemePostActionUpdating {
    func updatePostAction(at schemePath: String, schemeName: String, projectName: String) throws
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

    func updatePostAction(at schemePath: String, schemeName: String, projectName: String) throws {
        let xmlString = try fileSystem.readFile(atPath: schemePath)
        let xmlDocument = try parseXMLDocument(from: xmlString, schemePath: schemePath)
        let scheme = try schemeRoot(in: xmlDocument, schemePath: schemePath)
        guard let testAction = scheme.elements(forName: "TestAction").first else {
            throw SchemePostActionUpdaterError.missingTestAction(path: schemePath)
        }

        let postActions = testAction.elements(forName: "PostActions").first ?? {
            let element = XMLElement(name: "PostActions")
            testAction.addChild(element)
            return element
        }()
        let environmentBuildableReference = resolveEnvironmentBuildableReference(
            testAction: testAction,
            scheme: scheme
        )

        removeExistingManagedActions(from: postActions)
        postActions.addChild(
            newManagedExecutionAction(
                for: schemeName,
                projectName: projectName,
                environmentBuildableReference: environmentBuildableReference
            )
        )

        let updatedXML = xmlDocument.xmlString(options: [.nodePrettyPrint])
        try fileSystem.writeFile(updatedXML, toPath: schemePath)
    }

    private func removeExistingManagedActions(from postActions: XMLElement) {
        let managedTitles = Set([managedSpec.title] + ManagedPostActionSpec.legacyTitles)

        for executionAction in postActions.elements(forName: "ExecutionAction") {
            guard
                let actionContent = executionAction.elements(forName: "ActionContent").first,
                let title = actionContent.attribute(forName: "title")?.stringValue,
                managedTitles.contains(title)
            else {
                continue
            }

            executionAction.detach()
        }
    }

    private func newManagedExecutionAction(
        for schemeName: String,
        projectName: String,
        environmentBuildableReference: XMLElement?
    ) -> XMLElement {
        let executionAction = XMLElement(name: "ExecutionAction")
        addAttribute(named: "ActionType", value: managedSpec.actionType, to: executionAction)

        let actionContent = XMLElement(name: "ActionContent")
        addAttribute(named: "title", value: managedSpec.title, to: actionContent)
        addAttribute(
            named: "scriptText",
            value: managedSpec.scriptText(for: schemeName, projectName: projectName),
            to: actionContent
        )
        if let environmentBuildableReference {
            let environmentBuildable = XMLElement(name: "EnvironmentBuildable")
            environmentBuildable.addChild(environmentBuildableReference)
            actionContent.addChild(environmentBuildable)
        }
        executionAction.addChild(actionContent)

        return executionAction
    }

    private func resolveEnvironmentBuildableReference(
        testAction: XMLElement,
        scheme: XMLElement
    ) -> XMLElement? {
        if let reference = firstBuildableReference(in: testAction) {
            return reference
        }
        return firstBuildableReference(in: scheme)
    }

    private func firstBuildableReference(in element: XMLElement) -> XMLElement? {
        guard
            let references = try? element.nodes(forXPath: ".//BuildableReference"),
            let reference = references.first as? XMLElement
        else {
            return nil
        }

        return copyXMLElement(reference)
    }

    private func copyXMLElement(_ element: XMLElement) -> XMLElement? {
        try? XMLElement(xmlString: element.xmlString(options: []))
    }

    private func addAttribute(named name: String, value: String, to element: XMLElement) {
        guard let attribute = XMLNode.attribute(withName: name, stringValue: value) as? XMLNode else {
            return
        }
        element.addAttribute(attribute)
    }

    func parseXMLDocument(from xmlString: String, schemePath: String) throws -> XMLDocument {
        do {
            return try XMLDocument(data: Data(xmlString.utf8), options: [.nodePreserveAll])
        } catch {
            throw SchemePostActionUpdaterError.invalidXML(path: schemePath)
        }
    }

    func schemeRoot(in xmlDocument: XMLDocument, schemePath: String) throws -> XMLElement {
        guard let scheme = xmlDocument.rootElement() else {
            throw SchemePostActionUpdaterError.invalidXML(path: schemePath)
        }
        return scheme
    }
}
