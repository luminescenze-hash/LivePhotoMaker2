import Foundation
import Observation
import Photos

@MainActor
@Observable
final class AppModel {
    // MARK: - 文件夹

    private(set) var movieFolder: FolderRef?
    private(set) var photoFolder: FolderRef?

    // MARK: - 扫描结果

    private(set) var isScanning = false
    private(set) var pairs: [MediaPair] = []
    private(set) var unmatchedMovies: [FoundFile] = []
    private(set) var unmatchedPhotos: [FoundFile] = []
    private(set) var ignoredDuplicateMovies = 0
    private(set) var ignoredDuplicatePhotos = 0
    private(set) var scanError: String?

    // MARK: - 导入状态

    /// 是否跳过之前已经合成过的文件（按文件名称 + 大小 + 文件夹组合判断）。
    var skipImported = true
    private(set) var importedKeys: Set<String> = []
    private(set) var isImporting = false
    private(set) var currentPairName: String?
    private(set) var importProgress = ImportProgress(done: 0, total: 0)
    private(set) var importSummary: ImportSummary?
    private(set) var failures: [ImportFailure] = []

    /// 相册权限被拒绝时置为 true，由界面弹窗引导用户去设置。
    var permissionAlert = false

    private let defaults = UserDefaults.standard
    private let importer = LivePhotoImporter()
    private var scanTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?

    private enum Keys {
        static let movieBookmark = "movieFolderBookmark"
        static let photoBookmark = "photoFolderBookmark"
        static let importedKeys = "importedKeys"
    }

    init() {
        importedKeys = Set(defaults.stringArray(forKey: Keys.importedKeys) ?? [])
        movieFolder = restoreFolder(forKey: Keys.movieBookmark)
        photoFolder = restoreFolder(forKey: Keys.photoBookmark)
    }

    // MARK: - 生命周期

    func onAppear() {
        if movieFolder != nil, photoFolder != nil, pairs.isEmpty, !isScanning, scanError == nil {
            scan()
        }
    }

    // MARK: - 文件夹选择

    func setFolder(_ url: URL, role: FolderRole) {
        guard !isImporting else { return }

        let folder = FolderRef(url: url)
        switch role {
        case .movies:
            movieFolder = folder
            if let bookmark = folder.makeBookmark() {
                defaults.set(bookmark, forKey: Keys.movieBookmark)
            }
        case .photos:
            photoFolder = folder
            if let bookmark = folder.makeBookmark() {
                defaults.set(bookmark, forKey: Keys.photoBookmark)
            }
        }

        scan()
    }

    private func restoreFolder(forKey key: String) -> FolderRef? {
        guard let data = defaults.data(forKey: key) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            defaults.removeObject(forKey: key)
            return nil
        }

        let folder = FolderRef(url: url)
        if isStale, let refreshed = folder.makeBookmark() {
            defaults.set(refreshed, forKey: key)
        }
        return folder
    }

    // MARK: - 扫描

    func scan() {
        guard !isImporting else { return }

        scanTask?.cancel()
        resetScanResults()

        guard let movieFolder, let photoFolder else {
            return
        }

        isScanning = true
        scanError = nil

        let moviesRoot = movieFolder.url
        let photosRoot = photoFolder.url

        scanTask = Task { [weak self] in
            do {
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try MediaScanner.scan(moviesRoot: moviesRoot, photosRoot: photosRoot)
                }.value

                guard let self, !Task.isCancelled else { return }
                self.pairs = outcome.pairs
                self.unmatchedMovies = outcome.unmatchedMovies
                self.unmatchedPhotos = outcome.unmatchedPhotos
                self.ignoredDuplicateMovies = outcome.ignoredDuplicateMovies
                self.ignoredDuplicatePhotos = outcome.ignoredDuplicatePhotos
                self.isScanning = false
            } catch is CancellationError {
                // 已开始新的扫描，忽略本次结果。
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.scanError = error.localizedDescription
                self.isScanning = false
            }
        }
    }

    private func resetScanResults() {
        pairs = []
        unmatchedMovies = []
        unmatchedPhotos = []
        ignoredDuplicateMovies = 0
        ignoredDuplicatePhotos = 0
        scanError = nil
        isScanning = false
        importSummary = nil
        failures = []
        importProgress = ImportProgress(done: 0, total: 0)
    }

    // MARK: - 计算属性

    var hasFolders: Bool {
        movieFolder != nil && photoFolder != nil
    }

    /// 每次导入使用一个稳定 key，避免重复处理同一对文件。
    func importKey(for pair: MediaPair) -> String {
        let scope = "\(movieFolder?.name ?? "-")|\(photoFolder?.name ?? "-")"
        return [
            scope,
            "\(pair.movie.name.lowercased()):\(pair.movie.size)",
            "\(pair.photo.name.lowercased()):\(pair.photo.size)"
        ].joined(separator: "|")
    }

    func wasImported(_ pair: MediaPair) -> Bool {
        importedKeys.contains(importKey(for: pair))
    }

    /// 本轮真正会导入的配对。
    var importablePairs: [MediaPair] {
        pairs.filter { pair in
            switch pair.status {
            case .pending, .failed(_):
                if skipImported && wasImported(pair) { return false }
                return true
            case .importing, .imported:
                return false
            }
        }
    }

    /// 因“之前已合成过”而被跳过的数量。
    var historySkippedCount: Int {
        guard skipImported else { return 0 }
        return pairs.reduce(into: 0) { count, pair in
            switch pair.status {
            case .pending, .failed(_):
                if wasImported(pair) { count += 1 }
            case .importing, .imported:
                break
            }
        }
    }

    // MARK: - 导入

    func startImport() {
        guard !isImporting, importTask == nil else { return }

        let items = importablePairs
        guard !items.isEmpty else { return }
        let skipped = historySkippedCount

        isImporting = true
        importSummary = nil
        failures = []
        importProgress = ImportProgress(done: 0, total: items.count)

        importTask = Task { [weak self] in
            guard let self else { return }

            let granted = await self.ensurePhotoLibraryPermission()
            guard granted else {
                self.finishWithoutImporting()
                self.permissionAlert = true
                return
            }

            if Task.isCancelled {
                self.finishWithoutImporting()
                return
            }

            await self.performImport(items: items, skipped: skipped)
        }
    }

    func cancelImport() {
        importTask?.cancel()
    }

    private func ensurePhotoLibraryPermission() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        default:
            return false
        }
    }

    private func performImport(items: [MediaPair], skipped: Int) async {
        var successCount = 0
        var failureCount = 0
        var done = 0

        for pair in items {
            if Task.isCancelled { break }

            currentPairName = pair.stem
            setStatus(.importing, for: pair.id)

            do {
                try await importer.importPair(movieURL: pair.movie.url, photoURL: pair.photo.url)
                setStatus(.imported, for: pair.id)
                importedKeys.insert(importKey(for: pair))
                persistImportedKeys()
                successCount += 1
            } catch is CancellationError {
                setStatus(.pending, for: pair.id)
                break
            } catch {
                let message = error.localizedDescription
                setStatus(.failed(message), for: pair.id)
                failures.append(ImportFailure(name: pair.stem, message: message))
                failureCount += 1
            }

            done += 1
            importProgress = ImportProgress(done: done, total: items.count)
        }

        isImporting = false
        currentPairName = nil
        importSummary = ImportSummary(success: successCount, failure: failureCount, skipped: skipped)
        importTask = nil
    }

    private func finishWithoutImporting() {
        isImporting = false
        currentPairName = nil
        importProgress = ImportProgress(done: 0, total: 0)
        importTask = nil
    }

    private func setStatus(_ status: PairImportStatus, for pairID: String) {
        guard let index = pairs.firstIndex(where: { $0.id == pairID }) else { return }
        pairs[index].status = status
    }

    private func persistImportedKeys() {
        defaults.set(Array(importedKeys), forKey: Keys.importedKeys)
    }

    // MARK: - 导入记录

    func clearHistory() {
        importedKeys.removeAll()
        defaults.removeObject(forKey: Keys.importedKeys)

        // 本次运行中已经导入的条目也恢复为可再次导入。
        for index in pairs.indices {
            if pairs[index].status == .imported {
                pairs[index].status = .pending
            }
        }
    }
}
