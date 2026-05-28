import SwiftUI

struct ReportView: View {
    let sessionId: String
    @State private var session: ReviewSessionDetail?
    @State private var isLoading = true
    @State private var navigateToChat = false

    var body: some View {
        ScrollView {
            if let session {
                VStack(spacing: 18) {
                    // Document header
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            Image(systemName: fileIcon(session.filename))
                                .font(.system(size: 40))
                                .foregroundStyle(DogeTheme.blue)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.filename)
                                    .font(.system(size: 15, weight: .bold))
                                    .lineLimit(2)
                                if let date = session.completedAt ?? session.updatedAt {
                                    Text("上传时间：\(formatDate(date))")
                                        .font(.caption)
                                        .foregroundStyle(DogeTheme.muted)
                                }
                                Text("合同类型：\(contractType(session.filename))")
                                    .font(.caption)
                                    .foregroundStyle(DogeTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 12)

                        Divider().opacity(0.4)

                        HStack {
                            StatusBadge(status: session.status)
                            Spacer()
                            Button {
                                // TODO: show original contract text
                            } label: {
                                HStack(spacing: 4) {
                                    Text("查看原文")
                                        .font(.caption.bold())
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundStyle(DogeTheme.blue)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .pixelPanel()

                    // Risk overview
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("风险概览", systemImage: "shield.lefthalf.filled")
                                .font(.headline)
                            Spacer()
                            Button {} label: {
                                Text("如何解读风险?")
                                    .font(.caption)
                                    .foregroundStyle(DogeTheme.blue)
                            }
                        }
                        HStack(spacing: 4) {
                            Text("综合风险：")
                                .font(.subheadline)
                            Text(session.overallRisk.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(session.overallRisk.color)
                        }
                        HStack(spacing: 10) {
                            CounterCard(
                                title: "高风险",
                                count: (session.riskCounts["high"] ?? 0) + (session.riskCounts["critical"] ?? 0),
                                color: DogeTheme.red
                            )
                            CounterCard(title: "中风险", count: session.riskCounts["medium"] ?? 0, color: DogeTheme.orange)
                            CounterCard(title: "低风险", count: session.riskCounts["low"] ?? 0, color: DogeTheme.green)
                        }
                    }
                    .pixelPanel()

                    // Key issues
                    if !session.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("关键问题", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                Text("（\(session.issues.count)项）")
                                    .font(.subheadline)
                                    .foregroundStyle(DogeTheme.muted)
                                Spacer()
                            }
                            ForEach(session.issues) { issue in
                                IssueRow(issue: issue)
                            }
                        }
                        .pixelPanel()
                    }

                    // Suggestions
                    if !session.reportParagraphs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("修改建议", systemImage: "lightbulb.fill")
                                .font(.headline)
                            ForEach(Array(session.reportParagraphs.enumerated()), id: \.offset) { _, paragraph in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DogeTheme.green)
                                        .font(.caption)
                                        .padding(.top, 3)
                                    Text(paragraph)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .pixelPanel()
                    }

                    // Enter Q&A CTA
                    NavigationLink(destination: ChatViewFromSession(sessionId: sessionId)) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("进入问答")
                                .font(.system(size: 18, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DogeTheme.blue)
                        .foregroundStyle(.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2.5))
                    }
                }
                .padding(18)
            } else if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载报告中...")
                        .foregroundStyle(DogeTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(60)
            } else {
                EmptyStateView(title: "报告不存在", message: "这条审查记录可能已被删除或当前账号无权访问。")
            }
        }
        .background(DogeTheme.background)
        .navigationTitle("审查报告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DogeBadge(size: 36)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: ReviewSessionResponse = try await APIClient.shared.get("/review-sessions/\(sessionId)")
            session = response.session
        } catch {
            session = nil
        }
    }

    private func fileIcon(_ filename: String) -> String {
        let ext = filename.lowercased()
        if ext.contains(".pdf") { return "doc.richtext.fill" }
        if ext.contains(".docx") || ext.contains(".doc") { return "doc.fill" }
        if ext.contains(".png") || ext.contains(".jpg") || ext.contains(".jpeg") { return "photo.fill" }
        return "doc.text.fill"
    }

    private func contractType(_ filename: String) -> String {
        let lower = filename.lowercased()
        if lower.contains("劳动") { return "劳动合同" }
        if lower.contains("租赁") || lower.contains("房屋") { return "租赁合同" }
        if lower.contains("采购") || lower.contains("购买") { return "采购合同" }
        if lower.contains("保密") || lower.contains("nda") { return "保密协议" }
        if lower.contains("服务") { return "服务合同" }
        return "通用合同"
    }

    private func formatDate(_ dateStr: String) -> String {
        let input = ISO8601DateFormatter()
        input.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = input.date(from: dateStr) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
        return String(dateStr.prefix(16))
    }
}

// Thin wrapper to show chat from a report without needing a full ReviewSessionSummary binding
private struct ChatViewFromSession: View {
    let sessionId: String
    @State private var session: ReviewSessionSummary?
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded {
                ChatView(session: $session)
            } else {
                ProgressView()
                    .task {
                        do {
                            let r: ReviewSessionsResponse = try await APIClient.shared.get("/review-sessions")
                            session = r.sessions.first { $0.sessionId == sessionId }
                        } catch {}
                        loaded = true
                    }
            }
        }
    }
}

struct CounterCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.3), lineWidth: 1.5))
    }
}

private struct IssueRow: View {
    let issue: RiskFinding
    @State private var expanded = false

    var riskIcon: String {
        switch issue.level ?? .medium {
        case .low: return "checkmark.shield"
        case .medium: return "exclamationmark.triangle"
        case .high, .critical: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: riskIcon)
                        .font(.title3)
                        .foregroundStyle((issue.level ?? .medium).color)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(issue.clause)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DogeTheme.ink)
                        Text(issue.issue)
                            .font(.caption)
                            .foregroundStyle(DogeTheme.muted)
                            .lineLimit(expanded ? nil : 1)
                    }
                    Spacer()
                    RiskPill(risk: issue.level ?? .medium)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(DogeTheme.muted)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            if expanded, let suggestion = issue.suggestion {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("建议修改")
                        .font(.caption.bold())
                        .foregroundStyle(DogeTheme.blue)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(DogeTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DogeTheme.blue.opacity(0.05))
            }
        }
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.muted.opacity(0.3), lineWidth: 1))
    }
}

private struct StatusBadge: View {
    let status: String

    private var label: String {
        switch status {
        case "complete": return "已完成"
        case "reviewing": return "审查中"
        case "breakpoint": return "待确认"
        case "error": return "出错"
        default: return status
        }
    }

    private var color: Color {
        switch status {
        case "complete": return DogeTheme.green
        case "reviewing": return DogeTheme.blue
        case "error": return DogeTheme.red
        default: return DogeTheme.orange
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.3), lineWidth: 1.5))
    }
}
