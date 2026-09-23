// Render earned season awards as a compact collection on player profiles.
window.renderSeasonMedals = function (container, awards) {
  if (!container) return;
  container.replaceChildren();
  container.hidden = !awards?.length;
  for (const award of awards || []) {
    const custom = award.type === 'custom';
    const start = award.starts_on?.slice(0, 4);
    const end = award.ends_on?.slice(0, 4);
    const season = start && end ? start + ' - ' + end : award.season_name;
    const isFirstDesign = start === '2026' && end === '2027';
    const medal = document.createElement('span');
    medal.className = 'season-medal';
    medal.setAttribute('role', 'button');
    medal.setAttribute('tabindex', '0');
    medal.setAttribute('aria-expanded', 'false');
    medal.setAttribute('aria-label', (custom ? award.title : award.season_name + ' season medal') + '. Show details');
    if (custom && award.image_url) {
      const image = document.createElement('img');
      image.className = 'season-medal-art';
      image.src = award.image_url;
      image.alt = '';
      image.setAttribute('aria-hidden', 'true');
      medal.append(image);
    } else if (isFirstDesign && !custom) {
      const image = document.createElement('img');
      image.className = 'season-medal-art';
      image.src = './season-medal-2026-27.svg?v=20260923b';
      image.alt = '';
      image.setAttribute('aria-hidden', 'true');
      medal.append(image);
    } else {
      const fallback = document.createElement('span');
      fallback.className = 'season-medal-generic';
      fallback.setAttribute('aria-hidden', 'true');
      fallback.textContent = '🏅';
      medal.append(fallback);
    }
    const info = document.createElement('span');
    info.className = 'season-medal-info';
    info.hidden = true;
    info.textContent = custom ? award.title + ' — ' + award.description : 'for participating in the season of ' + season;
    medal.append(info);
    const toggle = event => {
      event.preventDefault();
      event.stopPropagation();
      document.querySelectorAll('.season-medal[aria-expanded="true"]').forEach(other => {
        if (other !== medal) {
          other.setAttribute('aria-expanded', 'false');
          other.querySelector('.season-medal-info').hidden = true;
        }
      });
      info.hidden = !info.hidden;
      medal.setAttribute('aria-expanded', String(!info.hidden));
    };
    medal.addEventListener('click', toggle);
    medal.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') toggle(event);
    });
    container.append(medal);
  }
};

// Only enabled, unrevoked custom awards can appear on player cards.
window.loadCustomMedals = async function (client) {
  const [catalog, grants] = await Promise.all([
    client.from('award_definitions').select('id,title,description,image_path').eq('is_active',true),
    client.from('award_grants').select('player_id,award_id,granted_at').is('revoked_at',null)
  ]);
  if (catalog.error || grants.error) {
    console.warn('Custom awards unavailable',catalog.error||grants.error);
    return [];
  }
  const byId = new Map((catalog.data||[]).map(item=>[item.id,item]));
  return (grants.data||[]).map(grant=>{
    const award=byId.get(grant.award_id);
    if (!award) return null;
    return {type:'custom',player_id:grant.player_id,title:award.title,description:award.description,
      image_url:award.image_path?client.storage.from('award-media').getPublicUrl(award.image_path).data.publicUrl:null,
      awarded_at:grant.granted_at};
  }).filter(Boolean).sort((a,b)=>new Date(b.awarded_at)-new Date(a.awarded_at));
};
