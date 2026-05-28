import SwiftUI

private enum AuthMode {
    case login
    case register
}

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.openURL) private var openURL

    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var code = ""
    @State private var devCode = ""
    @State private var successMessage = ""
    @State private var appearedAt = Date()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DogeTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        AuthHero(mode: mode)
                        modePicker

                        VStack(spacing: 14) {
                            PixelTextField(title: "邮箱地址", placeholder: "输入邮箱", text: $email, keyboardType: .emailAddress)

                            if mode == .register {
                                HStack(spacing: 10) {
                                    PixelTextField(title: "验证码", placeholder: "邮箱验证码", text: $code, keyboardType: .numberPad)
                                    Button {
                                        Task { await sendCode() }
                                    } label: {
                                        Text(authStore.isLoading ? "发送中" : "获取验证码")
                                            .font(.system(size: 14, weight: .bold))
                                            .frame(width: 96, height: 52)
                                            .background(DogeTheme.panel)
                                            .foregroundStyle(DogeTheme.ink)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2.5))
                                    }
                                    .padding(.top, 24)
                                    .disabled(authStore.isLoading)
                                }
                            }

                            PixelSecureField(title: "密码", placeholder: "输入密码", text: $password)

                            if mode == .register {
                                PixelSecureField(title: "确认密码", placeholder: "再次输入密码", text: $confirmPassword)
                                Text("密码必须至少 8 位，并包含大写字母、小写字母和数字")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DogeTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !devCode.isEmpty {
                            Text("开发模式验证码：\(devCode)")
                                .font(.footnote)
                                .foregroundStyle(DogeTheme.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !successMessage.isEmpty {
                            Text(successMessage)
                                .font(.footnote.bold())
                                .foregroundStyle(DogeTheme.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let error = authStore.errorMessage {
                            Text(error)
                                .font(.footnote.bold())
                                .foregroundStyle(DogeTheme.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            Text(primaryButtonTitle)
                                .font(.system(size: 20, weight: .black))
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(DogeTheme.blue)
                                .foregroundStyle(.white)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 3))
                        }
                        .disabled(authStore.isLoading)
                        .padding(.top, 2)

                        if mode == .login {
                            HStack {
                                Button("Google 登录") {
                                    openURL(URL(string: "https://ctsafe.top/api/auth/google?client=ios")!)
                                }
                                Spacer()
                                Button("GitHub 登录") {
                                    openURL(URL(string: "https://ctsafe.top/api/auth/github?client=ios")!)
                                }
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DogeTheme.blue)
                            .padding(.top, 4)
                        }
                    }
                    .padding(22)
                    .pixelPanel()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 42)
                    .frame(maxWidth: 520)
                    .frame(minHeight: proxy.size.height)
                    .frame(width: proxy.size.width)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appearedAt = Date() }
        .onChange(of: mode) {
            authStore.errorMessage = nil
            successMessage = ""
            devCode = ""
            appearedAt = Date()
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            AuthModeButton(title: "登录账号", isSelected: mode == .login) {
                mode = .login
            }
            AuthModeButton(title: "注册账号", isSelected: mode == .register) {
                mode = .register
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.7))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2))
    }

    private var primaryButtonTitle: String {
        if authStore.isLoading {
            return mode == .login ? "登录中..." : "提交中..."
        }
        return mode == .login ? "登录" : "注册账号"
    }

    private func elapsedMs() -> Int {
        max(0, Int(Date().timeIntervalSince(appearedAt) * 1000))
    }

    private func sendCode() async {
        authStore.errorMessage = nil
        successMessage = ""
        devCode = ""

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            authStore.errorMessage = "请输入邮箱地址"
            return
        }

        let code = await authStore.sendRegisterCode(email: normalizedEmail, clientElapsedMs: elapsedMs())
        devCode = code ?? ""
        if authStore.errorMessage == nil {
            successMessage = "验证码已发送，请查收邮箱"
        }
    }

    private func submit() async {
        authStore.errorMessage = nil
        successMessage = ""

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            authStore.errorMessage = "请输入邮箱和密码"
            return
        }

        if mode == .login {
            await authStore.login(email: normalizedEmail, password: normalizedPassword)
            return
        }

        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            authStore.errorMessage = "请输入邮箱验证码"
            return
        }
        guard passwordPolicyError(normalizedPassword) == nil else {
            authStore.errorMessage = passwordPolicyError(normalizedPassword)
            return
        }
        guard normalizedPassword == confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines) else {
            authStore.errorMessage = "两次输入的密码不一致"
            return
        }

        let registered = await authStore.register(
            email: normalizedEmail,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            password: normalizedPassword,
            clientElapsedMs: elapsedMs()
        )
        if registered {
            successMessage = "注册成功，请使用刚才的邮箱密码登录"
            mode = .login
            password = ""
            confirmPassword = ""
            code = ""
        }
    }

    private func passwordPolicyError(_ value: String) -> String? {
        let hasLowercase = value.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = value.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = value.range(of: "\\d", options: .regularExpression) != nil
        return value.count >= 8 && hasLowercase && hasUppercase && hasDigit ? nil : "密码必须至少 8 位，并包含大写字母、小写字母和数字"
    }
}

private struct AuthHero: View {
    let mode: AuthMode

    var body: some View {
        VStack(spacing: 14) {
            DogeBadge(size: 112)

            VStack(spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text("Doge")
                        .font(.system(size: 30, weight: .black))
                    Text("合同审查助手")
                        .font(.system(size: 27, weight: .black))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Text(mode == .login ? "登录后同步网页端和 iOS 端审查记录" : "邮箱注册后即可同步合同审查数据")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DogeTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AuthModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : DogeTheme.ink)
                .background(isSelected ? DogeTheme.blue : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private struct PixelTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DogeTheme.muted)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2.5))
        }
    }
}

private struct PixelSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DogeTheme.muted)
            SecureField(placeholder, text: $text)
                .font(.system(size: 17, weight: .medium))
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DogeTheme.ink, lineWidth: 2.5))
        }
    }
}
