import SwiftUI

/// Create-or-edit form for the viewer profile.
///
/// One view serves both first-run setup and later editing; only the chrome and
/// copy differ, so `Mode` keeps them from drifting apart.
struct ViewerProfileEditView: View {

    enum Mode {
        /// First run after sign-up. No dismiss affordance — the profile gate in
        /// ContentView is what this screen exists to satisfy.
        case setup
        /// Reached from Profile. Dismisses on save or cancel.
        case edit

        var title: String { self == .setup ? "About you" : "Edit profile" }
        var submitTitle: String { self == .setup ? "Continue" : "Save Changes" }
    }

    let mode: Mode

    @Environment(ViewerProfileService.self) private var profileService
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ViewerProfile()
    @State private var hasLoadedDraft = false
    @State private var showingTurnOnsPicker = false
    @State private var showingFetishesPicker = false
    @State private var saveError: String?
    @State private var didAttemptSubmit = false

    /// Nil until a birthdate is chosen, so the picker doesn't imply a default DOB.
    @State private var birthdateSelection = ViewerProfile.latestAllowedBirthdate()
    @State private var hasSetBirthdate = false

    private var validationErrors: [ViewerProfile.ValidationError] {
        draft.validationErrors()
    }

    private var canSubmit: Bool {
        validationErrors.isEmpty && !profileService.isSaving
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if mode == .setup { setupHeader }

                    basicsSection
                    identitySection
                    aboutMeSection
                    interestsSection

                    if didAttemptSubmit, let first = validationErrors.first {
                        errorBanner(first.localizedDescription)
                    }
                    if let saveError {
                        errorBanner(saveError)
                    }

                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, mode == .setup ? 16 : 8)
                .padding(.bottom, 48)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(mode == .edit ? mode.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(mode == .setup ? .hidden : .visible, for: .navigationBar)
        .task { loadDraftIfNeeded() }
        .sheet(isPresented: $showingTurnOnsPicker) {
            TagPickerView(
                title: "Turn ons",
                subtitle: "What gets your attention. Pick from the list or add your own.",
                catalog: InterestCatalog.turnOns,
                tint: .pink,
                selection: $draft.turnOns
            )
        }
        .sheet(isPresented: $showingFetishesPicker) {
            TagPickerView(
                title: "Fetishes",
                subtitle: "Kinks and fetishes you're into. Everything here is between consenting adults.",
                catalog: InterestCatalog.fetishes,
                tint: .purple,
                selection: $draft.fetishes
            )
        }
    }

    // MARK: — Header

    private var setupHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About you")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("This is what creators see. You can change any of it later.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.bottom, 4)
    }

    // MARK: — Basics

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Basics")

            fieldLabel("Display name")
            AuthTextField(placeholder: "What should we call you?", text: $draft.displayName)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Display name")
            counter(draft.displayName.count, ViewerProfile.displayNameMaxLength)

            birthdateRow
        }
    }

    private var birthdateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Date of birth")

            HStack {
                DatePicker(
                    "Date of birth",
                    selection: $birthdateSelection,
                    in: ...ViewerProfile.latestAllowedBirthdate(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .tint(.pink)
                .onChange(of: birthdateSelection) { _, newValue in
                    hasSetBirthdate = true
                    draft.birthdate = newValue
                }

                Spacer()

                if let age = draft.age {
                    Text("\(age)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("years old")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            // The picker's own range blocks under-18 dates, but the copy has to
            // say why the range stops where it does.
            Text(hasSetBirthdate
                 ? "Your age is shown on your profile; your date of birth is not."
                 : "AIxcam is \(ViewerProfile.minimumAge)+. Set your date of birth to continue.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: — Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Identity")

            fieldLabel("Gender")
            optionMenu(
                selectionLabel: draft.gender?.label ?? "Select",
                options: Gender.allCases,
                label: \.label,
                isSelected: { $0 == draft.gender },
                onSelect: { draft.gender = $0 }
            )
            .accessibilityLabel("Gender")

            if draft.gender?.requiresCustomText == true {
                AuthTextField(placeholder: "Describe your gender", text: $draft.genderSelfDescription)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Describe your gender")
            }

            fieldLabel("Pronouns")
            optionMenu(
                selectionLabel: draft.pronouns?.label ?? "Select",
                options: Pronouns.allCases,
                label: \.label,
                isSelected: { $0 == draft.pronouns },
                onSelect: { draft.pronouns = $0 }
            )
            .accessibilityLabel("Pronouns")

            if draft.pronouns?.requiresCustomText == true {
                AuthTextField(placeholder: "e.g. ve/ver", text: $draft.pronounsCustom)
                    .accessibilityLabel("Your pronouns")
            }

            Text("Pronouns are what chat and notifications use when they talk about you.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: — About me

    private var aboutMeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("About me")

            TextEditor(text: $draft.aboutMe)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(.white)
                .tint(.pink)
                .frame(minHeight: 130)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if draft.aboutMe.isEmpty {
                        Text("Tell creators who you are and what you're looking for.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("About me")

            counter(draft.aboutMe.count, ViewerProfile.aboutMeMaxLength)
        }
    }

    // MARK: — Interests

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            sectionLabel("Interests")

            interestBlock(
                title: "Turn ons",
                caption: "What you're into.",
                tags: draft.turnOns,
                tint: .pink,
                visibility: $draft.turnOnsVisibility,
                onEdit: { showingTurnOnsPicker = true }
            )

            interestBlock(
                title: "Fetishes",
                caption: "Kinks you want creators to know about.",
                tags: draft.fetishes,
                tint: .purple,
                visibility: $draft.fetishesVisibility,
                onEdit: { showingFetishesPicker = true }
            )
        }
    }

    private func interestBlock(
        title: String,
        caption: String,
        tags: [String],
        tint: Color,
        visibility: Binding<FieldVisibility>,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Button(tags.isEmpty ? "Add" : "Edit", action: onEdit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityLabel("\(tags.isEmpty ? "Add" : "Edit") \(title)")
            }

            if tags.isEmpty {
                Button(action: onEdit) {
                    Text("Nothing selected yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundStyle(Color.white.opacity(0.12))
                        )
                }
            } else {
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(title: tag, isSelected: true, tint: tint)
                    }
                }
            }

            visibilityPicker(title: title, selection: visibility, tint: tint)
        }
    }

    private func visibilityPicker(
        title: String,
        selection: Binding<FieldVisibility>,
        tint: Color
    ) -> some View {
        Menu {
            ForEach(FieldVisibility.allCases) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    Label(option.label, systemImage: option.systemImage)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selection.wrappedValue.systemImage)
                    .font(.caption2)
                Text("Visible to \(selection.wrappedValue.label.lowercased())")
                    .font(.caption)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(tint.opacity(0.85))
        }
        .accessibilityLabel("\(title) visibility, currently \(selection.wrappedValue.label)")
    }

    // MARK: — Submit

    private var submitButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await submit() }
            } label: {
                if profileService.isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Text(mode.submitTitle)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .background(Color.white.opacity(canSubmit ? 1.0 : 0.4), in: Capsule())
            .disabled(profileService.isSaving)
            .animation(.easeOut(duration: 0.12), value: canSubmit)

            if mode == .edit {
                Button("Cancel") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.top, 4)
    }

    // MARK: — Reusable bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.45))
            .textCase(.uppercase)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
    }

    private func counter(_ count: Int, _ limit: Int) -> some View {
        Text("\(count)/\(limit)")
            .font(.caption2)
            .foregroundStyle(count > limit ? .red.opacity(0.9) : .white.opacity(0.35))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.red.opacity(0.9))
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
    }

    /// Generic single-select menu so gender and pronouns stay visually identical.
    private func optionMenu<Option: Identifiable>(
        selectionLabel: String,
        options: [Option],
        label: KeyPath<Option, String>,
        isSelected: @escaping (Option) -> Bool,
        onSelect: @escaping (Option) -> Void
    ) -> some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    if isSelected(option) {
                        Label(option[keyPath: label], systemImage: "checkmark")
                    } else {
                        Text(option[keyPath: label])
                    }
                }
            }
        } label: {
            HStack {
                Text(selectionLabel)
                    .font(.body)
                    .foregroundStyle(selectionLabel == "Select" ? .white.opacity(0.35) : .white)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: — Actions

    /// Seeds the editable draft from the loaded profile exactly once, so a
    /// background refresh can't clobber what the person is typing.
    private func loadDraftIfNeeded() {
        guard !hasLoadedDraft else { return }
        hasLoadedDraft = true

        guard let existing = profileService.profile else { return }
        draft = existing
        if let birthdate = existing.birthdate {
            birthdateSelection = birthdate
            hasSetBirthdate = true
        }
    }

    private func submit() async {
        didAttemptSubmit = true
        saveError = nil
        guard validationErrors.isEmpty else { return }

        let success = await profileService.save(draft)
        if success {
            if mode == .edit { dismiss() }
            // In .setup the profile gate in ContentView reacts to the saved
            // profile becoming complete and swaps this screen for the app.
        } else {
            saveError = "We couldn't save your profile. Check your connection and try again."
        }
    }
}

#Preview("Setup") {
    NavigationStack {
        ViewerProfileEditView(mode: .setup)
    }
    .environment(ViewerProfileService())
    .preferredColorScheme(.dark)
}

#Preview("Edit") {
    NavigationStack {
        ViewerProfileEditView(mode: .edit)
    }
    .environment(ViewerProfileService())
    .preferredColorScheme(.dark)
}
