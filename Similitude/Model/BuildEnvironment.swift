import Foundation

/// Distinguishes development/TestFlight builds from App Store builds so
/// testing tools (premium override, model diagnostics) are available to
/// testers but never in the shipping app.
enum BuildEnvironment {

    /// True for DEBUG builds and TestFlight installs (sandbox receipt).
    /// App Store installs have a production receipt and return false.
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}
