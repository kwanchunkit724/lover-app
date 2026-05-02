// Chat screens — list, detail, kaomoji picker, voice recorder, camera
const { Icon, PhotoPH, Avatar, StatusBar, Chip } = window.UI;
const D = window.AppData;

// ─────────────────────────────────────────────────────────────
// Conversations list
// ─────────────────────────────────────────────────────────────
function ChatList({ theme, onOpen }) {
  return (
    <div style={{ background: theme.paper, minHeight: '100%', fontFamily: theme.fontUI }}>
      <div style={{ padding: '8px 20px 16px' }}>
        <div style={{ fontFamily: theme.fontHead, fontSize: 32, fontWeight: 600, color: theme.ink, letterSpacing: -0.5 }}>對話</div>
        <div style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted, marginTop: 2, letterSpacing: 0.3 }}>
          5月2日 · 星期六
        </div>
      </div>
      {/* Search */}
      <div style={{ padding: '0 20px 12px' }}>
        <div style={{
          background: theme.paperAlt, borderRadius: 12, padding: '10px 14px',
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <Icon name="search" size={16} color={theme.inkMuted} strokeWidth={1.8} />
          <span style={{ fontSize: 14, color: theme.inkMuted }}>搜尋對話</span>
        </div>
      </div>
      {/* List */}
      <div>
        {D.conversations.map((c, i) => {
          const isPartner = c.id === 'michel';
          const person = isPartner ? D.PARTNER : { initial: c.id === 'mom' ? '媽' : '?', tint: 'amber' };
          return (
            <button
              key={c.id}
              onClick={() => isPartner && onOpen(c.id)}
              style={{
                display: 'flex', gap: 14, alignItems: 'center',
                width: '100%', padding: '14px 20px',
                background: 'transparent', border: 'none', cursor: isPartner ? 'pointer' : 'default',
                borderTop: i === 0 ? 'none' : `0.5px solid ${theme.line}`,
                textAlign: 'left',
              }}>
              <Avatar person={person} theme={theme} size={48} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8 }}>
                  <span style={{ fontWeight: 600, color: theme.ink, fontSize: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
                    {c.name}
                    {c.pinned && <Icon name="pin" size={11} color={theme.inkMuted} fill={theme.inkMuted} />}
                  </span>
                  <span style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted }}>{c.lastT}</span>
                </div>
                <div style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 2, gap: 8,
                }}>
                  <span style={{
                    fontSize: 14, color: theme.inkSoft,
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1,
                  }}>{c.lastText}</span>
                  {c.unread > 0 && (
                    <span style={{
                      background: theme.rose, color: '#fff', fontSize: 11, fontWeight: 600,
                      minWidth: 18, height: 18, borderRadius: 10, padding: '0 6px',
                      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                    }}>{c.unread}</span>
                  )}
                  {c.muted && <Icon name="mic" size={12} color={theme.inkMuted} />}
                </div>
              </div>
            </button>
          );
        })}
      </div>
      {/* Empty hint */}
      <div style={{
        margin: '32px 20px', padding: '20px', textAlign: 'center',
        border: `1px dashed ${theme.lineStrong}`, borderRadius: 14,
        fontFamily: theme.fontMono, fontSize: 11, color: theme.inkMuted,
      }}>
        只有 Michel 嗰個對話有實際內容<br/>
        <span style={{ fontFamily: theme.fontUI, fontSize: 13, color: theme.inkSoft }}>
          (◕‿◕) tap 入去睇
        </span>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Chat detail — the centerpiece screen
// ─────────────────────────────────────────────────────────────
function ChatDetail({ theme, onBack, onCamera, onPhoto }) {
  const [messages, setMessages] = useState(D.messages);
  const [input, setInput] = useState('');
  const [showKao, setShowKao] = useState(false);
  const [showVoice, setShowVoice] = useState(false);
  const [showActions, setShowActions] = useState(false);
  const [reactingTo, setReactingTo] = useState(null);
  const [replyTo, setReplyTo] = useState(null);
  const [typing, setTyping] = useState(false);
  const scrollRef = useRef(null);

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages, typing]);

  const send = (text) => {
    if (!text.trim()) return;
    const newMsg = {
      id: Date.now(), from: 'kit', kind: 'text', text,
      t: '18:25', read: false,
      replyTo: replyTo ? { id: replyTo.id, kind: replyTo.kind, preview: replyTo.text || replyTo.caption || '0:08 語音訊息' } : undefined,
    };
    setMessages([...messages, newMsg]);
    setInput('');
    setReplyTo(null);
    // Simulate reply
    setTimeout(() => setTyping(true), 1200);
    setTimeout(() => {
      setTyping(false);
      setMessages(m => [...m, {
        id: Date.now() + 1, from: 'michel', kind: 'text',
        text: '收到 (♡˙︶˙♡)', t: '18:26', read: true,
      }]);
    }, 3500);
  };

  const addReaction = (msgId, kao) => {
    setMessages(messages.map(m => m.id === msgId ? {
      ...m, reactions: [...(m.reactions || []), { from: 'kit', kao }]
    } : m));
    setReactingTo(null);
  };

  return (
    <div style={{
      background: theme.paper, height: '100%',
      display: 'flex', flexDirection: 'column', fontFamily: theme.fontUI,
    }}>
      {/* Header */}
      <div style={{
        padding: '4px 14px 12px', borderBottom: `0.5px solid ${theme.line}`,
        background: theme.nav, backdropFilter: 'blur(20px)',
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <Avatar person={D.PARTNER} theme={theme} size={36} />
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontWeight: 600, fontSize: 16, color: theme.ink }}>Michel</span>
            <span style={{ fontFamily: theme.fontMono, fontSize: 11, color: theme.rose }}>♡</span>
          </div>
          <div style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.sage, letterSpacing: 0.3 }}>
            ● 在線 · 一齊 711 日
          </div>
        </div>
        <button aria-label="video" style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}>
          <Icon name="camera" size={20} color={theme.rose} />
        </button>
        <button style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}>
          <Icon name="more" size={22} color={theme.inkSoft} />
        </button>
      </div>

      {/* Messages */}
      <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '12px 14px 6px' }}>
        {/* Date divider */}
        <div style={{
          textAlign: 'center', fontFamily: theme.fontMono, fontSize: 10,
          color: theme.inkMuted, margin: '4px 0 14px', letterSpacing: 0.3,
        }}>5月2日 · 星期六</div>

        {messages.map((m, i) => (
          <MessageRow
            key={m.id}
            msg={m}
            onPhoto={onPhoto}
            theme={theme}
            prev={messages[i-1]}
            onReact={() => setReactingTo(m.id)}
            onReply={() => setReplyTo(m)}
            reacting={reactingTo === m.id}
            onPickReaction={(k) => addReaction(m.id, k)}
            onCloseReact={() => setReactingTo(null)}
          />
        ))}

        {typing && <TypingIndicator theme={theme} />}
      </div>

      {/* Reply preview */}
      {replyTo && (
        <div style={{
          padding: '8px 14px', borderTop: `0.5px solid ${theme.line}`,
          background: theme.paperAlt, display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <div style={{ width: 3, height: 28, background: theme.rose, borderRadius: 2 }}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 11, color: theme.rose, fontWeight: 600 }}>
              回覆 {replyTo.from === 'kit' ? 'Kit' : 'Michel'}
            </div>
            <div style={{ fontSize: 12, color: theme.inkSoft, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {replyTo.text || replyTo.caption || '語音訊息'}
            </div>
          </div>
          <button onClick={() => setReplyTo(null)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
            <Icon name="close" size={16} color={theme.inkMuted} />
          </button>
        </div>
      )}

      {/* Composer */}
      {!showVoice && (
        <Composer
          theme={theme}
          input={input}
          setInput={setInput}
          onSend={() => send(input)}
          onKao={() => setShowKao(!showKao)}
          onVoice={() => setShowVoice(true)}
          onPlus={() => setShowActions(!showActions)}
          onCamera={onCamera}
        />
      )}
      {showVoice && <VoiceRecorder theme={theme} onCancel={() => setShowVoice(false)} onSend={(d) => {
        setMessages([...messages, { id: Date.now(), from: 'kit', kind: 'voice', duration: d, t: '18:25', read: false }]);
        setShowVoice(false);
      }} />}

      {showKao && <KaomojiPicker theme={theme} onPick={(k) => setInput(input + k)} onClose={() => setShowKao(false)} />}
      {showActions && <ActionSheet theme={theme} onClose={() => setShowActions(false)} onCamera={onCamera} />}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Single message row
// ─────────────────────────────────────────────────────────────
function MessageRow({ msg, theme, prev, onReact, onReply, reacting, onPickReaction, onCloseReact, onPhoto }) {
  const isMe = msg.from === 'kit';
  const isContinuation = prev && prev.from === msg.from;

  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      alignItems: isMe ? 'flex-end' : 'flex-start',
      marginBottom: msg.reactions ? 18 : 4, marginTop: isContinuation ? 0 : 8,
      position: 'relative',
    }}>
      {/* Reply preview */}
      {msg.replyTo && (
        <div style={{
          fontSize: 11, color: theme.inkMuted, marginBottom: 3,
          padding: '4px 10px', background: theme.paperAlt, borderRadius: 10,
          maxWidth: '70%', borderLeft: `2px solid ${theme.rose}`,
        }}>
          <div style={{ fontWeight: 600, color: theme.inkSoft }}>↰ 回覆</div>
          <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {msg.replyTo.preview}
          </div>
        </div>
      )}

      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, maxWidth: '78%' }}>
        {/* Bubble */}
        <button
          onClick={() => msg.kind === 'photo' && onPhoto ? onPhoto(msg.src) : onReact()}
          style={{
            border: msg.kind === 'text' && !isMe ? `0.5px solid ${theme.bubbleThemBorder}` : 'none',
            cursor: 'pointer', textAlign: 'left',
            background: msg.kind === 'photo' ? 'transparent' :
                        isMe ? theme.bubbleMe : theme.bubbleThem,
            color: isMe ? theme.bubbleMeText : theme.bubbleThemText,
            padding: msg.kind === 'photo' ? 0 : msg.kind === 'voice' ? '8px 10px' : '9px 14px',
            borderRadius: 18,
            borderBottomRightRadius: isMe ? 6 : 18,
            borderBottomLeftRadius: !isMe ? 6 : 18,
            fontSize: 15, lineHeight: 1.4, fontFamily: theme.fontUI,
          }}>
          {msg.kind === 'text' && msg.text}
          {msg.kind === 'photo' && (
            <div style={{ borderRadius: 18, overflow: 'hidden', width: 220 }}>
              <PhotoPH id={msg.src} label={msg.src} h={260} rounded={0} theme={theme}/>
              {msg.caption && (
                <div style={{
                  padding: '8px 12px', background: isMe ? theme.bubbleMe : theme.bubbleThem,
                  color: isMe ? theme.bubbleMeText : theme.bubbleThemText,
                  fontSize: 14,
                }}>{msg.caption}</div>
              )}
            </div>
          )}
          {msg.kind === 'voice' && <VoicePlayback msg={msg} isMe={isMe} theme={theme}/>}
        </button>

        {/* Time + read */}
        <div style={{
          fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted,
          paddingBottom: 2, whiteSpace: 'nowrap',
        }}>
          {msg.t}
          {isMe && (
            <span style={{ marginLeft: 4, color: msg.read ? theme.sage : theme.inkMuted }}>
              {msg.read ? '✓✓' : '✓'}
            </span>
          )}
        </div>
      </div>

      {/* Reactions */}
      {msg.reactions && (
        <div style={{
          marginTop: -10, marginRight: isMe ? 8 : undefined, marginLeft: !isMe ? 8 : undefined,
          padding: '3px 8px', borderRadius: 12, background: theme.surface,
          border: `0.5px solid ${theme.line}`,
          fontFamily: theme.fontMono, fontSize: 12, color: theme.ink,
          alignSelf: isMe ? 'flex-end' : 'flex-start',
        }}>{msg.reactions.map(r => r.kao).join(' ')}</div>
      )}

      {/* Reaction picker overlay */}
      {reacting && (
        <div style={{
          position: 'absolute', top: -36, [isMe ? 'right' : 'left']: 0,
          background: theme.surface, borderRadius: 999,
          padding: '6px 10px', display: 'flex', gap: 6,
          boxShadow: theme.isDark ? '0 6px 24px rgba(0,0,0,0.4)' : '0 6px 24px rgba(0,0,0,0.12)',
          border: `0.5px solid ${theme.line}`,
          fontFamily: theme.fontMono, fontSize: 14, zIndex: 10,
        }}>
          {D.QUICK_REACT.slice(0, 5).map(k => (
            <button key={k} onClick={() => onPickReaction(k)} style={{
              background: 'none', border: 'none', cursor: 'pointer',
              color: theme.ink, padding: 0, fontSize: 13, fontFamily: theme.fontMono,
            }}>{k}</button>
          ))}
          <button onClick={onCloseReact} style={{ background: 'none', border: 'none', cursor: 'pointer', color: theme.inkMuted }}>
            <Icon name="close" size={14} color={theme.inkMuted}/>
          </button>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Voice playback bubble
// ─────────────────────────────────────────────────────────────
function VoicePlayback({ msg, isMe, theme }) {
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    if (!playing) return;
    const id = setInterval(() => setProgress(p => {
      if (p >= 1) { setPlaying(false); return 0; }
      return p + 0.05;
    }), msg.duration * 50);
    return () => clearInterval(id);
  }, [playing, msg.duration]);

  // Pseudo waveform — deterministic from msg.id
  const bars = useMemo(() => Array.from({ length: 22 }, (_, i) => {
    const seed = (msg.id * (i + 1)) % 100;
    return 0.3 + (seed / 100) * 0.7;
  }), [msg.id]);

  const fg = isMe ? theme.bubbleMeText : theme.ink;
  const dim = isMe ? 'rgba(250,248,244,0.4)' : theme.inkMuted;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 160 }}>
      <button onClick={(e) => { e.stopPropagation(); setPlaying(!playing); }} style={{
        width: 30, height: 30, borderRadius: '50%',
        background: isMe ? 'rgba(250,248,244,0.2)' : theme.paperAlt,
        border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>
        <Icon name={playing ? 'pause' : 'play2'} size={14} color={fg} />
      </button>
      <div style={{ display: 'flex', alignItems: 'center', gap: 2, flex: 1, height: 28 }}>
        {bars.map((h, i) => (
          <div key={i} style={{
            width: 2.5, height: `${h * 100}%`,
            background: i / bars.length < progress ? fg : dim,
            borderRadius: 2,
          }}/>
        ))}
      </div>
      <span style={{ fontFamily: theme.fontMono, fontSize: 10, color: dim }}>
        0:{String(msg.duration).padStart(2, '0')}
      </span>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────
function TypingIndicator({ theme }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
      <div style={{
        background: theme.bubbleThem, borderRadius: 18,
        border: `0.5px solid ${theme.bubbleThemBorder}`,
        padding: '10px 14px', display: 'flex', gap: 4,
      }}>
        {[0, 1, 2].map(i => (
          <div key={i} style={{
            width: 6, height: 6, borderRadius: '50%', background: theme.inkMuted,
            animation: `kit-bounce 1.4s ${i * 0.2}s infinite`,
          }}/>
        ))}
      </div>
      <span style={{ fontFamily: theme.fontMono, fontSize: 10, color: theme.inkMuted }}>Michel 打緊字</span>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Composer
// ─────────────────────────────────────────────────────────────
function Composer({ theme, input, setInput, onSend, onKao, onVoice, onPlus, onCamera }) {
  return (
    <div style={{
      padding: '10px 12px 12px', borderTop: `0.5px solid ${theme.line}`,
      background: theme.paper, display: 'flex', alignItems: 'flex-end', gap: 8,
    }}>
      <button onClick={onPlus} style={ibtn(theme)}>
        <Icon name="plus" size={20} color={theme.inkSoft}/>
      </button>
      <button onClick={onCamera} style={ibtn(theme)}>
        <Icon name="cam" size={20} color={theme.inkSoft}/>
      </button>
      <div style={{
        flex: 1, background: theme.surface, borderRadius: 20,
        border: `0.5px solid ${theme.line}`,
        display: 'flex', alignItems: 'center', gap: 4, padding: '4px 6px 4px 14px',
        minHeight: 36,
      }}>
        <input
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && onSend()}
          placeholder="訊息…"
          style={{
            flex: 1, border: 'none', outline: 'none', background: 'transparent',
            fontSize: 15, color: theme.ink, fontFamily: theme.fontUI, padding: '4px 0',
          }}/>
        <button onClick={onKao} style={ibtn(theme, 30)}>
          <Icon name="kao" size={18} color={theme.inkSoft}/>
        </button>
      </div>
      {input.trim() ? (
        <button onClick={onSend} style={{
          ...ibtn(theme), background: theme.rose, color: '#fff',
        }}>
          <Icon name="arrow" size={18} color="#fff" strokeWidth={2.4}/>
        </button>
      ) : (
        <button onClick={onVoice} style={ibtn(theme)}>
          <Icon name="mic" size={20} color={theme.inkSoft}/>
        </button>
      )}
    </div>
  );
}
const ibtn = (theme, size = 36) => ({
  width: size, height: size, borderRadius: '50%',
  background: theme.paperAlt, border: 'none', cursor: 'pointer',
  display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
});

// ─────────────────────────────────────────────────────────────
// Kaomoji picker — categories + search + recent
// ─────────────────────────────────────────────────────────────
function KaomojiPicker({ theme, onPick, onClose }) {
  const [cat, setCat] = useState('love');
  const [q, setQ] = useState('');
  const list = q ? Object.values(D.KAOMOJI).flat().filter(k => k.includes(q))
                 : (cat === 'recent' ? D.QUICK_REACT : D.KAOMOJI[cat] || []);
  return (
    <div style={{
      borderTop: `0.5px solid ${theme.line}`, background: theme.surface,
      maxHeight: 290, display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ padding: '10px 14px', display: 'flex', gap: 8, alignItems: 'center', borderBottom: `0.5px solid ${theme.line}` }}>
        <Icon name="search" size={14} color={theme.inkMuted}/>
        <input value={q} onChange={e => setQ(e.target.value)} placeholder="搜尋顏文字…" style={{
          flex: 1, border: 'none', outline: 'none', background: 'transparent',
          fontSize: 13, color: theme.ink, fontFamily: theme.fontUI,
        }}/>
        <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
          <Icon name="close" size={16} color={theme.inkMuted}/>
        </button>
      </div>
      {/* Grid */}
      <div style={{
        flex: 1, overflowY: 'auto', padding: 12,
        display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6,
      }}>
        {list.map((k, i) => (
          <button key={i} onClick={() => onPick(k)} style={{
            padding: '10px 4px', borderRadius: 10, border: 'none',
            background: theme.paperAlt, cursor: 'pointer',
            fontFamily: theme.fontMono, fontSize: 13, color: theme.ink,
            minHeight: 40,
          }}>{k}</button>
        ))}
      </div>
      {/* Categories */}
      <div style={{
        display: 'flex', gap: 6, padding: '8px 12px',
        borderTop: `0.5px solid ${theme.line}`, overflowX: 'auto',
      }}>
        {D.KAO_CATEGORIES.map(c => (
          <Chip key={c.id} theme={theme} active={cat === c.id} onClick={() => { setCat(c.id); setQ(''); }} color={theme.rose}>
            {c.label}
          </Chip>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Voice recorder UI
// ─────────────────────────────────────────────────────────────
function VoiceRecorder({ theme, onCancel, onSend }) {
  const [t, setT] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setT(x => x + 1), 1000);
    return () => clearInterval(id);
  }, []);
  const fmt = s => `0:${String(s).padStart(2, '0')}`;
  return (
    <div style={{
      padding: '20px 16px 16px', borderTop: `0.5px solid ${theme.line}`,
      background: theme.paper,
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 14,
        background: theme.roseSoft, padding: '14px 16px', borderRadius: 18,
      }}>
        <div style={{
          width: 12, height: 12, borderRadius: '50%', background: theme.rose,
          animation: 'kit-pulse 1.4s ease-in-out infinite',
        }}/>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 2, height: 28 }}>
          {Array.from({ length: 28 }).map((_, i) => {
            const active = i < (t * 2) % 28;
            return <div key={i} style={{
              width: 2.5, height: active ? `${30 + Math.sin(i + t) * 30}%` : '20%',
              background: active ? theme.rose : 'rgba(0,0,0,0.15)',
              borderRadius: 2, transition: 'all .2s',
            }}/>;
          })}
        </div>
        <span style={{ fontFamily: theme.fontMono, fontSize: 13, color: theme.rose, fontWeight: 600 }}>
          {fmt(t)}
        </span>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 14, gap: 10 }}>
        <button onClick={onCancel} style={{
          flex: 1, padding: 12, borderRadius: 14, border: `0.5px solid ${theme.line}`,
          background: 'transparent', color: theme.inkSoft, cursor: 'pointer',
          fontFamily: theme.fontUI, fontSize: 14,
        }}>取消</button>
        <button onClick={() => onSend(t || 1)} style={{
          flex: 2, padding: 12, borderRadius: 14, border: 'none',
          background: theme.rose, color: '#fff', cursor: 'pointer',
          fontFamily: theme.fontUI, fontSize: 14, fontWeight: 600,
        }}>傳送 ({fmt(t)})</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// + Action sheet (for camera, photo library, location etc)
// ─────────────────────────────────────────────────────────────
function ActionSheet({ theme, onClose, onCamera }) {
  const items = [
    { icon: 'cam', label: '影相', onClick: onCamera },
    { icon: 'image', label: '相簿', onClick: onClose },
    { icon: 'pin2', label: '位置', onClick: onClose },
    { icon: 'cal', label: '加入時間表', onClick: onClose },
    { icon: 'heart', label: '存到記憶', onClick: onClose },
    { icon: 'sparkle', label: '抽卡', onClick: onClose },
  ];
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.3)',
      zIndex: 100, display: 'flex', alignItems: 'flex-end',
    }}>
      <div onClick={e => e.stopPropagation()} style={{
        width: '100%', background: theme.surface, borderRadius: '20px 20px 0 0',
        padding: '20px 16px 32px', borderTop: `0.5px solid ${theme.line}`,
      }}>
        <div style={{ width: 36, height: 4, background: theme.line, borderRadius: 2, margin: '0 auto 16px' }}/>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
          {items.map(it => (
            <button key={it.label} onClick={it.onClick} style={{
              padding: '14px 8px', borderRadius: 14, border: 'none',
              background: theme.paperAlt, cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
              fontFamily: theme.fontUI, fontSize: 12, color: theme.inkSoft,
            }}>
              <Icon name={it.icon} size={22} color={theme.rose} strokeWidth={1.6}/>
              {it.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Camera screen — full-bleed mock viewfinder
// ─────────────────────────────────────────────────────────────
function Camera({ theme, onBack, onSend }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: '#000', zIndex: 200, display: 'flex', flexDirection: 'column' }}>
      <div style={{
        padding: '54px 16px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <button onClick={onBack} style={{ background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: '50%', width: 36, height: 36, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="close" size={20} color="#fff"/>
        </button>
        <button style={{ background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: '50%', width: 36, height: 36, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="flash" size={18} color="#fff"/>
        </button>
      </div>
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        <PhotoPH id="cam-viewfinder" label="相機預覽 · viewfinder" h="100%" rounded={0} theme={{ ...theme, isDark: true }}/>
        <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', width: 80, height: 80, border: '1px solid rgba(255,255,255,0.4)', borderRadius: 6 }}/>
      </div>
      <div style={{ padding: '20px 16px 36px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ width: 50, height: 50, borderRadius: 10, border: '2px solid rgba(255,255,255,0.5)', background: 'transparent', cursor: 'pointer', overflow: 'hidden' }}>
          <PhotoPH id="recent-photo" label="" h="100%" rounded={6} theme={theme}/>
        </button>
        <button onClick={() => onSend()} style={{
          width: 72, height: 72, borderRadius: '50%', border: '4px solid #fff',
          background: 'transparent', cursor: 'pointer', padding: 4,
        }}>
          <div style={{ width: '100%', height: '100%', borderRadius: '50%', background: '#fff' }}/>
        </button>
        <button style={{ width: 44, height: 44, borderRadius: '50%', background: 'rgba(255,255,255,0.15)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="flip" size={20} color="#fff"/>
        </button>
      </div>
    </div>
  );
}

window.ChatScreens = { ChatList, ChatDetail, Camera };
