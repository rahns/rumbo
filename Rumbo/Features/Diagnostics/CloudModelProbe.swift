import FoundationModels

/// Kept in its own file: the Private Cloud Compute model is new in iOS 27 and needs a managed entitlement,
/// so a sideloaded build may not be allowed to use it even when it reports itself available.
enum CloudModelProbe {
    static var isAvailable: Bool {
        PrivateCloudComputeLanguageModel().isAvailable
    }

    static func session(instructions: String) -> LanguageModelSession {
        LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: instructions)
    }
}
