import Foundation

// v1.5.1 — feature catalogs split out of MockData.
// These are static FEATURE DEFINITIONS (activity types, date cards, quiz
// questions). They are NOT user data and ship with the app like strings or
// images do. Renamed out of `MockData` so the audit rule "no MockData
// outside #Preview" is mechanical.

enum ActivityCatalog {
    static let all: [Activity] = [
        Activity(id: "a1", title: "盲盒約會", subtitle: "抽一張卡，跟住做", kind: .cards, count: 24),
        Activity(id: "a2", title: "21 條問題", subtitle: "了解多啲對方", kind: .quiz, count: 21),
        // v1.1.0 — 18 districts, journal each one as you visit.
        Activity(id: "a3", title: "18 區日記", subtitle: "一齊行勻香港，一區一篇", kind: .districts, count: 18),
        // v1.3.0 — MTR 站日記. 90 stations across 9 lines.
        Activity(id: "a4", title: "MTR 站日記", subtitle: "一齊搭遍 MTR，一站一篇", kind: .mtr, count: 90),
    ]
}

enum DateCardCatalog {
    static let all: [DateCard] = [
        DateCard(id: 1, title: "夜遊維港",
                 detail: "搭天星小輪，喺甲板上面影返張合照",
                 mood: "浪漫", kaomoji: "(♡˙︶˙♡)", tint: .rose, cost: "$$"),
        DateCard(id: 2, title: "一齊整 pancake",
                 detail: "揀一個未試過嘅口味，最差嗰個負責洗碗",
                 mood: "屋企", kaomoji: "(っ˘ڡ˘ς)", tint: .amber, cost: "$"),
        DateCard(id: 3, title: "影貼紙相",
                 detail: "銅鑼灣或旺角，搞笑款 4 連張",
                 mood: "玩樂", kaomoji: "(≧▽≦)", tint: .rose, cost: "$"),
        DateCard(id: 4, title: "行一條未行過嘅街",
                 detail: "Google Maps 隨機 drop pin，去最近嗰條",
                 mood: "探險", kaomoji: "(´｡• ω •｡`)", tint: .sage, cost: "$"),
        DateCard(id: 5, title: "寫信俾未來自己",
                 detail: "一年後拆，封住放入記憶簿",
                 mood: "靜", kaomoji: "(◍•ᴗ•◍)", tint: .amber, cost: "$"),
        DateCard(id: 6, title: "盲交換禮物",
                 detail: "$50 budget，30 分鐘內入便利店揀",
                 mood: "玩樂", kaomoji: "(¬‿¬)", tint: .sage, cost: "$"),
        DateCard(id: 7, title: "搭叮叮一程",
                 detail: "上層頭排，由筲箕灣坐去堅尼地城",
                 mood: "懷舊", kaomoji: "(◕‿◕)", tint: .sage, cost: "$"),
        DateCard(id: 8, title: "夜晚行山睇夜景",
                 detail: "獅子山或大潭，記得帶電筒",
                 mood: "探險", kaomoji: "(•̀ᴗ•́)و", tint: .sage, cost: "$"),
        DateCard(id: 9, title: "一齊煲劇 marathon",
                 detail: "揀一套兩個都未睇過嘅，一晚煲完",
                 mood: "屋企", kaomoji: "(─‿─)", tint: .amber, cost: "$"),
        DateCard(id: 10, title: "去街市買餸",
                 detail: "唔講食乜，望住有咩買咩，返屋企 freestyle",
                 mood: "屋企", kaomoji: "(￣ω￣)", tint: .amber, cost: "$"),
        DateCard(id: 11, title: "影黑白菲林",
                 detail: "買一筒可棄菲林，行半日，影晒佢",
                 mood: "靜", kaomoji: "(◍•ᴗ•◍)", tint: .rose, cost: "$$"),
        DateCard(id: 12, title: "去離島放空",
                 detail: "南丫、長洲、坪洲，揀一個冇去過",
                 mood: "靜", kaomoji: "(´｡• ω •｡`)", tint: .sage, cost: "$"),
        DateCard(id: 13, title: "去 IKEA 諗將來層樓",
                 detail: "唔買，淨係望，諗下將來想點佈置",
                 mood: "夢想", kaomoji: "(♡˙︶˙♡)", tint: .rose, cost: "$"),
        DateCard(id: 14, title: "整一餐情人節食物",
                 detail: "今晚煮個 valentine special，唔理乜日子",
                 mood: "浪漫", kaomoji: "(♡´︶`♡)", tint: .rose, cost: "$"),
        DateCard(id: 15, title: "去茶餐廳食 brunch",
                 detail: "揀間冇去過嘅，每人叫一個 set，分嚟食",
                 mood: "玩樂", kaomoji: "(っ˘ڡ˘ς)", tint: .amber, cost: "$"),
        DateCard(id: 16, title: "一齊去做運動",
                 detail: "踩單車／瑜珈／游水，揀一樣兩個都未試過",
                 mood: "玩樂", kaomoji: "(•̀ᴗ•́)و", tint: .sage, cost: "$"),
        DateCard(id: 17, title: "重做第一次 date",
                 detail: "去返第一次 date 嘅地方，影同樣 pose",
                 mood: "懷舊", kaomoji: "(´｡• ᵕ •｡`)", tint: .rose, cost: "$$"),
        DateCard(id: 18, title: "玩 board game café",
                 detail: "佐敦或太子，揀一隻冇玩過嘅",
                 mood: "玩樂", kaomoji: "(◕‿◕)", tint: .sage, cost: "$"),
        DateCard(id: 19, title: "睇夜場戲",
                 detail: "11pm 後嗰場，散場行返屋企",
                 mood: "靜", kaomoji: "(─‿─)", tint: .amber, cost: "$$"),
        DateCard(id: 20, title: "係屋企整 cocktail",
                 detail: "YouTube 學一隻新嘅，互相試味",
                 mood: "屋企", kaomoji: "(¬‿¬)", tint: .rose, cost: "$"),
        DateCard(id: 21, title: "做心理測驗",
                 detail: "搵一個 personality test，互相估對方答",
                 mood: "玩樂", kaomoji: "(≧▽≦)", tint: .amber, cost: "$"),
        DateCard(id: 22, title: "去石澤睇日落",
                 detail: "或者任何海邊，帶杯熱嘢飲",
                 mood: "浪漫", kaomoji: "(♡˙︶˙♡)", tint: .rose, cost: "$"),
        DateCard(id: 23, title: "一齊砌 LEGO",
                 detail: "買一套兩個一齊砌，邊砌邊吹水",
                 mood: "屋企", kaomoji: "(◍•ᴗ•◍)", tint: .amber, cost: "$$"),
        DateCard(id: 24, title: "寫一封情書畀對方",
                 detail: "10 分鐘 timer，唔可以 google，交換睇",
                 mood: "靜", kaomoji: "(´｡• ᵕ •｡`)", tint: .rose, cost: "$"),
    ]
}

enum QuizCatalog {
    static let all: [QuizQuestion] = [
        QuizQuestion(id: 1, question: "你最鍾意我邊度？",
                     kitAnswer: "你笑嗰陣眼仔彎彎",
                     michelAnswer: "你成日諗住其他人嘅心情"),
        QuizQuestion(id: 2, question: "我哋第一次去嘅餐廳叫乜？",
                     kitAnswer: "銅鑼灣嗰間意大利餐",
                     michelAnswer: "銅鑼灣嗰間意大利餐"),
        QuizQuestion(id: 3, question: "我最怕乜？",
                     kitAnswer: "蟑螂",
                     michelAnswer: "高度"),
    ]
}
