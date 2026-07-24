import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var appLock: AppLockController
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var pin = ""
    @State private var isAuthenticatingBiometrics = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            Image("AixcamIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

            Text("Aixcam")
                .font(.largeTitle.weight(.heavy))

            Text("Enter your PIN to continue")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            pinDots

            if let statusMessage = appLock.statusMessage {
                Text(statusMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            pinPad

            if appLock.canOfferBiometrics {
                Button {
                    Task {
                        isAuthenticatingBiometrics = true
                        await appLock.unlockWithBiometrics()
                        isAuthenticatingBiometrics = false
                    }
                } label: {
                    Label(
                        isAuthenticatingBiometrics ? "Waiting…" : "Unlock with \(appLock.biometryName)",
                        systemImage: "faceid"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(isAuthenticatingBiometrics)
                .padding(.horizontal, 28)
            }

            if appLock.failedPINAttempts >= 3 {
                Button("Sign out", role: .destructive) {
                    authViewModel.signOut()
                    appLock.clearStatus()
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 24)
        }
        .padding(20)
        .task {
            if appLock.canOfferBiometrics {
                await appLock.unlockWithBiometrics()
            }
        }
    }

    private var pinDots: some View {
        HStack(spacing: 14) {
            ForEach(0..<AppLockPolicy.pinLength, id: \.self) { index in
                Circle()
                    .strokeBorder(.secondary.opacity(0.45), lineWidth: 1.5)
                    .background {
                        Circle()
                            .fill(index < pin.count ? Color.teal : Color.clear)
                    }
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityLabel("PIN entry")
        .accessibilityValue("\(pin.count) of \(AppLockPolicy.pinLength) digits entered")
    }

    private var pinPad: some View {
        let keys = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]

        return VStack(spacing: 12) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 72, height: 72)
                        } else {
                            Button {
                                handleKey(key)
                            } label: {
                                Text(key)
                                    .font(.title2.weight(.semibold))
                                    .frame(width: 72, height: 72)
                                    .background(.thinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(key == "⌫" ? "Delete" : key)
                        }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        appLock.clearStatus()
        if key == "⌫" {
            if pin.isEmpty == false {
                pin.removeLast()
            }
            return
        }
        guard pin.count < AppLockPolicy.pinLength else { return }
        pin.append(key)
        if pin.count == AppLockPolicy.pinLength {
            let submitted = pin
            pin = ""
            _ = appLock.unlockWithPIN(submitted)
        }
    }
}

struct AppLockSettingsView: View {
    @EnvironmentObject private var appLock: AppLockController
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var biometricEnabled = true
    @State private var timeout: AppLockBackgroundTimeout = .oneMinute
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if appLock.isAppLockActive {
                        LabeledContent("Status", value: "On")
                        Toggle("Use \(appLock.biometryName)", isOn: $biometricEnabled)
                        Picker("Lock after background", selection: $timeout) {
                            ForEach(AppLockBackgroundTimeout.allCases, id: \.self) { value in
                                Text(value.title).tag(value)
                            }
                        }
                        Button("Save settings") {
                            saveExistingSettings()
                        }
                        Button("Disable App Lock", role: .destructive) {
                            disableLock()
                        }
                    } else {
                        Text("Protect Aixcam with a 4-digit PIN and optional \(appLock.biometryName) after you sign in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        SecureField("New PIN", text: $pin)
                            .keyboardType(.numberPad)
                        SecureField("Confirm PIN", text: $confirmPIN)
                            .keyboardType(.numberPad)
                        Toggle("Enable \(appLock.biometryName)", isOn: $biometricEnabled)
                        Picker("Lock after background", selection: $timeout) {
                            ForEach(AppLockBackgroundTimeout.allCases, id: \.self) { value in
                                Text(value.title).tag(value)
                            }
                        }
                        Button("Enable App Lock") {
                            enableLock()
                        }
                        .disabled(pin.count != AppLockPolicy.pinLength)
                    }
                } header: {
                    Text("App Lock")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if let status = appLock.statusMessage {
                        Text(status)
                    }
                }
            }
            .navigationTitle("App Lock")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                biometricEnabled = appLock.policy.biometricEnabled
                timeout = appLock.policy.backgroundTimeout
            }
        }
    }

    private func enableLock() {
        errorMessage = nil
        guard pin == confirmPIN else {
            errorMessage = "PINs do not match."
            return
        }
        do {
            try appLock.enableLock(withPIN: pin, biometricEnabled: biometricEnabled, timeout: timeout)
            pin = ""
            confirmPIN = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveExistingSettings() {
        errorMessage = nil
        do {
            try appLock.updateSettings(biometricEnabled: biometricEnabled, timeout: timeout)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func disableLock() {
        errorMessage = nil
        do {
            try appLock.disableLock()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
