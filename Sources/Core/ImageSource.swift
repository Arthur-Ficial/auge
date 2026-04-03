import Foundation

public enum ImageSource {
    private static let supportedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic", "heif", "pdf"
    ]

    public static func isSupportedExtension(_ ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    public static func extensionFrom(path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    public static func validatePath(_ path: String) -> Result<URL, AugeError> {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path))
        }
        guard let ext = extensionFrom(path: path), isSupportedExtension(ext) else {
            return .failure(.unsupportedFormat(extensionFrom(path: path) ?? "unknown"))
        }
        return .success(url)
    }
}
