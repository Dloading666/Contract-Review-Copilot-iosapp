import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    DogeBadge()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("设置")
                            .font(.system(size: 28, weight: .black))
                        Text(authStore.user?.email ?? "已登录")
                            .foregroundStyle(DogeTheme.muted)
                    }
                    Spacer()
                }
                .pixelPanel()

                VStack(spacing: 0) {
                    SettingsRow(title: "账号状态", value: authStore.user?.accountStatus ?? "-")
                    SettingsRow(title: "邮箱验证", value: authStore.user?.emailVerified == true ? "已验证" : "未验证")
                    SettingsRow(title: "服务器", value: APIClient.shared.baseURL.absoluteString)
                }
                .pixelPanel(border: DogeTheme.muted)

                Text("内容由 AI 生成，仅供参考，不构成法律意见。")
                    .font(.footnote)
                    .foregroundStyle(DogeTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pixelPanel(border: DogeTheme.orange)

                Button(role: .destructive) {
                    authStore.logout()
                } label: {
                    Text("退出登录")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.red, lineWidth: 2))
                }
            }
            .padding(18)
        }
        .background(DogeTheme.background)
        .navigationTitle("设置")
    }
}

struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(DogeTheme.muted)
        }
        .padding(.vertical, 12)
    }
}
