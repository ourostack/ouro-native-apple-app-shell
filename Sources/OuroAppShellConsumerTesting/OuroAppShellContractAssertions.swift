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

    public static func message(for issues: [OuroAppShellContractIssue]) -> String {
        guard !issues.isEmpty else {
            return "Ouro app shell contract is valid."
        }
        return issues.map(\.description).joined(separator: "\n")
    }
}
