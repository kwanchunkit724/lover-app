// Phase-2 玩樂 flows + photo viewer + settings detail screens
const { Icon, PhotoPH, Avatar, Chip } = window.UI;
const D = window.AppData;

// ─────────────────────────────────────────────────────────────
// 抽卡 — date idea card draw (deck of 24)
// ─────────────────────────────────────────────────────────────
const DATE_CARDS = [
  { id: 1, title: '夜遊維港', detail: '搭天星小輪，喺甲板上面影返張合照', mood: '浪漫', kao: '(♡˙︶˙♡)', tint: 'rose', cost: '$$' },
  { id: 2, title: '一齊整 pancake', detail: '揀一個未試過嘅口味，最差嗰個負責洗碗', mood: '屋企', kao: '(っ˘ڡ˘ς)', tint: 'amber', cost: '$' },
  { id: 3, title: '影貼紙相', detail: '銅鑼灣或旺角，搞笑款 4 連張', mood: '玩樂', kao: '(≧▽≦)', tint: 'rose', cost: '$' },
  { id: 4, title: '行一條未行過嘅街', detail: 'Google Maps 隨機 drop pin，去最近嗰條', mood: '探險', kao: '(´｡• ω •｡`)', tint: 'sage', cost: '$' },
  { id: 5, title: '寫信俾未來自己', detail: '一年後拆，封住放入記憶簿', mood: '靜', kao: '(◍•ᴗ•◍)', tint: 'amber', cost: '$' },
  { id: 6, title: '盲交換禮物', detail: '$50 budget，30 分鐘內入便利店揀', mood: '玩樂', kao: '(¬‿¬)', tint: 'sage', cost: '$' },
];

function CardDeck({ theme, onBack }) {
  const [idx, setIdx] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [drawn, setDrawn] = useState([]);

  const draw = () => {
    setFlipped(true);
    setTimeout(() => {
      setDrawn([...drawn, DATE_CARDS[idx % DATE_CARDS.length].id]);
    }, 300);
  };
  const next = () => {
    setFlipped(false);
    setTimeout(() => setIdx(i => i + 1), 250);
  };

  const card = DATE_CARDS[idx % DATE_CARDS.length];
  const tintColor = card.tint === 'rose' ? theme.rose : card.tint === 'sage' ? theme.sage : theme.amber;
  const tintSoft = card.tint === 'rose' ? theme.roseSoft : card.tint === 'sage' ? theme.sageSoft : theme.amberSoft;

  return (
    <div style={{ background: theme.paper, height: '100%', display: 'flex', flexDirection: 'column', fontFamily: theme.fontUI }}>
      {/* Header */}
      <div style={{ padding: '4px 14px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={onBack} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
          <Icon name="back" size={22} color={theme.rose} strokeWidth={2.2}/>
        </button>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontWeight: 600, color: theme.ink, fontSize: 15 }}>盲盒約會</div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>
            {drawn.length}/24 張已抽
          </div>
        </div>
        <div style={{ width: 34 }}/>
      </div>

      {/* Card stack */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        {/* shadow cards behind */}
        {[2, 1].map(off => (
          <div key={off} style={{
            position: 'absolute', width: 240, height: 340, borderRadius: 22,
            background: theme.surface, border: `0.5px solid ${theme.line}`,
            transform: `translate(${off * 6}px, ${off * 6}px) rotate(${off * 1.5}deg)`,
            zIndex: 0, opacity: 0.6,
          }}/>
        ))}

        <div style={{
          width: 240, height: 340, borderRadius: 22,
          position: 'relative', perspective: 1000, zIndex: 5,
        }}>
          <div style={{
            width: '100%', height: '100%', position: 'relative',
            transformStyle: 'preserve-3d', transition: 'transform .6s cubic-bezier(.4,.2,.2,1)',
            transform: flipped ? 'rotateY(180deg)' : 'rotateY(0)',
          }}>
            {/* Card back */}
            <div style={{
              position: 'absolute', inset: 0, borderRadius: 22, backfaceVisibility: 'hidden',
              background: `linear-gradient(135deg, ${theme.rose}, ${theme.amber})`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 12px 32px rgba(216,139,130,0.25)',
            }}>
              <div style={{ textAlign: 'center', color: '#fff' }}>
                <div style={{ fontFamily: theme.fontMono, fontSize: 28 }}>(♡˙︶˙♡)</div>
                <div style={{ fontFamily: theme.fontHead, fontSize: 18, fontWeight: 600, marginTop: 8, letterSpacing: 0.5 }}>抽卡</div>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, marginTop: 4, opacity: 0.7, letterSpacing: 0.4 }}>TAP TO REVEAL</div>
              </div>
            </div>
            {/* Card front */}
            <div style={{
              position: 'absolute', inset: 0, borderRadius: 22, backfaceVisibility: 'hidden',
              background: theme.surface, border: `0.5px solid ${theme.line}`,
              transform: 'rotateY(180deg)', padding: 22,
              display: 'flex', flexDirection: 'column',
              boxShadow: '0 12px 32px rgba(0,0,0,0.08)',
            }}>
              <div style={{
                fontFamily: theme.fontMono, fontSize: 9, color: tintColor,
                letterSpacing: 0.5, fontWeight: 600,
              }}>#{String(card.id).padStart(3, '0')} · {card.mood}</div>
              <div style={{ fontFamily: theme.fontHead, fontSize: 22, fontWeight: 600, color: theme.ink, marginTop: 8, lineHeight: 1.25 }}>
                {card.title}
              </div>
              <div style={{ fontSize: 13, color: theme.inkSoft, marginTop: 10, lineHeight: 1.55, flex: 1 }}>
                {card.detail}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 12 }}>
                <span style={{ padding: '4px 8px', background: tintSoft, color: tintColor, borderRadius: 6, fontFamily: theme.fontMono, fontSize: 10, fontWeight: 600 }}>
                  {card.cost}
                </span>
                <span style={{ fontFamily: theme.fontMono, fontSize: 16, color: tintColor }}>{card.kao}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Buttons */}
      <div style={{ padding: '14px 20px 24px', display: 'flex', gap: 10 }}>
        {!flipped ? (
          <button onClick={draw} style={primaryBtn(theme)}>
            抽張卡 <span style={{ fontFamily: theme.fontMono, marginLeft: 4 }}>(◕‿◕)</span>
          </button>
        ) : (
          <>
            <button onClick={next} style={secondaryBtn(theme)}>再抽</button>
            <button style={primaryBtn(theme)}>加入時間表 →</button>
          </>
        )}
      </div>
    </div>
  );
}

const primaryBtn = (theme) => ({
  flex: 1, padding: 14, borderRadius: 14, background: theme.rose,
  color: '#fff', border: 'none', cursor: 'pointer',
  fontFamily: theme.fontUI, fontSize: 15, fontWeight: 600,
});
const secondaryBtn = (theme) => ({
  flex: 1, padding: 14, borderRadius: 14, background: theme.surface,
  color: theme.ink, border: `0.5px solid ${theme.line}`, cursor: 'pointer',
  fontFamily: theme.fontUI, fontSize: 15, fontWeight: 500,
});

// ─────────────────────────────────────────────────────────────
// 21 條問題 — quiz flow
// ─────────────────────────────────────────────────────────────
const QUIZ = [
  { q: '你最鍾意我邊度？', kit: '你笑嗰陣眼仔彎彎', michel: '你成日諗住其他人嘅心情' },
  { q: '我哋第一次去嘅餐廳叫乜？', kit: '銅鑼灣嗰間意大利餐', michel: '銅鑼灣嗰間意大利餐' },
  { q: '我最怕乜？', kit: '蟑螂', michel: '高度' },
];

function Quiz({ theme, onBack }) {
  const [step, setStep] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const cur = QUIZ[step];
  const matched = cur.kit === cur.michel;

  return (
    <div style={{ background: theme.paper, height: '100%', display: 'flex', flexDirection: 'column', fontFamily: theme.fontUI }}>
      <div style={{ padding: '4px 14px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={onBack} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
          <Icon name="back" size={22} color={theme.rose} strokeWidth={2.2}/>
        </button>
        <span style={{ fontWeight: 600, color: theme.ink, fontSize: 15 }}>21 條問題</span>
        <span style={{ fontFamily: theme.fontMono, fontSize: 12, color: theme.inkMuted, padding: 6 }}>
          {step + 1}/21
        </span>
      </div>

      {/* Progress */}
      <div style={{ padding: '0 20px 24px' }}>
        <div style={{ height: 4, background: theme.line, borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ width: `${((step + 1) / 21) * 100}%`, height: '100%', background: theme.rose, transition: 'width .3s' }}/>
        </div>
      </div>

      <div style={{ flex: 1, padding: '0 24px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.rose, letterSpacing: 0.5, fontWeight: 600 }}>
          QUESTION {String(step + 1).padStart(2, '0')}
        </div>
        <div style={{ fontFamily: theme.fontHead, fontSize: 26, fontWeight: 600, color: theme.ink, marginTop: 10, lineHeight: 1.35 }}>
          {cur.q}
        </div>

        {!revealed ? (
          <div style={{ marginTop: 'auto', marginBottom: 10 }}>
            <div style={{
              padding: '14px 16px', background: theme.surface, borderRadius: 14,
              border: `0.5px solid ${theme.line}`, marginBottom: 10,
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <Avatar person={D.ME} theme={theme} size={28}/>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.sage }}>KIT 已答 ✓</div>
                <div style={{ fontSize: 13, color: theme.inkMuted, marginTop: 2 }}>等緊 Michel…</div>
              </div>
            </div>
            <div style={{
              padding: '14px 16px', background: theme.surface, borderRadius: 14,
              border: `0.5px solid ${theme.line}`,
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <Avatar person={D.PARTNER} theme={theme} size={28}/>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.amber }}>MICHEL 答緊…</div>
                <div style={{ fontSize: 13, color: theme.inkSoft, marginTop: 2, fontFamily: theme.fontMono, display: 'flex', gap: 3 }}>
                  {[0, 1, 2].map(i => (
                    <div key={i} style={{ width: 5, height: 5, borderRadius: '50%', background: theme.amber, animation: `kit-bounce 1.4s ${i * 0.2}s infinite` }}/>
                  ))}
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div style={{ marginTop: 24 }}>
            {matched && (
              <div style={{
                padding: '8px 14px', background: theme.sageSoft, color: theme.sage,
                borderRadius: 999, fontFamily: theme.fontMono, fontSize: 11, fontWeight: 600,
                display: 'inline-block', marginBottom: 14, letterSpacing: 0.4,
              }}>
                ♡ 心有靈犀！
              </div>
            )}
            <AnswerCard theme={theme} person={D.ME} answer={cur.kit}/>
            <AnswerCard theme={theme} person={D.PARTNER} answer={cur.michel}/>
          </div>
        )}
      </div>

      <div style={{ padding: '14px 20px 24px' }}>
        {!revealed ? (
          <button onClick={() => setRevealed(true)} style={primaryBtn(theme)}>
            睇答案
          </button>
        ) : (
          <button onClick={() => { setRevealed(false); setStep((step + 1) % 21); }} style={primaryBtn(theme)}>
            下一條 →
          </button>
        )}
      </div>
    </div>
  );
}

function AnswerCard({ theme, person, answer }) {
  const tint = person.tint === 'rose' ? theme.rose : theme.sage;
  const tintSoft = person.tint === 'rose' ? theme.roseSoft : theme.sageSoft;
  return (
    <div style={{
      padding: '14px 16px', background: tintSoft, borderRadius: 14,
      marginBottom: 10, display: 'flex', gap: 12, alignItems: 'flex-start',
    }}>
      <Avatar person={person} theme={theme} size={32}/>
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: tint, fontWeight: 600 }}>{person.name.toUpperCase()}</div>
        <div style={{ fontSize: 14, color: theme.ink, marginTop: 4, lineHeight: 1.5 }}>{answer}</div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Photo viewer — full-screen overlay
// ─────────────────────────────────────────────────────────────
function PhotoViewer({ theme, photoId, onClose }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, background: '#000', zIndex: 300,
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{
        padding: '54px 16px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10,
        background: 'linear-gradient(rgba(0,0,0,0.5), transparent)',
      }}>
        <button onClick={onClose} style={{ background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: '50%', width: 36, height: 36, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="close" size={20} color="#fff"/>
        </button>
        <span style={{ color: '#fff', fontFamily: 'inherit', fontSize: 13 }}>1 / 7</span>
        <button style={{ background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: '50%', width: 36, height: 36, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="more" size={18} color="#fff"/>
        </button>
      </div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0 }}>
        <PhotoPH id={photoId} label={photoId} h={500} w="100%" rounded={0} theme={theme}/>
      </div>
      <div style={{
        padding: '16px 20px 36px', position: 'absolute', bottom: 0, left: 0, right: 0,
        background: 'linear-gradient(transparent, rgba(0,0,0,0.6))',
      }}>
        <div style={{ color: '#fff', fontSize: 13, fontFamily: 'inherit', opacity: 0.85 }}>
          5月 2 日 · 09:14
        </div>
        <div style={{ color: '#fff', fontSize: 14, fontFamily: 'inherit', marginTop: 4 }}>
          今朝嘅咖啡 ☕
        </div>
        <div style={{ display: 'flex', gap: 16, marginTop: 12, color: '#fff' }}>
          <button style={iconActionBtn()}><Icon name="heart" size={18} color="#fff"/></button>
          <button style={iconActionBtn()}><Icon name="reply" size={18} color="#fff"/></button>
          <button style={iconActionBtn()}><Icon name="book" size={18} color="#fff"/> <span style={{ fontSize: 11, marginLeft: 4 }}>存到記憶</span></button>
        </div>
      </div>
    </div>
  );
}
const iconActionBtn = () => ({
  background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: 999,
  padding: '8px 12px', cursor: 'pointer', color: '#fff',
  display: 'flex', alignItems: 'center', fontFamily: 'inherit',
});

// ─────────────────────────────────────────────────────────────
// Settings detail — kaomoji preference
// ─────────────────────────────────────────────────────────────
function KaoSettings({ theme, onBack }) {
  const [pref, setPref] = useState('jp');
  const [autoSuggest, setAutoSuggest] = useState(true);
  const styles = [
    { id: 'jp', label: '日系', sample: '(´｡• ω •｡`)', desc: '圓潤可愛，最常見' },
    { id: 'classic', label: '經典', sample: '(◕‿◕)', desc: '簡潔易讀' },
    { id: 'expressive', label: '誇張', sample: '＼(º □ º l|l)/', desc: '表情豐富' },
    { id: 'mixed', label: '混合', sample: 'ʕ•ᴥ•ʔ', desc: '咩都有' },
  ];
  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 30 }}>
      <div style={{ padding: '4px 14px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={onBack} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
          <Icon name="back" size={22} color={theme.rose} strokeWidth={2.2}/>
        </button>
        <span style={{ fontWeight: 600, color: theme.ink, fontSize: 17 }}>顏文字偏好</span>
      </div>
      <div style={{ padding: '0 20px' }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 10 }}>
          風格
        </div>
        <div style={{ background: theme.surface, borderRadius: 14, border: `0.5px solid ${theme.line}`, overflow: 'hidden' }}>
          {styles.map((s, i) => (
            <button key={s.id} onClick={() => setPref(s.id)} style={{
              width: '100%', padding: '14px 16px', background: pref === s.id ? theme.roseSoft : 'transparent',
              border: 'none', borderTop: i === 0 ? 'none' : `0.5px solid ${theme.line}`,
              cursor: 'pointer', textAlign: 'left',
              display: 'flex', alignItems: 'center', gap: 14,
            }}>
              <div style={{ fontFamily: theme.fontMono, fontSize: 16, color: theme.ink, minWidth: 80 }}>{s.sample}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, color: theme.ink, fontSize: 14 }}>{s.label}</div>
                <div style={{ fontSize: 11, color: theme.inkMuted, marginTop: 2 }}>{s.desc}</div>
              </div>
              {pref === s.id && <Icon name="check" size={18} color={theme.rose} strokeWidth={2.4}/>}
            </button>
          ))}
        </div>

        <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase', margin: '24px 0 10px' }}>
          選項
        </div>
        <div style={{ background: theme.surface, borderRadius: 14, border: `0.5px solid ${theme.line}`, overflow: 'hidden' }}>
          <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, color: theme.ink }}>智能建議</div>
              <div style={{ fontSize: 11, color: theme.inkMuted, marginTop: 2 }}>根據對話情緒推薦顏文字</div>
            </div>
            <button onClick={() => setAutoSuggest(!autoSuggest)} style={{
              width: 44, height: 26, borderRadius: 13, border: 'none', cursor: 'pointer',
              background: autoSuggest ? theme.rose : theme.lineStrong, position: 'relative',
            }}>
              <div style={{
                width: 22, height: 22, borderRadius: '50%', background: '#fff',
                position: 'absolute', top: 2, left: autoSuggest ? 20 : 2,
                transition: 'left .2s', boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
              }}/>
            </button>
          </div>
        </div>

        <div style={{
          marginTop: 20, padding: 14, background: theme.roseSoft, borderRadius: 14,
        }}>
          <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.rose, fontWeight: 600, marginBottom: 6 }}>預覽</div>
          <div style={{ fontSize: 14, color: theme.ink, lineHeight: 1.6 }}>
            早安 {styles.find(s => s.id === pref).sample} 今日好天 ☀
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Settings detail — theme picker
// ─────────────────────────────────────────────────────────────
function ThemeSettings({ theme, onBack }) {
  const [pick, setPick] = useState('jbeam');
  const themes = [
    { id: 'jbeam', label: '日系奶油', desc: '柔和玫瑰、圓潤字體', colors: ['#FBF4EE', '#D88B82', '#9CAB8B'] },
    { id: 'notion', label: 'Notion 暖紙', desc: '暖白底配黑墨字', colors: ['#FAF8F4', '#C97064', '#7B8A6E'] },
    { id: 'cozy', label: '深夜暖色', desc: '深色模式，陶土橙', colors: ['#1C1916', '#E89E8E', '#A8B89A'] },
  ];
  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 30 }}>
      <div style={{ padding: '4px 14px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={onBack} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
          <Icon name="back" size={22} color={theme.rose} strokeWidth={2.2}/>
        </button>
        <span style={{ fontWeight: 600, color: theme.ink, fontSize: 17 }}>主題</span>
      </div>
      <div style={{ padding: '0 20px' }}>
        {themes.map(t => (
          <button key={t.id} onClick={() => setPick(t.id)} style={{
            width: '100%', padding: 16, marginBottom: 10, borderRadius: 16,
            background: theme.surface, border: pick === t.id ? `1.5px solid ${theme.rose}` : `0.5px solid ${theme.line}`,
            cursor: 'pointer', textAlign: 'left',
            display: 'flex', alignItems: 'center', gap: 14,
          }}>
            {/* swatch */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {t.colors.map((c, i) => (
                <div key={i} style={{
                  width: 36, height: i === 0 ? 26 : 13,
                  background: c, borderRadius: i === 0 ? '8px 8px 0 0' : i === 2 ? '0 0 8px 8px' : 0,
                  border: c === '#FBF4EE' || c === '#FAF8F4' ? `0.5px solid ${theme.line}` : 'none',
                }}/>
              ))}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 600, color: theme.ink, fontSize: 15 }}>{t.label}</div>
              <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 3 }}>{t.desc}</div>
            </div>
            {pick === t.id && (
              <div style={{ width: 24, height: 24, borderRadius: '50%', background: theme.rose, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="check" size={14} color="#fff" strokeWidth={3}/>
              </div>
            )}
          </button>
        ))}

        <div style={{
          marginTop: 14, padding: '12px 14px', background: theme.amberSoft,
          fontFamily: theme.fontMono, fontSize: 11, color: theme.amber, borderRadius: 10,
        }}>
          ⚠ 主題會同步到 Michel 嘅手機
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Settings detail — anniversaries
// ─────────────────────────────────────────────────────────────
function Anniversaries({ theme, onBack }) {
  // Compute next occurrence + days for each anniversary, sort by soonest
  const items = D.anniversaries
    .map(a => ({ ...a, ...window.NextOccurrence(a) }))
    .sort((a, b) => a.days - b.days);
  const TODAY = D.TODAY_ISO;
  const WEEKDAYS = ['日','一','二','三','四','五','六'];

  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 30 }}>
      <div style={{ padding: '4px 14px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={onBack} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
            <Icon name="back" size={22} color={theme.rose} strokeWidth={2.2}/>
          </button>
          <span style={{ fontWeight: 600, color: theme.ink, fontSize: 17 }}>紀念日</span>
        </div>
        <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: theme.rose, fontSize: 18, fontWeight: 600, padding: 6 }}>＋</button>
      </div>

      {/* Hero — soonest */}
      <div style={{ padding: '0 20px 20px' }}>
        <div style={{
          padding: 20, borderRadius: 18, background: theme.rose, color: '#fff',
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ fontFamily: theme.fontMono, fontSize: 10, opacity: 0.8, letterSpacing: 0.5 }}>下一個 · 倒數中</div>
          <div style={{ fontFamily: theme.fontHead, fontSize: 22, fontWeight: 600, marginTop: 4 }}>
            {items[0].title}
          </div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 12, opacity: 0.85, marginTop: 4 }}>
            {items[0].iso} · 星期{WEEKDAYS[new Date(items[0].iso).getDay()]}
            {items[0].ordinal != null && items[0].ordinal > 0 && ` · 第 ${items[0].ordinal} 年`}
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 18 }}>
            <span style={{ fontFamily: theme.fontHead, fontSize: 56, fontWeight: 700, lineHeight: 1 }}>{items[0].days}</span>
            <span style={{ fontFamily: theme.fontMono, fontSize: 14, opacity: 0.9 }}>日後 ♡</span>
          </div>
          <div style={{ position: 'absolute', right: -20, bottom: -30, fontSize: 120, opacity: 0.12, lineHeight: 1, fontFamily: theme.fontMono }}>
            {items[0].emoji || '♡'}
          </div>
        </div>
      </div>

      <div style={{ padding: '0 20px' }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 10, paddingLeft: 4 }}>
          所有 · {items.length} 個
        </div>
        {items.slice(1).map(it => {
          const daysSinceBase = Math.round((new Date(TODAY) - new Date(it.baseDate)) / 86400000);
          return (
            <div key={it.id} style={{
              background: theme.surface, borderRadius: 14, padding: 14,
              border: `0.5px solid ${theme.line}`, marginBottom: 8,
              display: 'flex', alignItems: 'center', gap: 14,
            }}>
              <div style={{
                width: 48, height: 48, borderRadius: 12,
                background: theme.roseSoft,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 22, flexShrink: 0,
              }}>{it.emoji}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontWeight: 600, color: theme.ink, fontSize: 14 }}>{it.title}</span>
                  <span style={{
                    fontFamily: theme.fontMono, fontSize: 9, padding: '2px 6px', borderRadius: 4,
                    background: it.recur === 'monthly' ? theme.amberSoft : theme.sageSoft,
                    color: it.recur === 'monthly' ? theme.amber : theme.sage,
                    letterSpacing: 0.3, fontWeight: 600,
                  }}>
                    {it.recur === 'yearly' ? '每年' : '每月'}
                  </span>
                </div>
                <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, marginTop: 3 }}>
                  從 {it.baseDate} · 一齊 {daysSinceBase} 日
                </div>
              </div>
              <div style={{ textAlign: 'right', flexShrink: 0 }}>
                <div style={{ fontFamily: theme.fontHead, fontSize: 20, fontWeight: 600, color: theme.rose, lineHeight: 1 }}>
                  {it.days}
                </div>
                <div style={{ fontFamily: theme.fontMono, fontSize: 9, color: theme.inkMuted, letterSpacing: 0.3, marginTop: 2 }}>
                  日後
                </div>
              </div>
            </div>
          );
        })}

        <button style={{
          width: '100%', padding: 14, marginTop: 8, borderRadius: 14,
          border: `1px dashed ${theme.lineStrong}`, background: 'transparent',
          color: theme.inkMuted, fontFamily: theme.fontUI, fontSize: 13, cursor: 'pointer',
        }}>
          ＋ 加新紀念日
        </button>
      </div>
    </div>
  );
}

window.AppExtra = { CardDeck, Quiz, PhotoViewer, KaoSettings, ThemeSettings, Anniversaries };
