import Foundation

enum RDPDisplayMode: String, CaseIterable, Identifiable {
    case fit, actualSize, matchWindow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fit: return "Fit to window"
        case .actualSize: return "100% with scrolling"
        case .matchWindow: return "Match window at connection"
        }
    }
    var explanation: String {
        switch self {
        case .fit: return "Scale the entire desktop to fit the window."
        case .actualSize:
            return
                "One remote pixel per Mac point. Use the scrollbars or Option-scroll to move across the desktop; normal scrolling goes to Windows."
        case .matchWindow:
            return
                "Start with the available window area at 100%. Keep that resolution until reconnecting; scroll if the window becomes smaller. One remote pixel per Mac point."
        }
    }
}
