package michel.kit.us.data

import androidx.compose.runtime.Immutable

/**
 * Port of ios/LoverApp/Core/Catalogs.swift — static feature catalogs.
 *
 * These are FEATURE DEFINITIONS (activity types, date cards, quiz questions)
 * that ship with the app, not user data. Mirrors the iOS field names exactly
 * so the wire / UI can be cross-checked.
 *
 * v1.6.0 — date card pool expanded to 120 HK-rooted ideas. Vibes:
 * 浪漫 / 屋企 / 玩樂 / 探險 / 食 / 文化 / 影相 / 慢活 / 學嘢 / 懷舊 / 靜 / 夢想.
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
        CatalogActivity("a1", "盲盒約會", "抽一張卡，跟住做", CatalogActivity.Kind.cards, 120),
        CatalogActivity("a2", "21 條問題", "了解多啲對方", CatalogActivity.Kind.quiz, 21),
        CatalogActivity("a3", "18 區日記", "一齊行勻香港，一區一篇", CatalogActivity.Kind.districts, 18),
        CatalogActivity("a4", "MTR 站日記", "一齊搭遍 MTR，一站一篇", CatalogActivity.Kind.mtr, 90),
    )
}

object DateCardCatalog {
    val all: List<DateCard> = listOf(
        // ── 浪漫 ──
        DateCard(1, "夜遊維港", "搭天星小輪，喺甲板上面影返張合照", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$"),
        DateCard(2, "太平山頂睇夜景", "唔搭纜車，搭巴士上山，行盧吉道一個圈", "浪漫", "(♡´︶`♡)", DateCard.Tint.rose, "$"),
        DateCard(3, "中環摩天輪", "黃昏嗰場，一卡兩個人，影 360 度", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$"),
        DateCard(4, "西環泳棚日落", "黃昏前到，等天色變紫，影一張剪影", "浪漫", "(´｡• ᵕ •｡`) ♡", DateCard.Tint.rose, "$"),
        DateCard(5, "石澳睇日落", "海邊石灘，帶杯熱嘢飲坐到天黑", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$"),
        DateCard(6, "維港遊船 dinner cruise", "揀個有 buffet 嘅，食住睇煙花碼頭", "浪漫", "(♡´︶`♡)", DateCard.Tint.rose, "$$$"),
        DateCard(7, "山頂纜車黃昏一程", "唔上頂，淨係坐個來回，影沿途光線", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$"),
        DateCard(8, "尖沙咀海濱散步", "由文化中心行去星光大道，8 點睇幻彩詠香江", "浪漫", "(´｡• ᵕ •｡`)", DateCard.Tint.rose, "$"),
        DateCard(9, "香港仔避風塘食艇仔", "搭舢舨入避風塘，叫一隻艇仔粉一齊食", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$"),
        DateCard(10, "整一餐情人節食物", "今晚煮個 valentine special，唔理乜日子", "浪漫", "(♡´︶`♡)", DateCard.Tint.rose, "$"),
        DateCard(11, "寫一封情書畀對方", "10 分鐘 timer，唔可以 google，交換睇", "浪漫", "(´｡• ᵕ •｡`) ♡", DateCard.Tint.rose, "$"),
        DateCard(12, "Skybar 雞尾酒", "中環或尖沙咀 rooftop，揀杯顏色靚嘅", "浪漫", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$$"),

        // ── 屋企 ──
        DateCard(13, "一齊整 pancake", "揀一個未試過嘅口味，最差嗰個負責洗碗", "屋企", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(14, "一齊煲劇 marathon", "揀一套兩個都未睇過嘅，一晚煲完", "屋企", "(─‿─)", DateCard.Tint.amber, "$"),
        DateCard(15, "係屋企整 cocktail", "YouTube 學一隻新嘅，互相試味", "屋企", "(¬‿¬)", DateCard.Tint.rose, "$"),
        DateCard(16, "一齊砌 LEGO", "買一套兩個一齊砌，邊砌邊吹水", "屋企", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$$"),
        DateCard(17, "共做窩夫早餐", "周日早上慢慢整，配 cold brew 或熱茶", "屋企", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(18, "屋企 movie night", "搭帳篷喺廳，買爆谷，揀套經典戲", "屋企", "(◕‿◕)", DateCard.Tint.amber, "$"),
        DateCard(19, "一齊砌 puzzle", "買 500 塊嘅，邊砌邊聽 playlist", "屋企", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$"),
        DateCard(20, "煮韓式部隊鍋", "去 City'super 買齊料，火鍋慢慢食", "屋企", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$$"),
        DateCard(21, "屋企 spa night", "敷面膜、開精油、聽 lo-fi，互相按頭", "屋企", "(˘ω˘)", DateCard.Tint.rose, "$"),
        DateCard(22, "一齊整壽司卷", "買米同紫菜，自己搵料，邊整邊食", "屋企", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(23, "煲老火湯", "落街市買藥材，慢火煲 3 個鐘", "屋企", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$"),
        DateCard(24, "一齊煲 K-drama", "揀一套兩個都聽到推薦嘅，唔好劇透", "屋企", "(─‿─)", DateCard.Tint.amber, "$"),
        DateCard(25, "整 ramen 比賽", "各人整一碗，對方評分，輸嗰個洗碗", "屋企", "(¬‿¬)", DateCard.Tint.amber, "$"),

        // ── 玩樂 ──
        DateCard(26, "影貼紙相", "銅鑼灣或旺角，搞笑款 4 連張", "玩樂", "(≧▽≦)", DateCard.Tint.rose, "$"),
        DateCard(27, "盲交換禮物", "\$50 budget，30 分鐘內入便利店揀", "玩樂", "(¬‿¬)", DateCard.Tint.sage, "$"),
        DateCard(28, "去茶餐廳食 brunch", "揀間冇去過嘅，每人叫一個 set，分嚟食", "玩樂", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(29, "一齊去做運動", "踩單車／瑜珈／游水，揀一樣兩個都未試過", "玩樂", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$"),
        DateCard(30, "玩 board game café", "佐敦或太子，揀一隻冇玩過嘅", "玩樂", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(31, "做心理測驗", "搵一個 personality test，互相估對方答", "玩樂", "(≧▽≦)", DateCard.Tint.amber, "$"),
        DateCard(32, "KTV 包房", "中午 happy hour 時段，唱足 3 個鐘", "玩樂", "(≧▽≦)", DateCard.Tint.rose, "$$"),
        DateCard(33, "Escape Room 走出旺角", "揀一個中等難度，60 分鐘出唔到再諗計", "玩樂", "(¬‿¬)", DateCard.Tint.sage, "$$"),
        DateCard(34, "Bowling 二人賽", "輸嗰個請食晚飯，三局決勝", "玩樂", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(35, "室內攀岩 JCC", "新手 wall 都好玩，輪流 belay", "玩樂", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$$"),
        DateCard(36, "ICE skating Mega Box", "揀平日下晝，人少又凍", "玩樂", "(≧▽≦)", DateCard.Tint.sage, "$$"),
        DateCard(37, "Mini golf 沙田", "18 個洞，當散步又當比賽", "玩樂", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(38, "Trampoline park", "BounceInc 觀塘，跳到出汗", "玩樂", "(≧▽≦)", DateCard.Tint.sage, "$$"),
        DateCard(39, "夾公仔大挑戰", "旺角信和或荷里活，\$100 limit", "玩樂", "(¬‿¬)", DateCard.Tint.rose, "$"),
        DateCard(40, "桌球室一場", "新手亦可，輸嗰個唱一首歌", "玩樂", "(◕‿◕)", DateCard.Tint.sage, "$"),

        // ── 探險 ──
        DateCard(41, "行一條未行過嘅街", "Google Maps 隨機 drop pin，去最近嗰條", "探險", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(42, "夜晚行山睇夜景", "獅子山或大潭，記得帶電筒", "探險", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$"),
        DateCard(43, "龍脊日落", "由土地灣行入，3 個鐘搞掂", "探險", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$"),
        DateCard(44, "西貢獨木舟", "白沙灣或半月灣，租兩個鐘", "探險", "(≧▽≦)", DateCard.Tint.sage, "$$"),
        DateCard(45, "鹽田仔尋墟", "西貢搭船入，行客家村落", "探險", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(46, "香港地質公園", "東平洲一日遊，睇千層糕岩石", "探險", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(47, "大澳食艇仔粉", "搭巴士入，行棚屋，順便睇白海豚", "探險", "(っ˘ڡ˘ς)", DateCard.Tint.sage, "$"),
        DateCard(48, "嘉道理農場睇動物", "大埔出發，行勻成個園 5 個鐘", "探險", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(49, "麥理浩徑第二段", "西灣到鹹田，影千古浪潮", "探險", "(•̀ᴗ•́)و", DateCard.Tint.sage, "$"),
        DateCard(50, "塔門紮營", "黃石碼頭搭船入，星空無敵", "探險", "(✧ω✧)", DateCard.Tint.sage, "$$"),
        DateCard(51, "夜遊鯉魚門", "賞夜景＋食海鮮，揀條街市旁邊嘅", "探險", "(´｡• ω •｡`)", DateCard.Tint.sage, "$$"),

        // ── 食 ──
        DateCard(52, "深水埗街頭小食巡禮", "由福榮街行到鴨寮街，每檔試一樣", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(53, "天后廟街宵夜大排檔", "凌晨先去，叫煲仔飯同椒鹽鮮魷", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$$"),
        DateCard(54, "米芝蓮車仔麵盲試", "揀 3 間有得獎嘅，逐間試打分", "食", "(¬‿¬)", DateCard.Tint.amber, "$$"),
        DateCard(55, "去街市買餸", "唔講食乜，望住有咩買咩，返屋企 freestyle", "食", "(￣ω￣)", DateCard.Tint.amber, "$"),
        DateCard(56, "灣仔早茶", "龍門大酒樓嗰類，叫蝦餃燒賣鳳爪", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$$"),
        DateCard(57, "九龍城泰國菜街", "城南道隨便揀一間，叫冬蔭功＋椰青", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$$"),
        DateCard(58, "西貢海鮮街", "揀條魚請廚房代煮，加碟蒜蓉炒菜", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$$$"),
        DateCard(59, "上環日式居酒屋", "Hidden 嗰啲，叫熱清酒＋串燒拼盤", "食", "(´◔౪◔)", DateCard.Tint.amber, "$$"),
        DateCard(60, "甜品大會", "一晚跑 3 間糖水鋪，每人揀一樣", "食", "(っ˘ڡ˘ς)", DateCard.Tint.rose, "$$"),
        DateCard(61, "牛雜車仔", "搵間排隊嗰啲，企住食", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(62, "本土微醺酒吧", "卑利街或太子，揀杯試新調酒", "食", "(¬‿¬)", DateCard.Tint.rose, "$$"),
        DateCard(63, "蛋撻馬拉松", "由泰昌行到檀島，比較邊間最香", "食", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$"),
        DateCard(64, "Omakase 一次", "\$1k 以下都有，揀 lunch set 較抵", "食", "(´｡• ᵕ •｡`)", DateCard.Tint.amber, "$$$"),

        // ── 文化 ──
        DateCard(65, "M+ 睇展", "揀個 special exhibition，行 3 個鐘", "文化", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(66, "PMQ 文青週末", "上去睇手作 pop-up，順便食 cafe", "文化", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(67, "灣仔藍屋導覽", "預約唐樓 tour，了解戰前歷史", "文化", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(68, "大館睇 art", "中環 Tai Kwun，加埋 cafe 食 scone", "文化", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(69, "Tai Kwun book fair", "週末市集，揀本中古書送對方", "文化", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(70, "香港藝術館", "尖沙咀，揀個香港藝術家展覽", "文化", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(71, "歷史博物館", "尖沙咀，行香港故事常設展", "文化", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(72, "獨立電影 Broadway", "油麻地電影中心，揀套冷門法國片", "文化", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$$"),
        DateCard(73, "西九戲曲中心", "茶館劇場，新手粵劇入門", "文化", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(74, "灣仔藝術中心", "睇場 indie 音樂表演", "文化", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$$"),

        // ── 影相 ──
        DateCard(75, "影黑白菲林", "買一筒可棄菲林，行半日，影晒佢", "影相", "(◍•ᴗ•◍)", DateCard.Tint.rose, "$$"),
        DateCard(76, "中環半山扶手電梯街拍", "由德輔道行到士丹頓街，捕捉街景", "影相", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(77, "油麻地果欄夜景", "凌晨 2 點開檔，霓虹同紙皮箱好出片", "影相", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(78, "彩虹邨幾何打卡", "唐樓對稱構圖，配波鞋色", "影相", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(79, "中環怪獸大廈", "鰂魚涌益昌大廈，仰拍密集恐懼", "影相", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(80, "西營盤龍虎山日出", "5 點起身，行松林廢堡睇晨曦", "影相", "(✧ω✧)", DateCard.Tint.sage, "$"),
        DateCard(81, "上環海味街掃街", "德輔道西，影乾貨同老店招牌", "影相", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(82, "石硤尾賽馬會創意藝術中心", "Jockey Club 工作室開放日打卡", "影相", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(83, "深水埗大南街 cafe hop", "3 間 cafe 各影 1 角，砌成 IG 9 宮格", "影相", "(◍•ᴗ•◍)", DateCard.Tint.rose, "$$"),

        // ── 慢活 ──
        DateCard(84, "海濱長廊踩單車", "沙田到大埔，租一日，中途食魚蛋", "慢活", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(85, "太空館圓頂戲院", "睇場 dome show，躺住睇星空", "慢活", "(˘ω˘)", DateCard.Tint.sage, "$"),
        DateCard(86, "北角電車一程", "頭排上層，由屈地街坐到筲箕灣", "慢活", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(87, "搭叮叮一程", "上層頭排，由筲箕灣坐去堅尼地城", "慢活", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(88, "去離島放空", "南丫、長洲、坪洲，揀一個冇去過", "慢活", "(´｡• ω •｡`)", DateCard.Tint.sage, "$"),
        DateCard(89, "九龍公園野餐", "Pacific Coffee 買三文治，鋪布坐草地", "慢活", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(90, "獨立書店 reading time", "見山或蒲窩，揀本書讀一個鐘", "慢活", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(91, "南區海洋公園纜車", "唔玩機動，淨係坐纜車睇南區海岸", "慢活", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(92, "Cafe 慢工夫沖咖啡", "灣仔 NOC 嗰類，叫 hand drip + 朱古力多士", "慢活", "(˘ω˘)", DateCard.Tint.amber, "$$"),
        DateCard(93, "公園做瑜珈", "維園或迪欣湖，YouTube 跟 20 分鐘 flow", "慢活", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),

        // ── 學嘢 ──
        DateCard(94, "學做廣式月餅", "中秋前班，整完帶返屋企送家人", "學嘢", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$$"),
        DateCard(95, "Cocktail 調酒班", "2 個鐘整 3 杯，加埋食物 pairing", "學嘢", "(¬‿¬)", DateCard.Tint.rose, "$$"),
        DateCard(96, "一齊學跳 Salsa", "中環有試堂班，1 小時學基本步", "學嘢", "(✧ω✧)", DateCard.Tint.rose, "$$"),
        DateCard(97, "Pottery 工作坊", "上水或柴灣，整對 mug 互送", "學嘢", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$$"),
        DateCard(98, "整對銀戒指", "尖沙咀 metalsmith 班，2 個鐘整一對", "學嘢", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$$"),
        DateCard(99, "Latte art 班", "Cupping Room 嗰類，學拉心同葉", "學嘢", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$$"),
        DateCard(100, "捏陶笛工作坊", "完場一人一個，玩到識吹首歌", "學嘢", "(◕‿◕)", DateCard.Tint.sage, "$$"),
        DateCard(101, "韓國菜班", "學整辣炒年糕＋韓式煎餅，現場食", "學嘢", "(っ˘ڡ˘ς)", DateCard.Tint.amber, "$$"),
        DateCard(102, "侍酒師入門課", "中環 wine school，試 6 款紅白酒", "學嘢", "(¬‿¬)", DateCard.Tint.rose, "$$$"),
        DateCard(103, "Calligraphy 班", "中環書法室，學行書，寫一句送對方", "學嘢", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$$"),

        // ── 懷舊 ──
        DateCard(104, "重做第一次 date", "去返第一次 date 嘅地方，影同樣 pose", "懷舊", "(´｡• ᵕ •｡`)", DateCard.Tint.rose, "$$"),
        DateCard(105, "去鴨寮街掃懷舊嘢", "搵錄音帶、菲林機，買到當回禮", "懷舊", "(◕‿◕)", DateCard.Tint.sage, "$"),
        DateCard(106, "睇舊戲院", "油麻地 Broadway，揀部 80 年代港產片", "懷舊", "(´｡• ω •｡`)", DateCard.Tint.amber, "$$"),
        DateCard(107, "西九 graffiti wall", "影返廿年前舊香港 vibe", "懷舊", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(108, "茶記點對唱嘅歌", "搵間有點唱嘅，點 90s 廣東歌", "懷舊", "(◕‿◕)", DateCard.Tint.amber, "$"),
        DateCard(109, "再食一次第一餐 date 嘅嘢", "重現 menu，連飲品都要一樣", "懷舊", "(♡˙︶˙♡)", DateCard.Tint.rose, "$$"),

        // ── 靜 ──
        DateCard(110, "寫信俾未來自己", "一年後拆，封住放入記憶簿", "靜", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$"),
        DateCard(111, "睇夜場戲", "11pm 後嗰場，散場行返屋企", "靜", "(─‿─)", DateCard.Tint.amber, "$$"),
        DateCard(112, "聽 vinyl 一晚", "去 White Noise 揀張舊唱片，返屋企播", "靜", "(˘ω˘)", DateCard.Tint.amber, "$$"),
        DateCard(113, "去 Cafe 各做各嘢", "你睇書我畫畫，唔出聲 2 個鐘", "靜", "(◍•ᴗ•◍)", DateCard.Tint.sage, "$"),
        DateCard(114, "公園睇書一晝", "帶 1 本書 1 杯咖啡，攤喺草地", "靜", "(˘ω˘)", DateCard.Tint.sage, "$"),
        DateCard(115, "屋企 candlelight dinner", "閂晒燈，點蠟燭，食簡單嘅意粉", "靜", "(♡˙︶˙♡)", DateCard.Tint.rose, "$"),
        DateCard(116, "去廟拜一拜", "黃大仙或文武廟，求籤解籤", "靜", "(◕‿◕)", DateCard.Tint.sage, "$"),

        // ── 夢想 ──
        DateCard(117, "去 IKEA 諗將來層樓", "唔買，淨係望，諗下將來想點佈置", "夢想", "(♡˙︶˙♡)", DateCard.Tint.rose, "$"),
        DateCard(118, "睇 show flat", "假裝買樓，行 2 個示範單位", "夢想", "(◕‿◕)", DateCard.Tint.rose, "$"),
        DateCard(119, "畫一齊住屋企嘅 floor plan", "Cafe 攤紙筆畫，每人輪流加一樣", "夢想", "(◍•ᴗ•◍)", DateCard.Tint.amber, "$"),
        DateCard(120, "做一個 5 年 bucket list", "各寫 10 樣想一齊做嘅，逐樣 cross 出", "夢想", "(✧ω✧)", DateCard.Tint.rose, "$"),
    )
}

object QuizCatalog {
    val all: List<QuizQuestion> = listOf(
        QuizQuestion(1, "你最鍾意我邊度？", "你笑嗰陣眼仔彎彎", "你成日諗住其他人嘅心情"),
        QuizQuestion(2, "我哋第一次去嘅餐廳叫乜？", "銅鑼灣嗰間意大利餐", "銅鑼灣嗰間意大利餐"),
        QuizQuestion(3, "我最怕乜？", "蟑螂", "高度"),
    )
}
