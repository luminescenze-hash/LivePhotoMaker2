import Foundation

struct ScanOutcome: Sendable {
    var pairs: [MediaPair] = []
    var unmatchedMovies: [FoundFile] = []
    var unmatchedPhotos: [FoundFile] = []
    var ignoredDuplicateMovies = 0
    var ignoredDuplicatePhotos = 0
}

enum MediaScanError: LocalizedError {
    case cannotEnumerate(folder: String)

    var errorDescription: String? {
        switch self {
        case .cannotEnumerate(let folder):
            return "无法读取文件夹「\(folder)」。请确认 U 盘仍然连接，并重新选择文件夹。"
        }
    }
}

enum MediaScanner {
    /// 目前按需求只匹配 MOV 与 JPG/JPEG。
    /// 如需支持 HEIC，把 "heic" 加入 photoExtensions 即可。
    static let movieExtensions: Set<String> = ["mov"]
    static let photoExtensions: Set<String> = ["jpg", "jpeg"]

    /// U 盘上常见的系统目录，直接跳过。
    private static let ignoredDirectoryNames: Set<String> = [
        "$recycle.bin",
        "system volume information",
        ".trashes",
        ".spotlight-v100",
        ".fseventsd"
    ]

    static func scan(moviesRoot: URL, photosRoot: URL) throws -> ScanOutcome {
        let movies = try collectFiles(in: moviesRoot, extensions: movieExtensions)
        let photos = try collectFiles(in: photosRoot, extensions: photoExtensions)

        // 同一个文件名出现多次时，只取路径层级最浅的一个（例如优先 DCIM 根目录），
        // 避免不同子目录里的同名文件造成歧义。
        var movieByStem: [String: FoundFile] = [:]
        var duplicateMovies = 0
        for movie in movies.sorted(by: { $0.url.pathComponents.count < $1.url.pathComponents.count }) {
            let key = movie.stem.lowercased()
            if movieByStem[key] == nil {
                movieByStem[key] = movie
            } else {
                duplicateMovies += 1
            }
        }

        var photoByStem: [String: FoundFile] = [:]
        var duplicatePhotos = 0
        for photo in photos.sorted(by: { $0.url.pathComponents.count < $1.url.pathComponents.count }) {
            let key = photo.stem.lowercased()
            if photoByStem[key] == nil {
                photoByStem[key] = photo
            } else {
                duplicatePhotos += 1
            }
        }

        var pairs: [MediaPair] = []
        var unmatchedMovies: [FoundFile] = []
        var matchedStems = Set<String>()

        for movie in movieByStem.values.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let key = movie.stem.lowercased()
            if let photo = photoByStem[key] {
                pairs.append(MediaPair(stem: movie.stem, movie: movie, photo: photo))
                matchedStems.insert(key)
            } else {
                unmatchedMovies.append(movie)
            }
        }

        let unmatchedPhotos = photoByStem
            .filter { !matchedStems.contains($0.key) }
            .map { $0.value }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return ScanOutcome(
            pairs: pairs,
            unmatchedMovies: unmatchedMovies,
            unmatchedPhotos: unmatchedPhotos,
            ignoredDuplicateMovies: duplicateMovies,
            ignoredDuplicatePhotos: duplicatePhotos
        )
    }

    // MARK: - 递归扫描

    private static func collectFiles(in root: URL, extensions: Set<String>) throws -> [FoundFile] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw MediaScanError.cannotEnumerate(folder: root.lastPathComponent)
        }

        var files: [FoundFile] = []
        for case let url as URL in enumerator {
            let lowercasedComponents = url.pathComponents.map { $0.lowercased() }
            if lowercasedComponents.contains(where: { ignoredDirectoryNames.contains($0) }) {
                continue
            }

            guard extensions.contains(url.pathExtension.lowercased()) else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                continue
            }

            let name = url.lastPathComponent
            let stem = (name as NSString).deletingPathExtension

            var relativePath = url.path
            if relativePath.hasPrefix(root.path) {
                relativePath = String(relativePath.dropFirst(root.path.count))
            }
            relativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            files.append(FoundFile(
                url: url,
                name: name,
                stem: stem,
                relativePath: relativePath,
                size: Int64(values.fileSize ?? 0)
            ))
        }

        return files
    }
}
