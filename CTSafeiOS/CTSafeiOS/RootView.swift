import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var selectedSession: ReviewSessionSummary?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if authStore.token == nil {
                LoginView()
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeView(selectedSession: $selectedSession, selectedTab: $selectedTab)
                    }
                    .tabItem { Label("首页", systemImage: "house") }
                    .tag(0)

                    NavigationStack {
                        ChatView(session: $selectedSession)
                    }
                    .tabItem { Label("对话", systemImage: "message") }
                    .tag(1)

                    NavigationStack {
                        HistoryView(selectedSession: $selectedSession, selectedTab: $selectedTab)
                    }
                    .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
                    .tag(2)

                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem { Label("设置", systemImage: "gearshape") }
                    .tag(3)
                }
                .tint(DogeTheme.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DogeTheme.background.ignoresSafeArea())
        .onOpenURL { url in
            guard url.scheme == "ctsafe",
                  url.host == "auth",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                return
            }
            Task {
                await authStore.acceptOAuthToken(token)
            }
        }
    }
}
