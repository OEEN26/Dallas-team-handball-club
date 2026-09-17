/* Shared navigation for the existing HTML pages. Include with <script defer src="./header.js"></script>. */
(() => {
  'use strict';
  const root = new URL('./', document.currentScript?.src || location.href);
  const path = name => new URL(name, root).href;
  const fallback = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="32" fill="#153d25"/><circle cx="32" cy="25" r="11" fill="#00c853"/><path d="M12 55c2-13 10-20 20-20s18 7 20 20" fill="#00c853"/></svg>');
  const common = isAdmin => [
    ['Dashboard', isAdmin ? 'index.html' : 'player-dashboard.html'],
    ['Profile', 'profile-settings.html'],
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
      if (error || !session) { close();host.hidden = true;document.body.classList.remove('club-header-ready');return; }
      const {data:profile,error:roleError} = await client.from('profiles').select('role,full_name').eq('id',session.user.id).maybeSingle();
      if (roleError || !profile) return;
      const isAdmin = profile.role === 'admin' || profile.role === 'manager';
      const groups = [['Navigate',common(isAdmin)]];
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
      const {data:player} = await client.from('player_directory_public').select('profile_photo_url').eq('user_id',session.user.id).maybeSingle();
      avatar.src = player?.profile_photo_url || fallback;
      host.hidden = false;
      document.body.classList.add('club-header-ready');
    };
    window.addEventListener('popstate', () => render().catch(() => {}));
    window.addEventListener('hashchange', () => render().catch(() => {}));
    window.addEventListener('club:routechange', () => render().catch(() => {}));
    client.auth.onAuthStateChange(event => {
      if (event === 'SIGNED_OUT') { close();host.hidden = true;document.body.classList.remove('club-header-ready'); }
      if (event === 'SIGNED_IN' || event === 'USER_UPDATED') setTimeout(() => render().catch(() => {}), 0);
    });
    render().catch(() => {});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
})();
