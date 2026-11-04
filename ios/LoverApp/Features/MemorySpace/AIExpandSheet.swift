import SwiftUI

// AI reads typed text and memory items only. This sheet has no field for
// chat ciphertext. The consume call is local until `kk_ai_consume_and_run`.

struct AIExpandSheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel
    @Environment(\.dismiss) private var dismiss

    let request: AIExpandRequest

    @State private var text: String = ""
    @State private var result: String?
    @State private var didConsume = false

    private var memoryLines: [MemoryItem] {
        kk.memory.items.filter { request.memoryItemIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("今個月 \(kk.ai.snapshot.used)/\(KKAIQuota.monthlyCap)")
                        .font(DSText.mono(theme, 12))
                        .foregroundStyle(kk.ai.snapshot.isLocked ? theme.rose : theme.inkSoft)

                    if kk.ai.snapshot.isLocked && !didConsume {
                        Text("(´;ω;`)")
                            .font(.system(size: 40, design: .monospaced))
                            .foregroundStyle(theme.rose)
                        Text("今個月 10 次用完。下個月先再試。")
                            .font(DSText.ui(theme, 15))
                            .foregroundStyle(theme.ink)
                    } else {
                        Text("你打嘅字")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.inkMuted)
                        TextField("想整理啲咩", text: $text, axis: .vertical)
                            .lineLimit(3...8)
                            .font(DSText.ui(theme, 15))
                            .padding(12)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if !memoryLines.isEmpty {
                            Text("記憶空間項目")
                                .font(DSText.mono(theme, 11))
                                .foregroundStyle(theme.inkMuted)
                            ForEach(memoryLines) { item in
                                Text(item.originalText.isEmpty ? item.title : item.originalText)
                                    .font(DSText.ui(theme, 14))
                                    .foregroundStyle(theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(theme.paperAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }

                        Text("唔會讀聊天密文或者附件二進位。")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.inkMuted)

                        if let result {
                            Text(result)
                                .font(DSText.ui(theme, 14))
                                .foregroundStyle(theme.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button(action: run) {
                            Text(didConsume ? "已扣 1 次" : "展開（扣 1 次）")
                                .font(DSText.ui(theme, 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(didConsume || kk.ai.snapshot.isLocked ? theme.line : theme.rose)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(didConsume || kk.ai.snapshot.isLocked)

                        if let note = kk.ai.lastNote {
                            Text(note)
                                .font(DSText.mono(theme, 11))
                                .foregroundStyle(theme.rose)
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.paper.ignoresSafeArea())
            .navigationTitle("AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
        .onAppear { text = request.userText }
    }

    private func run() {
        let memories = kk.memory.items
            .filter { request.memoryItemIds.contains($0.id) }
            .map {
                KKRPC.AIMemoryInput(id: $0.id.uuidString, title: $0.title, original_text: $0.originalText)
            }
        Task {
            let outcome = await kk.ai.consumeOnServer(userText: text, memories: memories)
            guard outcome.ok else { return }
            didConsume = true
            result = outcome.message
        }
    }
}
