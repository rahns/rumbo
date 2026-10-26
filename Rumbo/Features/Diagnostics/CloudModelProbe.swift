import FoundationModels

/// Kept in its own file: the Private Cloud Compute model is new in iOS 27 and needs a managed entitlement.
/// In a sideloaded build it reports itself available, but sending it a request crashes the app,
/// so diagnostics only reads `isAvailable` and never opens a session.
enum CloudModelProbe {
    static var isAvailable: Bool {
        PrivateCloudComputeLanguageModel().isAvailable
    }
}
