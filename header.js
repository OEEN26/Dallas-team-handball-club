/* Shared navigation for the existing HTML pages. Include with <script defer src="./header.js"></script>. */
(() => {
  'use strict';
  const root = new URL('./', document.currentScript?.src || location.href);
  const path = name => new URL(name, root).href;
  const fallback = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="32" fill="#153d25"/><circle cx="32" cy="25" r="11" fill="#00c853"/><path d="M12 55c2-13 10-20 20-20s18 7 20 20" fill="#00c853"/></svg>');
  const ensureI18n = () => {
    if (window.clubI18n || document.querySelector('script[data-club-i18n]')) return;
    const script = document.createElement('script');
    script.src = path('i18n.js');
    script.defer = true;
    script.dataset.clubI18n = 'true';
    document.head.append(script);
  };
  ensureI18n();
  const common = isAdmin => [
    ['Dashboard', isAdmin ? 'index.html' : 'player-dashboard.html'],
    ['Profile Settings', 'profile-settings.html'],
    ['Events', 'events.html'],
    ['Tournaments', isAdmin ? 'admin-operations.html?tab=tournaments' : 'club-hub.html?tab=tournaments'],
    ['Membership', 'club-hub.html?tab=membership']
  ];
  const admin = [
    ['Club Operations', 'admin-operations.html'],
    ['Players', 'player-management.html'],
    ['Practices', 'admin-content.html#practices'],
    ['Announcements', 'admin-content.html#announcements'],
    ['Event Management', 'events.html'],
    ['Jersey Approvals', 'jersey-approvals.html'],
    ['Tournament Readiness', 'event-readiness.html'],
    ['Reports', 'admin-operations.html?tab=overview#stats'],
    ['Event Attendance', 'event-attendance.html'],
    ['Men’s Roster', 'admin-team-profiles.html?team=Men'],
    ['Women’s Roster', 'admin-team-profiles.html?team=Women'],
    ['Player View', 'admin-player-dashboard.html']
  ];
  const adminOnly = [
    ['Admin Management', 'admin-management.html'],
    ['System Logs', 'system-logs.html']
  ];
  const pageKey = url => {
    const u = new URL(url, root);
    const name = u.pathname.split('/').pop() || 'index.html';
    if (name === 'admin-content.html') return name + (u.hash === '#practices' ? '#practices' : '#announcements');
    if (name === 'club-hub.html' || name === 'admin-operations.html') {
      const tab = u.searchParams.get('tab') || (name === 'admin-operations.html' ? 'overview' : 'schedule');
      return name + '?tab=' + tab + (name === 'admin-operations.html' && u.hash === '#stats' ? '#stats' : '');
    }
    if (name === 'admin-team-profiles.html') return name + '?team=' + (u.searchParams.get('team') || 'Men');
    return name;
  };
  const currentLabel = (items) => {
    const key = pageKey(location.href);
    return items.find(([,url]) => pageKey(path(url)) === key)?.[0] || ({
      'player.html':'Player Profile', 'jersey-selection.html':'Jersey Registry',
      'profile-completion.html':'Complete Profile', 'player-preview.html':'Player View',
      'player-view.html':'Player View', 'admin-player-dashboard.html':'Player View',
      'admin-team-profiles.html':'Team Rosters'
    }[key.split('?')[0]] || 'Club Page');
  };
  const dockItems = isAdmin => isAdmin ? [
    ['⌂','Home','index.html','home'],
    ['♟','Players','player-management.html','players'],
    ['◷','Schedule','admin-content.html#practices','schedule'],
    ['🏆','Tournaments','admin-operations.html?tab=tournaments','tournaments'],
    ['⚙','Operations','admin-operations.html?tab=overview','operations']
  ] : [
    ['⌂','Home','player-dashboard.html','home'],
    ['◷','Schedule','club-hub.html?tab=schedule','schedule'],
    ['★','Events','events.html','events'],
    ['🏆','Tournaments','club-hub.html?tab=tournaments','tournaments'],
    ['●','Profile','player.html','profile']
  ];
  const activeDockSection = isAdmin => {
    const key = pageKey(location.href);
    const page = key.split(/[?#]/)[0];
    if (!isAdmin) {
      if (page === 'player-dashboard.html') return 'home';
      if (key === 'club-hub.html?tab=schedule') return 'schedule';
      if (page === 'events.html') return 'events';
      if (key === 'club-hub.html?tab=tournaments') return 'tournaments';
      if (page === 'player.html' || page === 'profile-settings.html') return 'profile';
      return '';
    }
    if (page === 'index.html') return 'home';
    if (['player-management.html','admin-team-profiles.html'].includes(page)) return 'players';
    if (page === 'admin-content.html' || page === 'events.html' || page === 'event-attendance.html') return 'schedule';
    if (key === 'admin-operations.html?tab=tournaments' || page === 'event-readiness.html') return 'tournaments';
    return 'operations';
  };

  function start() {
    if (!window.supabase || !document.body || document.getElementById('club-shared-nav')) return;
    let bar = document.querySelector('body > header .bar');
    if (!bar) {
      const header = document.createElement('header');
      header.className = 'club-created-header';
      header.innerHTML = '<div class="bar"><div class="brand">Dallas <span>THC</span></div></div>';
      document.body.prepend(header);
      bar = header.querySelector('.bar');
    }
    const link = document.createElement('link');
    link.rel = 'stylesheet'; link.href = path('header.css');
    document.head.append(link);
    const host = document.createElement('div');
    host.id = 'club-shared-nav';
    host.hidden = true;
    host.innerHTML = '<span class="club-current-page"></span><button class="club-avatar-button" type="button" aria-label="Open profile menu" aria-haspopup="true" aria-expanded="false" aria-controls="club-profile-menu"><img class="club-avatar" alt="" /><span aria-hidden="true">⌄</span></button><nav id="club-profile-menu" aria-label="Club and account navigation" hidden></nav>';
    bar.append(host);
    const roleDock = document.createElement('nav');
    roleDock.id = 'club-role-dock';
    roleDock.hidden = true;
    document.body.append(roleDock);
    const button = host.querySelector('button');
    const menu = host.querySelector('nav');
    const avatar = host.querySelector('img');
    avatar.src = fallback;
    avatar.addEventListener('error', () => { if (avatar.src !== fallback) avatar.src = fallback; });
    let openedByHover = false;
    const close = () => { menu.hidden = true; openedByHover = false; button.setAttribute('aria-expanded','false'); };
    const open = (hover = false) => { menu.hidden = false; openedByHover = hover; button.setAttribute('aria-expanded','true'); };
    button.addEventListener('click', () => {
      if (menu.hidden || openedByHover) open(); else close();
    });
    host.addEventListener('pointerenter', e => { if (e.pointerType === 'mouse' && matchMedia('(hover:hover)').matches) open(true); });
    host.addEventListener('mouseleave', close);
    document.addEventListener('pointerdown', e => { if (!host.contains(e.target)) close(); });
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape' && !menu.hidden) { close(); button.focus(); }
    });
    menu.addEventListener('click', e => { if (e.target.closest('a')) close(); });

    const client = window.supabase.createClient('https://edfshtjrxbtydoaghhip.supabase.co', 'sb_publishable_O0ozz6dTfqcSjmnzl5uwHQ_oc_-EXeZ');
    const render = async () => {
      const {data:{session},error} = await client.auth.getSession();
      if (error || !session) { close();host.hidden = true;roleDock.hidden=true;document.body.classList.remove('club-header-ready','club-role-dock-ready');return; }
      const {data:profile,error:roleError} = await client.from('profiles').select('role,full_name,preferred_language').eq('id',session.user.id).maybeSingle();
      if (roleError || !profile) return;
      const isAdmin = profile.role === 'admin' || profile.role === 'manager';
      const {data:player} = await client.from('player_directory_public').select('id,profile_photo_url').eq('user_id',session.user.id).maybeSingle();
      const groups = [['Navigate',common(isAdmin)]];
      if (player?.id) groups[0][1].splice(1,0,['Profile','player.html']);
      if (isAdmin) groups.push(['Manage Club',admin]);
      if (profile.role === 'admin') groups.push(['Admin',adminOnly]);
      const items = groups.flatMap(([,links]) => links);
      const key = pageKey(location.href);
      const label = currentLabel(items);
      host.querySelector('.club-current-page').textContent = label;
      menu.replaceChildren();
      const identity = document.createElement('div');
      identity.className = 'club-menu-identity';
      const name = document.createElement('strong');
      name.textContent = profile.full_name || session.user.email || 'Club member';
      const role = document.createElement('small');
      role.textContent = isAdmin ? (profile.role === 'admin' ? 'Admin' : 'Manager') : 'Player';
      identity.append(name, role); menu.append(identity);
      const languageSection = document.createElement('div');
      languageSection.className = 'club-menu-section club-language-section';
      const languageHeading = document.createElement('label');
      languageHeading.className = 'club-menu-heading';
      languageHeading.htmlFor = 'club-language-select';
      languageHeading.textContent = 'Preferred Language';
      const languageSelect = document.createElement('select');
      languageSelect.id = 'club-language-select';
      languageSelect.className = 'club-language-select';
      languageSelect.innerHTML = '<option value="en">English</option><option value="es">Español</option>';
      languageSelect.value = profile.preferred_language || 'en';
      languageSelect.addEventListener('change', async () => {
        const next = languageSelect.value;
        languageSelect.disabled = true;
        const {error:languageError} = await client.rpc('set_my_preferred_language',{p_language:next});
        languageSelect.disabled = false;
        if (languageError) {
          languageSelect.value = profile.preferred_language || 'en';
          alert('Could not save language preference. Please try again.');
          return;
        }
        profile.preferred_language = next;
        window.clubI18n?.setLanguage(next);
      });
      languageSection.append(languageHeading, languageSelect);
      menu.append(languageSection);
      for (const [heading,links] of groups) {
        const section = document.createElement('div');section.className = 'club-menu-section';
        const title = document.createElement('span');title.className = 'club-menu-heading';title.textContent = heading;section.append(title);
        for (const [text,url] of links) {
          const a = document.createElement('a');a.href = path(url);a.textContent = text;
          if (pageKey(a.href) === key) a.setAttribute('aria-current','page');
          section.append(a);
        }
        menu.append(section);
      }
      const logout = document.createElement('button');
      logout.type = 'button';logout.className = 'club-menu-logout';logout.textContent = 'Log Out';
      logout.onclick = async () => {
        logout.disabled = true;
        const {error:signOutError} = await client.auth.signOut();
        if (signOutError) { logout.disabled = false; alert('Could not sign out. Please try again.'); return; }
        location.href = path('index.html');
      };
      menu.append(logout);
      avatar.src = player?.profile_photo_url || fallback;
      host.hidden = false;
      document.body.classList.add('club-header-ready');
      const preferredLanguage = profile.preferred_language || 'en';
      if (window.clubI18n) window.clubI18n.setLanguage(preferredLanguage);
      else {
        const languageScript = document.querySelector('script[data-club-i18n]');
        languageScript?.addEventListener('load', () => window.clubI18n?.setLanguage(preferredLanguage), {once:true});
      }
      const showDock=isAdmin||!!player?.id;
      roleDock.setAttribute('aria-label',isAdmin?'Admin navigation':'Player navigation');
      roleDock.innerHTML=dockItems(isAdmin).map(([icon,text,url,section])=>'<a href="'+path(url)+'" data-section="'+section+'"><span aria-hidden="true">'+icon+'</span><small>'+text+'</small></a>').join('');
      roleDock.hidden=!showDock;
      document.body.classList.toggle('club-role-dock-ready',showDock);
      const activeSection=activeDockSection(isAdmin);
      for(const link of roleDock.querySelectorAll('a')){
        if(link.dataset.section===activeSection)link.setAttribute('aria-current','page');else link.removeAttribute('aria-current');
      }
    };
    window.addEventListener('popstate', () => render().catch(() => {}));
    window.addEventListener('hashchange', () => render().catch(() => {}));
    window.addEventListener('club:routechange', () => render().catch(() => {}));
    client.auth.onAuthStateChange(event => {
      if (event === 'SIGNED_OUT') { close();host.hidden = true;roleDock.hidden=true;document.body.classList.remove('club-header-ready','club-role-dock-ready'); }
      if (event === 'SIGNED_IN' || event === 'USER_UPDATED') setTimeout(() => render().catch(() => {}), 0);
    });
    render().catch(() => {});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
})();
