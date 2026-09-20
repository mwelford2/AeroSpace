import AppKit
import Common

public final class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    @Published var trayItems: [TrayItem] = []
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaces: [WorkspaceViewModel] = []
    @Published var experimentalUISettings: ExperimentalUISettings = ExperimentalUISettings()
    @Published var sponsorshipMessage: String = sponsorshipPrompts.randomElement().orDie()
    @Published var lastReloadConfigContainedWarnings: Bool = false
    @Published var axPermissionStatus: AxPermissionStatus = .waitingWithPrompt
}

enum AxPermissionStatus: Equatable {
    case granted
    case waiting
    case waitingWithPrompt
}

@MainActor func updateTrayText() async {
    let sortedMonitors = sortedMonitorInfos
    let focus = focus
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first.map { "(\($0.uppercased())) " } ?? "") +
        sortedMonitors
        .map {
            let hasFullscreenWindows = $0.activeWorkspace.allLeafWindowsRecursive.contains { $0.isFullscreen }
            let activeWorkspaceName = hasFullscreenWindows ? "[\($0.activeWorkspace.name)]" : $0.activeWorkspace.name
            return ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + activeWorkspaceName
        }
        .joined(separator: " │ ")
    var workspaceViewModels: [WorkspaceViewModel] = []
    for workspace in Workspace.all {
        var labels: [String] = []
        for window in workspace.allLeafWindowsRecursive {
            if let label = await formatWorkspaceMenuWindowLabel(window, config.workspaceMenuWindowFormat), !label.isEmpty {
                labels.append(label)
            }
        }
        let dash = " - "
        let suffix = switch true {
            case !labels.isEmpty: dash + labels.toSet().sorted().joinTruncating(separator: ", ", length: 25)
            case workspace.isVisible: dash + workspace.workspaceMonitor.name
            default: ""
        }
        let hasFullscreenWindows = workspace.allLeafWindowsRecursive.contains { $0.isFullscreen }
        workspaceViewModels.append(
            WorkspaceViewModel(
                name: workspace.name,
                suffix: suffix,
                isFocused: focus.workspace == workspace,
                isEffectivelyEmpty: workspace.isEffectivelyEmpty,
                isVisible: workspace.isVisible,
                hasFullscreenWindows: hasFullscreenWindows,
            ),
        )
    }
    TrayMenuModel.shared.workspaces = workspaceViewModels
    var items = sortedMonitors.map {
        let hasFullscreenWindows = $0.activeWorkspace.allLeafWindowsRecursive.contains { $0.isFullscreen }
        return TrayItem(
            type: .workspace,
            name: $0.activeWorkspace.name,
            isActive: $0.activeWorkspace == focus.workspace,
            hasFullscreenWindows: hasFullscreenWindows,
        )
    }
    let mode = activeMode?.takeIf { $0 != mainModeId }?.first.map {
        TrayItem(type: .mode, name: $0.uppercased(), isActive: true, hasFullscreenWindows: false)
    }
    if let mode {
        items.insert(mode, at: 0)
    }
    TrayMenuModel.shared.trayItems = items
}

@MainActor
func formatWorkspaceMenuWindowLabel(_ window: Window, _ format: [InterToken<InterVar>]) async -> String? {
    guard let appName = window.app.name, !appName.isEmpty else { return nil }
    guard let window = try? await WindowWithPrefetchedTitle.resolveWindow(window, for: format, .nonCancellable) else { return appName }
    return switch [AeroObj.window(window)].format(format) {
        case .success(let labels): labels.singleOrNil().orDie()
        case .failure: appName
    }
}

struct WorkspaceViewModel: Hashable {
    let name: String
    let suffix: String
    let isFocused: Bool
    let isEffectivelyEmpty: Bool
    let isVisible: Bool
    let hasFullscreenWindows: Bool
}

enum TrayItemType: String, Hashable {
    case mode
    case workspace
}

private let validLetters = "A" ... "Z"

struct TrayItem: Hashable, Identifiable {
    let type: TrayItemType
    let name: String
    let isActive: Bool
    let hasFullscreenWindows: Bool
    var systemImageName: String? {
        // System image type is only valid for numbers 0 to 50 and single capital char workspace name
        switch Int(name) {
            case let number?: if !(0 ... 50).contains(number) { return nil }
            case nil where name.count == 1: if !validLetters.contains(name) { return nil }
            default: return nil
        }
        let lowercasedName = name.lowercased()
        return switch type {
            case .mode: "\(lowercasedName).circle"
            case .workspace where isActive: "\(lowercasedName).square.fill"
            case .workspace: "\(lowercasedName).square"
        }
    }
    var id: String {
        return type.rawValue + name
    }
}
