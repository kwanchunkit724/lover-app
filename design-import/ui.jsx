// Shared UI primitives — icons, photo placeholders, status bar, tab bar
// All themed via the theme prop. No external assets.

const { useState, useEffect, useRef, useMemo } = React;

// ─────────────────────────────────────────────────────────────
// Icons — minimal stroke icons, scale via size prop
// ─────────────────────────────────────────────────────────────
const Icon = ({ name, size = 22, color = 'currentColor', strokeWidth = 1.6, fill = 'none' }) => {
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill, stroke: color, strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'chat': return <svg {...props}><path d="M21 12a8 8 0 0 1-11.7 7.1L4 20l1-4.5A8 8 0 1 1 21 12z"/></svg>;
    case 'book': return <svg {...props}><path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3V4z"/><path d="M5 17h14"/></svg>;
    case 'cal': return <svg {...props}><rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/></svg>;
    case 'play': return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M10 9l5 3-5 3z" fill={color}/></svg>;
    case 'us': return <svg {...props}><path d="M12 21s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.5-7 10-7 10z"/></svg>;
    case 'cam': return <svg {...props}><path d="M3 8a2 2 0 0 1 2-2h2l2-2.5h6L17 6h2a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8z"/><circle cx="12" cy="13" r="3.5"/></svg>;
    case 'image': return <svg {...props}><rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><circle cx="9" cy="10" r="1.5"/><path d="M4 17l5-4 4 3 3-2 4 3"/></svg>;
    case 'mic': return <svg {...props}><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3M9 21h6"/></svg>;
    case 'send': return <svg {...props}><path d="M4 12l16-8-6 16-3-7-7-1z"/></svg>;
    case 'plus': return <svg {...props}><path d="M12 5v14M5 12h14"/></svg>;
    case 'search': return <svg {...props}><circle cx="11" cy="11" r="6"/><path d="M16 16l4 4"/></svg>;
    case 'back': return <svg {...props}><path d="M15 6l-6 6 6 6"/></svg>;
    case 'close': return <svg {...props}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case 'check': return <svg {...props}><path d="M5 12l4.5 4.5L19 7"/></svg>;
    case 'check2': return <svg {...props}><path d="M3 12l4 4 8-8M9 16l8-8"/></svg>;
    case 'pin': return <svg {...props}><path d="M9 3l6 6-2 2 3 3-3 3-3-3-2 2-6-6 7-7z" fill={color} opacity="0.15"/><path d="M9 3l6 6-2 2 3 3-3 3-3-3-2 2-6-6 7-7z"/></svg>;
    case 'reply': return <svg {...props}><path d="M9 7L4 12l5 5M4 12h11a5 5 0 0 1 5 5v3"/></svg>;
    case 'more': return <svg {...props}><circle cx="5" cy="12" r="1.4" fill={color}/><circle cx="12" cy="12" r="1.4" fill={color}/><circle cx="19" cy="12" r="1.4" fill={color}/></svg>;
    case 'kao': return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M8 10h.01M16 10h.01M8 15c1.5 1 6.5 1 8 0"/></svg>;
    case 'play2': return <svg {...props}><path d="M7 5l12 7-12 7z" fill={color}/></svg>;
    case 'pause': return <svg {...props}><rect x="6" y="5" width="4" height="14" rx="1" fill={color}/><rect x="14" y="5" width="4" height="14" rx="1" fill={color}/></svg>;
    case 'pin2': return <svg {...props}><path d="M12 2a7 7 0 0 1 7 7c0 5-7 13-7 13S5 14 5 9a7 7 0 0 1 7-7z"/><circle cx="12" cy="9" r="2.5"/></svg>;
    case 'clock': return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'heart': return <svg {...props}><path d="M12 21s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.5-7 10-7 10z" fill={color}/></svg>;
    case 'edit': return <svg {...props}><path d="M14 4l6 6-11 11H3v-6L14 4z"/></svg>;
    case 'flip': return <svg {...props}><path d="M4 8a8 8 0 0 1 14-4l2-2v6h-6l2-2A6 6 0 0 0 6 8M20 16a8 8 0 0 1-14 4l-2 2v-6h6l-2 2a6 6 0 0 0 10-2"/></svg>;
    case 'flash': return <svg {...props}><path d="M13 3L5 14h6l-1 7 8-11h-6l1-7z"/></svg>;
    case 'shutter': return <svg {...props}><circle cx="12" cy="12" r="10" strokeWidth="2"/><circle cx="12" cy="12" r="7" fill={color}/></svg>;
    case 'arrow': return <svg {...props}><path d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case 'sparkle': return <svg {...props}><path d="M12 4l1.5 5L18 11l-4.5 1.5L12 18l-1.5-5.5L5 11l5.5-2L12 4z"/></svg>;
    default: return null;
  }
};

// ─────────────────────────────────────────────────────────────
// Photo placeholder — striped SVG with a label, no actual image
// Used everywhere we'd normally need a photo asset.
// ─────────────────────────────────────────────────────────────
const PhotoPH = ({ id, label, w = '100%', h = 200, theme, rounded = 14 }) => {
  // Different "photos" get different hue / direction based on id
  const hash = (id || label || '').split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const hue = hash % 360;
  const angle = (hash * 37) % 180;
  const tints = theme.isDark
    ? [`oklch(0.32 0.04 ${hue})`, `oklch(0.26 0.04 ${(hue + 30) % 360})`]
    : [`oklch(0.86 0.04 ${hue})`, `oklch(0.78 0.05 ${(hue + 30) % 360})`];
  const strokeC = theme.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)';
  const labelC = theme.isDark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.45)';
  return (
    <div style={{
      width: w, height: h, borderRadius: rounded, overflow: 'hidden', position: 'relative',
      background: `linear-gradient(${angle}deg, ${tints[0]}, ${tints[1]})`,
    }}>
      <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0 }} preserveAspectRatio="none">
        <defs>
          <pattern id={`stripe-${id}`} width="14" height="14" patternUnits="userSpaceOnUse" patternTransform={`rotate(${angle})`}>
            <line x1="0" y1="0" x2="0" y2="14" stroke={strokeC} strokeWidth="1"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill={`url(#stripe-${id})`}/>
      </svg>
      {label && (
        <div style={{
          position: 'absolute', bottom: 8, left: 10, right: 10,
          fontFamily: theme.fontMono, fontSize: 10, color: labelC,
          letterSpacing: 0.3, textTransform: 'lowercase',
        }}>{label}</div>
      )}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Avatar — initial letter on a tinted circle
// ─────────────────────────────────────────────────────────────
const Avatar = ({ person, theme, size = 36 }) => {
  const tint = person.tint === 'rose' ? theme.rose : person.tint === 'sage' ? theme.sage : theme.amber;
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: tint,
      color: theme.isDark ? theme.paper : '#fff',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: theme.fontHead, fontWeight: 600, fontSize: size * 0.42,
      flexShrink: 0,
    }}>{person.initial}</div>
  );
};

// ─────────────────────────────────────────────────────────────
// Status bar (light ink) — replaces IOSStatusBar so it themes
// ─────────────────────────────────────────────────────────────
const StatusBar = ({ theme, time = '18:24' }) => {
  const c = theme.ink;
  return (
    <div style={{
      height: 54, padding: '21px 28px 0', display: 'flex',
      justifyContent: 'space-between', alignItems: 'flex-start',
      position: 'relative', zIndex: 20, fontFamily: theme.fontUI,
    }}>
      <span style={{ fontWeight: 600, fontSize: 16, color: c, letterSpacing: -0.2 }}>{time}</span>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center', paddingTop: 2 }}>
        <svg width="17" height="11" viewBox="0 0 17 11">
          <rect x="0" y="7" width="3" height="4" rx="0.5" fill={c}/>
          <rect x="4.5" y="5" width="3" height="6" rx="0.5" fill={c}/>
          <rect x="9" y="2.5" width="3" height="8.5" rx="0.5" fill={c}/>
          <rect x="13.5" y="0" width="3" height="11" rx="0.5" fill={c}/>
        </svg>
        <svg width="24" height="11" viewBox="0 0 24 11">
          <rect x="0.5" y="0.5" width="20" height="10" rx="2.5" stroke={c} strokeOpacity="0.4" fill="none"/>
          <rect x="2" y="2" width="17" height="7" rx="1.5" fill={c}/>
          <path d="M22 4v3c.7-.2 1.2-.8 1.2-1.5S22.7 4.2 22 4z" fill={c} opacity="0.4"/>
        </svg>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Tab bar — bottom navigation, 5 items
// ─────────────────────────────────────────────────────────────
const TabBar = ({ theme, current, onChange }) => {
  const tabs = [
    { id: 'chat', icon: 'chat', label: '對話' },
    { id: 'time', icon: 'cal', label: '時間' },
    { id: 'play', icon: 'play', label: '玩樂' },
    { id: 'us', icon: 'us', label: '我哋' },
  ];
  return (
    <div style={{
      borderTop: `0.5px solid ${theme.line}`,
      background: theme.nav,
      backdropFilter: 'blur(20px) saturate(180%)',
      WebkitBackdropFilter: 'blur(20px) saturate(180%)',
      padding: '8px 6px 24px',
      display: 'flex', justifyContent: 'space-around',
      fontFamily: theme.fontUI,
    }}>
      {tabs.map(t => {
        const active = t.id === current;
        return (
          <button key={t.id} onClick={() => onChange(t.id)} style={{
            background: 'none', border: 'none', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            padding: '4px 8px', flex: 1,
            color: active ? theme.rose : theme.inkMuted,
          }}>
            <Icon name={t.icon} size={22} strokeWidth={active ? 2 : 1.5} />
            <span style={{ fontSize: 10, letterSpacing: 0.2, fontWeight: active ? 600 : 400 }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Soft button & chip
// ─────────────────────────────────────────────────────────────
const Chip = ({ children, theme, active, onClick, color }) => (
  <button onClick={onClick} style={{
    border: 'none', cursor: onClick ? 'pointer' : 'default',
    padding: '6px 12px', borderRadius: 999,
    fontFamily: theme.fontUI, fontSize: 12, fontWeight: 500,
    background: active ? (color || theme.ink) : (theme.isDark ? theme.paperAlt : theme.paperAlt),
    color: active ? (theme.isDark ? theme.paper : theme.paper) : theme.inkSoft,
    transition: 'all .15s',
    whiteSpace: 'nowrap',
  }}>{children}</button>
);

window.UI = { Icon, PhotoPH, Avatar, StatusBar, TabBar, Chip };
