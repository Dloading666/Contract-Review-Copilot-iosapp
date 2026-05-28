import SwiftUI

struct HistoryView: View {
    @Binding var selectedSession: ReviewSessionSummary?
    @Binding var selectedTab: Int
    @State private var sessions: [ReviewSessionSummary] = []
    @State private var query = ""
    @State private var riskFilter: RiskLevel? = nil

    private var riskCounts: [RiskLevel: Int] {
        var counts: [RiskLevel: Int] = [:]
        for session in sessions {
            counts[session.overallRisk, default: 0] += 1
        }
        return counts
    }

    private var filtered: [ReviewSessionSummary] {
        sessions.filter { session in
            let matchesQuery = query.isEmpty ||
                session.filename.localizedCaseInsensitiveContains(query) ||
                session.issues.contains { $0.issue.localizedCaseInsensitiveContains(query) }
            let matchesRisk = riskFilter == nil || session.overallRisk == riskFilter
            return matchesQuery && matchesRisk
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                HStack(spacing: 16) {
                    DogeBadge()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("审查历史")
                            .font(.system(size: 26, weight: .black))
                        Text("查看你的合同审查记录")
                            .font(.subheadline)
                            .foregroundStyle(DogeTheme.muted)
                    }
                    Spacer()
                }
                .pixelPanel()

                // Stats bar
                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        Text("累计审查")
                            .font(.caption)
                            .foregroundStyle(DogeTheme.muted)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(sessions.count)")
                                .font(.system(size: 32, weight: .black))
                                .foregroundStyle(DogeTheme.blue)
                            Text("份合同")
                                .font(.caption)
                                .foregroundStyle(DogeTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 44)

                    HStack(spacing: 14) {
                        RiskCountItem(risk: .low, count: riskCounts[.low] ?? 0)
                        Divider().frame(height: 32)
                        RiskCountItem(risk: .medium, count: riskCounts[.medium] ?? 0)
                        Divider().frame(height: 32)
                        RiskCountItem(risk: .high, count: (riskCounts[.high] ?? 0) + (riskCounts[.critical] ?? 0))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 72)
                .pixelPanel(border: DogeTheme.muted, dashed: true)

                // Search + filter
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DogeTheme.muted)
                        TextField("搜索合同名称或关键词", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.muted.opacity(0.5), lineWidth: 1.5))

                    Menu {
                        Button("全部") { riskFilter = nil }
                        Divider()
                        ForEach(RiskLevel.allCases, id: \.rawValue) { risk in
                            Button(risk.title) { riskFilter = risk }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(riskFilter?.title ?? "全部")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(riskFilter == nil ? DogeTheme.ink : riskFilter!.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                            riskFilter == nil ? DogeTheme.muted.opacity(0.5) : riskFilter!.color.opacity(0.5),
                            lineWidth: 1.5
                        ))
                    }
                }

                // Session list
                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(DogeTheme.muted.opacity(0.4))
                        Text(sessions.isEmpty ? "还没有审查记录" : "没有匹配的记录")
                            .foregroundStyle(DogeTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(filtered) { session in
                        HistoryRow(session: session, isSelected: selectedSession?.sessionId == session.sessionId)
                            .onTapGesture { selectedSession = session }
                    }
                }

                if !sessions.isEmpty {
                    Text("已加载到底部")
                        .font(.caption)
                        .foregroundStyle(DogeTheme.muted.opacity(0.5))
                        .padding(.vertical, 8)
                }
            }
            .padding(18)
        }
        .background(DogeTheme.background)
        .navigationTitle("历史")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            let response: ReviewSessionsResponse = try await APIClient.shared.get("/review-sessions")
            sessions = response.sessions
            if selectedSession == nil {
                selectedSession = sessions.first
            }
        } catch {
            sessions = []
        }
    }
}

private struct RiskCountItem: View {
    let risk: RiskLevel
    let count: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(risk.color)
            Text(risk.title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(risk.color.opacity(0.8))
        }
        .frame(minWidth: 40)
    }
}

private struct HistoryRow: View {
    let session: ReviewSessionSummary
    let isSelected: Bool

    private var fileIcon: String {
        let fn = session.filename.lowercased()
        if fn.contains(".pdf") { return "doc.richtext.fill" }
        if fn.contains(".docx") || fn.contains(".doc") { return "doc.fill" }
        if fn.contains(".png") || fn.contains(".jpg") { return "photo.fill" }
        return "doc.text.fill"
    }

    private var iconColor: Color {
        let fn = session.filename.lowercased()
        if fn.contains(".pdf") { return .red }
        if fn.contains(".docx") { return Color(red: 0.1, green: 0.35, blue: 0.8) }
        return DogeTheme.blue
    }

    var body: some View {
        NavigationLink {
            ReportView(sessionId: session.sessionId)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: fileIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(iconColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(session.filename)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DogeTheme.ink)
                        .lineLimit(1)
                    if let date = session.completedAt ?? session.updatedAt {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundStyle(DogeTheme.muted)
                    }
                    RiskPill(risk: session.overallRisk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("查看报告")
                        .font(.caption.bold())
                        .foregroundStyle(DogeTheme.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DogeTheme.muted)
                }
            }
            .padding(14)
            .background(isSelected ? DogeTheme.blue.opacity(0.04) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DogeTheme.blue.opacity(0.3) : DogeTheme.muted.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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
