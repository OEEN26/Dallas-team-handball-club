(() => {
  'use strict';
  const dictionaries = {
    es: {
      "Dashboard":"Panel",
      "Profile":"Perfil",
      "Profile Settings":"Configuración del perfil",
      "Events":"Eventos",
      "Tournaments":"Torneos",
      "Membership":"Membresía",
      "Club Operations":"Operaciones del club",
      "Players":"Jugadores",
      "Practices":"Prácticas",
      "Announcements":"Anuncios",
      "Event Management":"Gestión de eventos",
      "Jersey Approvals":"Aprobaciones de uniforme",
      "Tournament Readiness":"Preparación para torneos",
      "Reports":"Reportes",
      "Event Attendance":"Asistencia a eventos",
      "Men’s Roster":"Plantilla masculina",
      "Women’s Roster":"Plantilla femenina",
      "Player View":"Vista del jugador",
      "Admin Management":"Administración",
      "System Logs":"Registros del sistema",
      "Navigate":"Navegar",
      "Manage Club":"Administrar club",
      "Admin":"Administrador",
      "Manager":"Encargado",
      "Player":"Jugador",
      "Log Out":"Cerrar sesión",
      "Home":"Inicio",
      "Schedule":"Calendario",
      "Operations":"Operaciones",
      "Preferred Language":"Idioma preferido",
      "English":"Inglés",
      "Spanish":"Español",
      "Schedule & RSVP":"Calendario y confirmación",
      "Attendance":"Asistencia",
      "Notifications":"Notificaciones",
      "Upcoming Practices":"Próximas prácticas",
      "Upcoming Events":"Próximos eventos",
      "Open Tournament Registration":"Inscripción abierta para torneos",
      "Tell Dallas THC if you want to attend. This is your interest registration, not final roster selection.":"Dile a Dallas THC si quieres asistir. Esto registra tu interés, no es la selección final de la plantilla.",
      "My Event Travel Information":"Mi información de viaje",
      "Membership Status":"Estado de membresía",
      "No upcoming practices.":"No hay próximas prácticas.",
      "No upcoming events.":"No hay próximos eventos.",
      "No notifications.":"No hay notificaciones.",
      "No tournament registration is open right now.":"No hay inscripciones de torneos abiertas en este momento.",
      "Practice":"Práctica",
      "Canceled":"Cancelada",
      "Going":"Voy",
      "Maybe":"Tal vez",
      "Not Going":"No voy",
      "I Want to Go":"Quiero ir",
      "I Can’t Go":"No puedo ir",
      "Create Practice":"Crear práctica",
      "Edit Practice":"Editar práctica",
      "Practice Name":"Nombre de la práctica",
      "First Practice Date":"Fecha de la primera práctica",
      "Team":"Equipo",
      "Start Time":"Hora de inicio",
      "End Time":"Hora de finalización",
      "Repeats":"Se repite",
      "One time":"Una vez",
      "Every week":"Cada semana",
      "Repeat Until":"Repetir hasta",
      "Location / Venue":"Lugar / instalación",
      "Street Address":"Dirección",
      "Practice Information":"Información de la práctica",
      "Apply Edits To":"Aplicar cambios a",
      "This practice only":"Solo esta práctica",
      "This and future practices in this series":"Esta y las prácticas futuras de esta serie",
      "Save Practice":"Guardar práctica",
      "Cancel Edit":"Cancelar edición",
      "Practice Schedule":"Calendario de prácticas",
      "Weekly practices can be canceled individually without removing the rest of the series.":"Las prácticas semanales se pueden cancelar individualmente sin eliminar el resto de la serie.",
      "Weekly":"Semanal",
      "Edit":"Editar",
      "Cancel":"Cancelar",
      "Restore":"Restaurar",
      "Delete":"Eliminar",
      "No practices scheduled.":"No hay prácticas programadas.",
      "Create Announcement":"Crear anuncio",
      "Edit Announcement":"Editar anuncio",
      "Title":"Título",
      "Message":"Mensaje",
      "Audience":"Audiencia",
      "Pinned":"Fijado",
      "Yes":"Sí",
      "No":"No",
      "Save Announcement":"Guardar anuncio",
      "Announcement Board":"Tablero de anuncios",
      "Players see these on their dashboard.":"Los jugadores ven estos anuncios en su panel.",
      "Create Tournament":"Crear torneo",
      "Tournament Roster Manager":"Administrador de plantilla del torneo",
      "Tournament":"Torneo",
      "Team Filter":"Filtro de equipo",
      "All":"Todos",
      "Men":"Hombres",
      "Women":"Mujeres",
      "Add Player":"Agregar jugador",
      "No players waiting to be selected.":"No hay jugadores esperando ser seleccionados.",
      "Needs Attention":"Requiere atención",
      "Attendance Leaders":"Líderes de asistencia",
      "Take Attendance":"Tomar asistencia",
      "Practice Schedule":"Calendario de prácticas",
      "Load Roster":"Cargar plantilla",
      "Mark All Present":"Marcar todos presentes",
      "Roster":"Plantilla",
      "Record Membership Payment":"Registrar pago de membresía",
      "Recent Membership Records":"Registros recientes de membresía",
      "Send In-App Notification":"Enviar notificación",
      "Recent Notifications":"Notificaciones recientes",
      "Club snapshot":"Resumen del club",
      "Needs your attention":"Requiere tu atención",
      "What’s next":"Lo próximo",
      "Quick admin tools":"Herramientas rápidas de administración",
      "Where do you want to go?":"¿A dónde quieres ir?",
      "Your next activities":"Tus próximas actividades",
      "Open tournaments":"Torneos abiertos",
      "Club announcements":"Anuncios del club",
      "My status":"Mi estado",
      "Player directory":"Directorio de jugadores",
      "Full schedule":"Calendario completo",
      "Update my profile":"Actualizar mi perfil",
      "Membership Paid":"Membresía pagada",
      "Active Players":"Jugadores activos",
      "New Players":"Jugadores nuevos",
      "Next Practice":"Próxima práctica",
      "Upcoming Events":"Próximos eventos",
      "Tournament Roster":"Plantilla del torneo",
      "Refresh":"Actualizar"
    }
  };

  const originals = new WeakMap();
  let current = 'en';
  let applying = false;

  function translateText(value, lang) {
    if (lang === 'en') return value;
    const dict = dictionaries[lang] || {};
    const trimmed = value.trim();
    if (!trimmed) return value;
    const translated = dict[trimmed];
    if (!translated) return value;
    const lead = value.match(/^\s*/)?.[0] || '';
    const tail = value.match(/\s*$/)?.[0] || '';
    return lead + translated + tail;
  }

  function translateElement(el, lang) {
    if (!el || el.closest?.('[data-no-translate]')) return;
    if (['SCRIPT','STYLE','NOSCRIPT'].includes(el.tagName)) return;

    for (const attr of ['placeholder','aria-label','title']) {
      if (el.hasAttribute?.(attr)) {
        let map = originals.get(el);
        if (!map) { map = {}; originals.set(el, map); }
        if (!(attr in map)) map[attr] = el.getAttribute(attr);
        const original = map[attr];
        const next = translateText(original, lang);
        if (el.getAttribute(attr) !== next) el.setAttribute(attr, next);
      }
    }

    for (const node of el.childNodes || []) {
      if (node.nodeType !== Node.TEXT_NODE) continue;
      let map = originals.get(node);
      if (!map) { map = {text: node.nodeValue}; originals.set(node, map); }
      const next = translateText(map.text, lang);
      if (node.nodeValue !== next) node.nodeValue = next;
    }
  }

  function apply(lang = current) {
    if (applying) return;
    applying = true;
    current = dictionaries[lang] ? lang : 'en';
    document.documentElement.lang = current;
    document.querySelectorAll('body *').forEach(el => translateElement(el, current));
    applying = false;
    window.dispatchEvent(new CustomEvent('club:languagechanged',{detail:{language:current}}));
  }

  const observer = new MutationObserver(mutations => {
    if (applying) return;
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          translateElement(node, current);
          node.querySelectorAll?.('*').forEach(el => translateElement(el, current));
        } else if (node.nodeType === Node.TEXT_NODE && node.parentElement) {
          translateElement(node.parentElement, current);
        }
      }
    }
  });

  function start() {
    observer.observe(document.body,{childList:true,subtree:true});
    apply(current);
  }

  window.clubI18n = {
    setLanguage(lang) { apply(lang); },
    getLanguage() { return current; },
    supported: ['en','es']
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
})();
