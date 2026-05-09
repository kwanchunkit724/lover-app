import Foundation

// v1.3.0 — Hong Kong MTR heavy-rail stations. Backs the MTR 站日記
// activity, sibling to 18 區日記 (District). One row per visit, recorded
// via PlayHistoryService.recordMtrStation.
//
// Coverage: 9 heavy-rail lines (excludes Light Rail because its 68 stops
// at small intervals would overwhelm a couple-friendly journal).
//
// Each station has a stable 3-letter code (matching MTR Corp's official
// station codes — never renumber). Order within a line follows the
// official line direction.

struct MTRStation: Identifiable, Hashable {
    let id: String       // 3-letter code, e.g. "ADM" for 金鐘
    let name: String
    let line: MTRLine
}

enum MTRLine: String, CaseIterable, Hashable {
    case island      = "港島綫"
    case tsuenWan    = "荃灣綫"
    case kwunTong    = "觀塘綫"
    case tseungKwanO = "將軍澳綫"
    case tungChung   = "東涌綫"
    case airport     = "機場快綫"
    case eastRail    = "東鐵綫"
    case tuenMa      = "屯馬綫"
    case southIsland = "南港島綫"

    /// Hex color string mapping the official MTR brand color per line.
    var colorHex: String {
        switch self {
        case .island:      return "#0860A8"   // navy
        case .tsuenWan:    return "#E2231A"   // red
        case .kwunTong:    return "#00888E"   // teal
        case .tseungKwanO: return "#7E3C8C"   // purple
        case .tungChung:   return "#F3A22A"   // orange
        case .airport:     return "#1C7670"   // dark green
        case .eastRail:    return "#5EB7E8"   // light blue
        case .tuenMa:      return "#923011"   // brown
        case .southIsland: return "#BAC429"   // lime
        }
    }
}

extension MTRStation {
    /// 90 stations across 9 lines. Order matters — list each line in its
    /// canonical direction.
    static let all: [MTRStation] = [
        // 港島綫 (Island Line) — 17 stations, west → east
        .init(id: "KET", name: "堅尼地城", line: .island),
        .init(id: "HKU", name: "香港大學", line: .island),
        .init(id: "SYP", name: "西營盤",   line: .island),
        .init(id: "SHW", name: "上環",     line: .island),
        .init(id: "CEN", name: "中環",     line: .island),
        .init(id: "ADM", name: "金鐘",     line: .island),
        .init(id: "WAC", name: "灣仔",     line: .island),
        .init(id: "CAB", name: "銅鑼灣",   line: .island),
        .init(id: "TIH", name: "天后",     line: .island),
        .init(id: "FOH", name: "炮台山",   line: .island),
        .init(id: "NOP", name: "北角",     line: .island),
        .init(id: "QUB", name: "鰂魚涌",   line: .island),
        .init(id: "TAK", name: "太古",     line: .island),
        .init(id: "SWH", name: "西灣河",   line: .island),
        .init(id: "SKW", name: "筲箕灣",   line: .island),
        .init(id: "HFC", name: "杏花邨",   line: .island),
        .init(id: "CHW", name: "柴灣",     line: .island),

        // 荃灣綫 (Tsuen Wan Line) — 16 stations
        .init(id: "TSW", name: "荃灣",     line: .tsuenWan),
        .init(id: "TWH", name: "大窩口",   line: .tsuenWan),
        .init(id: "KWH", name: "葵興",     line: .tsuenWan),
        .init(id: "KWF", name: "葵芳",     line: .tsuenWan),
        .init(id: "LAK", name: "茘景",     line: .tsuenWan),
        .init(id: "MEF", name: "美孚",     line: .tsuenWan),
        .init(id: "LCK", name: "茘枝角",   line: .tsuenWan),
        .init(id: "CSW", name: "長沙灣",   line: .tsuenWan),
        .init(id: "SSP", name: "深水埗",   line: .tsuenWan),
        .init(id: "PRE", name: "太子",     line: .tsuenWan),
        .init(id: "MOK", name: "旺角",     line: .tsuenWan),
        .init(id: "YMT", name: "油麻地",   line: .tsuenWan),
        .init(id: "JOR", name: "佐敦",     line: .tsuenWan),
        .init(id: "TST", name: "尖沙咀",   line: .tsuenWan),
        // CEN/ADM shared with Island; only listed once above.

        // 觀塘綫 (Kwun Tong Line) — 17 stations
        .init(id: "WHA", name: "黃埔",     line: .kwunTong),
        .init(id: "HOM", name: "何文田",   line: .kwunTong),
        .init(id: "SKM", name: "石硤尾",   line: .kwunTong),
        .init(id: "KOT", name: "九龍塘",   line: .kwunTong),
        .init(id: "LOF", name: "樂富",     line: .kwunTong),
        .init(id: "WTS", name: "黃大仙",   line: .kwunTong),
        .init(id: "DIH", name: "鑽石山",   line: .kwunTong),
        .init(id: "CHH", name: "彩虹",     line: .kwunTong),
        .init(id: "KOB", name: "九龍灣",   line: .kwunTong),
        .init(id: "NTK", name: "牛頭角",   line: .kwunTong),
        .init(id: "KWT", name: "觀塘",     line: .kwunTong),
        .init(id: "LAT", name: "藍田",     line: .kwunTong),
        .init(id: "YAT", name: "油塘",     line: .kwunTong),
        .init(id: "TIK", name: "調景嶺",   line: .kwunTong),

        // 將軍澳綫 (Tseung Kwan O Line)
        .init(id: "TKO", name: "將軍澳",   line: .tseungKwanO),
        .init(id: "HAH", name: "坑口",     line: .tseungKwanO),
        .init(id: "POA", name: "寶琳",     line: .tseungKwanO),
        .init(id: "LHP", name: "康城",     line: .tseungKwanO),

        // 東涌綫 (Tung Chung Line) — 8 stations
        .init(id: "OLY", name: "奧運",     line: .tungChung),
        .init(id: "NAC", name: "南昌",     line: .tungChung),
        .init(id: "LAI", name: "茘景東涌", line: .tungChung),
        .init(id: "TSY", name: "青衣",     line: .tungChung),
        .init(id: "SUN", name: "欣澳",     line: .tungChung),
        .init(id: "TUC", name: "東涌",     line: .tungChung),

        // 機場快綫 (Airport Express)
        .init(id: "AIR", name: "機場",     line: .airport),
        .init(id: "AWE", name: "博覽館",   line: .airport),

        // 東鐵綫 (East Rail Line) — 14 stations, Admiralty → Lo Wu / Lok Ma Chau
        .init(id: "EXC", name: "會展",     line: .eastRail),
        .init(id: "HUH", name: "紅磡",     line: .eastRail),
        .init(id: "MKK", name: "旺角東",   line: .eastRail),
        .init(id: "TAW", name: "大圍",     line: .eastRail),
        .init(id: "SHT", name: "沙田",     line: .eastRail),
        .init(id: "FOT", name: "火炭",     line: .eastRail),
        .init(id: "RAC", name: "馬場",     line: .eastRail),
        .init(id: "UNI", name: "大學",     line: .eastRail),
        .init(id: "TAP", name: "大埔墟",   line: .eastRail),
        .init(id: "TWO", name: "太和",     line: .eastRail),
        .init(id: "FAN", name: "粉嶺",     line: .eastRail),
        .init(id: "SHS", name: "上水",     line: .eastRail),
        .init(id: "LOW", name: "羅湖",     line: .eastRail),
        .init(id: "LMC", name: "落馬洲",   line: .eastRail),

        // 屯馬綫 (Tuen Ma Line) — 27 stations, west → east
        .init(id: "TUM", name: "屯門",     line: .tuenMa),
        .init(id: "SIH", name: "兆康",     line: .tuenMa),
        .init(id: "TIS", name: "天水圍",   line: .tuenMa),
        .init(id: "LOP", name: "朗屏",     line: .tuenMa),
        .init(id: "YUL", name: "元朗",     line: .tuenMa),
        .init(id: "KSR", name: "錦上路",   line: .tuenMa),
        .init(id: "TWW", name: "荃灣西",   line: .tuenMa),
        .init(id: "MEW", name: "美孚屯馬", line: .tuenMa),
        .init(id: "AUS", name: "柯士甸",   line: .tuenMa),
        .init(id: "ETS", name: "尖東",     line: .tuenMa),
        .init(id: "HUN", name: "紅磡屯馬", line: .tuenMa),
        .init(id: "HOT", name: "何文田屯馬",line: .tuenMa),
        .init(id: "TKW", name: "土瓜灣",   line: .tuenMa),
        .init(id: "SUW", name: "宋皇臺",   line: .tuenMa),
        .init(id: "KAT", name: "啟德",     line: .tuenMa),
        .init(id: "DIA", name: "鑽石山屯馬",line: .tuenMa),
        .init(id: "HIK", name: "顯徑",     line: .tuenMa),
        .init(id: "CKT", name: "車公廟",   line: .tuenMa),
        .init(id: "STW", name: "沙田圍",   line: .tuenMa),
        .init(id: "CIO", name: "第一城",   line: .tuenMa),
        .init(id: "SHM", name: "石門",     line: .tuenMa),
        .init(id: "TSH", name: "大水坑",   line: .tuenMa),
        .init(id: "HEO", name: "恆安",     line: .tuenMa),
        .init(id: "MOS", name: "馬鞍山",   line: .tuenMa),
        .init(id: "WKS", name: "烏溪沙",   line: .tuenMa),

        // 南港島綫 (South Island Line)
        .init(id: "OCP", name: "海洋公園", line: .southIsland),
        .init(id: "WCH", name: "黃竹坑",   line: .southIsland),
        .init(id: "LET", name: "利東",     line: .southIsland),
        .init(id: "SOH", name: "海怡半島", line: .southIsland),
    ]

    static func find(code: String) -> MTRStation? {
        all.first { $0.id == code }
    }

    static func stations(on line: MTRLine) -> [MTRStation] {
        all.filter { $0.line == line }
    }
}
