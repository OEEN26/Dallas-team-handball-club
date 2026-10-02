/* Shared account eligibility for dashboard counts and focused admin lists. */
(function (global) {
  const DAY = 86400000;
  async function accounts(sb) {
    const rows = [];
    for (let offset = 0; ; offset += 1000) {
      const result = await sb.from('profiles').select('id,created_at').order('id').range(offset, offset + 999);
      if (result.error) throw new Error('Registered accounts could not be loaded. Please refresh.');
      rows.push(...(result.data || []));
      if ((result.data || []).length < 1000) break;
    }
    return new Map(rows.map(row => [row.id, row]));
  }
  function registered(player, profiles) {
    return player.player_category !== 'Guest' && !player.deleted_at && !!player.user_id && profiles.has(player.user_id);
  }
  function recent(player, profiles, now = Date.now()) {
    const created = Date.parse(profiles.get(player.user_id)?.created_at);
    return registered(player, profiles) && Number.isFinite(created) && created >= now - 30 * DAY && created <= now;
  }
  function incomplete(player) { return !player.position?.trim() || !player.jersey_number || !player.shirt_size?.trim(); }
  function review(playerId, registrations, packets) {
    return registrations.get(playerId)?.status === 'Pending' && packets.has(playerId);
  }
  function banner(parent, label, clearUrl) {
    const section = document.createElement('section');
    section.className = 'card'; section.style.marginBottom = '16px';
    const title = document.createElement('h2'); title.textContent = label;
    const note = document.createElement('p'); note.textContent = 'Registered accounts from the last 30 days that need this action.';
    const link = document.createElement('a'); link.className = 'btn'; link.href = clearUrl; link.textContent = 'Show all';
    section.append(title, note, link); parent.prepend(section);
  }
  global.ClubAttention = { accounts, registered, recent, incomplete, review, banner };
})(globalThis);
