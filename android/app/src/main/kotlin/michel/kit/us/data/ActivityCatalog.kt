package michel.kit.us.data

import androidx.compose.runtime.Immutable

/**
 * Port of ios/LoverApp/Core/Catalogs.swift — static feature catalogs.
 *
 * These are FEATURE DEFINITIONS (activity types, date cards, quiz questions)
 * that ship with the app, not user data. Mirrors the iOS field names exactly
 * so the wire / UI can be cross-checked.
 */
@Immutable
data class CatalogActivity(
    val id: String,
    val title: String,
    val subtitle: String,
    val kind: Kind,
    val count: Int?
) {
    enum class Kind { cards, quiz, map, journal, districts, mtr }
}

@Immutable
data class DateCard(
    val id: Int,
    val title: String,
    val detail: String,
    val mood: String,
    val kaomoji: String,
    val tint: Tint,
    val cost: String
) {
    enum class Tint { rose, sage, amber }
}

@Immutable
data class QuizQuestion(
    val id: Int,
    val question: String,
    val kitAnswer: String,
    val michelAnswer: String
) {
    val matched: Boolean get() = kitAnswer == michelAnswer
}

object ActivityCatalog {
    val all: List<CatalogActivity> = listOf(
        CatalogActivity("a1", "盲盒約會", "抽一張卡，跟住做", CatalogActivity.Kind.cards, 24),
        CatalogActivity("a2", "21 條問題", "了解多啲對方", CatalogActivity.Kind.quiz, 21),
        CatalogActivity("a3", "18 區日記", "一齊行勻香港，一區一篇", CatalogActivity.Kind.districts, 18),
        CatalogActivity("a4", "MTR 站日記", "一齊搭遍 MTR，一站一篇", CatalogActivity.Kind.mtr, 90),
    )
}

object DateCardCatalog {
    val all: List<DateCard> = listOf(
        DateCard(1, "夜遊維港", "搭天星小輪，喺甲板上面影返張合照", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$"),
        DateCard(2, "一齊整 pancake", "揀一個未試過嘅口味，最差嗰個負責洗碗", "屋企", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(3, "影貼紙相", "銅鑼灣或旺角，搞笑款 4 連張", "玩樂", "(≧▽≦)", DateCard.Tint.rose, "$"),
        DateCard(4, "行一條未行過嘅街", "Google Maps 隨機 drop pin，去最近嗰條", "探險", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(5, "寫信俾未來自己", "一年後拆，封住放入記憶簿", "靜", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$"),
        DateCard(6, "盲交換禮物", "\$50 budget，30 分鐘內入便利店揀", "玩樂", "(¬‿¬)", DateCard.Tint.sage, "$"),
        DateCard(7, "搭叮叮一程", "上層頭排，由筲箕灣坐去堅尼地城", "懷舊", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(8, "夜晚行山睇夜景", "獅子山或大潭，記得帶電筒", "探險", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$"),
        DateCard(9, "一齊煲劇 marathon", "揀一套兩個都未睇過嘅，一晚煲完", "屋企", "(─‿─)", DateCard.Tint.amber, "$"),
        DateCard(10, "去街市買餸", "唔講食乜，望住有咩買咩，返屋企 freestyle", "屋企", "(￣ω￣)", DateCard.Tint.amber, "$"),
        DateCard(11, "影黑白菲林", "買一筒可棄菲林，行半日，影晒佢", "靜", "(◍•ᴗ•◍)", DateCard.Tint.rose, "$$"),
        DateCard(12, "去離島放空", "南丫、長洲、坪洲，揀一個冇去過", "靜", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(13, "去 IKEA 諗將來層樓", "唔買，淨係望，諗下將來想點佈置", "夢想", "(♡˙︶˙♡)", DateCard.Tint.rose, "$"),
        DateCard(14, "整一餐情人節食物", "今晚煮個 valentine special，唔理乜日子", "浪漫", "(♡´︶`♡)", DateCard.Tint.rose, "$"),
        DateCard(15, "去茶餐廳食 brunch", "揀間冇去過嘅，每人叫一個 set，分嚟食", "玩樂", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(16, "一齊去做運動", "踩單車／瑜珈／游水，揀一樣兩個都未試過", "玩樂", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$"),
        DateCard(17, "重做第一次 date", "去返第一次 date 嘅地方，影同樣 pose", "懷舊", "(´｡• ᵕ •｡`)", DateCard.Tint.rose, "$$"),
        DateCard(18, "玩 board game café", "佐敦或太子，揀一隻冇玩過嘅", "玩樂", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(19, "睇夜場戲", "11pm 後嗰場，散場行返屋企", "靜", "(─‿─)", DateCard.Tint.amber, "$$"),
        DateCard(20, "係屋企整 cocktail", "YouTube 學一隻新嘅，互相試味", "屋企", "(¬‿¬)", DateCard.Tint.rose, "$"),
        DateCard(21, "做心理測驗", "搵一個 personality test，互相估對方答", "玩樂", "(≧▽≦)", DateCard.Tint.amber, "$"),
        DateCard(22, "去石澤睇日落", "或者任何海邊，帶杯熱嘢飲", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$"),
        DateCard(23, "一齊砌 LEGO", "買一套兩個一齊砌，邊砌邊吹水", "屋企", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$$"),
        DateCard(24, "寫一封情書畀對方", "10 分鐘 timer，唔可以 google，交換睇", "靜", "(´｡• ᵕ •｡`)", DateCard.Tint.rose, "$"),
    )
}

object QuizCatalog {
    val all: List<QuizQuestion> = listOf(
        QuizQuestion(1, "你最鍾意我邊度？", "你笑嗰陣眼仔彎彎", "你成日諗住其他人嘅心情"),
        QuizQuestion(2, "我哋第一次去嘅餐廳叫乜？", "銅鑼灣嗰間意大利餐", "銅鑼灣嗰間意大利餐"),
        QuizQuestion(3, "我最怕乜？", "蟑螂", "高度"),
    )
}
