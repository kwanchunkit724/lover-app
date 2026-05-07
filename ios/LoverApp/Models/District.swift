import Foundation

// v1.1.0 — Hong Kong's 18 administrative districts. Backs the 18 區日記
// activity: each district is a "journal slot" the couple fills in by
// visiting + writing a short reflection.
//
// `code` is the stable identifier (NEVER renumber — used as the encrypted
// payload's districtCode field, persists across schema changes).
//
// `tint` cycles 3-way through rose/sage/amber so the grid has visual
// variety without per-district color choices.

struct District: Identifiable, Hashable {
    enum Tint: String { case rose, sage, amber }
    enum Region: String, CaseIterable { case hkIsland = "港島", kowloon = "九龍", nt = "新界" }

    /// Stable 2-char code, also the .id. Never renumber.
    let id: String
    let name: String
    let region: Region
    let kaomoji: String
    let tint: Tint
}

extension District {
    /// All 18 districts in canonical order — Island first, Kowloon second,
    /// New Territories third.
    static let all: [District] = [
        // Hong Kong Island (4)
        .init(id: "CW", name: "中西區", region: .hkIsland, kaomoji: "(´｡• ω •｡`)", tint: .rose),
        .init(id: "WC", name: "灣仔區", region: .hkIsland, kaomoji: "(◕‿◕)",       tint: .sage),
        .init(id: "EA", name: "東區",   region: .hkIsland, kaomoji: "(◍•ᴗ•◍)",     tint: .amber),
        .init(id: "SO", name: "南區",   region: .hkIsland, kaomoji: "(♡˙︶˙♡)",    tint: .rose),
        // Kowloon (5)
        .init(id: "YT", name: "油尖旺區", region: .kowloon, kaomoji: "(≧▽≦)",       tint: .sage),
        .init(id: "SS", name: "深水埗區", region: .kowloon, kaomoji: "(¬‿¬)",       tint: .amber),
        .init(id: "KC", name: "九龍城區", region: .kowloon, kaomoji: "(•̀ᴗ•́)و",    tint: .rose),
        .init(id: "WT", name: "黃大仙區", region: .kowloon, kaomoji: "(´｡• ᵕ •｡`)", tint: .sage),
        .init(id: "KT", name: "觀塘區",   region: .kowloon, kaomoji: "(◕‿◕)",       tint: .amber),
        // New Territories (9)
        .init(id: "KE", name: "葵青區", region: .nt, kaomoji: "(◍•ᴗ•◍)",       tint: .rose),
        .init(id: "TW", name: "荃灣區", region: .nt, kaomoji: "(♡´︶`♡)",       tint: .sage),
        .init(id: "TM", name: "屯門區", region: .nt, kaomoji: "(´｡• ω •｡`)",  tint: .amber),
        .init(id: "YL", name: "元朗區", region: .nt, kaomoji: "(っ˘ڡ˘ς)",       tint: .rose),
        .init(id: "NO", name: "北區",   region: .nt, kaomoji: "(─‿─)",         tint: .sage),
        .init(id: "TP", name: "大埔區", region: .nt, kaomoji: "(•̀ᴗ•́)و",     tint: .amber),
        .init(id: "ST", name: "沙田區", region: .nt, kaomoji: "(◕‿◕)",         tint: .rose),
        .init(id: "SK", name: "西貢區", region: .nt, kaomoji: "(♡˙︶˙♡)",      tint: .sage),
        .init(id: "IS", name: "離島區", region: .nt, kaomoji: "(´｡• ᵕ •｡`)",  tint: .amber),
    ]

    static func find(code: String) -> District? {
        all.first { $0.id == code }
    }
}
