import Foundation

/// 持有用户通过“文件”选择的外部文件夹 URL，并在整个使用期间保持 security-scoped 访问权限。
final class FolderRef {
    let url: URL
    let name: String

    private var isAccessingSecurityScopedResource = false

    init(url: URL) {
        self.url = url
        let lastComponent = url.lastPathComponent
        self.name = lastComponent.isEmpty ? url.path : lastComponent
        self.isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if isAccessingSecurityScopedResource {
            url.stopAccessingSecurityScopedResource()
        }
    }

    /// 在权限仍然有效时生成书签，供下次启动时恢复访问。
    func makeBookmark() -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
