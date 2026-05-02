// Main app — routing for B 日系奶油 only with extended sub-flows
const { TabBar, StatusBar } = window.UI;
const { ChatDetail, Camera } = window.ChatScreens;
const { Timetable, AddEvent, EntryDetail, Activities, Profile, Onboarding } = window.AppScreens;
const { CardDeck, Quiz, PhotoViewer, KaoSettings, ThemeSettings, Anniversaries } = window.AppExtra;

function App({ theme, initialTab = 'chat', initialView, initialEntryId }) {
  const [tab, setTab] = useState(initialTab);
  const [view, setView] = useState(initialView || null);
  const [entryId, setEntryId] = useState(initialEntryId || 'm3');
  const [photoId, setPhotoId] = useState(null);

  if (view === 'onboarding') return <Onboarding theme={theme} onDone={() => setView(null)} />;

  let screen;
  if (view === 'camera') screen = <Camera theme={theme} onBack={() => setView(null)} onSend={() => setView(null)} />;
  else if (view === 'addEvent') screen = <AddEvent theme={theme} onClose={() => setView(null)} />;
  else if (view === 'entry') screen = <EntryDetail theme={theme} id={entryId} onBack={() => setView(null)} onPhoto={(id) => setPhotoId(id)} />;
  else if (view === 'cards') screen = <CardDeck theme={theme} onBack={() => setView(null)} />;
  else if (view === 'quiz') screen = <Quiz theme={theme} onBack={() => setView(null)} />;
  else if (view === 'kao') screen = <KaoSettings theme={theme} onBack={() => setView(null)} />;
  else if (view === 'theme') screen = <ThemeSettings theme={theme} onBack={() => setView(null)} />;
  else if (view === 'anniversaries') screen = <Anniversaries theme={theme} onBack={() => setView(null)} />;
  else {
    // chat tab → ChatDetail directly (only one conversation: with partner)
    if (tab === 'chat') screen = <ChatDetail theme={theme} onCamera={() => setView('camera')} onPhoto={(id) => setPhotoId(id)} />;
    else if (tab === 'time') screen = <Timetable theme={theme} onAddEvent={() => setView('addEvent')} onOpenEntry={(id) => { setEntryId(id); setView('entry'); }} />;
    else if (tab === 'play') screen = <Activities theme={theme} onOpen={(k) => k && setView(k)} />;
    else if (tab === 'us') screen = <Profile theme={theme} onOpen={(k) => setView(k)} />;
  }

  const showTabBar = !view;

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', background: theme.paper, position: 'relative', overflow: 'hidden' }}>
      <StatusBar theme={theme} />
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden' }}>{screen}</div>
        {showTabBar && <TabBar theme={theme} current={tab} onChange={setTab} />}
      </div>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 22, display: 'flex', justifyContent: 'center', alignItems: 'flex-end', paddingBottom: 6, pointerEvents: 'none', zIndex: 100 }}>
        <div style={{ width: 120, height: 4, borderRadius: 100, background: theme.isDark ? 'rgba(255,255,255,0.6)' : 'rgba(0,0,0,0.3)' }}/>
      </div>
      {photoId && <PhotoViewer theme={theme} photoId={photoId} onClose={() => setPhotoId(null)} />}
    </div>
  );
}

function PhoneFrame({ theme, children }) {
  return (
    <div style={{
      width: 380, height: 800, borderRadius: 46, overflow: 'hidden', position: 'relative',
      background: theme.paper,
      boxShadow: '0 30px 80px rgba(60,40,30,0.18), 0 0 0 1px rgba(0,0,0,0.06)',
    }}>
      <div style={{ position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)', width: 110, height: 32, borderRadius: 22, background: '#000', zIndex: 50 }} />
      {children}
    </div>
  );
}

function Phone({ themeId, tab, view, entryId }) {
  const theme = window.AppThemes[themeId];
  return <PhoneFrame theme={theme}><App theme={theme} initialTab={tab || 'chat'} initialView={view} initialEntryId={entryId} /></PhoneFrame>;
}
window.Phone = Phone;
window.MainApp = App;
window.PhoneFrame = PhoneFrame;
