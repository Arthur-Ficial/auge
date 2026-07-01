// ============================================================================
// PDFProcessor.swift — PDF handling now lives in the `lesbar` package.
// auge keeps only the Configuration name (aliased to lesbar's pure type) so the
// existing call sites in main.swift and Analyzer keep compiling unchanged.
// ============================================================================

import LesbarCore

enum PDFProcessor {
    /// Rasterization DPI + embedded-text preference. Aliased to lesbar's pure type.
    typealias Configuration = LesbarCore.PDFConfiguration
}
