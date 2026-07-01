// ============================================================================
// LesbarAliases.swift — pure OCR helpers now live in the `lesbar` package.
// These aliases keep auge's source and tests (ImageSizePolicyTests, LineMergerTests,
// LanguageHintsTests) compiling and passing unchanged while the implementations are
// maintained once, in lesbar.
// ============================================================================

import LesbarCore

/// Image resize policy for OCR preprocessing. Owned by lesbar.
public typealias ImageSizePolicy = LesbarCore.ImageSizePolicy

/// Multi-pass OCR line merger. Owned by lesbar.
public typealias LineMerger = LesbarCore.LineMerger

/// `en-US,de-DE` language-hint parser. Owned by lesbar.
public typealias LanguageHints = LesbarCore.LanguageHints
