import Foundation

/// Maps `kk_ai_consume_and_run` into something the sheet can show.
///
/// A response is a successful expand only when the RPC says `ok` and there is
/// a real plan string. `status` of `stub` / `unavailable`, `ok: false`, and
/// developer notes (`quota_consumed`, "wire Gemini Edge…") are failures.
/// Failures do not change the local used-count and do not lock the button
/// as 「已扣 1 次」.
///
/// Quota may be incremented on the server only together with a real plan.
/// See `ios/KK_IOS_BACKEND_CONTRACT.md`.
enum AIExpandMapping {
    static let emptyInputMessage = "AI 只處理你打嘅字同記憶空間項目。"
    static let unavailableMessage = "AI 暫時未開，今次冇扣次數。稍後再試。"
    static let genericFailureMessage = "暫時整理唔到。今次冇扣次數，可以再試。"
    static let quotaMessage = "今個月 \(KKAIQuota.monthlyCap) 次用完。下個月先再試。"

    struct UsageSnapshot: Equatable {
        var period: String
        var used: Int
    }

    struct Decision: Equatable {
        var succeeded: Bool
        var userMessage: String
        /// Replaces the local used-count. Nil leaves the on-device count as it was.
        var used: Int?
        var period: String?
        var exhaustsQuota: Bool
    }

    /// Sheet button. `didConsume` is true only after `Decision.succeeded`.
    enum Button {
        static func title(didConsume: Bool) -> String {
            didConsume ? "已扣 1 次" : "展開（扣 1 次）"
        }

        static func isDisabled(didConsume: Bool, quotaLocked: Bool) -> Bool {
            didConsume || quotaLocked
        }
    }

    static func decide(
        ok: Bool?,
        status: String?,
        note: String?,
        plan: String?,
        text: String?,
        reportedUsed: Int?,
        period: String?
    ) -> Decision {
        let statusToken = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if isQuotaExhausted(statusToken) || isQuotaExhausted(note ?? "") {
            return Decision(
                succeeded: false,
                userMessage: quotaMessage,
                used: KKAIQuota.monthlyCap,
                period: period,
                exhaustsQuota: true
            )
        }
        if ok == false || isFailureStatus(statusToken) {
            return Decision(
                succeeded: false,
                userMessage: failureMessage(status: statusToken, note: note),
                used: nil,
                period: nil,
                exhaustsQuota: false
            )
        }
        guard let planText = firstPlan(plan: plan, text: text, note: note) else {
            return Decision(
                succeeded: false,
                userMessage: unavailableMessage,
                used: nil,
                period: nil,
                exhaustsQuota: false
            )
        }
        return Decision(
            succeeded: true,
            userMessage: planText,
            used: reportedUsed,
            period: period,
            exhaustsQuota: false
        )
    }

    static func decision(forThrown error: Error) -> Decision {
        decision(forThrownRaw: rawText(from: error))
    }

    static func decision(forThrownRaw raw: String) -> Decision {
        let lowered = raw.lowercased()
        if isQuotaExhausted(lowered) {
            return Decision(
                succeeded: false,
                userMessage: quotaMessage,
                used: KKAIQuota.monthlyCap,
                period: nil,
                exhaustsQuota: true
            )
        }
        if lowered.contains("not_paired") {
            return Decision(
                succeeded: false,
                userMessage: "未配對 — 請先配對",
                used: nil,
                period: nil,
                exhaustsQuota: false
            )
        }
        if lowered.contains("not_authenticated") || lowered.contains("not authenticated") {
            return Decision(
                succeeded: false,
                userMessage: "未登入 — 重新登入",
                used: nil,
                period: nil,
                exhaustsQuota: false
            )
        }
        if lowered.contains("empty_ai_input") {
            return Decision(
                succeeded: false,
                userMessage: emptyInputMessage,
                used: nil,
                period: nil,
                exhaustsQuota: false
            )
        }
        if isUnavailableSignal(lowered) {
            return Decision(
                succeeded: false,
                userMessage: unavailableMessage,
                used: nil,
                period: nil,
                exhaustsQuota: false
            )
        }
        return Decision(
            succeeded: false,
            userMessage: genericFailureMessage,
            used: nil,
            period: nil,
            exhaustsQuota: false
        )
    }

    static func applying(_ decision: Decision, to snapshot: UsageSnapshot) -> UsageSnapshot {
        if decision.exhaustsQuota {
            return UsageSnapshot(period: snapshot.period, used: KKAIQuota.monthlyCap)
        }
        guard decision.succeeded, let used = decision.used else { return snapshot }
        return UsageSnapshot(period: decision.period ?? snapshot.period, used: used)
    }

    static func isDeveloperLeak(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let needles = [
            "quota_consumed", "quota_exhausted", "ai_quota_exhausted",
            "gemini", "wire gemini", "kk_ai", "not wired", "edge function",
            "not_paired", "not_authenticated", "invalid_payload",
            "empty_ai_input", "forbidden_ai_key", "chat_ciphertext",
            "kk_ai_consume_and_run"
        ]
        if needles.contains(where: { lowered.contains($0) }) { return true }
        if lowered.range(of: #"[a-z][a-z0-9]*_[a-z0-9_]+"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    static func rawText(from error: Error) -> String {
        let ns = error as NSError
        var parts = [ns.localizedDescription]
        if let message = ns.userInfo["message"] as? String {
            parts.append(message)
        }
        if let reason = ns.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            parts.append(reason)
        }
        return parts.joined(separator: "\n")
    }

    private static func isFailureStatus(_ status: String) -> Bool {
        ["stub", "unavailable", "error", "failed", "quota_consumed"].contains(status)
    }

    private static func isQuotaExhausted(_ raw: String) -> Bool {
        let lowered = raw.lowercased()
        return lowered.contains("ai_quota_exhausted") || lowered.contains("quota_exhausted")
    }

    private static func isUnavailableSignal(_ lowered: String) -> Bool {
        lowered.contains("quota_consumed")
            || lowered.contains("gemini")
            || lowered.contains("stub")
            || lowered.contains("unavailable")
            || lowered.contains("not wired")
    }

    private static func failureMessage(status: String, note: String?) -> String {
        if isUnavailableSignal(status) || isUnavailableSignal(note?.lowercased() ?? "") {
            return unavailableMessage
        }
        return genericFailureMessage
    }

    private static func firstPlan(plan: String?, text: String?, note: String?) -> String? {
        for raw in [plan, text, note] {
            guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                continue
            }
            if isDeveloperLeak(trimmed) { continue }
            return trimmed
        }
        return nil
    }
}
