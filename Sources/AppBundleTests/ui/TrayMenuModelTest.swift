@testable import AppBundle
import Common
import XCTest

@MainActor
final class TrayMenuModelTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testWorkspaceMenuWindowLabelDefaultsToAppName() async {
        let window = TestWindow.new(id: 7, parent: focus.workspace.rootTilingContainer)
        let format: [InterToken<InterVar>] = [.interVar(.formatVar(.app(.appName)))]

        assertEquals(await formatWorkspaceMenuWindowLabel(window, format), TestApp.shared.name)
    }

    func testWorkspaceMenuWindowLabelCanIncludeTitle() async {
        let window = TestWindow.new(id: 7, parent: focus.workspace.rootTilingContainer)
        let format: [InterToken<InterVar>] = [
            .interVar(.formatVar(.app(.appName))),
            .literal(" | "),
            .interVar(.formatVar(.window(.windowTitle))),
        ]

        assertEquals(
            await formatWorkspaceMenuWindowLabel(window, format),
            "\(TestApp.shared.name.orDie()) | TestWindow(7)",
        )
    }

    func testTrayMenuUsesConfiguredWindowFormat() async {
        config.workspaceMenuWindowFormat = [
            .interVar(.formatVar(.app(.appName))),
            .literal(" | "),
            .interVar(.formatVar(.window(.windowTitle))),
        ]
        TestWindow.new(id: 7, parent: focus.workspace.rootTilingContainer)

        await updateTrayText()

        assertEquals(
            TrayMenuModel.shared.workspaces.singleOrNil()?.suffix,
            " - \(TestApp.shared.name.orDie()) | TestWindow(7)",
        )
    }

    func testDefaultTrayMenuFormatDeduplicatesAppNames() async {
        TestWindow.new(id: 7, parent: focus.workspace.rootTilingContainer)
        TestWindow.new(id: 8, parent: focus.workspace.rootTilingContainer)

        await updateTrayText()

        assertEquals(
            TrayMenuModel.shared.workspaces.singleOrNil()?.suffix,
            " - \(TestApp.shared.name.orDie())",
        )
    }
}
