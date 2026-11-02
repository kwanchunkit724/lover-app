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
    private var observing = false

    /// Called once the model is fully initialized. Doing this in `init` captures
    /// `self` in an escaping Combine sink before the instance is ready.
    func startObserving() {
        guard !observing else { return }
        observing = true
        observe(dailyMood.objectWillChange)
        observe(memory.objectWillChange)
        observe(want.objectWillChange)
        observe(ai.objectWillChange)
        observe(kaomoji.objectWillChange)
    }

    private func observe<P: Publisher>(_ publisher: P) where P.Failure == Never {
        publisher.sink { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }.store(in: &bag)
    }

    func bind(userId: UUID) {
        startObserving()
        guard boundUser != userId else { return }
        boundUser = userId
        dailyMood.bind(userId: userId)
        memory.bind(userId: userId)
        want.bind(userId: userId)
        ai.bind(userId: userId)
        kaomoji.bind(userId: userId)
        Task { await syncRemote() }
    }

    /// Pulls server rows and opportunistically purges expired chat.
    /// 48h Edge/cron is still TODO; this call is not that schedule.
    private func syncRemote() async {
        await dailyMood.refreshFromServer()
        await memory.refreshFromServer()
        await want.refreshFromServer()
        await ai.refreshFromServer()
        await kaomoji.refreshFromServer()
        do {
            try await KKRPC.purgeExpiredMessages()
        } catch {
            memory.lastError = error.localizedDescription
        }
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
