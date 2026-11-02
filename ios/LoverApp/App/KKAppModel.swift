import Combine
import Foundation

// One environment object so KK screens share local stores without each
// preview growing a new parameter. Child stores still publish; we forward
// objectWillChange so SwiftUI refreshes.

@MainActor
final class KKAppModel: ObservableObject {
    let dailyMood = DailyMoodStore()
    let memory = MemorySpaceStore()
    let want = WantYouKnowStore()
    let ai = AIUsageStore()
    let kaomoji = KaomojiPrefsStore()

    @Published var requestedTab: AppTab?
    @Published var aiRequest: AIExpandRequest?

    private var bag = Set<AnyCancellable>()
    private var boundUser: UUID?

    init() {
        let publishers = [
            dailyMood.objectWillChange,
            memory.objectWillChange,
            want.objectWillChange,
            ai.objectWillChange,
            kaomoji.objectWillChange,
        ]
        for publisher in publishers {
            publisher.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &bag)
        }
    }

    func bind(userId: UUID) {
        guard boundUser != userId else { return }
        boundUser = userId
        dailyMood.bind(userId: userId)
        memory.bind(userId: userId)
        want.bind(userId: userId)
        ai.bind(userId: userId)
        kaomoji.bind(userId: userId)
    }

    func clearSession() {
        boundUser = nil
        requestedTab = nil
        aiRequest = nil
        dailyMood.clearSession()
        memory.clearSession()
        want.clearSession()
        ai.clearSession()
        kaomoji.clearSession()
    }
}
