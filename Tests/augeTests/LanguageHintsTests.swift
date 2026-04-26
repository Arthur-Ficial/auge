import Foundation
import AugeCore

func runLanguageHintsTests() {
    test("single tag") {
        try assertEqual(LanguageHints.parse("en-US"), ["en-US"])
    }
    test("multiple tags split by comma") {
        try assertEqual(LanguageHints.parse("en-US,de-DE,fr-FR"), ["en-US", "de-DE", "fr-FR"])
    }
    test("whitespace around tags is trimmed") {
        try assertEqual(LanguageHints.parse(" en-US , de-DE "), ["en-US", "de-DE"])
    }
    test("empty entries dropped") {
        try assertEqual(LanguageHints.parse("en-US,,de-DE"), ["en-US", "de-DE"])
    }
    test("trailing comma ignored") {
        try assertEqual(LanguageHints.parse("en-US,"), ["en-US"])
    }
    test("leading comma ignored") {
        try assertEqual(LanguageHints.parse(",en-US"), ["en-US"])
    }
    test("only commas yields empty") {
        try assertEqual(LanguageHints.parse(",,,"), [])
    }
    test("empty string yields empty") {
        try assertEqual(LanguageHints.parse(""), [])
    }
    test("only whitespace yields empty") {
        try assertEqual(LanguageHints.parse("   "), [])
    }
    test("preserves priority order") {
        let hints = LanguageHints.parse("zh-Hant,zh-Hans,en")
        try assertEqual(hints[0], "zh-Hant")
        try assertEqual(hints[2], "en")
    }
    test("script subtags preserved") {
        try assertEqual(LanguageHints.parse("zh-Hant,sr-Cyrl"), ["zh-Hant", "sr-Cyrl"])
    }
    test("tabs and newlines trimmed") {
        try assertEqual(LanguageHints.parse("en-US\t,\nde-DE"), ["en-US", "de-DE"])
    }
}
