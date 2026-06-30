import XCTest
@_exported import OuroAppShellContract

public enum OuroAppShellContractAssertions {
    public static func assertValid(
        _ contract: OuroAppShellContract,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let issues = OuroAppShellContractValidator.validate(contract)
        XCTAssertTrue(issues.isEmpty, message(for: issues), file: file, line: line)
    }

    public static func assertRequiresShellFirstSurfaces(
        _ contract: OuroAppShellContract,
        _ expected: [AppShellSurface],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(contract.shellFirstRequiredSurfaces, expected, file: file, line: line)
    }

    public static func assertCommandManifestMatchesReference(
        _ contract: OuroAppShellContract,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(contract.commandReference, "Missing command reference contract.", file: file, line: line)
        XCTAssertNotNil(contract.commandManifest, "Missing command surface manifest.", file: file, line: line)
        XCTAssertEqual(contract.commandReference?.commandCount, contract.commandManifest?.count, file: file, line: line)
        let manifestSections = contract.commandManifest?.sections ?? []
        let representedReferenceSections = contract.commandReference?.sections.filter { manifestSections.contains($0) }
        XCTAssertEqual(representedReferenceSections, manifestSections, file: file, line: line)
    }

    public static func assertCommandManifest(
        _ contract: OuroAppShellContract,
        matches runtimeCommands: [OuroAppShellCommandSurface],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(contract.commandManifest?.commands, runtimeCommands, file: file, line: line)
    }

    public static func message(for issues: [OuroAppShellContractIssue]) -> String {
        guard !issues.isEmpty else {
            return "Ouro app shell contract is valid."
        }
        return issues.map(\.description).joined(separator: "\n")
    }
}
