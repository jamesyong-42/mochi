import Foundation
import Virtualization

@Observable
final class IPSWService {

    var isDownloading = false
    var downloadProgress: Double = 0.0
    var totalBytes: Int64 = 0
    var downloadedBytes: Int64 = 0
    var downloadSpeed: Double = 0.0 // bytes per second
    var cachedIPSWURL: URL?
    var errorMessage: String?

    private var speedSampleTime: Date = .now
    private var speedSampleBytes: Int64 = 0

    private static let cacheDirectory: URL = {
        StorageService.appSupportURL.appendingPathComponent("IPSWCache", isDirectory: true)
    }()

    // MARK: - Fetch Latest Image Info

    func fetchLatestImageInfo() async throws -> VZMacOSRestoreImage {
        try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.fetchLatestSupported { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Ensure IPSW Available

    func ensureIPSWAvailable() async throws -> URL {
        if let cached = findCachedIPSW() {
            cachedIPSWURL = cached
            return cached
        }

        let restoreImage = try await fetchLatestImageInfo()
        let downloadURL = restoreImage.url

        let destinationURL = try await downloadIPSW(from: downloadURL)
        cachedIPSWURL = destinationURL
        return destinationURL
    }

    // MARK: - Configuration Requirements

    func mostFeaturefulConfiguration(from restoreImage: VZMacOSRestoreImage) -> VZMacOSConfigurationRequirements? {
        restoreImage.mostFeaturefulSupportedConfiguration
    }

    // MARK: - Private

    private func findCachedIPSW() -> URL? {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)

        guard let contents = try? fm.contentsOfDirectory(
            at: Self.cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        return contents.first { $0.pathExtension.lowercased() == "ipsw" }
    }

    private func downloadIPSW(from url: URL) async throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)

        let fileName = url.lastPathComponent
        let destinationURL = Self.cacheDirectory.appendingPathComponent(fileName)

        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }

        isDownloading = true
        downloadProgress = 0.0
        totalBytes = 0
        downloadedBytes = 0
        downloadSpeed = 0.0
        speedSampleTime = .now
        speedSampleBytes = 0
        errorMessage = nil

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let delegate = DownloadDelegate(
                    continuation: continuation,
                    onProgress: { [weak self] written, total in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.downloadedBytes = written
                            self.totalBytes = total
                            self.downloadProgress = total > 0 ? Double(written) / Double(total) : 0

                            // Calculate speed (sample every 0.5s to smooth out)
                            let now = Date.now
                            let elapsed = now.timeIntervalSince(self.speedSampleTime)
                            if elapsed >= 0.5 {
                                let bytesInInterval = written - self.speedSampleBytes
                                self.downloadSpeed = Double(bytesInInterval) / elapsed
                                self.speedSampleTime = now
                                self.speedSampleBytes = written
                            }
                        }
                    }
                )
                // Keep delegate alive by storing it
                self._activeDelegate = delegate

                let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
                let task = session.downloadTask(with: url)
                delegate.session = session
                task.resume()
            }

            // Move downloaded file to final location
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: result, to: destinationURL)

            downloadProgress = 1.0
            isDownloading = false
            _activeDelegate = nil
            return destinationURL

        } catch {
            isDownloading = false
            _activeDelegate = nil
            throw error
        }
    }

    // Strong reference to keep delegate alive during download
    private var _activeDelegate: DownloadDelegate?
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    private let continuation: CheckedContinuation<URL, Error>
    private let onProgress: @Sendable (_ written: Int64, _ total: Int64) -> Void
    private let lock = NSLock()
    nonisolated(unsafe) private var _resumed = false
    nonisolated(unsafe) var session: URLSession?

    private func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
    }

    init(
        continuation: CheckedContinuation<URL, Error>,
        onProgress: @escaping @Sendable (_ written: Int64, _ total: Int64) -> Void
    ) {
        self.continuation = continuation
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard markResumed() else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ipsw")
        do {
            try FileManager.default.moveItem(at: location, to: tempURL)
            continuation.resume(returning: tempURL)
        } catch {
            continuation.resume(throwing: error)
        }
        session.finishTasksAndInvalidate()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            guard markResumed() else { return }
            continuation.resume(throwing: error)
        }
        session.finishTasksAndInvalidate()
    }
}

enum IPSWError: LocalizedError {
    case noDownloadURL
    case downloadFailed
    case invalidRestoreImage

    var errorDescription: String? {
        switch self {
        case .noDownloadURL:
            "No download URL available for the restore image"
        case .downloadFailed:
            "Failed to download the IPSW restore image"
        case .invalidRestoreImage:
            "The restore image is invalid or unsupported"
        }
    }
}
