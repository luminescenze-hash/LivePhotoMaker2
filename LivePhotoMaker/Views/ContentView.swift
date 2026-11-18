import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @Bindable var model: AppModel

    @State private var isPickerPresented = false
    @State private var pickingRole: FolderRole = .movies
    @State private var showClearHistoryConfirm = false
    @State private var showFailures = false
    @State private var showUnmatched = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    folderCards
                    statusSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("实况照片合成")
            .toolbar { topBarMenu }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .task { model.onAppear() }
            .sheet(isPresented: $isPickerPresented) {
                FolderPicker(
                    onPick: { url in
                        isPickerPresented = false
                        let role = pickingRole
                        model.setFolder(url, role: role)
                    },
                    onCancel: { isPickerPresented = false }
                )
            }
            .sheet(isPresented: $showFailures) {
                FailureListView(failures: model.failures)
            }
            .sheet(isPresented: $showUnmatched) {
                UnmatchedListView(
                    movies: model.unmatchedMovies,
                    photos: model.unmatchedPhotos
                )
            }
            .alert("需要相册写入权限", isPresented: $model.permissionAlert) {
                Button("前往设置") { openSettings() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请在“设置 → 隐私与安全性 → 照片”中允许本 App 添加照片。")
            }
            .confirmationDialog(
                "清除导入记录？",
                isPresented: $showClearHistoryConfirm,
                titleVisibility: .visible
            ) {
                Button("清除", role: .destructive) { model.clearHistory() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清除后，之前合成过的文件将不再被自动跳过。")
            }
        }
    }

    // MARK: - 顶部说明

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "livephoto")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("把 U 盘里的照片和视频合成实况照片")
                    .font(.subheadline.weight(.semibold))
                Text("从 GRLIFE 中读取 MOV，从 DCIM 中读取同名 JPG，合成后保存到系统相册。文件名忽略大小写，DCIM 的子文件夹会被递归查找。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 文件夹选择

    private var folderCards: some View {
        VStack(spacing: 12) {
            FolderCardView(
                title: "GRLIFE 文件夹（MOV）",
                subtitle: "选择 U 盘根目录下的 GRLIFE",
                systemImage: "film",
                folder: model.movieFolder,
                selectTitle: "选择文件夹",
                action: { presentPicker(for: .movies) }
            )

            FolderCardView(
                title: "DCIM 文件夹（JPG）",
                subtitle: "选择 U 盘根目录下的 DCIM",
                systemImage: "photo.on.rectangle.angled",
                folder: model.photoFolder,
                selectTitle: "选择文件夹",
                action: { presentPicker(for: .photos) }
            )
        }
    }

    private func presentPicker(for role: FolderRole) {
        guard !model.isImporting else { return }
        pickingRole = role
        isPickerPresented = true
    }

    // MARK: - 扫描 / 结果

    @ViewBuilder
    private var statusSection: some View {
        if model.isScanning {
            HStack(spacing: 10) {
                ProgressView()
                Text("正在扫描文件夹…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        } else if let error = model.scanError {
            scanErrorCard(error)
        } else if model.hasFolders {
            resultsCard

            if let summary = model.importSummary {
                importResultCard(summary)
            }

            if !model.pairs.isEmpty {
                pairsList
            }

            if !model.unmatchedMovies.isEmpty || !model.unmatchedPhotos.isEmpty {
                unmatchedCard
            }

            if model.ignoredDuplicateMovies + model.ignoredDuplicatePhotos > 0 {
                duplicateNote
            }
        }
    }

    private func scanErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("无法扫描文件夹", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("重新扫描") { model.scan() }
                .font(.footnote.weight(.medium))
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("匹配结果", systemImage: "photo.stack")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    model.scan()
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(model.isImporting)
            }

            HStack(spacing: 10) {
                statTile(value: model.pairs.count, label: "可合成", tint: .green)
                statTile(value: model.unmatchedMovies.count, label: "缺 JPG", tint: .orange)
                statTile(value: model.unmatchedPhotos.count, label: "缺 MOV", tint: .gray)
            }

            if model.pairs.isEmpty {
                Text("没有找到同名的 MOV 与 JPG。配对依据是去掉扩展名后的文件名，例如 IMG_0001.MOV ↔ IMG_0001.JPG。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.historySkippedCount > 0 {
                Text("其中 \(model.historySkippedCount) 对之前已合成过，默认会自动跳过。可在右上角菜单里调整。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func statTile(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func importResultCard(_ summary: ImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("本次合成完成", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            HStack(spacing: 8) {
                resultPill(title: "成功", value: summary.success, tint: .green)
                resultPill(title: "失败", value: summary.failure, tint: .red)
                resultPill(title: "跳过", value: summary.skipped, tint: .gray)
            }

            if !model.failures.isEmpty {
                Button {
                    showFailures = true
                } label: {
                    Label("查看失败详情", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func resultPill(title: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.1), in: Capsule())
    }

    private var pairsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文件列表（\(model.pairs.count)）")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 2)

            LazyVStack(spacing: 8) {
                ForEach(model.pairs) { pair in
                    PairRowView(
                        pair: pair,
                        wasImportedBefore: model.wasImported(pair)
                    )
                    .padding(10)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
    }

    private var unmatchedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("有未匹配的文件")
                    .font(.footnote.weight(.medium))
                Text("\(model.unmatchedMovies.count) 个 MOV、\(model.unmatchedPhotos.count) 个 JPG 找不到同名对象")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("查看") { showUnmatched = true }
                .font(.caption)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var duplicateNote: some View {
        Text("已忽略 \(model.ignoredDuplicateMovies) 个重名 MOV、\(model.ignoredDuplicatePhotos) 个重名 JPG；每个文件名只处理路径层级最浅的一个文件。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 底部操作栏

    @ViewBuilder
    private var bottomBar: some View {
        if model.hasFolders, !model.isScanning, !model.pairs.isEmpty {
            VStack(spacing: 10) {
                if model.isImporting {
                    ProgressView(value: model.importProgress.fraction)

                    HStack(spacing: 6) {
                        Text(model.currentPairName ?? "正在合成…")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(model.importProgress.done)/\(model.importProgress.total)")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Button {
                        model.cancelImport()
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        model.startImport()
                    } label: {
                        Label(
                            "合成 \(model.importablePairs.count) 张实况照片",
                            systemImage: "wand.and.stars"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.importablePairs.isEmpty)

                    Text(footerHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var footerHint: String {
        if model.importablePairs.isEmpty {
            return model.historySkippedCount > 0
                ? "所有可合成文件都已合成过"
                : "没有可合成的文件"
        }
        if model.historySkippedCount > 0 {
            return "已自动跳过 \(model.historySkippedCount) 对之前合成过的文件"
        }
        return "合成过程中请保持 App 在前台，并确保 U 盘连接稳定"
    }

    // MARK: - 菜单

    @ToolbarContentBuilder
    private var topBarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle(isOn: $model.skipImported) {
                    Label("跳过已合成过的文件", systemImage: "clock.arrow.circlepath")
                }

                Divider()

                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    Label("清除导入记录", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
            }
            .disabled(model.isImporting)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 失败详情

private struct FailureListView: View {
    let failures: [ImportFailure]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if failures.isEmpty {
                    ContentUnavailableView("没有失败记录", systemImage: "checkmark.circle")
                } else {
                    List(failures) { failure in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(failure.name)
                                .font(.subheadline.weight(.semibold))
                            Text(failure.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("失败详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 未匹配文件

private struct UnmatchedListView: View {
    let movies: [FoundFile]
    let photos: [FoundFile]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if movies.isEmpty {
                        Text("没有未匹配的 MOV")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(movies) { file in
                            fileRow(file, kind: "MOV")
                        }
                    }
                } header: {
                    Text("没有同名 JPG 的 MOV（\(movies.count)）")
                } footer: {
                    Text("这些 MOV 在 DCIM 中找不到去掉扩展名后同名的 JPG。")
                }

                Section {
                    if photos.isEmpty {
                        Text("没有未匹配的 JPG")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(photos) { file in
                            fileRow(file, kind: "JPG")
                        }
                    }
                } header: {
                    Text("没有同名 MOV 的 JPG（\(photos.count)）")
                } footer: {
                    Text("这些 JPG 在 GRLIFE 中找不到去掉扩展名后同名的 MOV。")
                }
            }
            .navigationTitle("未匹配文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func fileRow(_ file: FoundFile, kind: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.relativePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(kind)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

