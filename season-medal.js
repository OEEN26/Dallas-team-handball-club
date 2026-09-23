// Render earned season awards as a compact collection on player profiles.
window.renderSeasonMedals = function (container, awards) {
  if (!container) return;
  container.replaceChildren();
  container.hidden = !awards?.length;
  for (const award of awards || []) {
    const start = award.starts_on?.slice(0, 4);
    const end = award.ends_on?.slice(0, 4);
    const season = start && end ? start + ' - ' + end : award.season_name;
    const isFirstDesign = start === '2026' && end === '2027';
    const medal = document.createElement('span');
    medal.className = 'season-medal';
    medal.setAttribute('role', 'button');
    medal.setAttribute('tabindex', '0');
    medal.setAttribute('aria-expanded', 'false');
    medal.setAttribute('aria-label', award.season_name + ' season medal. Show details');
    if (isFirstDesign) {
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
    info.textContent = 'for participating in the season of ' + season;
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
