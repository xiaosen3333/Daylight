import Foundation

final class TodaySuggestionsProvider {
    private let slotCount: Int
    private var usedSuggestionIds: Set<String> = []

    init(slotCount: Int = 3) {
        self.slotCount = slotCount
    }

    var allSuggestions: [TodayViewModel.Suggestion] {
        [
            .init(id: "commit.suggestion1", text: NSLocalizedString("commit.suggestion1", comment: "")),
            .init(id: "commit.suggestion2", text: NSLocalizedString("commit.suggestion2", comment: "")),
            .init(id: "commit.suggestion3", text: NSLocalizedString("commit.suggestion3", comment: "")),
            .init(id: "commit.suggestion4", text: NSLocalizedString("commit.suggestion4", comment: "")),
            .init(id: "commit.suggestion5", text: NSLocalizedString("commit.suggestion5", comment: "")),
            .init(id: "commit.suggestion6", text: NSLocalizedString("commit.suggestion6", comment: "")),
            .init(id: "commit.suggestion7", text: NSLocalizedString("commit.suggestion7", comment: "")),
            .init(id: "commit.suggestion8", text: NSLocalizedString("commit.suggestion8", comment: ""))
        ]
    }

    func setupSuggestions(initialText: String) -> [TodayViewModel.SuggestionSlot] {
        usedSuggestionIds = []
        let normalized = normalize(initialText)
        var available = allSuggestions.filter { normalize($0.text) != normalized }.shuffled()
        var slots: [TodayViewModel.SuggestionSlot] = []
        for index in 0..<slotCount {
            if let suggestion = available.popLast() {
                usedSuggestionIds.insert(suggestion.id)
                slots.append(TodayViewModel.SuggestionSlot(id: suggestion.id, text: suggestion.text))
            } else {
                slots.append(makeEmptySlot(index: index))
            }
        }
        return slots
    }

    func pickSuggestion(at index: Int,
                        slots: [TodayViewModel.SuggestionSlot],
                        currentInput: String) -> (String, [TodayViewModel.SuggestionSlot])? {
        guard slots.indices.contains(index),
              let text = slots[index].text else { return nil }
        var updated = slots
        updated = refillSlot(index: index, slots: updated, excluding: [text, currentInput])
        return (text, updated)
    }

    func onTextChanged(_ text: String,
                       slots: [TodayViewModel.SuggestionSlot],
                       currentInput: String) -> [TodayViewModel.SuggestionSlot] {
        let normalized = normalize(text)
        var updated = slots
        for index in updated.indices where normalize(updated[index].text) == normalized {
            updated[index] = makeEmptySlot(index: index)
            updated = refillSlot(index: index, slots: updated, excluding: [text, currentInput])
        }
        return updated
    }

    // MARK: - Private
    private func refillSlot(index: Int,
                            slots: [TodayViewModel.SuggestionSlot],
                            excluding: [String]) -> [TodayViewModel.SuggestionSlot] {
        guard slots.indices.contains(index) else { return slots }
        var updated = slots
        let normalizedExclusions = excluding.map { normalize($0) }

        let occupiedIds = updated.enumerated().compactMap { offset, slot -> String? in
            guard offset != index, slot.text != nil else { return nil }
            return slot.id
        }

        let filtered = allSuggestions.filter {
            !occupiedIds.contains($0.id) &&
            !normalizedExclusions.contains(normalize($0.text))
        }
        let unused = filtered.filter { !usedSuggestionIds.contains($0.id) }
        let pool = unused.isEmpty ? filtered : unused
        guard let next = pool.randomElement() else {
            updated[index] = makeEmptySlot(index: index)
            return updated
        }
        usedSuggestionIds.insert(next.id)
        updated[index] = TodayViewModel.SuggestionSlot(id: next.id, text: next.text)
        return updated
    }

    private func makeEmptySlot(index: Int) -> TodayViewModel.SuggestionSlot {
        TodayViewModel.SuggestionSlot(id: "slot-\(index)-empty-\(UUID().uuidString)", text: nil)
    }

    private func normalize(_ text: String?) -> String {
        text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
