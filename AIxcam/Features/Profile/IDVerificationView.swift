import FirebaseAuth
import SwiftUI

struct IDVerificationView: View {
    @Environment(\.dismiss) private var dismiss

    // SECURITY: Government-issued identity data (legal name, ID number, DOB) is
    // sensitive PII and is NEVER persisted on-device. These fields live only in
    // memory for the lifetime of the screen and are transmitted over TLS to the
    // verification backend on submit. Only the non-sensitive submission status is
    // persisted locally so the UI can reflect an "under review" state on return.
    @State private var legalName       = ""
    @State private var idNumber        = ""
    @State private var countryOfIssue  = ""
    @State private var idTypeRaw       = IDType.passport.rawValue
    @State private var ageConfirmed    = false
    @State private var consentGiven    = false

    @AppStorage("idv_submittedDate")   private var submittedDate   = ""

    @State private var dateOfBirth: Date = Calendar.current.date(
        byAdding: .year, value: -18, to: Date()
    ) ?? Date()
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var submitError: String?

    private var idType: IDType {
        IDType(rawValue: idTypeRaw) ?? .passport
    }

    private var isFormValid: Bool {
        !legalName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !idNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !countryOfIssue.trimmingCharacters(in: .whitespaces).isEmpty &&
        ageConfirmed && consentGiven
    }

    private var isSubmitted: Bool { !submittedDate.isEmpty }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerBanner

                    if isSubmitted {
                        submittedBanner
                    }

                    Group {
                        sectionLabel("Legal Information")
                        verificationField(label: "Full Legal Name",
                                          placeholder: "As it appears on your ID",
                                          text: $legalName)

                        dateOfBirthRow

                        sectionLabel("Government-Issued ID")
                        idTypePicker
                        verificationField(label: "ID Number",
                                          placeholder: "e.g. A12345678",
                                          text: $idNumber)
                        verificationField(label: "Country of Issuance",
                                          placeholder: "e.g. United States",
                                          text: $countryOfIssue)

                        sectionLabel("Consent & Acknowledgment")
                        consentRow(
                            text: "I confirm I am 18 years of age or older.",
                            isOn: $ageConfirmed
                        )
                        consentRow(
                            text: "I certify that the information provided is accurate and that I consent to this information being used for identity verification and legal compliance purposes.",
                            isOn: $consentGiven
                        )
                    }
                    .disabled(isSubmitted)

                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("ID Verification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .overlay(successOverlay)
        .alert("Verification Error", isPresented: Binding(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Button("OK", role: .cancel) { submitError = nil }
        } message: {
            Text(submitError ?? "")
        }
    }

    // MARK: - Subviews

    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue],
                                   startPoint: .top, endPoint: .bottom)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Creator Verification")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Required for live broadcasting and legal compliance.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
        .padding(.top, 8)
    }

    private var submittedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("Verification Submitted")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Submitted on \(submittedDate) · Under review")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private var dateOfBirthRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Date of Birth")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            DatePicker("", selection: $dateOfBirth,
                       in: ...Calendar.current.date(byAdding: .year, value: -18, to: Date())!,
                       displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(.cyan)
                .colorScheme(.dark)
                .labelsHidden()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var idTypePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ID Type")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            Picker("ID Type", selection: Binding(
                get: { idType },
                set: { idTypeRaw = $0.rawValue }
            )) {
                ForEach(IDType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .colorScheme(.dark)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submitVerification() }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else if isSubmitted {
                    Label("Submitted", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Submit Verification")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                isSubmitted
                    ? Color.green.opacity(0.4)
                    : (isFormValid ? Color.cyan.opacity(0.8) : Color.white.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .disabled(!isFormValid || isSubmitted || isSaving)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var successOverlay: some View {
        if showSuccess {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("Verification Submitted")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Your information is under review.\nWe'll notify you once verified.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.45))
            .textCase(.uppercase)
            .padding(.top, 4)
    }

    private func verificationField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(.white)
                .tint(.cyan)
                .padding(12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private func consentRow(text: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.cyan)
                .scaleEffect(0.9)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private func submitVerification() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await postVerification()
        } catch {
            submitError = error.localizedDescription
            return
        }

        // Wipe the in-memory PII the moment it has been handed to the backend —
        // it must not linger in the view's state any longer than necessary.
        legalName = ""
        idNumber = ""
        countryOfIssue = ""

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        submittedDate = formatter.string(from: Date())

        withAnimation(.spring(response: 0.4)) { showSuccess = true }
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation { showSuccess = false }
    }

    /// Transmits identity data to the authenticated verification backend over TLS.
    ///
    /// The backend forwards this to a KYC provider (e.g. Stripe Identity / Persona)
    /// and must NOT store raw ID numbers at rest. Nothing sensitive is written to
    /// disk on the device.
    private func postVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw IDVerificationError.notSignedIn
        }
        let idToken = try await user.getIDToken()

        let url = URL(string: "https://us-central1-aixcam.cloudfunctions.net/submitIdentityVerification")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let payload: [String: Any] = [
            "data": [
                "legalName": legalName.trimmingCharacters(in: .whitespaces),
                "idNumber": idNumber.trimmingCharacters(in: .whitespaces),
                "idType": idTypeRaw,
                "countryOfIssue": countryOfIssue.trimmingCharacters(in: .whitespaces),
                "dateOfBirth": ISO8601DateFormatter().string(from: dateOfBirth)
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw IDVerificationError.submissionFailed
        }
    }
}

enum IDVerificationError: LocalizedError {
    case notSignedIn
    case submissionFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return String(localized: "You must be signed in to submit verification.")
        case .submissionFailed:
            return String(localized: "We couldn’t submit your verification. Please try again.")
        }
    }
}

// MARK: - Supporting Types

enum IDType: String, CaseIterable, Identifiable {
    case passport       = "passport"
    case driversLicense = "drivers_license"
    case nationalID     = "national_id"
    case stateID        = "state_id"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .passport:       return "Passport"
        case .driversLicense: return "Driver's License"
        case .nationalID:     return "National ID"
        case .stateID:        return "State ID"
        }
    }
}

#Preview {
    NavigationStack {
        IDVerificationView()
    }
}
