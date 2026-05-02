// Timetable, Memory, Activities, Profile, Onboarding — rebuilt around the entry lifecycle
// One entry has two phases: 'upcoming' (reminder) → 'past' (memory)
// Past entries get enriched with photos, reflections, location, who suggested

const { Icon, PhotoPH, Avatar, Chip } = window.UI;
const D = window.AppData;
const TODAY = D.TODAY_ISO; // '2026-05-02'

// ── helpers ──────────────────────────────────────────────────
const WEEKDAYS = ['日','一','二','三','四','五','六'];
const MONTHS_TC = ['一月','二月','三月','四月','五月','六月','七月','八月','九月','十月','十一月','十二月'];

function fmtMD(iso) {
  const [, m, d] = iso.split('-').map(Number);
  return `${m}.${d}`;
}
function fmtFull(iso) {
  const dt = new Date(iso);
  return `${dt.getFullYear()} · ${MONTHS_TC[dt.getMonth()]} ${dt.getDate()} 日 · 星期${WEEKDAYS[dt.getDay()]}`;
}
function daysBetween(a, b) {
  return Math.round((new Date(b) - new Date(a)) / 86400000);
}
function whoLabel(who) {
  if (who === 'both') return '我哋';
  if (who === 'kit') return 'Kit';
  if (who === 'michel') return 'Michel';
  return who;
}
function tagColor(theme, tag) {
  if (tag === '特別日子') return theme.rose;
  if (tag === '出遊') return theme.sage;
  if (tag === '食') return theme.amber;
  if (tag === '屋企') return theme.amber;
  if (tag === '散步') return theme.sage;
  if (tag === 'solo') return theme.inkMuted;
  return theme.inkSoft;
}

// Compute next anniversary occurrence + days until
function nextOccurrence(an, todayIso = TODAY) {
  const today = new Date(todayIso);
  const base = new Date(an.baseDate);
  let next;
  if (an.recur === 'yearly') {
    next = new Date(today.getFullYear(), base.getMonth(), base.getDate());
    if (next < today) next = new Date(today.getFullYear() + 1, base.getMonth(), base.getDate());
  } else if (an.recur === 'monthly') {
    next = new Date(today.getFullYear(), today.getMonth(), base.getDate());
    if (next < today) next = new Date(today.getFullYear(), today.getMonth() + 1, base.getDate());
  }
  const days = Math.round((next - today) / 86400000);
  const yearsSinceBase = next.getFullYear() - base.getFullYear();
  const ordinal = an.recur === 'yearly' ? yearsSinceBase : null;
  // Format locally to avoid TZ shift from toISOString
  const iso = `${next.getFullYear()}-${String(next.getMonth() + 1).padStart(2, '0')}-${String(next.getDate()).padStart(2, '0')}`;
  return { iso, days, ordinal };
}

// Common section primitives
const Section = ({ theme, title, accessory, children, gap = true }) => (
  <div style={{ marginBottom: gap ? 22 : 0 }}>
    {title && (
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 8, paddingLeft: 4 }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, textTransform: 'uppercase', letterSpacing: 0.5 }}>
          {title}
        </div>
        {accessory}
      </div>
    )}
    <div style={{ background: theme.surface, borderRadius: 14, border: `0.5px solid ${theme.line}`, overflow: 'hidden' }}>
      {children}
    </div>
  </div>
);
const Row = ({ theme, icon, label, value, subtle, onClick }) => (
  <div onClick={onClick} style={{
    padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
    borderBottom: `0.5px solid ${theme.line}`, cursor: onClick ? 'pointer' : 'default',
  }}>
    {icon && <Icon name={icon} size={16} color={theme.inkMuted}/>}
    <span style={{ flex: 1, fontSize: 14, color: theme.ink }}>{label}</span>
    <span style={{ fontFamily: theme.fontMono, fontSize: 13, color: subtle ? theme.inkMuted : theme.inkSoft }}>{value}</span>
  </div>
);
const Toggle = ({ theme, on, onChange }) => (
  <button onClick={() => onChange(!on)} style={{
    width: 44, height: 26, borderRadius: 13, border: 'none', cursor: 'pointer',
    background: on ? theme.rose : theme.lineStrong, position: 'relative', transition: 'background .2s',
  }}>
    <div style={{
      width: 22, height: 22, borderRadius: '50%', background: '#fff',
      position: 'absolute', top: 2, left: on ? 20 : 2,
      transition: 'left .2s', boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
    }}/>
  </button>
);

// ─────────────────────────────────────────────────────────────
// TIMETABLE — unified month grid combining reminders + memories
// Past days show their photo; today is highlighted; future days show event titles
// Tap any day → detail; tap an entry → entry detail
// ─────────────────────────────────────────────────────────────
function Timetable({ theme, onAddEvent, onOpenEntry }) {
  const [viewMonth, setViewMonth] = useState({ y: 2026, m: 4 }); // May 2026 (0-indexed)
  const [selected, setSelected] = useState(TODAY);

  const monthName = MONTHS_TC[viewMonth.m];
  const firstDay = new Date(viewMonth.y, viewMonth.m, 1).getDay(); // 0 = Sun
  const daysInMonth = new Date(viewMonth.y, viewMonth.m + 1, 0).getDate();
  const todayDate = new Date(TODAY);
  const isViewingCurrentMonth = viewMonth.y === todayDate.getFullYear() && viewMonth.m === todayDate.getMonth();

  // Build cells
  const cells = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  while (cells.length % 7) cells.push(null);

  const dateForCell = (d) => `${viewMonth.y}-${String(viewMonth.m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  const entriesForDate = (iso) => D.entries.filter(e => e.date === iso);

  const selectedEntries = entriesForDate(selected);
  const selectedDate = new Date(selected);
  const selectedIsPast = selected < TODAY;
  const selectedIsToday = selected === TODAY;

  // Next anniversary for the spotlight ribbon
  const anniv = D.anniversaries
    .map(a => ({ ...a, ...nextOccurrence(a) }))
    .sort((a, b) => a.days - b.days)[0];

  // Counts for header
  const monthEntries = D.entries.filter(e => e.date.startsWith(`${viewMonth.y}-${String(viewMonth.m + 1).padStart(2, '0')}`));
  const memoriesCount = monthEntries.filter(e => e.status === 'past').length;
  const upcomingCount = monthEntries.filter(e => e.status === 'upcoming').length;

  const goPrevMonth = () => setViewMonth(({ y, m }) => m === 0 ? { y: y - 1, m: 11 } : { y, m: m - 1 });
  const goNextMonth = () => setViewMonth(({ y, m }) => m === 11 ? { y: y + 1, m: 0 } : { y, m: m + 1 });

  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 28 }}>
      {/* Anniversary ribbon — only on current month */}
      {isViewingCurrentMonth && (
        <div style={{ padding: '8px 16px 12px' }}>
          <div style={{
            padding: '12px 14px', borderRadius: 14, background: theme.rose, color: '#fff',
            display: 'flex', alignItems: 'center', gap: 10, position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: theme.fontMono, fontSize: 10, opacity: 0.85, letterSpacing: 0.4 }}>下一個紀念日</div>
              <div style={{ fontFamily: theme.fontHead, fontSize: 15, fontWeight: 600, marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {anniv.title}
                {anniv.ordinal != null && anniv.ordinal > 0 && <span style={{ fontWeight: 400, opacity: 0.85 }}> · 第 {anniv.ordinal} 年</span>}
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: theme.fontHead, fontSize: 30, fontWeight: 700, lineHeight: 1 }}>{anniv.days}</div>
              <div style={{ fontFamily: theme.fontMono, fontSize: 9, opacity: 0.85 }}>日後</div>
            </div>
            <div style={{ position: 'absolute', right: -4, bottom: -8, fontFamily: theme.fontMono, fontSize: 44, opacity: 0.12, lineHeight: 1 }}>♡</div>
          </div>
        </div>
      )}

      {/* Month switcher */}
      <div style={{ padding: '6px 16px 10px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <button onClick={goPrevMonth} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: theme.inkSoft, fontFamily: theme.fontMono, fontSize: 16 }}>‹</button>
          <div>
            <div style={{ fontFamily: theme.fontHead, fontSize: 24, fontWeight: 600, color: theme.ink, letterSpacing: -0.3, lineHeight: 1.1 }}>
              {viewMonth.y} {monthName}
            </div>
            <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, marginTop: 3, letterSpacing: 0.3 }}>
              {memoriesCount} 個記憶 · {upcomingCount} 個提醒
            </div>
          </div>
          <button onClick={goNextMonth} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: theme.inkSoft, fontFamily: theme.fontMono, fontSize: 16 }}>›</button>
        </div>
        <button onClick={onAddEvent} aria-label="加" style={{
          width: 34, height: 34, borderRadius: '50%', background: theme.rose,
          border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexShrink: 0,
        }}>
          <Icon name="plus" size={18} color="#fff" strokeWidth={2.4}/>
        </button>
      </div>

      {/* Day-of-week header */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', padding: '0 8px',
        fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted,
        textAlign: 'center', marginBottom: 4, letterSpacing: 0.5,
      }}>
        {['日', '一', '二', '三', '四', '五', '六'].map(d => <div key={d} style={{ padding: '4px 0' }}>{d}</div>)}
      </div>

      {/* Month grid — square cells */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', padding: '0 8px', gap: 3,
      }}>
        {cells.map((d, i) => {
          if (!d) return <div key={i} style={{ aspectRatio: '1' }}/>;
          const iso = dateForCell(d);
          const evs = entriesForDate(iso);
          const past = evs.find(e => e.status === 'past');
          const upcoming = evs.filter(e => e.status === 'upcoming');
          const isToday = iso === TODAY;
          const isSel = iso === selected;
          const isFuture = iso > TODAY;
          const isPastEmpty = iso < TODAY && !past;

          return (
            <button key={i} onClick={() => setSelected(iso)} style={{
              aspectRatio: '1', border: 'none', cursor: 'pointer', borderRadius: 8,
              background: 'transparent', padding: 0, position: 'relative', overflow: 'hidden',
              outline: isSel ? `2px solid ${theme.rose}` : 'none', outlineOffset: -1,
            }}>
              {/* Past with memory: photo fill */}
              {past ? (
                <div style={{ position: 'absolute', inset: 0, borderRadius: 8, overflow: 'hidden' }}>
                  <PhotoPH id={past.cover || past.id} h="100%" w="100%" rounded={8} theme={theme}/>
                  {/* dark overlay for legibility */}
                  <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.05) 0%, rgba(0,0,0,0) 40%, rgba(0,0,0,0.55) 100%)' }}/>
                  {/* day number top-left */}
                  <span style={{
                    position: 'absolute', top: 4, left: 5,
                    fontFamily: theme.fontMono, fontSize: 11, fontWeight: 700, color: '#fff',
                    textShadow: '0 1px 2px rgba(0,0,0,0.4)',
                  }}>{d}</span>
                  {past.special && (
                    <span style={{ position: 'absolute', top: 4, right: 5, fontSize: 10, color: '#fff' }}>♡</span>
                  )}
                  {/* photo count chip */}
                  {past.photos > 0 && (
                    <span style={{
                      position: 'absolute', bottom: 3, right: 4,
                      fontFamily: theme.fontMono, fontSize: 8, color: '#fff',
                      background: 'rgba(0,0,0,0.4)', padding: '1px 4px', borderRadius: 4,
                      letterSpacing: 0.2,
                    }}>{past.photos}</span>
                  )}
                </div>
              ) : (
                // Empty / today / upcoming cell
                <div style={{
                  position: 'absolute', inset: 0, borderRadius: 8,
                  background: isToday ? theme.rose : isPastEmpty ? 'transparent' : theme.surface,
                  border: isPastEmpty ? `0.5px dashed ${theme.line}` : `0.5px solid ${theme.line}`,
                  display: 'flex', flexDirection: 'column', padding: '5px 5px 4px',
                }}>
                  <div style={{
                    fontFamily: theme.fontMono, fontSize: 11, fontWeight: isToday ? 700 : 500,
                    color: isToday ? '#fff' : isPastEmpty ? theme.inkMuted : theme.ink,
                  }}>{d}</div>
                  {/* upcoming entries: tiny labels */}
                  <div style={{ flex: 1, marginTop: 2, display: 'flex', flexDirection: 'column', gap: 2, overflow: 'hidden' }}>
                    {upcoming.slice(0, 2).map(e => {
                      const c = tagColor(theme, e.tag);
                      return (
                        <div key={e.id} style={{
                          fontFamily: theme.fontUI, fontSize: 8, lineHeight: 1.15,
                          color: isToday ? '#fff' : c,
                          background: isToday ? 'rgba(255,255,255,0.22)' : c + '1f',
                          padding: '1px 3px', borderRadius: 3,
                          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                          fontWeight: 500,
                        }}>
                          {e.special ? '♡ ' : ''}{e.title}
                        </div>
                      );
                    })}
                    {upcoming.length > 2 && (
                      <div style={{ fontFamily: theme.fontMono, fontSize: 8, color: isToday ? 'rgba(255,255,255,0.8)' : theme.inkMuted }}>
                        +{upcoming.length - 2}
                      </div>
                    )}
                  </div>
                </div>
              )}
            </button>
          );
        })}
      </div>

      {/* Selected day detail */}
      <div style={{ padding: '20px 16px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 10, paddingLeft: 4 }}>
          <span style={{ fontFamily: theme.fontHead, fontSize: 18, fontWeight: 600, color: theme.ink }}>
            {selectedIsToday ? '今日' : selectedIsPast ? '回望' : '將至'}
          </span>
          <span style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, letterSpacing: 0.3 }}>
            {fmtMD(selected)} · 星期{WEEKDAYS[selectedDate.getDay()]}
            {selectedEntries.length > 0 && ` · ${selectedEntries.length} 件事`}
          </span>
        </div>

        {selectedEntries.length === 0 ? (
          <div style={{
            padding: 24, textAlign: 'center', border: `1px dashed ${theme.lineStrong}`,
            borderRadius: 14, color: theme.inkMuted, fontSize: 13,
          }}>
            {selectedIsPast ? '呢日冇記低嘢' : selectedIsToday ? 'tap "+" 加件事' : '冇活動'}
            <div style={{ fontFamily: theme.fontMono, fontSize: 16, marginTop: 8, color: theme.inkSoft }}>
              {selectedIsPast ? '(´｡• ω •｡`)' : '＿(:3 」∠)＿'}
            </div>
          </div>
        ) : (
          selectedEntries.map(e => (
            e.status === 'past' ? (
              <PastEntryRow key={e.id} entry={e} theme={theme} onClick={() => onOpenEntry && onOpenEntry(e.id)}/>
            ) : (
              <UpcomingCard key={e.id} entry={e} theme={theme} onClick={() => onOpenEntry && onOpenEntry(e.id)} hero={selectedIsToday}/>
            )
          ))
        )}
      </div>

      {/* 一年前嘅今日 — surface only on TODAY */}
      {selectedIsToday && (() => {
        const lookbacks = D.entries.filter(e => {
          if (e.status !== 'past') return false;
          const d = new Date(e.date), t = new Date(TODAY);
          return d.getMonth() === t.getMonth() && d.getDate() === t.getDate() && d.getFullYear() < t.getFullYear();
        });
        if (lookbacks.length === 0) return null;
        return (
          <div style={{ padding: '24px 16px 0' }}>
            <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.rose, letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 10, paddingLeft: 4, fontWeight: 600 }}>
              ⌛ 一年前嘅今日
            </div>
            {lookbacks.map(m => {
              const yr = new Date(TODAY).getFullYear() - new Date(m.date).getFullYear();
              return (
                <div key={m.id} onClick={() => onOpenEntry && onOpenEntry(m.id)} style={{
                  padding: 12, borderRadius: 14, cursor: 'pointer',
                  background: `linear-gradient(135deg, ${theme.roseSoft} 0%, ${theme.amberSoft} 100%)`,
                  border: `0.5px solid ${theme.rose}33`,
                  display: 'flex', gap: 10,
                }}>
                  <PhotoPH id={m.cover} h={72} w={72} rounded={10} theme={theme}/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.rose, fontWeight: 600, letterSpacing: 0.4 }}>
                      {yr} 年前
                    </div>
                    <div style={{ fontFamily: theme.fontHead, fontSize: 16, fontWeight: 600, color: theme.ink, marginTop: 2 }}>
                      {m.title}
                    </div>
                    {m.reflection && (
                      <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 4, lineHeight: 1.45,
                        display: '-webkit-box', WebkitBoxOrient: 'vertical', WebkitLineClamp: 2, overflow: 'hidden' }}>
                        "{m.reflection.text}"
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        );
      })()}
    </div>
  );
}

// Compact past-entry row for the day detail panel
function PastEntryRow({ entry, theme, onClick }) {
  return (
    <div onClick={onClick} style={{
      background: theme.surface, borderRadius: 14, padding: 12,
      border: `0.5px solid ${theme.line}`,
      marginBottom: 8, display: 'flex', gap: 12, cursor: 'pointer', alignItems: 'center',
    }}>
      <PhotoPH id={entry.cover} h={64} w={64} rounded={10} theme={theme}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{
            fontFamily: theme.fontMono, fontSize: 9, padding: '2px 6px', borderRadius: 4,
            background: theme.sageSoft, color: theme.sage, letterSpacing: 0.3, fontWeight: 600,
          }}>已發生</span>
          <span style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted }}>{entry.time}</span>
        </div>
        <div style={{ fontFamily: theme.fontHead, fontWeight: 600, fontSize: 15, color: theme.ink, marginTop: 4 }}>
          {entry.title}
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 4, fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>
          <span>📷 {entry.photos}</span>
          {entry.voiceClips > 0 && <span>🎙 {entry.voiceClips}</span>}
          <span>💬 {entry.messages}</span>
        </div>
      </div>
    </div>
  );
}

// Reminder card — for upcoming entries
function UpcomingCard({ entry, theme, onClick, hero }) {
  const c = tagColor(theme, entry.tag);
  const proposer = entry.proposedBy === 'kit' ? D.ME
    : entry.proposedBy === 'michel' ? D.PARTNER : null;
  const proposerLabel = entry.proposedBy === 'both' ? '一齊諗' : `${proposer.name} 提議`;

  return (
    <div onClick={onClick} style={{
      background: theme.surface, borderRadius: 14, padding: hero ? 16 : 12,
      border: `0.5px solid ${theme.line}`,
      marginBottom: 8, display: 'flex', gap: 12, cursor: 'pointer',
      boxShadow: hero ? `0 1px 3px rgba(0,0,0,0.04)` : 'none',
    }}>
      <div style={{
        width: 4, alignSelf: 'stretch', background: c, borderRadius: 2, flexShrink: 0,
      }}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8 }}>
          <span style={{ fontWeight: 600, color: theme.ink, fontSize: hero ? 17 : 15 }}>
            {entry.title} {entry.special && '♡'}
          </span>
          <span style={{ fontFamily: theme.fontMono, fontSize: 12, color: theme.inkSoft, flexShrink: 0 }}>
            {entry.time}
          </span>
        </div>
        {entry.loc && (
          <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 4, display: 'flex', alignItems: 'center', gap: 4 }}>
            <Icon name="pin2" size={10} color={theme.inkMuted}/> {entry.loc}
          </div>
        )}
        {entry.notes && hero && (
          <div style={{
            marginTop: 8, padding: '6px 10px', background: theme.roseSoft, borderRadius: 8,
            fontSize: 12, color: theme.ink, fontFamily: theme.fontUI,
          }}>
            📝 {entry.notes}
          </div>
        )}
        <div style={{ marginTop: hero ? 10 : 6, display: 'flex', alignItems: 'center', gap: 8 }}>
          {entry.who === 'both' ? (
            <>
              <div style={{ display: 'flex' }}>
                <Avatar person={D.PARTNER} theme={theme} size={18}/>
                <div style={{ marginLeft: -6 }}><Avatar person={D.ME} theme={theme} size={18}/></div>
              </div>
              <span style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>我哋兩個 · {proposerLabel}</span>
            </>
          ) : (
            <>
              <Avatar person={entry.who === 'kit' ? D.ME : D.PARTNER} theme={theme} size={18}/>
              <span style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>
                只係 {whoLabel(entry.who)}
              </span>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ENTRY DETAIL — same screen for upcoming & past, behaviour differs
// ─────────────────────────────────────────────────────────────
function EntryDetail({ theme, id, onBack, onPhoto }) {
  const entry = D.entries.find(e => e.id === id) || D.entries[5];
  const isPast = entry.status === 'past';

  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI }}>
      {/* Top bar */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10, padding: '4px 14px 8px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: theme.nav, backdropFilter: 'blur(20px)',
      }}>
        <button onClick={onBack} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
          <Icon name="back" size={22} color={theme.rose} strokeWidth={2.2}/>
        </button>
        <span style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, letterSpacing: 0.3 }}>
          {isPast ? '記憶' : '提醒'}
        </span>
        <button style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 6 }}>
          <Icon name="more" size={22} color={theme.inkSoft}/>
        </button>
      </div>

      {isPast && entry.cover && (
        <PhotoPH id={entry.cover} label={entry.cover} h={240} rounded={0} theme={theme}/>
      )}

      <div style={{ padding: '20px 20px 30px' }}>
        {/* Status pill */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
          <span style={{
            fontFamily: theme.fontMono, fontSize: 10, letterSpacing: 0.5,
            padding: '3px 8px', borderRadius: 999,
            background: isPast ? theme.sageSoft : theme.roseSoft,
            color: isPast ? theme.sage : theme.rose,
          }}>
            {isPast ? '已發生 · 記憶' : '未發生 · 提醒'}
          </span>
          {entry.tag && entry.tag !== 'solo' && (
            <span style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>＃{entry.tag}</span>
          )}
        </div>

        <div style={{ fontFamily: theme.fontHead, fontSize: 28, fontWeight: 600, color: theme.ink, letterSpacing: -0.3, lineHeight: 1.2 }}>
          {entry.title} {entry.special && '♡'}
        </div>
        <div style={{ fontFamily: theme.fontMono, fontSize: 12, color: theme.inkMuted, marginTop: 6, letterSpacing: 0.3 }}>
          {fmtFull(entry.date)} · {entry.time}
        </div>

        {/* Meta row */}
        <div style={{ display: 'flex', gap: 14, marginTop: 14, paddingTop: 14, borderTop: `0.5px solid ${theme.line}` }}>
          <Meta theme={theme} icon="pin2" label={entry.loc || '冇地點'}/>
          <Meta theme={theme} icon="us"
            label={entry.who === 'both' ? '我哋兩個' : `只係 ${whoLabel(entry.who)}`}/>
        </div>
        <div style={{ marginTop: 8, fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted }}>
          {entry.proposedBy === 'both' ? '一齊諗到' :
           entry.proposedBy === 'kit' ? 'Kit 提議' : 'Michel 提議'}
        </div>

        {/* UPCOMING — reminder mode */}
        {!isPast && (
          <>
            {entry.notes && (
              <Section theme={theme} title="筆記">
                <div style={{ padding: 14, fontSize: 14, color: theme.ink, lineHeight: 1.6 }}>
                  📝 {entry.notes}
                </div>
              </Section>
            )}
            <Section theme={theme} title="提醒">
              <Row theme={theme} icon="clock" label="提前提醒" value="1 個鐘前"/>
              <Row theme={theme} icon="heart" label="過咗存做記憶" value="開"/>
            </Section>

            <div style={{
              marginTop: 18, padding: 14, background: theme.amberSoft, borderRadius: 14,
              fontSize: 13, color: theme.ink, lineHeight: 1.55,
            }}>
              <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.amber, fontWeight: 600, marginBottom: 6, letterSpacing: 0.5 }}>
                過咗之後 ⤵
              </div>
              呢個提醒會自動變成記憶。當日嘅相片、語音、對話會自動結集喺度。你可以後補感想、地點。
            </div>
          </>
        )}

        {/* PAST — memory mode */}
        {isPast && (
          <>
            {/* Reflection */}
            {entry.reflection && (
              <div style={{
                marginTop: 18, padding: 14, background: theme.roseSoft, borderRadius: 14,
              }}>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.rose, fontWeight: 600, marginBottom: 6, letterSpacing: 0.5 }}>
                  {entry.reflection.from === 'kit' ? 'KIT' : 'MICHEL'} 寫低
                </div>
                <div style={{ fontSize: 14, color: theme.ink, lineHeight: 1.6 }}>
                  {entry.reflection.text}
                </div>
                {entry.reflection.kao && (
                  <div style={{ fontFamily: theme.fontMono, fontSize: 16, color: theme.rose, marginTop: 8 }}>
                    {entry.reflection.kao}
                  </div>
                )}
              </div>
            )}

            {/* Add other-person reflection prompt */}
            {entry.reflection && entry.reflection.from === 'kit' && (
              <button style={{
                marginTop: 8, width: '100%', padding: 12, borderRadius: 12,
                border: `1px dashed ${theme.lineStrong}`, background: 'transparent',
                color: theme.inkMuted, fontFamily: theme.fontUI, fontSize: 13, cursor: 'pointer',
              }}>
                ＋ Michel 仲未寫感想
              </button>
            )}

            {/* Photos */}
            {entry.photos > 0 && (
              <>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase', margin: '24px 0 10px', paddingLeft: 4 }}>
                  相片 · {entry.photos} 張
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 4 }}>
                  {Array.from({ length: Math.min(entry.photos, 6) }).map((_, i) => (
                    <div key={i} onClick={() => onPhoto && onPhoto(`${entry.id}-p${i}`)} style={{ cursor: 'pointer' }}>
                      <PhotoPH id={`${entry.id}-p${i}`} h={100} rounded={6} theme={theme}/>
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Voice */}
            {entry.voiceClips > 0 && (
              <>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase', margin: '24px 0 10px', paddingLeft: 4 }}>
                  語音 · {entry.voiceClips} 段
                </div>
                <div style={{ background: theme.surface, padding: 12, borderRadius: 14, border: `0.5px solid ${theme.line}`, display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 36, height: 36, borderRadius: '50%', background: theme.roseSoft, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name="play2" size={14} color={theme.rose}/>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, color: theme.ink }}>當日嘅笑聲</div>
                    <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>0:14</div>
                  </div>
                </div>
              </>
            )}

            {/* Messages excerpt */}
            {entry.messages > 0 && (
              <>
                <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase', margin: '24px 0 10px', paddingLeft: 4 }}>
                  當日對話 · {entry.messages} 條
                </div>
                <div style={{ background: theme.surface, padding: 14, borderRadius: 14, border: `0.5px solid ${theme.line}`, fontSize: 13, color: theme.inkSoft, lineHeight: 1.7 }}>
                  <div><b style={{ color: theme.rose }}>Michel:</b> 而家行緊嚟 (´｡• ω •｡`)</div>
                  <div><b style={{ color: theme.sage }}>Kit:</b> 慢慢嚟，我等你</div>
                  <div style={{ color: theme.inkMuted, fontSize: 11, marginTop: 8 }}>… 仲有 {entry.messages - 2} 條</div>
                </div>
              </>
            )}

            {/* Add more */}
            <div style={{ display: 'flex', gap: 8, marginTop: 20 }}>
              <SmallChip theme={theme} icon="image">＋ 加相</SmallChip>
              <SmallChip theme={theme} icon="edit">＋ 補感想</SmallChip>
              <SmallChip theme={theme} icon="pin2">＋ 地點</SmallChip>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

const Meta = ({ theme, icon, label }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: theme.inkSoft }}>
    <Icon name={icon} size={12} color={theme.inkMuted}/> {label}
  </div>
);
const SmallChip = ({ theme, icon, children }) => (
  <button style={{
    flex: 1, padding: '10px 8px', borderRadius: 12,
    border: `1px dashed ${theme.lineStrong}`, background: 'transparent',
    color: theme.inkSoft, fontFamily: theme.fontUI, fontSize: 12, cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
  }}>{children}</button>
);

// ─────────────────────────────────────────────────────────────
// MEMORY — focuses on PAST entries + 回望 surface
// ─────────────────────────────────────────────────────────────
function MemoryFeed({ theme, onOpen }) {
  const [tag, setTag] = useState('all');

  const past = D.entries.filter(e => e.status === 'past');
  // 回望 — entries from this day in past years
  const onThisDay = past.filter(e => e.onThisDay || (() => {
    const d = new Date(e.date), t = new Date(TODAY);
    return d.getMonth() === t.getMonth() && d.getDate() === t.getDate() && d.getFullYear() < t.getFullYear();
  })());

  // Filter
  const filtered = tag === 'all' ? past : past.filter(m => m.tag === tag);
  // Sort newest first
  filtered.sort((a, b) => b.date.localeCompare(a.date));

  // Group by month
  const byMonth = {};
  filtered.forEach(e => {
    const k = e.date.slice(0, 7);
    (byMonth[k] = byMonth[k] || []).push(e);
  });
  const monthKeys = Object.keys(byMonth).sort((a, b) => b.localeCompare(a));

  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 28 }}>
      <div style={{ padding: '8px 20px 14px' }}>
        <div style={{ fontFamily: theme.fontHead, fontSize: 32, fontWeight: 600, color: theme.ink, letterSpacing: -0.5 }}>記憶簿</div>
        <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, marginTop: 2, letterSpacing: 0.3 }}>
          {past.length} 個記憶 · 已發生先會喺度
        </div>
      </div>

      {/* 回望 spotlight */}
      {onThisDay.length > 0 && (
        <div style={{ padding: '0 20px 20px' }}>
          <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.rose, letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 8, paddingLeft: 4, fontWeight: 600 }}>
            ⌛ 一年前嘅今日
          </div>
          {onThisDay.map(m => {
            const yr = new Date(TODAY).getFullYear() - new Date(m.date).getFullYear();
            return (
              <div key={m.id} onClick={() => onOpen(m.id)} style={{
                padding: 14, borderRadius: 16, cursor: 'pointer',
                background: `linear-gradient(135deg, ${theme.roseSoft} 0%, ${theme.amberSoft} 100%)`,
                border: `0.5px solid ${theme.rose}33`,
                display: 'flex', gap: 12,
              }}>
                <PhotoPH id={m.cover} label={m.cover} h={88} w={88} rounded={12} theme={theme}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.rose, fontWeight: 600, letterSpacing: 0.4 }}>
                    {yr} 年前嘅 {fmtMD(m.date)}
                  </div>
                  <div style={{ fontFamily: theme.fontHead, fontSize: 18, fontWeight: 600, color: theme.ink, marginTop: 3 }}>
                    {m.title}
                  </div>
                  {m.reflection && (
                    <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 6, lineHeight: 1.5,
                      display: '-webkit-box', WebkitBoxOrient: 'vertical', WebkitLineClamp: 2, overflow: 'hidden' }}>
                      "{m.reflection.text}"
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* This month roundup */}
      <div style={{ padding: '0 20px 16px' }}>
        <div style={{
          background: theme.surface, borderRadius: 14, padding: 14,
          border: `0.5px solid ${theme.line}`,
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.4 }}>2026 五月 · 月誌</div>
            <div style={{ fontFamily: theme.fontHead, fontSize: 17, fontWeight: 600, color: theme.ink, marginTop: 2 }}>
              呢個月已經 {past.filter(e => e.date.startsWith('2026-05')).length} 個記憶
            </div>
            <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 4 }}>
              下星期係兩週年 ♡
            </div>
          </div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 22, color: theme.rose }}>(♡˙︶˙♡)</div>
        </div>
      </div>

      {/* Tag filter */}
      <div style={{ padding: '0 20px 14px', display: 'flex', gap: 6, overflowX: 'auto' }}>
        {[['all', '全部'], ['特別日子', '特別日子'], ['出遊', '出遊'], ['屋企', '屋企'], ['散步', '散步'], ['食', '食']].map(([id, lab]) => (
          <Chip key={id} theme={theme} active={tag === id} color={theme.ink} onClick={() => setTag(id)}>{lab}</Chip>
        ))}
      </div>

      {/* Timeline grouped by month */}
      <div style={{ padding: '0 20px' }}>
        {monthKeys.map(mk => {
          const [y, m] = mk.split('-');
          return (
            <div key={mk}>
              <div style={{
                position: 'sticky', top: 0, zIndex: 1, padding: '6px 0',
                fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.5, textTransform: 'uppercase',
                background: `linear-gradient(${theme.paper}, ${theme.paper} 60%, transparent)`,
              }}>
                {y} · {MONTHS_TC[Number(m) - 1]}
              </div>
              {byMonth[mk].map((m, i, arr) => (
                <MemoryRow key={m.id} entry={m} theme={theme} onClick={() => onOpen(m.id)} last={i === arr.length - 1}/>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function MemoryRow({ entry, theme, onClick, last }) {
  return (
    <div onClick={onClick} style={{ position: 'relative', cursor: 'pointer' }}>
      {/* timeline rail */}
      <div style={{ position: 'absolute', left: 8, top: 0, bottom: last ? '50%' : 0, width: 1, background: theme.line }}/>
      <div style={{ position: 'absolute', left: 4, top: 22, width: 9, height: 9, borderRadius: '50%', background: theme.rose, border: `2px solid ${theme.paper}` }}/>

      <div style={{ paddingLeft: 28, paddingTop: 10, paddingBottom: 14 }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, letterSpacing: 0.4 }}>
          {fmtMD(entry.date)} · 星期{WEEKDAYS[new Date(entry.date).getDay()]}
        </div>
        <div style={{
          background: theme.surface, borderRadius: 14, padding: 12, marginTop: 6,
          border: `0.5px solid ${theme.line}`,
          display: 'flex', gap: 10,
        }}>
          <PhotoPH id={entry.cover} label={entry.cover} h={66} w={66} rounded={10} theme={theme}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: theme.fontHead, fontWeight: 600, fontSize: 16, color: theme.ink }}>
              {entry.title}
            </div>
            {entry.reflection && (
              <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 3, lineHeight: 1.45,
                display: '-webkit-box', WebkitBoxOrient: 'vertical', WebkitLineClamp: 2, overflow: 'hidden' }}>
                {entry.reflection.text}
              </div>
            )}
            <div style={{
              marginTop: 6, display: 'flex', alignItems: 'center', gap: 10,
              fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted,
            }}>
              <span>📷 {entry.photos}</span>
              {entry.voiceClips > 0 && <span>🎙 {entry.voiceClips}</span>}
              <span>💬 {entry.messages}</span>
              <span style={{ marginLeft: 'auto', fontSize: 13, color: theme.ink }}>{entry.kao}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ADD ENTRY — adapted for the new model
// ─────────────────────────────────────────────────────────────
function AddEvent({ theme, onClose }) {
  const [title, setTitle] = useState('');
  const [tag, setTag] = useState('出遊');
  const [who, setWho] = useState('both');
  const [proposer, setProposer] = useState('kit');
  const [memorable, setMemorable] = useState(true);

  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI }}>
      <div style={{ padding: '4px 14px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: theme.rose, fontSize: 15 }}>取消</button>
        <span style={{ fontWeight: 600, color: theme.ink }}>新提醒</span>
        <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: theme.rose, fontSize: 15, fontWeight: 600 }}>加</button>
      </div>

      <div style={{ padding: '20px 20px 0' }}>
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="想做啲乜？" style={{
          width: '100%', border: 'none', outline: 'none', background: 'transparent',
          fontFamily: theme.fontHead, fontSize: 26, color: theme.ink, fontWeight: 600,
          padding: '8px 0', marginBottom: 14,
        }}/>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 22 }}>
          {['食飯', '睇戲', '行山', '散步', '煮嘢食', '紀念日'].map(s => (
            <Chip key={s} theme={theme} onClick={() => setTitle(s)}>＋ {s}</Chip>
          ))}
        </div>

        <Section theme={theme} title="日期 · 時間">
          <Row theme={theme} icon="cal" label="日期" value="5月 2 日 (六)"/>
          <Row theme={theme} icon="clock" label="時間" value="18:30"/>
          <Row theme={theme} icon="pin2" label="地點" value="未填" subtle/>
        </Section>

        <Section theme={theme} title="標籤">
          <div style={{ padding: '12px 14px' }}>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {['出遊', '屋企', '食', '散步', '特別日子'].map(t => (
                <button key={t} onClick={() => setTag(t)} style={{
                  padding: '6px 12px', borderRadius: 999, fontSize: 12,
                  border: tag === t ? `1.5px solid ${tagColor(theme, t)}` : `1px solid ${theme.line}`,
                  background: tag === t ? tagColor(theme, t) + '22' : 'transparent',
                  color: theme.ink, cursor: 'pointer',
                }}>＃{t}</button>
              ))}
            </div>
          </div>
        </Section>

        <Section theme={theme} title="邊個">
          <div style={{ padding: '12px 14px' }}>
            <div style={{ display: 'flex', gap: 8 }}>
              {[['both', '我哋兩個'], ['kit', '只係 Kit'], ['michel', '只係 Michel']].map(([k, l]) => (
                <button key={k} onClick={() => setWho(k)} style={{
                  flex: 1, padding: '8px 6px', borderRadius: 10, fontSize: 12,
                  border: who === k ? `1.5px solid ${theme.rose}` : `1px solid ${theme.line}`,
                  background: who === k ? theme.roseSoft : 'transparent',
                  color: theme.ink, cursor: 'pointer',
                }}>{l}</button>
              ))}
            </div>
          </div>
          {who === 'both' && (
            <div style={{ padding: '12px 14px', borderTop: `0.5px solid ${theme.line}` }}>
              <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, marginBottom: 8 }}>邊個提議？</div>
              <div style={{ display: 'flex', gap: 8 }}>
                {[['kit', 'Kit'], ['michel', 'Michel'], ['both', '一齊諗']].map(([k, l]) => (
                  <button key={k} onClick={() => setProposer(k)} style={{
                    flex: 1, padding: '6px 4px', borderRadius: 10, fontSize: 12,
                    border: proposer === k ? `1.5px solid ${theme.sage}` : `1px solid ${theme.line}`,
                    background: proposer === k ? theme.sageSoft : 'transparent',
                    color: theme.ink, cursor: 'pointer',
                  }}>{l}</button>
                ))}
              </div>
            </div>
          )}
        </Section>

        <Section theme={theme} title="記憶簿">
          <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
            <Icon name="heart" size={18} color={theme.rose} fill={memorable ? theme.rose : 'none'}/>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, color: theme.ink, fontWeight: 500 }}>過咗之後存做記憶</div>
              <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, marginTop: 2 }}>
                當日相片、語音、對話會自動結集
              </div>
            </div>
            <Toggle theme={theme} on={memorable} onChange={setMemorable}/>
          </div>
        </Section>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ACTIVITIES (unchanged structure, kept intact)
// ─────────────────────────────────────────────────────────────
function Activities({ theme, onOpen }) {
  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 20 }}>
      <div style={{ padding: '8px 20px 16px' }}>
        <div style={{ fontFamily: theme.fontHead, fontSize: 32, fontWeight: 600, color: theme.ink, letterSpacing: -0.5 }}>玩樂</div>
        <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, marginTop: 2, letterSpacing: 0.3 }}>
          約會點子、小遊戲、測驗
        </div>
      </div>

      <div style={{ padding: '0 20px 16px' }}>
        <div style={{
          padding: '20px', borderRadius: 18, background: theme.rose,
          color: '#fff', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ fontFamily: theme.fontMono, fontSize: 10, letterSpacing: 0.5, opacity: 0.7 }}>本週推介</div>
          <div style={{ fontFamily: theme.fontHead, fontSize: 22, fontWeight: 600, marginTop: 4 }}>抽張卡，今晚做乜？</div>
          <div style={{ fontSize: 13, opacity: 0.85, marginTop: 6, lineHeight: 1.5 }}>
            24 個冇做過嘅約會點子<br/>由 random 揀
          </div>
          <div style={{ position: 'absolute', right: -10, top: -10, fontFamily: theme.fontMono, fontSize: 36, opacity: 0.3, transform: 'rotate(15deg)' }}>
            (♡˙︶˙♡)
          </div>
          <button style={{
            marginTop: 14, padding: '10px 18px', borderRadius: 999,
            background: '#fff', color: theme.rose, border: 'none', cursor: 'pointer',
            fontFamily: theme.fontUI, fontSize: 13, fontWeight: 600,
          }} onClick={() => onOpen && onOpen('cards')}>抽卡 →</button>
        </div>
      </div>

      <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {D.activities.map(a => (
          <div key={a.id} onClick={() => onOpen && onOpen(a.kind === 'cards' ? 'cards' : a.kind === 'quiz' ? 'quiz' : null)} style={{
            background: theme.surface, borderRadius: 14, padding: 14,
            border: `0.5px solid ${theme.line}`, position: 'relative',
            minHeight: 120, cursor: 'pointer',
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: 8,
              background: a.kind === 'cards' ? theme.roseSoft : a.kind === 'quiz' ? theme.sageSoft : theme.amberSoft,
              display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10,
            }}>
              <Icon name={a.kind === 'cards' ? 'sparkle' : a.kind === 'quiz' ? 'kao' : a.kind === 'map' ? 'pin2' : 'edit'}
                size={16} color={a.kind === 'cards' ? theme.rose : a.kind === 'quiz' ? theme.sage : theme.amber}/>
            </div>
            <div style={{ fontWeight: 600, fontSize: 14, color: theme.ink }}>{a.title}</div>
            <div style={{ fontSize: 11, color: theme.inkSoft, marginTop: 3, lineHeight: 1.4 }}>{a.subtitle}</div>
            {a.count && (
              <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted, marginTop: 8, letterSpacing: 0.3 }}>
                {a.count} 個
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// PROFILE / 我哋 — surfaces next anniversary + days together
// ─────────────────────────────────────────────────────────────
function Profile({ theme, onOpen }) {
  const days = daysBetween('2024-05-22', TODAY);
  const anniv = D.anniversaries.map(a => ({ ...a, ...nextOccurrence(a) })).sort((a, b) => a.days - b.days)[0];
  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, paddingBottom: 28 }}>
      <div style={{ padding: '8px 20px 16px' }}>
        <div style={{ fontFamily: theme.fontHead, fontSize: 32, fontWeight: 600, color: theme.ink, letterSpacing: -0.5 }}>我哋</div>
      </div>

      <div style={{ padding: '0 20px 20px' }}>
        <div style={{
          background: theme.surface, borderRadius: 18, padding: 20,
          border: `0.5px solid ${theme.line}`, textAlign: 'center',
        }}>
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 14 }}>
            <Avatar person={D.PARTNER} theme={theme} size={56}/>
            <div style={{
              margin: '0 -10px', alignSelf: 'center', fontFamily: theme.fontHead, fontSize: 22, color: theme.rose,
              transform: 'translateY(2px)', zIndex: 1,
            }}>♡</div>
            <Avatar person={D.ME} theme={theme} size={56}/>
          </div>
          <div style={{ fontFamily: theme.fontHead, fontSize: 22, fontWeight: 600, color: theme.ink }}>Kit & Michel</div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, marginTop: 4, letterSpacing: 0.3 }}>
            一齊 {days} 日 · 自 2024.5.22
          </div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 14, color: theme.rose, marginTop: 10 }}>(♡˙︶˙♡)</div>
        </div>
      </div>

      <div style={{ padding: '0 20px' }}>
        <Section theme={theme} title="紀念日">
          <Row theme={theme} icon="heart"
            label={`下一個：${anniv.title}`}
            value={`${anniv.days} 日後 →`}
            onClick={() => onOpen && onOpen('anniversaries')}/>
          <Row theme={theme} icon="cal" label={`所有紀念日 (${D.anniversaries.length})`} value="→"
            onClick={() => onOpen && onOpen('anniversaries')}/>
        </Section>

        <Section theme={theme} title="設定">
          <Row theme={theme} icon="kao" label="顏文字偏好" value="日系 →" onClick={() => onOpen && onOpen('kao')}/>
          <Row theme={theme} icon="image" label="共用相簿" value="247"/>
          <Row theme={theme} icon="clock" label="提醒時間" value="08:00"/>
          <Row theme={theme} icon="us" label="主題" value="日系奶油 →" onClick={() => onOpen && onOpen('theme')}/>
        </Section>

        <Section theme={theme} title="帳戶">
          <Row theme={theme} icon="more" label="解除配對" value="" subtle/>
          <Row theme={theme} icon="more" label="關於" value="v0.1"/>
        </Section>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ONBOARDING (kept)
// ─────────────────────────────────────────────────────────────
function Onboarding({ theme, onDone }) {
  const [step, setStep] = useState(0);
  const steps = [
    { kao: '(´｡• ω •｡`)', title: '只屬於你哋兩個', body: '一個小小嘅地方，記低你哋之間嘅每一個瞬間。' },
    { kao: '(♡˙︶˙♡)', title: '配對對方', body: '輸入對方嘅 6 位數字配對碼，或者掃描 QR。', input: true },
    { kao: '(≧▽≦)', title: '揀個顏色', body: '揀一個代表你哋嘅主題。', themePicker: true },
  ];
  const cur = steps[step];
  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI, display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '20px 20px 0', display: 'flex', gap: 6 }}>
        {steps.map((_, i) => (
          <div key={i} style={{
            flex: 1, height: 3, borderRadius: 2,
            background: i <= step ? theme.rose : theme.line,
          }}/>
        ))}
      </div>

      <div style={{ flex: 1, padding: '60px 28px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
        <div style={{ fontFamily: theme.fontMono, fontSize: 38, color: theme.rose }}>{cur.kao}</div>
        <div style={{ fontFamily: theme.fontHead, fontSize: 28, fontWeight: 600, color: theme.ink, marginTop: 24, letterSpacing: -0.3 }}>
          {cur.title}
        </div>
        <div style={{ fontSize: 15, color: theme.inkSoft, marginTop: 12, lineHeight: 1.6, maxWidth: 280 }}>
          {cur.body}
        </div>

        {cur.input && (
          <div style={{ marginTop: 36, display: 'flex', gap: 8 }}>
            {['8', '4', '2', '1', '6', '9'].map((n, i) => (
              <div key={i} style={{
                width: 38, height: 50, borderRadius: 10,
                background: theme.surface, border: `1px solid ${theme.line}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: theme.fontMono, fontSize: 22, fontWeight: 600, color: theme.ink,
              }}>{n}</div>
            ))}
          </div>
        )}

        {cur.themePicker && (
          <div style={{ marginTop: 36, display: 'flex', gap: 12 }}>
            {[theme.rose, theme.sage, theme.amber].map((c, i) => (
              <div key={i} style={{
                width: 56, height: 56, borderRadius: '50%', background: c,
                border: i === 0 ? `3px solid ${theme.ink}` : 'none',
              }}/>
            ))}
          </div>
        )}
      </div>

      <div style={{ padding: 20 }}>
        <button onClick={() => step < 2 ? setStep(step + 1) : onDone()} style={{
          width: '100%', padding: 14, borderRadius: 14,
          background: theme.ink, color: theme.paper, border: 'none', cursor: 'pointer',
          fontFamily: theme.fontUI, fontSize: 15, fontWeight: 600,
        }}>
          {step < 2 ? '繼續' : '完成 ♡'}
        </button>
        {step === 0 && (
          <button onClick={() => setStep(2)} style={{
            width: '100%', padding: 12, marginTop: 6, background: 'transparent',
            border: 'none', color: theme.inkMuted, fontSize: 13, cursor: 'pointer',
          }}>已經有 account →</button>
        )}
      </div>
    </div>
  );
}

window.AppScreens = { Timetable, AddEvent, MemoryFeed, EntryDetail, MemoryDetail: EntryDetail, Activities, Profile, Onboarding };
window.NextOccurrence = nextOccurrence;
