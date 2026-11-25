import SwiftUI

/// Squall Uno's settings, which live on the PC: the API key, how many steps a task may take,
/// Docker, and how many tokens were used today.
struct UnoSettingsView: View {
    @EnvironmentObject private var uno: UnoModel
    @State private var key = ""
    @State private var steps = 80
    @State private var stepsTask: Task<Void, Never>?
    @State private var confirmRemove = false

    private static let watcher = "settings"

    var body: some View {
        ZStack {
            UnoColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let settings = uno.settings {
                        if let problem = uno.problem {
                            UnoNoticeText(text: problem)
                        }
                        keySection(settings)
                        stepsSection(settings)
                        computerSection(settings)
                        todaySection(settings)
                    } else if let problem = uno.problem {
                        UnoMessageCard(icon: "desktopcomputer", text: problem)
                    } else {
                        ProgressView("Asking your PC…")
                            .tint(UnoColors.purple)
                            .foregroundStyle(UnoColors.muted)
                            .frame(maxWidth: .infinity)
                            .padding(30)
                    }
                    if let notice = uno.notice {
                        UnoNoticeText(text: notice)
                    }
                }
                .padding(16)
                .readableColumn(700)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            uno.show(Self.watcher)
            if let settings = uno.settings { steps = settings.maxSteps }
        }
        .onDisappear {
            uno.hide(Self.watcher)
        }
        .onChange(of: uno.settings?.maxSteps) {
            if let value = uno.settings?.maxSteps, stepsTask == nil { steps = value }
        }
        .onChange(of: steps) {
            saveStepsSoon()
        }
        .confirmationDialog("Remove the saved key from your PC?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                Task { @MainActor in
                    await uno.removeKey()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Squall Uno can't work until you add a key again.")
        }
    }

    // MARK: Sections

    private func keySection(_ settings: UnoSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "API key")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: settings.hasKey ? "checkmark.seal.fill" : "key.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(settings.hasKey ? Theme.green : Theme.goldBright)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(keyStatus(settings))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(UnoColors.text)
                        if settings.hasKey, !settings.keyHint.isEmpty {
                            Text(settings.keyHint)
                                .font(Theme.mono(12))
                                .foregroundStyle(UnoColors.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                SecureField("", text: $key, prompt: Text("Paste your Anthropic API key").foregroundStyle(Theme.muted))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                Button(uno.isBusy("key") ? "Saving…" : "Save key to my PC") {
                    saveKey()
                }
                .buttonStyle(FilledButtonStyle(fill: UnoColors.purple))
                .disabled(uno.isBusy("key") || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Your key is stored on your PC, encrypted. This phone never keeps it. You can also set the SQUALL_UNO_KEY variable on your PC instead.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(UnoColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(uno.isBusy("check") ? "Checking…" : "Check it works") {
                        Task { @MainActor in
                            await uno.check()
                        }
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                    .disabled(uno.isBusy("check"))
                    if settings.keySource == "saved" {
                        Button("Remove key") {
                            confirmRemove = true
                        }
                        .buttonStyle(GhostButtonStyle(height: 40, foreground: Theme.redText, border: Theme.red.opacity(0.5), fontSize: 14))
                        .disabled(uno.isBusy("key"))
                    }
                }
                if let checkText = uno.checkText {
                    Text(checkText)
                        .font(.system(size: 13))
                        .foregroundStyle(UnoColors.text)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.3)))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if settings.keySource == "env" {
                    Text("This key comes from the SQUALL_UNO_KEY variable on your PC, so it can only be changed there.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(UnoColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .glassCard(radius: 16)
        }
    }

    private func stepsSection(_ settings: UnoSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Steps")
            VStack(alignment: .leading, spacing: 6) {
                Stepper(value: $steps, in: 10...300, step: 10) {
                    Text("At most \(steps) steps per task")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(UnoColors.text)
                }
                .tint(UnoColors.purple)
                Text("Squall Uno stops by itself after this many clicks, keys and looks.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(UnoColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .glassCard(radius: 16)
        }
    }

    private func computerSection(_ settings: UnoSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Computers")
            VStack(alignment: .leading, spacing: 10) {
                statusLine(
                    ok: settings.dockerReady,
                    text: settings.dockerText.isEmpty
                        ? (settings.dockerReady ? "Docker is running." : "Docker Desktop needs to be running on your PC.")
                        : settings.dockerText
                )
                statusLine(
                    ok: settings.imageReady,
                    text: settings.imageReady
                        ? "The computers' desktop is built."
                        : "The desktop gets built the first time a computer turns on. That takes a few minutes, once."
                )
                if !settings.model.isEmpty {
                    HStack {
                        Text("Model")
                            .foregroundStyle(UnoColors.muted)
                        Spacer()
                        Text(settings.model)
                            .font(Theme.mono(12.5))
                            .foregroundStyle(UnoColors.text)
                    }
                    .font(.system(size: 13.5))
                }
            }
            .padding(14)
            .glassCard(radius: 16)
        }
    }

    private func todaySection(_ settings: UnoSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Today")
            HStack(spacing: 10) {
                tokenBox(title: "Tokens in", value: settings.tokensToday.input)
                tokenBox(title: "Tokens out", value: settings.tokensToday.output)
            }
        }
    }

    // MARK: Pieces

    private func statusLine(ok: Bool, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ok ? Theme.green : Theme.goldBright)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(UnoColors.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func tokenBox(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.formatted())
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(UnoColors.text)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(UnoColors.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 16)
    }

    private func keyStatus(_ settings: UnoSettings) -> String {
        guard settings.hasKey else { return "No key yet" }
        switch settings.keySource {
        case "env": return "Key set on your PC (SQUALL_UNO_KEY)"
        case "saved": return "Key saved on your PC"
        default: return "Key is set"
        }
    }

    // MARK: Actions

    private func saveKey() {
        let typed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        // The phone doesn't keep the key: the field is cleared as soon as it's sent.
        key = ""
        Task { @MainActor in
            await uno.saveKey(typed)
        }
    }

    /// Waits a moment after the last tap on the stepper, then saves once.
    private func saveStepsSoon() {
        stepsTask?.cancel()
        guard let current = uno.settings?.maxSteps, current != steps else {
            stepsTask = nil
            return
        }
        let value = steps
        stepsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await uno.setMaxSteps(value)
            stepsTask = nil
        }
    }
}
