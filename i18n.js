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
    },
    fr: {
      "Dashboard":"Tableau de bord","Profile":"Profil","Profile Settings":"Paramètres du profil","Events":"Événements","Tournaments":"Tournois","Membership":"Adhésion","Players":"Joueurs","Practices":"Entraînements","Announcements":"Annonces","Tournament Readiness":"Préparation au tournoi","Reports":"Rapports","Attendance":"Présence","Home":"Accueil","Schedule":"Calendrier","Operations":"Opérations","Preferred Language":"Langue préférée","Log Out":"Se déconnecter","Player":"Joueur","Manager":"Responsable","Admin":"Administrateur","Practice":"Entraînement","Canceled":"Annulé","Going":"J’y vais","Maybe":"Peut-être","Not Going":"Je n’y vais pas","I Want to Go":"Je veux y aller","I Can’t Go":"Je ne peux pas y aller","Create Practice":"Créer un entraînement","Edit Practice":"Modifier l’entraînement","Practice Name":"Nom de l’entraînement","First Practice Date":"Date du premier entraînement","Team":"Équipe","Start Time":"Heure de début","End Time":"Heure de fin","Repeats":"Répétition","One time":"Une fois","Every week":"Chaque semaine","Repeat Until":"Répéter jusqu’au","Location / Venue":"Lieu","Street Address":"Adresse","Practice Information":"Informations sur l’entraînement","Save Practice":"Enregistrer","Cancel Edit":"Annuler la modification","Weekly":"Hebdomadaire","Edit":"Modifier","Cancel":"Annuler","Restore":"Restaurer","Delete":"Supprimer","Tournament":"Tournoi","Team Filter":"Filtre d’équipe","All":"Tous","Men":"Hommes","Women":"Femmes","Add Player":"Ajouter un joueur","Roster":"Effectif","Notifications":"Notifications","Refresh":"Actualiser"
    },
    de: {
      "Dashboard":"Übersicht","Profile":"Profil","Profile Settings":"Profileinstellungen","Events":"Veranstaltungen","Tournaments":"Turniere","Membership":"Mitgliedschaft","Players":"Spieler","Practices":"Training","Announcements":"Ankündigungen","Tournament Readiness":"Turniervorbereitung","Reports":"Berichte","Attendance":"Anwesenheit","Home":"Start","Schedule":"Kalender","Operations":"Verwaltung","Preferred Language":"Bevorzugte Sprache","Log Out":"Abmelden","Player":"Spieler","Manager":"Manager","Admin":"Admin","Practice":"Training","Canceled":"Abgesagt","Going":"Dabei","Maybe":"Vielleicht","Not Going":"Nicht dabei","I Want to Go":"Ich möchte teilnehmen","I Can’t Go":"Ich kann nicht teilnehmen","Create Practice":"Training erstellen","Edit Practice":"Training bearbeiten","Practice Name":"Trainingsname","First Practice Date":"Erster Trainingstag","Team":"Team","Start Time":"Startzeit","End Time":"Endzeit","Repeats":"Wiederholt sich","One time":"Einmalig","Every week":"Jede Woche","Repeat Until":"Wiederholen bis","Location / Venue":"Ort","Street Address":"Adresse","Practice Information":"Trainingsinformationen","Save Practice":"Training speichern","Cancel Edit":"Bearbeitung abbrechen","Weekly":"Wöchentlich","Edit":"Bearbeiten","Cancel":"Absagen","Restore":"Wiederherstellen","Delete":"Löschen","Tournament":"Turnier","Team Filter":"Teamfilter","All":"Alle","Men":"Herren","Women":"Damen","Add Player":"Spieler hinzufügen","Roster":"Kader","Notifications":"Benachrichtigungen","Refresh":"Aktualisieren"
    },
    uk: {
      "Dashboard":"Панель","Profile":"Профіль","Profile Settings":"Налаштування профілю","Events":"Події","Tournaments":"Турніри","Membership":"Членство","Players":"Гравці","Practices":"Тренування","Announcements":"Оголошення","Tournament Readiness":"Готовність до турніру","Reports":"Звіти","Attendance":"Відвідуваність","Home":"Головна","Schedule":"Розклад","Operations":"Операції","Preferred Language":"Бажана мова","Log Out":"Вийти","Player":"Гравець","Manager":"Менеджер","Admin":"Адмін","Practice":"Тренування","Canceled":"Скасовано","Going":"Буду","Maybe":"Можливо","Not Going":"Не буду","I Want to Go":"Хочу поїхати","I Can’t Go":"Не можу поїхати","Create Practice":"Створити тренування","Edit Practice":"Редагувати тренування","Practice Name":"Назва тренування","First Practice Date":"Дата першого тренування","Team":"Команда","Start Time":"Час початку","End Time":"Час завершення","Repeats":"Повторюється","One time":"Один раз","Every week":"Щотижня","Repeat Until":"Повторювати до","Location / Venue":"Місце","Street Address":"Адреса","Practice Information":"Інформація про тренування","Save Practice":"Зберегти тренування","Cancel Edit":"Скасувати редагування","Weekly":"Щотижня","Edit":"Редагувати","Cancel":"Скасувати","Restore":"Відновити","Delete":"Видалити","Tournament":"Турнір","Team Filter":"Фільтр команди","All":"Усі","Men":"Чоловіки","Women":"Жінки","Add Player":"Додати гравця","Roster":"Склад","Notifications":"Сповіщення","Refresh":"Оновити"
    },
    pl: {
      "Dashboard":"Panel","Profile":"Profil","Profile Settings":"Ustawienia profilu","Events":"Wydarzenia","Tournaments":"Turnieje","Membership":"Członkostwo","Players":"Zawodnicy","Practices":"Treningi","Announcements":"Ogłoszenia","Tournament Readiness":"Gotowość do turnieju","Reports":"Raporty","Attendance":"Frekwencja","Home":"Start","Schedule":"Harmonogram","Operations":"Operacje","Preferred Language":"Preferowany język","Log Out":"Wyloguj","Player":"Zawodnik","Manager":"Menedżer","Admin":"Administrator","Practice":"Trening","Canceled":"Odwołany","Going":"Będę","Maybe":"Może","Not Going":"Nie będę","I Want to Go":"Chcę jechać","I Can’t Go":"Nie mogę jechać","Create Practice":"Utwórz trening","Edit Practice":"Edytuj trening","Practice Name":"Nazwa treningu","First Practice Date":"Data pierwszego treningu","Team":"Drużyna","Start Time":"Godzina rozpoczęcia","End Time":"Godzina zakończenia","Repeats":"Powtarza się","One time":"Jednorazowo","Every week":"Co tydzień","Repeat Until":"Powtarzaj do","Location / Venue":"Miejsce","Street Address":"Adres","Practice Information":"Informacje o treningu","Save Practice":"Zapisz trening","Cancel Edit":"Anuluj edycję","Weekly":"Co tydzień","Edit":"Edytuj","Cancel":"Odwołaj","Restore":"Przywróć","Delete":"Usuń","Tournament":"Turniej","Team Filter":"Filtr drużyny","All":"Wszyscy","Men":"Mężczyźni","Women":"Kobiety","Add Player":"Dodaj zawodnika","Roster":"Skład","Notifications":"Powiadomienia","Refresh":"Odśwież"
    },
    no: {
      "Dashboard":"Dashbord","Profile":"Profil","Profile Settings":"Profilinnstillinger","Events":"Arrangementer","Tournaments":"Turneringer","Membership":"Medlemskap","Players":"Spillere","Practices":"Treninger","Announcements":"Kunngjøringer","Tournament Readiness":"Turneringsklar","Reports":"Rapporter","Attendance":"Oppmøte","Home":"Hjem","Schedule":"Plan","Operations":"Drift","Preferred Language":"Foretrukket språk","Log Out":"Logg ut","Player":"Spiller","Manager":"Leder","Admin":"Admin","Practice":"Trening","Canceled":"Avlyst","Going":"Kommer","Maybe":"Kanskje","Not Going":"Kommer ikke","I Want to Go":"Jeg vil delta","I Can’t Go":"Jeg kan ikke delta","Create Practice":"Opprett trening","Edit Practice":"Rediger trening","Practice Name":"Treningsnavn","First Practice Date":"Første treningsdato","Team":"Lag","Start Time":"Starttid","End Time":"Sluttid","Repeats":"Gjentas","One time":"Én gang","Every week":"Hver uke","Repeat Until":"Gjenta til","Location / Venue":"Sted","Street Address":"Adresse","Practice Information":"Treningsinformasjon","Save Practice":"Lagre trening","Cancel Edit":"Avbryt redigering","Weekly":"Ukentlig","Edit":"Rediger","Cancel":"Avlys","Restore":"Gjenopprett","Delete":"Slett","Tournament":"Turnering","Team Filter":"Lagfilter","All":"Alle","Men":"Menn","Women":"Kvinner","Add Player":"Legg til spiller","Roster":"Tropp","Notifications":"Varsler","Refresh":"Oppdater"
    },
    hi: {
      "Dashboard":"डैशबोर्ड","Profile":"प्रोफ़ाइल","Profile Settings":"प्रोफ़ाइल सेटिंग्स","Events":"कार्यक्रम","Tournaments":"टूर्नामेंट","Membership":"सदस्यता","Players":"खिलाड़ी","Practices":"अभ्यास","Announcements":"घोषणाएँ","Tournament Readiness":"टूर्नामेंट तैयारी","Reports":"रिपोर्ट","Attendance":"उपस्थिति","Home":"होम","Schedule":"शेड्यूल","Operations":"संचालन","Preferred Language":"पसंदीदा भाषा","Log Out":"लॉग आउट","Player":"खिलाड़ी","Manager":"प्रबंधक","Admin":"एडमिन","Practice":"अभ्यास","Canceled":"रद्द","Going":"आ रहा हूँ","Maybe":"शायद","Not Going":"नहीं आ रहा","I Want to Go":"मैं जाना चाहता हूँ","I Can’t Go":"मैं नहीं जा सकता","Create Practice":"अभ्यास बनाएँ","Edit Practice":"अभ्यास संपादित करें","Practice Name":"अभ्यास का नाम","First Practice Date":"पहली अभ्यास तिथि","Team":"टीम","Start Time":"शुरू होने का समय","End Time":"समाप्ति समय","Repeats":"दोहराव","One time":"एक बार","Every week":"हर सप्ताह","Repeat Until":"यहाँ तक दोहराएँ","Location / Venue":"स्थान","Street Address":"पता","Practice Information":"अभ्यास जानकारी","Save Practice":"अभ्यास सहेजें","Cancel Edit":"संपादन रद्द करें","Weekly":"साप्ताहिक","Edit":"संपादित करें","Cancel":"रद्द करें","Restore":"बहाल करें","Delete":"हटाएँ","Tournament":"टूर्नामेंट","Team Filter":"टीम फ़िल्टर","All":"सभी","Men":"पुरुष","Women":"महिलाएँ","Add Player":"खिलाड़ी जोड़ें","Roster":"रोस्टर","Notifications":"सूचनाएँ","Refresh":"रीफ़्रेश"
    },
    tr: {
      "Dashboard":"Panel","Profile":"Profil","Profile Settings":"Profil Ayarları","Events":"Etkinlikler","Tournaments":"Turnuvalar","Membership":"Üyelik","Players":"Oyuncular","Practices":"Antrenmanlar","Announcements":"Duyurular","Tournament Readiness":"Turnuva Hazırlığı","Reports":"Raporlar","Attendance":"Katılım","Home":"Ana Sayfa","Schedule":"Takvim","Operations":"Operasyonlar","Preferred Language":"Tercih Edilen Dil","Log Out":"Çıkış Yap","Player":"Oyuncu","Manager":"Yönetici","Admin":"Admin","Practice":"Antrenman","Canceled":"İptal edildi","Going":"Geliyorum","Maybe":"Belki","Not Going":"Gelmiyorum","I Want to Go":"Gitmek istiyorum","I Can’t Go":"Gidemem","Create Practice":"Antrenman oluştur","Edit Practice":"Antrenmanı düzenle","Practice Name":"Antrenman adı","First Practice Date":"İlk antrenman tarihi","Team":"Takım","Start Time":"Başlangıç saati","End Time":"Bitiş saati","Repeats":"Tekrar","One time":"Bir kez","Every week":"Her hafta","Repeat Until":"Şu tarihe kadar tekrarla","Location / Venue":"Konum","Street Address":"Adres","Practice Information":"Antrenman bilgisi","Save Practice":"Antrenmanı kaydet","Cancel Edit":"Düzenlemeyi iptal et","Weekly":"Haftalık","Edit":"Düzenle","Cancel":"İptal et","Restore":"Geri yükle","Delete":"Sil","Tournament":"Turnuva","Team Filter":"Takım filtresi","All":"Tümü","Men":"Erkekler","Women":"Kadınlar","Add Player":"Oyuncu ekle","Roster":"Kadro","Notifications":"Bildirimler","Refresh":"Yenile"
    },
    ar: {
      "Dashboard":"لوحة التحكم","Profile":"الملف الشخصي","Profile Settings":"إعدادات الملف الشخصي","Events":"الفعاليات","Tournaments":"البطولات","Membership":"العضوية","Players":"اللاعبون","Practices":"التدريبات","Announcements":"الإعلانات","Tournament Readiness":"الاستعداد للبطولة","Reports":"التقارير","Attendance":"الحضور","Home":"الرئيسية","Schedule":"الجدول","Operations":"العمليات","Preferred Language":"اللغة المفضلة","Log Out":"تسجيل الخروج","Player":"لاعب","Manager":"مدير","Admin":"مسؤول","Practice":"تدريب","Canceled":"ملغى","Going":"سأحضر","Maybe":"ربما","Not Going":"لن أحضر","I Want to Go":"أريد الذهاب","I Can’t Go":"لا أستطيع الذهاب","Create Practice":"إنشاء تدريب","Edit Practice":"تعديل التدريب","Practice Name":"اسم التدريب","First Practice Date":"تاريخ أول تدريب","Team":"الفريق","Start Time":"وقت البدء","End Time":"وقت الانتهاء","Repeats":"التكرار","One time":"مرة واحدة","Every week":"كل أسبوع","Repeat Until":"التكرار حتى","Location / Venue":"الموقع","Street Address":"العنوان","Practice Information":"معلومات التدريب","Save Practice":"حفظ التدريب","Cancel Edit":"إلغاء التعديل","Weekly":"أسبوعي","Edit":"تعديل","Cancel":"إلغاء","Restore":"استعادة","Delete":"حذف","Tournament":"البطولة","Team Filter":"تصفية الفريق","All":"الكل","Men":"رجال","Women":"نساء","Add Player":"إضافة لاعب","Roster":"القائمة","Notifications":"الإشعارات","Refresh":"تحديث"
    },
    pt: {
      "Dashboard":"Painel","Profile":"Perfil","Profile Settings":"Configurações do perfil","Events":"Eventos","Tournaments":"Torneios","Membership":"Associação","Players":"Jogadores","Practices":"Treinos","Announcements":"Anúncios","Tournament Readiness":"Preparação para torneio","Reports":"Relatórios","Attendance":"Presença","Home":"Início","Schedule":"Agenda","Operations":"Operações","Preferred Language":"Idioma preferido","Log Out":"Sair","Player":"Jogador","Manager":"Gerente","Admin":"Admin","Practice":"Treino","Canceled":"Cancelado","Going":"Vou","Maybe":"Talvez","Not Going":"Não vou","I Want to Go":"Quero ir","I Can’t Go":"Não posso ir","Create Practice":"Criar treino","Edit Practice":"Editar treino","Practice Name":"Nome do treino","First Practice Date":"Data do primeiro treino","Team":"Equipe","Start Time":"Horário de início","End Time":"Horário de término","Repeats":"Repetição","One time":"Uma vez","Every week":"Toda semana","Repeat Until":"Repetir até","Location / Venue":"Local","Street Address":"Endereço","Practice Information":"Informações do treino","Save Practice":"Salvar treino","Cancel Edit":"Cancelar edição","Weekly":"Semanal","Edit":"Editar","Cancel":"Cancelar","Restore":"Restaurar","Delete":"Excluir","Tournament":"Torneio","Team Filter":"Filtro de equipe","All":"Todos","Men":"Homens","Women":"Mulheres","Add Player":"Adicionar jogador","Roster":"Elenco","Notifications":"Notificações","Refresh":"Atualizar"
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
    document.documentElement.dir = current === 'ar' ? 'rtl' : 'ltr';
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
    supported: ['en','es','fr','de','uk','pl','no','hi','tr','ar','pt']
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
})();
