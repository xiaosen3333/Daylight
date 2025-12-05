import SwiftUI

// MARK: - Day Commitment Page 对齐 daycommit.png
struct DayCommitmentPage: View {
    @ObservedObject var viewModel: TodayViewModel
    @Environment(\.dismiss) private var dismiss
    private let maxCommitmentLength = 80

    var body: some View {
        ZStack {
            DaylightColors.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 24) {
                GlowingSun(size: 120)
                    .padding(.top, 40)

                Text(NSLocalizedString("commit.title.full", comment: ""))
                    .daylight(.title2, alignment: .center, lineLimit: 2)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    capsuleField(title: NSLocalizedString("commit.placeholder.short", comment: ""), isEditable: true)
                    ForEach(Array(viewModel.suggestionsVisible.enumerated()), id: \.element.id) { index, slot in
                        suggestionButton(slot: slot, index: index)
                    }
                }
                .padding(.top, 12)

                DaylightPrimaryButton(title: NSLocalizedString("common.confirm", comment: ""),
                                      isEnabled: isCommitmentValid,
                                      isLoading: viewModel.state.isSavingCommitment) {
                    Task { await submitCommitment() }
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 32)
            .onAppear {
                let initialText = viewModel.state.record?.commitmentText ?? viewModel.commitmentText
                viewModel.commitmentText = initialText
                viewModel.setupSuggestions(initialText: initialText)
            }
            .onChange(of: viewModel.locale) { _, _ in
                viewModel.setupSuggestions(initialText: viewModel.commitmentText)
            }
            .onChange(of: viewModel.commitmentText) { _, newValue in
                let limited = String(newValue.prefix(maxCommitmentLength))
                if limited != newValue {
                    viewModel.commitmentText = limited
                    return
                }
                viewModel.onTextChanged(newValue)
            }
        }
    }

    private var isCommitmentValid: Bool {
        let trimmed = viewModel.commitmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxCommitmentLength
    }

    private func submitCommitment() async {
        let trimmed = viewModel.commitmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxCommitmentLength else { return }
        viewModel.commitmentText = trimmed
        await viewModel.submitCommitment()
        if viewModel.state.errorMessage == nil {
            dismiss()
        }
    }

    @ViewBuilder
    private func capsuleField(title: String, isEditable: Bool) -> some View {
        if isEditable {
            TextField(title, text: Binding(
                get: { viewModel.commitmentText },
                set: { viewModel.commitmentText = $0 }
            ))
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(DaylightColors.actionPrimary)
            .cornerRadius(DaylightRadius.capsule)
            .foregroundColor(.white)
        } else {
            Text(title)
                .daylight(.body2, color: .white, alignment: .leading)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DaylightColors.actionPrimary)
                .cornerRadius(DaylightRadius.capsule)
        }
    }

    @ViewBuilder
    private func suggestionButton(slot: TodayViewModel.SuggestionSlot, index: Int) -> some View {
        if let suggestion = slot.text {
            Button {
                viewModel.pickSuggestion(at: index)
            } label: {
                Text(suggestion)
                    .daylight(.body2, color: .white, alignment: .leading)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DaylightColors.actionPrimary)
                    .cornerRadius(DaylightRadius.capsule)
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: DaylightRadius.capsule)
                .fill(DaylightColors.actionPrimary.opacity(0.24))
                .frame(height: 52)
                .frame(maxWidth: .infinity)
        }
    }
}
