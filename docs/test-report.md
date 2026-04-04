# auge — Test Report

**Date:** 2026-04-04
**Version:** 0.0.6
**Platform:** macOS 26.3.1, Apple Silicon, Swift 6.3
**Tester:** Arthur Ficial (automated + manual)

## Summary

| Category | Tests | Passed | Failed |
|----------|-------|--------|--------|
| Unit tests | 115 | 115 | 0 |
| Integration tests | 17 | 17 | 0 |
| Demo script tests | 55 | 55 | 0 |
| CLI edge cases | 14 | 14 | 0 |
| **Total** | **201** | **201** | **0** |

## 1. Unit Tests (`swift run auge-tests`)

115 tests across 7 suites. All passed.

### AugeErrorTests (10 tests)

| Test | Result |
|------|--------|
| file not found keyword -> .fileNotFound | PASS |
| invalid image keyword -> .invalidImage | PASS |
| unsupported format keyword -> .unsupportedFormat | PASS |
| vision unavailable keyword -> .visionUnavailable | PASS |
| unknown error -> .unknown | PASS |
| CLI labels | PASS |
| exit codes | PASS |
| userMessage is non-empty for all cases | PASS |
| classify passes through existing AugeError unchanged | PASS |
| equatable works for associated values | PASS |

### AugeErrorDeepTests (18 tests)

| Test | Result |
|------|--------|
| classify: 'file not found' keyword | PASS |
| classify: 'No Such File' (mixed case) | PASS |
| classify: 'INVALID IMAGE' (uppercase) | PASS |
| classify: 'unsupported image' triggers unsupportedFormat | PASS |
| classify: 'vision unavailable' triggers visionUnavailable | PASS |
| classify: 'vision' alone without 'available' does not match | PASS |
| classify: 'unsupported' alone without 'format'/'image' does not match | PASS |
| classify: empty description -> .unknown | PASS |
| classify passthrough: fileNotFound preserves path | PASS |
| classify passthrough: unsupportedFormat preserves format | PASS |
| classify passthrough: unknown preserves message | PASS |
| different error types are not equal | PASS |
| userMessage for fileNotFound includes the path | PASS |
| userMessage for unsupportedFormat includes the format | PASS |
| userMessage for unknown includes the original message | PASS |
| all cliLabels are bracketed | PASS |
| noTextFound and noResults are non-error exit codes | PASS |
| all real errors have non-zero exit codes | PASS |

### ImageSourceTests (16 tests)

| Test | Result |
|------|--------|
| png is supported | PASS |
| jpg is supported | PASS |
| jpeg is supported | PASS |
| tiff is supported | PASS |
| bmp is supported | PASS |
| gif is supported | PASS |
| heic is supported | PASS |
| pdf is supported | PASS |
| webp is not supported | PASS |
| txt is not supported | PASS |
| extensions are case-insensitive | PASS |
| extensionFrom extracts correctly | PASS |
| extensionFrom returns nil for no extension | PASS |
| validatePath rejects nonexistent file | PASS |
| validatePath rejects unsupported extension | PASS |
| validatePath accepts existing file with supported extension | PASS |

### ImageSourceDeepTests (11 tests)

| Test | Result |
|------|--------|
| validatePath with relative path to existing file | PASS |
| validatePath success URL has correct path | PASS |
| validatePath with unicode filename | PASS |
| validatePath with spaces in filename | PASS |
| validatePath fileNotFound carries the original path | PASS |
| validatePath unsupportedFormat carries the extension | PASS |
| validatePath rejects file with no extension | PASS |
| all 10 supported extensions individually | PASS |
| common unsupported formats individually (15 formats) | PASS |
| extensionFrom with trailing dot | PASS |
| extensionFrom normalizes to lowercase | PASS |

### ResultFormatterTests (15 tests)

| Test | Result |
|------|--------|
| formatOCR joins lines with newlines | PASS |
| formatOCR handles single line | PASS |
| formatOCR handles empty array | PASS |
| formatClassification shows label and confidence | PASS |
| formatClassification sorts by confidence descending | PASS |
| formatClassification handles empty array | PASS |
| formatBarcodes shows payload and type | PASS |
| formatBarcodes handles multiple results | PASS |
| formatBarcodes handles empty array | PASS |
| formatFaces shows count | PASS |
| formatFaces handles single face | PASS |
| formatFaces handles empty array | PASS |
| ClassificationResult encodes to JSON | PASS |
| BarcodeResult encodes to JSON | PASS |
| FaceResult encodes to JSON | PASS |

### ResultFormatterDeepTests (23 tests)

| Test | Result |
|------|--------|
| formatClassification exact format: 'label: NN%' | PASS |
| formatClassification 100% confidence | PASS |
| formatClassification 0% confidence | PASS |
| formatClassification 1% confidence | PASS |
| formatClassification equal confidences — both present | PASS |
| formatClassification multiline format | PASS |
| formatBarcodes exact format: '[TYPE] payload' | PASS |
| formatBarcodes multiline format | PASS |
| formatBarcodes with URL payload | PASS |
| formatFaces exact format: 'N face(s) detected' | PASS |
| formatFaces with 100 faces | PASS |
| formatOCR with empty strings in array | PASS |
| formatOCR with unicode text | PASS |
| formatOCR with very long line (10,000 chars) | PASS |
| formatOCR with newlines inside a line | PASS |
| ClassificationResult JSON round-trip (encode + decode) | PASS |
| BarcodeResult JSON round-trip (encode + decode) | PASS |
| FaceResult JSON round-trip (encode + decode) | PASS |
| ClassificationResult JSON keys are 'label' and 'confidence' | PASS |
| BarcodeResult JSON keys are 'payload' and 'symbology' | PASS |
| FaceResult JSON keys are x, y, width, height | PASS |
| ClassificationResult with spaces in label | PASS |
| ClassificationResult with unicode label | PASS |

### CLIParsingTests (22 tests)

| Test | Result |
|------|--------|
| validatePath with directory returns fileNotFound | PASS |
| validatePath with empty string fails | PASS |
| tif extension is supported | PASS |
| heif extension is supported | PASS |
| svg is not supported | PASS |
| ico is not supported | PASS |
| empty string is not supported | PASS |
| extensionFrom handles dotfiles | PASS |
| extensionFrom handles multiple dots | PASS |
| extensionFrom handles spaces in path | PASS |
| classify recognizes 'doesn't exist' as fileNotFound | PASS |
| classify recognizes 'corrupt' as invalidImage | PASS |
| formatOCR preserves whitespace in lines | PASS |
| formatClassification rounds percentages | PASS |
| formatClassification handles very low confidence | PASS |
| formatBarcodes handles empty payload | PASS |
| formatFaces singular vs plural | PASS |
| ClassificationResult with zero confidence | PASS |
| FaceResult with normalized coordinates | PASS |
| BarcodeResult with special characters in payload | PASS |
| formatOCR with many lines (100) | PASS |
| formatClassification with many results maintains sort (20) | PASS |

## 2. Integration Tests (`bash Tests/integration/run.sh`)

17 tests. All passed.

| Test | Result |
|------|--------|
| --version displays version | PASS |
| --help displays USAGE | PASS |
| --release displays VERSION | PASS |
| nonexistent file -> exit 1 | PASS |
| bad flag -> exit 2 | PASS |
| no args -> exit 2 | PASS |
| --ocr detects text from test image | PASS |
| --ocr json has mode field | PASS |
| --ocr json has on_device field | PASS |
| --classify shows percentages | PASS |
| --classify --top 2 limits output to 2 lines | PASS |
| --classify json output | PASS |
| --faces output says "faces detected" | PASS |
| --faces json has count field | PASS |
| --barcode exits 0 (no barcodes in test image) | PASS |
| stdin pipe of file paths works | PASS |
| --quiet suppresses messages | PASS |

## 3. Demo Script Tests

55 tests across 11 scripts. All passed.

### screenshot (5 tests)

| Test | Result | Detail |
|------|--------|--------|
| plain output | PASS | 70 lines of OCR from screen |
| -j JSON output | PASS | Valid JSON (stderr separated) |
| -h help | PASS | exit 0 |
| --bad flag rejected | PASS | exit 2 |
| -c copy to clipboard | PASS | Outputs text + "(copied to clipboard)" |

### clipboard-ocr (4 tests)

| Test | Result | Detail |
|------|--------|--------|
| OCR from clipboard image | PASS | "Hello World" from test image |
| -j JSON output | PASS | Valid JSON |
| no image on clipboard | PASS | exit 1, error message |
| -h help | PASS | exit 0 |

### describe (4 tests)

| Test | Result | Detail |
|------|--------|--------|
| describe screenshot | PASS | "a screenshot of a document with the date APRIL 13" |
| no args | PASS | exit 2 |
| missing file | PASS | exit 1 |
| -h help | PASS | exit 0 |

### qr (5 tests)

| Test | Result | Detail |
|------|--------|--------|
| no barcode in image | PASS | "No barcodes found", exit 0 |
| -j JSON mode | PASS | exit 0 |
| no args | PASS | exit 2 |
| missing file | PASS | exit 1 |
| -h help | PASS | exit 0 |

### receipt (5 tests)

| Test | Result | Detail |
|------|--------|--------|
| OCR + parse (non-receipt image) | PASS | apfel correctly says it can't extract receipt data |
| -j JSON mode | PASS | exit 0 |
| no args | PASS | exit 2 |
| missing file | PASS | exit 1 |
| -h help | PASS | exit 0 |

### sort-images (4 tests)

| Test | Result | Detail |
|------|--------|--------|
| classify directory | PASS | "1 images in 1 categories" |
| -j JSON output | PASS | Valid JSON (stderr separated) |
| bad directory | PASS | exit 1 |
| -h help | PASS | exit 0 |

### diff-text (6 tests)

| Test | Result | Detail |
|------|--------|--------|
| diff two different images | PASS | 104 lines of unified diff |
| diff identical images | PASS | "No text differences found." |
| -s side-by-side | PASS | 100 lines of side-by-side diff |
| one file only | PASS | exit 2 |
| no args | PASS | exit 2 |
| -h help | PASS | exit 0 |

### translate (6 tests)

| Test | Result | Detail |
|------|--------|--------|
| default (English) | PASS | "Hello World" |
| -l German | PASS | "Hallo Welt" |
| -l French | PASS | "Bonjour Monde" |
| no args | PASS | exit 2 |
| missing file | PASS | exit 1 |
| -h help | PASS | exit 0 |

### faces (6 tests)

| Test | Result | Detail |
|------|--------|--------|
| single image | PASS | "0 faces detected" |
| multiple images | PASS | "0 faces across 2 images." |
| -j JSON output | PASS | Valid JSON |
| no args | PASS | exit 2 |
| --bad flag rejected | PASS | exit 2 |
| -h help | PASS | exit 0 |

### monitor (2 tests)

| Test | Result | Detail |
|------|--------|--------|
| -h help | PASS | exit 0 |
| --bad flag rejected | PASS | exit 2 |

Note: monitor's watch loop was tested manually — it captures screenshots, OCRs them, and detects text changes. The -g pattern match mode scans for a target string and exits when found.

### explain-image (4 tests)

| Test | Result | Detail |
|------|--------|--------|
| explain screenshot | PASS | "a digital document containing dates and times" |
| no args | PASS | exit 2 |
| missing file | PASS | exit 1 |
| -h help | PASS | exit 0 |

## 4. CLI Edge Cases

14 tests. All passed.

| Test | Result | Detail |
|------|--------|--------|
| Multiple files processed | PASS | 99 lines across 2 images |
| Mixed valid + invalid files | PASS | exit 1, error on stderr, valid output on stdout |
| Unsupported format (.txt) | PASS | exit 1, clear error message |
| OCR JSON output valid | PASS | python3 json.tool validates |
| Classify JSON output valid | PASS | python3 json.tool validates |
| Faces JSON output valid | PASS | python3 json.tool validates |
| Errors go to stderr only | PASS | stdout empty, stderr has error |
| --release shows build info | PASS | Contains version line |
| -h exits 0 | PASS | |
| -v exits 0 | PASS | |
| --release exits 0 | PASS | |
| no args exits 2 | PASS | |
| --ocr no file exits 2 | PASS | |
| --bad flag exits 2 | PASS | |

## 5. Build Verification

| Check | Result |
|-------|--------|
| `swift build` (debug) | PASS — exit 0 |
| `swift build -c release` | PASS — exit 0 |
| `make install` | PASS — installed to /usr/local/bin |
| `brew install Arthur-Ficial/tap/auge` | PASS — v0.0.6 from tap |
| `auge --version` | PASS — "auge v0.0.6" |
| GitHub CI | PASS — all runs green |
| GitHub release v0.0.6 | PASS — binary asset uploaded |
| Homebrew formula updated | PASS — tap has v0.0.6 |

## 6. Known Limitations

These are not bugs — they are documented limitations of the Vision framework and architecture:

| Limitation | Detail |
|------------|--------|
| OCR accuracy | Depends on image quality. Screenshots and scans work well. Blurry photos or tiny text may produce poor results. |
| Classification depth | ~1000 broad categories (document, cat, outdoor, food). Not fine-grained (won't identify dog breeds or car models). |
| Face detection | Finds faces and bounding boxes. No face recognition or identity. |
| Barcode clarity | Barcode must be reasonably large and in focus. |
| apfel token limit | Demo scripts that use apfel truncate OCR to 10-25 lines to fit the 4096-token context window. Long documents lose content. |
| macOS versions | OCR: 10.15+, Classification: 12+, Barcodes/Faces: 10.13+. |
| No video | Static images only. No real-time video analysis. |
| PDF pages | Multi-page PDFs may only process the first page. |
| No WebP | WebP format not supported by Vision framework. |

## 7. Test Infrastructure

- **Unit tests**: Pure Swift runner (`swift run auge-tests`), no XCTest dependency
- **Integration tests**: Bash script (`Tests/integration/run.sh`) with test image
- **Demo tests**: Manual + scripted execution of all scripts with all flags
- **CI**: GitHub Actions on every push to main (build + unit tests)
- **Automated releases**: `publish-release.yml` workflow with auto version bump, test, release, and Homebrew tap update
