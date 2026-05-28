import SwiftUI
import UniformTypeIdentifiers

private enum ReviewPhase: Equatable {
    case idle
    case uploading
    case reviewing(progress: String)
    case complete(sessionId: String)
    case failed(String)
}

struct HomeView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Binding var selectedSession: ReviewSessionSummary?
    @Binding var selectedTab: Int

    @State private var phase: ReviewPhase = .idle
    @State private var isImporterPresented = false
    @State private var reviewTask: Task<Void, Never>? = nil

    private var statusText: String {
        switch phase {
        case .idle: return "等待上传合同"
        case .uploading: return "正在识别文件内容..."
        case .reviewing(let p): return p
        case .complete: return "审查完成！"
        case .failed(let e): return e
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    DogeBadge()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Doge 合同审查助手")
                            .font(.system(size: 22, weight: .black))
                        HStack(spacing: 6) {
                            phaseIndicator
                            Text(statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(phaseTextColor)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                .pixelPanel()

                // Upload area
                uploadPanel

                // Q&A entry card — switches to Q&A tab
                Button {
                    selectedTab = 1
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title2)
                            .foregroundStyle(DogeTheme.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q&A")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(DogeTheme.ink)
                            Text("上传合同后为您分析，报告生成完成后可以进行问答")
                                .font(.caption)
                                .foregroundStyle(DogeTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(DogeTheme.muted)
                    }
                    .pixelPanel(border: DogeTheme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(DogeTheme.background)
        .navigationTitle("首页")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                .pdf, .text, .image,
                UTType(filenameExtension: "docx") ?? .data,
                UTType(filenameExtension: "doc") ?? .data,
            ]
        ) { result in
            switch result {
            case .success(let url):
                reviewTask?.cancel()
                reviewTask = Task { await startReview(fileURL: url) }
            case .failure(let error):
                phase = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: Upload panel

    @ViewBuilder
    private var uploadPanel: some View {
        VStack(spacing: 16) {
            switch phase {
            case .uploading:
                UploadingIndicator()

            case .reviewing(let progress):
                ReviewingProgress(progress: progress)

            case .complete(let sessionId):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(DogeTheme.green)
                    Text("审查完成！")
                        .font(.title2.bold())
                    Text("请前往「历史」查看完整报告")
                        .font(.footnote)
                        .foregroundStyle(DogeTheme.muted)
                    HStack(spacing: 12) {
                        Button {
                            selectedTab = 2
                        } label: {
                            Label("查看报告", systemImage: "doc.text.magnifyingglass")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DogeTheme.green)
                                .foregroundStyle(.white)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2.5))
                        }
                        Button {
                            phase = .idle
                        } label: {
                            Text("重新上传")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white)
                                .foregroundStyle(DogeTheme.ink)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.muted, lineWidth: 2))
                        }
                    }
                }

            case .failed(let msg):
                VStack(spacing: 12) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(DogeTheme.red)
                    Text("出错了")
                        .font(.title3.bold())
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(DogeTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    Button("重试") { phase = .idle }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DogeTheme.blue)
                        .padding(.top, 4)
                }

            case .idle:
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(DogeTheme.blue.opacity(0.7))

                VStack(spacing: 4) {
                    Text("上传合同")
                        .font(.title2.bold())
                    Text("文档或照片")
                        .font(.subheadline)
                        .foregroundStyle(DogeTheme.muted)
                }

                Text("支持：TXT / DOCX / PDF / JPG / PNG / WEBP")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DogeTheme.muted)
                    .multilineTextAlignment(.center)

                Button {
                    isImporterPresented = true
                } label: {
                    Label("选择文件", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DogeTheme.blue)
                        .foregroundStyle(.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2.5))
                }

                HStack {
                    Rectangle()
                        .fill(DogeTheme.muted.opacity(0.2))
                        .frame(height: 1)
                    Text("或直接拖拽文件或照片到这里")
                        .font(.caption)
                        .foregroundStyle(DogeTheme.muted)
                        .lineLimit(1)
                        .fixedSize()
                    Rectangle()
                        .fill(DogeTheme.muted.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.top, 2)

                Text("也可以点击上方按钮选择")
                    .font(.caption2)
                    .foregroundStyle(DogeTheme.muted.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .pixelPanel(
            border: (phase == .idle) ? DogeTheme.muted : DogeTheme.ink,
            dashed: phase == .idle
        )
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    // MARK: Phase helpers

    @ViewBuilder
    private var phaseIndicator: some View {
        switch phase {
        case .idle, .complete:
            Circle().fill(DogeTheme.green).frame(width: 8, height: 8)
        case .uploading, .reviewing:
            ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DogeTheme.red)
                .font(.caption)
        }
    }

    private var phaseTextColor: Color {
        switch phase {
        case .idle: return DogeTheme.muted
        case .complete: return DogeTheme.green
        case .uploading, .reviewing: return DogeTheme.blue
        case .failed: return DogeTheme.red
        }
    }

    // MARK: Review flow

    private func startReview(fileURL: URL) async {
        phase = .uploading

        // Step 1: OCR/ingest the file
        let ingestResponse: OcrIngestResponse
        do {
            ingestResponse = try await APIClient.shared.uploadFile("/ocr/ingest", fileURL: fileURL, fieldName: "files")
        } catch {
            phase = .failed("文件识别失败：\(error.localizedDescription)")
            return
        }

        let contractText = ingestResponse.mergedText
        guard !contractText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("未能从文件中提取文字，请尝试其他格式。")
            return
        }

        let filename = ingestResponse.displayName ?? fileURL.lastPathComponent
        let sessionId = "session-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        // Step 2: Start review SSE — process events for progress, always check server at the end
        phase = .reviewing(progress: "正在分析合同条款...")
        let token = authStore.token
        var collectedIssues: [[String: Any]] = []
        var hitBreakpoint = false

        do {
            for try await event in SSEClient.stream(
                path: "review",
                body: ["contract_text": contractText, "filename": filename, "session_id": sessionId],
                token: token
            ) {
                if Task.isCancelled { return }
                let dict = (try? JSONSerialization.jsonObject(with: event.data) as? [String: Any]) ?? [:]
                handleReviewEvent(event.event, dict: dict, sessionId: sessionId, collectedIssues: &collectedIssues)
                if event.event == "breakpoint" {
                    hitBreakpoint = true
                    if let issues = dict["issues"] as? [[String: Any]] { collectedIssues = issues }
                    break
                }
                if event.event == "review_complete" {
                    await checkServerAndFinish(sessionId: sessionId)
                    return
                }
                if event.event == "error" {
                    let msg = dict["message"] as? String ?? "审查失败"
                    phase = .failed(msg)
                    return
                }
            }
        } catch {
            // Stream error — server may have already saved the result
            await checkServerAndFinish(sessionId: sessionId)
            return
        }

        // Stream ended without breakpoint or review_complete
        if !hitBreakpoint {
            await checkServerAndFinish(sessionId: sessionId)
            return
        }

        // Step 3: Auto-confirm breakpoint → get final report via confirm SSE
        phase = .reviewing(progress: "正在生成最终报告...")

        do {
            for try await event in SSEClient.stream(
                path: "review/confirm/\(sessionId)",
                body: [
                    "confirmed": true,
                    "contract_text": contractText,
                    "issues": collectedIssues,
                    "filename": filename,
                ],
                token: token
            ) {
                if Task.isCancelled { return }
                let dict = (try? JSONSerialization.jsonObject(with: event.data) as? [String: Any]) ?? [:]
                if event.event == "final_report" {
                    phase = .reviewing(progress: "正在生成报告...")
                }
                if event.event == "review_complete" {
                    await checkServerAndFinish(sessionId: sessionId)
                    return
                }
                if event.event == "error" {
                    let msg = dict["message"] as? String ?? "报告生成失败"
                    phase = .failed(msg)
                    return
                }
            }
        } catch {}

        // Confirm SSE ended — check server
        await checkServerAndFinish(sessionId: sessionId)
    }

    /// Check server for session result. Mark complete if found, error only if server has nothing.
    private func checkServerAndFinish(sessionId: String) async {
        do {
            let response: ReviewSessionsResponse = try await APIClient.shared.get("/review-sessions")
            if let match = response.sessions.first(where: { $0.sessionId == sessionId }) {
                selectedSession = match
                phase = .complete(sessionId: sessionId)
                return
            }
        } catch {}
        phase = .failed("审查未返回结果，请重试")
    }

    private func handleReviewEvent(_ eventName: String, dict: [String: Any], sessionId: String, collectedIssues: inout [[String: Any]]) {
        switch eventName {
        case "review_started": phase = .reviewing(progress: "审查已开始...")
        case "entity_extraction": phase = .reviewing(progress: "正在提取合同要素...")
        case "routing": phase = .reviewing(progress: "正在检索法规依据...")
        case "logic_review": phase = .reviewing(progress: "正在逐条分析风险...")
        case "rag_retrieval": phase = .reviewing(progress: "正在查询法条数据库...")
        case "final_report": phase = .reviewing(progress: "正在生成报告...")
        case "initial_review_ready", "deep_review_update", "deep_review_complete":
            phase = .reviewing(progress: "深度分析中...")
            if let issues = dict["issues"] as? [[String: Any]] {
                collectedIssues = issues
            }
        default: break
        }
    }
}

// MARK: - Sub-views

private struct ReviewingProgress: View {
    let progress: String
    @State private var shimmer: CGFloat = -1

    private let steps = ["审查已开始...", "正在提取合同要素...", "正在检索法规依据...", "正在逐条分析风险...", "深度分析中...", "正在生成报告..."]

    private var stepIndex: Int {
        steps.firstIndex(where: { $0 == progress }) ?? 0
    }

    private var barFraction: CGFloat {
        CGFloat(stepIndex + 1) / CGFloat(steps.count)
    }

    var body: some View {
        VStack(spacing: 16) {
            DogeBadge(size: 56)

            Text("正在审查中...")
                .font(.title3.bold())

            Text(progress)
                .font(.footnote.bold())
                .foregroundStyle(DogeTheme.blue)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: progress)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DogeTheme.muted.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DogeTheme.blue)
                        .frame(width: geo.size.width * barFraction, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: barFraction)
                }
            }
            .frame(height: 8)

            Text("通常需要 30–120 秒，请保持网络连接")
                .font(.caption2)
                .foregroundStyle(DogeTheme.muted)
        }
        .padding(.vertical, 8)
    }
}

private struct UploadingIndicator: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.3)
            Text("正在识别文件内容...")
                .font(.title3.bold())
            Text("支持文字提取与 OCR 图像识别")
                .font(.caption)
                .foregroundStyle(DogeTheme.muted)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.headline)
            Text(message).foregroundStyle(DogeTheme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(DogeTheme.background)
    }
}
