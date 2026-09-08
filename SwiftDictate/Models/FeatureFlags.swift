enum FeatureFlags {
    // PCC requires Apple's managed entitlement. Open-source builds can opt in
    // after receiving access by changing this flag to true.
    static let privateCloudCompute = false
}
