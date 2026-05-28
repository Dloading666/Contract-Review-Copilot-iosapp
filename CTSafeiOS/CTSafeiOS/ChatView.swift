import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Binding var session: ReviewSessionSummary?
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var showSessionPicker = false
    @State private var allSessions: [ReviewSessionSummary] = []

    private var topIssues: [RiskFinding] {
        guard let session else { return [] }
        return Array(session.issues.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tappable header — tap to switch contract
            Button {
                Task { await fetchSessions() }
                showSessionPicker = true
            } label: {
                HStack(spacing: 12) {
                    if let session {
                        Image(systemName: fileIcon(session.filename))
                            .font(.title2)
                            .foregroundStyle(DogeTheme.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.filename)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DogeTheme.ink)
                                .lineLimit(1)
                            if let date = session.completedAt ?? session.updatedAt {
                                Text("分析完成 · \(formatDate(date))")
                                    .font(.caption)
                                    .foregroundStyle(DogeTheme.muted)
                            }
                        }
                        Spacer()
                        RiskPill(risk: session.overallRisk)
                    } else {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundStyle(DogeTheme.muted)
                        Text("点击选择合同")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DogeTheme.muted)
                        Spacer()
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(DogeTheme.muted)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(DogeTheme.panel)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(DogeTheme.muted.opacity(0.2)), alignment: .bottom)
            }
            .buttonStyle(.plain)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if isLoading {
                            HStack(alignment: .top, spacing: 10) {
                                DogeBadge(size: 32)
                                TypingIndicator()
                                Spacer(minLength: 60)
                            }
                            .id("loading")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.last?.id ?? "loading", anchor: .bottom) }
                }
                .onChange(of: isLoading) { _, loading in
                    if loading { withAnimation { proxy.scrollTo("loading", anchor: .bottom) } }
                }
            }

            // Key findings strip
            if !topIssues.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(DogeTheme.orange)
                                .font(.caption)
                            Text("建议关注点")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DogeTheme.orange)
                            ForEach(topIssues) { issue in
                                Button {
                                    draft = "请详细解释：\(issue.clause)"
                                } label: {
                                    HStack(spacing: 5) {
                                        RiskPill(risk: issue.level ?? .medium)
                                        Text(issue.clause)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(DogeTheme.ink)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.muted.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .background(DogeTheme.panel)
            }

            // Input bar
            HStack(spacing: 10) {
                Button {} label: {
                    Image(systemName: "plus")
                        .frame(width: 42, height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.muted, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                }
                .foregroundStyle(DogeTheme.muted)

                TextField("输入你的问题...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 42)
                        .background(DogeTheme.blue)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2))
                }
                .disabled(session == nil || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DogeTheme.background)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(DogeTheme.muted.opacity(0.2)), alignment: .top)
        }
        .background(DogeTheme.background)
        .navigationTitle("对话")
        .task(id: session?.sessionId) {
            await loadMessages()
        }
        .sheet(isPresented: $showSessionPicker) {
            SessionPickerSheet(sessions: allSessions, selectedId: session?.sessionId) { picked in
                session = picked
                showSessionPicker = false
            }
        }
    }

    // MARK: - Data

    private func fetchSessions() async {
        do {
            let response: ReviewSessionsResponse = try await APIClient.shared.get("/review-sessions")
            allSessions = response.sessions
        } catch {}
    }

    private func loadMessages() async {
        guard let session else {
            messages = [ChatMessage(id: "welcome", sessionId: nil, role: "assistant",
                                   content: "先完成一次合同审查，我就能围绕报告继续问答。",
                                   status: "complete", model: nil, createdAt: nil)]
            return
        }
        do {
            let response: ChatMessagesResponse = try await APIClient.shared.get("/review-sessions/\(session.sessionId)/chat")
            messages = response.messages.isEmpty ? [
                ChatMessage(id: "intro", sessionId: session.sessionId, role: "assistant",
                            content: "报告已就绪！可以问我任何关于这份合同的问题，例如条款风险、修改建议等。",
                            status: "complete", model: nil, createdAt: nil)
            ] : response.messages
        } catch {
            messages = []
        }
    }

    private func send() async {
        guard let session else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        messages.append(ChatMessage(id: UUID().uuidString, sessionId: session.sessionId,
                                    role: "user", content: text, status: "complete", model: nil, createdAt: nil))
        isLoading = true
        defer { isLoading = false }
        do {
            let response: ChatResponse = try await APIClient.shared.post(
                "/chat",
                body: ["message": text,
                       "review_session_id": session.sessionId,
                       "risk_summary": session.issues.map(\.issue).joined(separator: "\n")]
            )
            messages.append(ChatMessage(id: UUID().uuidString, sessionId: session.sessionId,
                                        role: "assistant", content: response.reply,
                                        status: "complete", model: response.model, createdAt: nil))
        } catch {
            messages.append(ChatMessage(id: UUID().uuidString, sessionId: session.sessionId,
                                        role: "assistant", content: error.localizedDescription,
                                        status: "error", model: nil, createdAt: nil))
        }
    }

    private func fileIcon(_ filename: String) -> String {
        let ext = filename.lowercased()
        if ext.contains(".pdf") { return "doc.richtext.fill" }
        if ext.contains(".docx") || ext.contains(".doc") { return "doc.fill" }
        if ext.contains(".png") || ext.contains(".jpg") || ext.contains(".jpeg") { return "photo.fill" }
        return "doc.text.fill"
    }

    private func formatDate(_ dateStr: String) -> String {
        let input = ISO8601DateFormatter()
        input.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = input.date(from: dateStr) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
        return String(dateStr.prefix(16))
    }
}

// MARK: - Session Picker Sheet

private struct SessionPickerSheet: View {
    let sessions: [ReviewSessionSummary]
    let selectedId: String?
    let onSelect: (ReviewSessionSummary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundStyle(DogeTheme.muted.opacity(0.35))
                        Text("暂无审查记录")
                            .foregroundStyle(DogeTheme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DogeTheme.background)
                } else {
                    List(sessions) { s in
                        Button { onSelect(s) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: sessionFileIcon(s.filename))
                                    .font(.system(size: 22))
                                    .foregroundStyle(s.sessionId == selectedId ? DogeTheme.blue : DogeTheme.muted)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.filename)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(DogeTheme.ink)
                                        .lineLimit(1)
                                    if let date = s.completedAt ?? s.updatedAt {
                                        Text(sessionFormatDate(date))
                                            .font(.caption)
                                            .foregroundStyle(DogeTheme.muted)
                                    }
                                }
                                Spacer()
                                RiskPill(risk: s.overallRisk)
                                if s.sessionId == selectedId {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(DogeTheme.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("选择合同")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(DogeTheme.blue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sessionFileIcon(_ filename: String) -> String {
        let ext = filename.lowercased()
        if ext.contains(".pdf") { return "doc.richtext.fill" }
        if ext.contains(".docx") || ext.contains(".doc") { return "doc.fill" }
        if ext.contains(".png") || ext.contains(".jpg") { return "photo.fill" }
        return "doc.text.fill"
    }

    private func sessionFormatDate(_ dateStr: String) -> String {
        let input = ISO8601DateFormatter()
        input.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = input.date(from: dateStr) {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return f.string(from: date)
        }
        return String(dateStr.prefix(16))
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(DogeTheme.muted)
                    .frame(width: 7, height: 7)
                    .opacity(phase == i ? 1.0 : 0.3)
                    .scaleEffect(phase == i ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: phase)
            }
        }
        .padding(12)
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DogeTheme.ink, lineWidth: 2))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(450))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == "user" {
            HStack(alignment: .bottom, spacing: 10) {
                Spacer(minLength: 60)
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DogeTheme.blue)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Circle()
                    .fill(DogeTheme.blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DogeTheme.blue)
                    )
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                DogeBadge(size: 32)
                VStack(alignment: .leading, spacing: 4) {
                    if let model = message.model {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(DogeTheme.muted.opacity(0.7))
                    }
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundStyle(DogeTheme.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DogeTheme.ink, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer(minLength: 60)
            }
        }
    }
}
