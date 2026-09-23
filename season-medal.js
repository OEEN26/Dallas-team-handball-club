// Enhances season badges on player profiles and directory cards.
window.decorateSeasonMedals = function () {
  document.querySelectorAll('.season-medal:not([data-medal-ready])').forEach(medal => {
    if (medal.hidden) return;
    medal.dataset.medalReady = 'true';
    medal.setAttribute('role', 'button');
    medal.setAttribute('tabindex', '0');
    medal.setAttribute('aria-expanded', 'false');
    medal.setAttribute('aria-label', '2026–2027 season medal. Show details');
    medal.innerHTML = '<img class="season-medal-art" src="./season-medal-2026-27.svg?v=20260923b" alt="" aria-hidden="true"><span class="season-medal-info" hidden>for participating in the season of 2026 - 2027</span>';
    const toggle = event => {
      event.preventDefault();
      event.stopPropagation();
      const info = medal.querySelector('.season-medal-info');
      info.hidden = !info.hidden;
      medal.setAttribute('aria-expanded', String(!info.hidden));
    };
    medal.addEventListener('click', toggle);
    medal.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') toggle(event);
    });
  });
};
