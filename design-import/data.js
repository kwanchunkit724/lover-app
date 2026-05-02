// Shared mock data for Kit & Michel's couples app
// All in 繁體中文 with kaomoji as the emotional layer

window.AppData = (() => {
  const KAOMOJI = {
    happy: ['(◕‿◕)', '(´｡• ω •｡`)', '(≧▽≦)', '(*≧ω≦*)', '(◍•ᴗ•◍)', '(｡•̀ᴗ-)✧', '(✿◕‿◕)', '(*ˊᗜˋ*)', 'ヽ(´▽`)/', '(っ´ω`c)'],
    love: ['(♡˙︶˙♡)', '(´♡‿♡`)', '(/▽＼*)｡o○♡', '♡(>ᴗ<)♡', '(˘∇˘)♡', '(„• ֊ •„)♡', '(*˘︶˘*).｡.:*♡', '(ෆˇᴗˇෆ)', '꒰⑅•ᴗ•⑅꒱♡', '(◍•ᴗ•◍)❤'],
    sad: ['(╥﹏╥)', '(´;ω;`)', '(っ˘̩╭╮˘̩)っ', '(｡•́︿•̀｡)', '(っ- ‸ - ς)', '(´；ω；`)', '(╯︵╰,)', '(ಥ﹏ಥ)'],
    silly: ['(￣ω￣)', '(¬‿¬)', '(￣▽￣)ノ', '( ͡° ͜ʖ ͡°)', '(；￢＿￢)', '(◔_◔)', '(¬､¬)', 'ᕙ(⇀‸↼‶)ᕗ'],
    surprise: ['(⊙_⊙)', '(°ロ°)', '(⊙o⊙)', '(*ﾟｪﾟ*)', '＼(º □ º l|l)/', '(゜o゜;'],
    sleep: ['(￣o￣) zzZ', '(-, – )…zzzZZ', '(´〜｀*) zzz', '(￣ρ￣)..zzZZ'],
    food: ['(っ˘ڡ˘ς)', '(*¯︶¯*)', '|･ω･`)○ ⊃─', '~(￣▽￣)~*'],
    dance: ['ヽ(•‿•)ノ', '٩(◕‿◕)۶', '＼(^o^)／', 'ヽ(´∇`)ﾉ', '٩(｡•́‿•̀｡)۶'],
    bear: ['ʕ•ᴥ•ʔ', 'ʕ◉ᴥ◉ʔ', 'ʕ•́ᴥ•̀ʔ', 'ʕ•͡-•ʔ', 'ʕ ﾟ●ﾟʔ'],
    cat: ['=^.^=', '(=ↀωↀ=)', '(=^･ω･^=)', '(^◔ᴥ◔^)', '(=｀ω´=)', '(=ᴗ͈ˬᴗ͈)'],
  };

  const KAO_CATEGORIES = [
    { id: 'recent', label: '最近' },
    { id: 'love', label: '愛意' },
    { id: 'happy', label: '開心' },
    { id: 'silly', label: '搞怪' },
    { id: 'sad', label: '失落' },
    { id: 'surprise', label: '驚訝' },
    { id: 'sleep', label: '睏' },
    { id: 'food', label: '食' },
    { id: 'dance', label: '跳舞' },
    { id: 'bear', label: '熊' },
    { id: 'cat', label: '貓' },
  ];

  const QUICK_REACT = ['(♡˙︶˙♡)', '(≧▽≦)', '(╥﹏╥)', '(¬‿¬)', '(⊙_⊙)', '(っ´ω`c)'];

  const ME = { id: 'kit', name: 'Kit', initial: 'K', tint: 'rose' };
  const PARTNER = { id: 'michel', name: 'Michel', initial: 'M', tint: 'sage' };

  // Single conversation — only with partner
  const messages = [
    { id: 1, from: 'michel', kind: 'text', text: '早安 (´｡• ω •｡`)', t: '08:42', read: true },
    { id: 2, from: 'michel', kind: 'text', text: '夢到我哋去咗京都食雪糕', t: '08:42', read: true },
    { id: 3, from: 'kit', kind: 'text', text: '(◕‿◕) 我都想去', t: '08:51', read: true },
    { id: 4, from: 'kit', kind: 'text', text: '今晚記得六點半西營盤地鐵口見', t: '08:51', read: true, reactions: [{ from: 'michel', kao: '(♡˙︶˙♡)' }] },
    { id: 5, from: 'michel', kind: 'photo', src: 'morning-coffee', caption: '今朝嘅咖啡 ☕', t: '09:14', read: true },
    { id: 6, from: 'kit', kind: 'text', text: '靚！你拉花越嚟越叻 (≧▽≦)', t: '09:16', read: true },
    { id: 7, from: 'michel', kind: 'voice', duration: 8, t: '12:30', read: true, transcript: '中午食緊嗰個沙律真係好食' },
    { id: 8, from: 'kit', kind: 'text', text: '哈哈我估到你會錄', t: '12:32', read: true,
      replyTo: { id: 7, kind: 'voice', preview: '0:08 語音訊息' } },
    { id: 9, from: 'michel', kind: 'text', text: '六點半見 (´♡‿♡`)', t: '17:58', read: true },
    { id: 10, from: 'kit', kind: 'text', text: '行緊嚟', t: '18:24', read: false },
  ];

  const today = new Date(2026, 4, 2); // May 2, 2026
  const TODAY_ISO = '2026-05-02';

  // ─── ENTRIES — the heart of the app ───
  // Every entry has a lifecycle: 'upcoming' (reminder) → 'past' (memory)
  // Past entries can be enriched: photos, reflections, location, who suggested
  // The same shape works for both Timetable and 記憶簿 — they're filtered views of one list
  const entries = [
    // ── UPCOMING ── (reminders)
    {
      id: 'e_today1', date: '2026-05-02', time: '18:30',
      title: '西營盤食晚飯', loc: 'Bistro 1968',
      proposedBy: 'kit', who: 'both', tag: '食',
      status: 'upcoming',
      notes: '記得訂位 · 我之前 mark 咗想試',
      reminded: true,
    },
    {
      id: 'e_today2', date: '2026-05-02', time: '21:00',
      title: '睇戲：Past Lives', loc: 'Broadway Cinema',
      proposedBy: 'michel', who: 'both', tag: '出遊',
      status: 'upcoming',
    },
    {
      id: 'e_w1', date: '2026-05-04', time: '14:00',
      title: 'Michel 牙醫', proposedBy: 'michel', who: 'michel',
      tag: 'solo', status: 'upcoming',
    },
    {
      id: 'e_w2', date: '2026-05-07', time: '19:30',
      title: '行山：龍脊', loc: '石澳',
      proposedBy: 'kit', who: 'both', tag: '出遊',
      status: 'upcoming',
      notes: '帶水同零食',
    },
    {
      id: 'e_anniv', date: '2026-05-22', time: '19:00',
      title: '我哋兩週年 ♡', loc: 'TBD',
      proposedBy: 'both', who: 'both', tag: '特別日子',
      status: 'upcoming', special: true,
      notes: '兩個人一齊諗去邊',
    },

    // ── PAST · ENRICHED with memory data ──
    {
      id: 'm_recent', date: '2026-05-01', time: '19:00',
      title: '屋企煮意粉',
      proposedBy: 'kit', who: 'both', tag: '屋企',
      loc: '我哋屋企',
      status: 'past',
      photos: 5,
      voiceClips: 0,
      messages: 28,
      reflection: { from: 'kit', text: '你話我落鹽落多咗 (¬‿¬) 但係你食晒成碟', kao: '(っ´ω`c)' },
      kao: '(っ˘ڡ˘ς)',
      cover: 'pasta',
    },
    {
      id: 'm1', date: '2026-04-26', time: '15:00',
      title: '荔枝角散步',
      proposedBy: 'michel', who: 'both', tag: '散步',
      loc: '荔枝角公園',
      status: 'past',
      photos: 4,
      voiceClips: 1,
      messages: 23,
      reflection: { from: 'michel', text: '個日好曬但係陽光好靚', kao: '(´｡• ω •｡`)' },
      kao: '(´｡• ω •｡`)',
      cover: 'walk',
    },
    {
      id: 'm2', date: '2026-04-19', time: '20:00',
      title: '第一次煮意粉',
      proposedBy: 'both', who: 'both', tag: '屋企',
      loc: '我哋屋企',
      status: 'past',
      photos: 7, messages: 41,
      reflection: { from: 'kit', text: '燒燶咗少少但係好開心 — Michel 話下次佢嚟煮', kao: '(*ˊᗜˋ*)' },
      kao: '(っ˘ڡ˘ς)',
      cover: 'pasta-first',
    },
    {
      id: 'm3', date: '2026-04-12', time: '10:30',
      title: '南丫島一日遊',
      proposedBy: 'kit', who: 'both', tag: '出遊',
      loc: '南丫島',
      status: 'past',
      photos: 12, voiceClips: 3, messages: 67,
      reflection: { from: 'michel', text: '搭船嗰陣風好大，你頭髮好亂但好得意 (´♡‿♡`)', kao: '(≧▽≦)' },
      kao: '(≧▽≦)',
      cover: 'lamma',
      featured: true,
    },
    {
      id: 'm4', date: '2026-04-05', time: '19:00',
      title: 'Michel 生日會',
      proposedBy: 'kit', who: 'both', tag: '特別日子',
      loc: '我哋屋企',
      status: 'past',
      photos: 9, messages: 102,
      reflection: { from: 'kit', text: 'Surprise 成功，你喊咗 — 我都喊埋', kao: '(♡˙︶˙♡)' },
      kao: '(♡˙︶˙♡)',
      cover: 'birthday',
    },

    // ── 一年前嘅今日 (回望 surface anchor) ──
    {
      id: 'mly', date: '2025-05-02', time: '14:00',
      title: '第一次去你屋企見家姐',
      proposedBy: 'michel', who: 'both', tag: '特別日子',
      loc: 'Michel 屋企',
      status: 'past',
      photos: 6, messages: 38,
      reflection: { from: 'kit', text: '我緊張到食唔落飯，家姐話我好乖', kao: '(´；ω；`)' },
      kao: '(´｡• ω •｡`)',
      cover: 'family',
      onThisDay: true, // surfaces in 回望
    },

    // ── More past entries to populate the month grid ──
    { id: 'm5', date: '2026-04-29', title: '街市買餸', tag: '屋企', proposedBy: 'kit', who: 'both', status: 'past', photos: 2, messages: 12, cover: 'market', kao: '(´｡• ᵕ •｡`)' },
    { id: 'm6', date: '2026-04-27', title: '夜晚散步', tag: '散步', proposedBy: 'michel', who: 'both', status: 'past', photos: 3, messages: 8, cover: 'night', kao: '(˘ω˘)' },
    { id: 'm7', date: '2026-04-22', title: '週年月誌 ♡', tag: '特別日子', proposedBy: 'both', who: 'both', status: 'past', photos: 4, messages: 22, cover: 'monthly', special: true, kao: '(♡˙︶˙♡)' },
    { id: 'm8', date: '2026-04-17', title: '茶餐廳食 lunch', tag: '食', proposedBy: 'kit', who: 'both', status: 'past', photos: 1, messages: 5, cover: 'cha', kao: '(っ˘ڡ˘ς)' },
    { id: 'm9', date: '2026-04-15', title: '揀盆栽', tag: '出遊', proposedBy: 'michel', who: 'both', status: 'past', photos: 5, messages: 19, cover: 'plants', kao: '(´｡• ω •｡`)' },
    { id: 'm10', date: '2026-04-09', title: '睇日落 @ 西環', tag: '散步', proposedBy: 'kit', who: 'both', status: 'past', photos: 6, messages: 15, cover: 'sunset', featured: true, kao: '(◕‿◕)' },
    { id: 'm11', date: '2026-04-02', title: '咖啡店打 work', tag: '出遊', proposedBy: 'michel', who: 'both', status: 'past', photos: 2, messages: 7, cover: 'cafe', kao: '(˘ω˘)' },
  ];

  // ─── ANNIVERSARIES ── recurring + countdown
  // Computed from a base date with a recurrence rule
  const anniversaries = [
    {
      id: 'an1', title: '我哋一齊嘅日子', baseDate: '2024-05-22',
      recur: 'yearly', kao: '(♡˙︶˙♡)', emoji: '♡',
      // 2 years on 2026-05-22 — 20 days from today
    },
    {
      id: 'an2', title: '第一次見面', baseDate: '2023-11-08',
      recur: 'yearly', kao: '(´｡• ω •｡`)', emoji: '☕',
    },
    {
      id: 'an3', title: '搬入嚟一齊住', baseDate: '2025-09-14',
      recur: 'yearly', kao: '(´♡‿♡`)', emoji: '🏠',
    },
    {
      id: 'an4', title: '每月 22 號', baseDate: '2024-05-22',
      recur: 'monthly', kao: '(˘∇˘)♡', emoji: '♡',
      subtitle: '月誌',
    },
    {
      id: 'an5', title: 'Michel 生日', baseDate: '1996-04-05',
      recur: 'yearly', kao: '(≧▽≦)', emoji: '🎂',
    },
    {
      id: 'an6', title: 'Kit 生日', baseDate: '1997-08-19',
      recur: 'yearly', kao: '(*ˊᗜˋ*)', emoji: '🎂',
    },
  ];

  const activities = [
    { id: 'a1', title: '盲盒約會', subtitle: '抽一張卡，跟住做', kind: 'cards', count: 24 },
    { id: 'a2', title: '21 條問題', subtitle: '了解多啲對方', kind: 'quiz', count: 21 },
    { id: 'a3', title: '香港探險地圖', subtitle: '一齊去未去過嘅地方', kind: 'map', count: 18 },
    { id: 'a4', title: '今晚煮乜', subtitle: '隨機菜譜', kind: 'cards', count: 36 },
    { id: 'a5', title: '情侶小測驗', subtitle: '你有幾了解 Michel？', kind: 'quiz', count: 10 },
    { id: 'a6', title: '感激清單', subtitle: '每日寫一樣', kind: 'journal' },
  ];

  return {
    KAOMOJI, KAO_CATEGORIES, QUICK_REACT,
    ME, PARTNER,
    messages,
    entries, anniversaries, activities,
    today, TODAY_ISO,
  };
})();
