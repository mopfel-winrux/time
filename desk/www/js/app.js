// Time – Main SPA
// Hash-based routing with month/week/day/agenda views

const App = {
  currentDate: new Date(),
  calendars: [],
  events: [],
  settings: {},
  subscriptions: [],
  selectedCalendars: new Set(),

  async init() {
    this.initTheme();
    window.addEventListener('hashchange', () => this.route());
    window.addEventListener('calendar-state-changed', () => this.refresh());
    await this.loadData();
    this.route();
  },

  initTheme() {
    let t = localStorage.getItem('time-theme');
    if (!t) t = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', t);
  },

  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('time-theme', next);
    this.route();
  },

  async loadData() {
    try {
      const [calData, settingsData, subData] = await Promise.all([
        CalendarAPI.getCalendars(),
        CalendarAPI.getSettings(),
        CalendarAPI.getSubscriptions()
      ]);
      this.calendars = calData.calendars || [];
      this.settings = settingsData;
      this.subscriptions = subData.subscriptions || [];
      this.selectedCalendars = new Set(this.calendars.map(c => c.id));
    } catch (e) {
      console.error('Failed to load data:', e);
    }
  },

  async refresh() {
    await this.loadData();
    this.route();
  },

  route() {
    const hash = location.hash || '#/';
    const app = document.getElementById('app');
    const parts = hash.slice(2).split('/');
    const view = parts[0] || 'month';

    // Public booking page - no auth needed
    if (view === 'book') {
      BookingPage.render(app, parts[1] || '');
      return;
    }

    app.innerHTML = `
      ${this.renderNav(view)}
      <div class="main-layout">
        ${this.renderSidebar(view)}
        <div class="content" id="content"></div>
      </div>
    `;

    const content = document.getElementById('content');

    switch (view) {
      case 'month': this.renderMonth(content); break;
      case 'week': this.renderWeek(content); break;
      case 'day': this.renderDay(content); break;
      case 'agenda': this.renderAgenda(content); break;
      case 'calendars': this.renderCalendars(content); break;
      case 'event': this.renderEventDetail(content, parts[1]); break;
      case 'booking-types': this.renderBookingTypes(content); break;
      case 'availability': this.renderAvailability(content); break;
      case 'bookings': this.renderBookings(content); break;
      case 'settings': this.renderSettings(content); break;
      case 'import': this.renderImport(content); break;
      case 'subscriptions': this.renderSubscriptions(content); break;
      default: this.renderMonth(content);
    }
  },

  renderNav(activeView) {
    const views = [
      { id: 'month', label: 'Month' },
      { id: 'week', label: 'Week' },
      { id: 'day', label: 'Day' },
      { id: 'agenda', label: 'Agenda' }
    ];
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    return `
      <nav class="nav">
        <div class="nav-period">
          <button onclick="App.prevPeriod()" class="btn-icon">&larr;</button>
          <button onclick="App.goToday()" class="btn-sm">Today</button>
          <button onclick="App.nextPeriod()" class="btn-icon">&rarr;</button>
          <h1 class="nav-title">${this.formatCurrentDate(activeView)}</h1>
        </div>
        <div class="nav-controls">
          <div class="nav-views">
            ${views.map(v => `
              <a href="#/${v.id}" class="view-btn ${activeView === v.id ? 'is-active' : ''}">${v.label}</a>
            `).join('')}
          </div>
          <button onclick="App.showCreateEvent()" class="btn-primary">New event</button>
          <button onclick="App.toggleTheme()" class="theme-toggle">${isDark ? 'Light' : 'Dark'}</button>
        </div>
      </nav>
    `;
  },

  renderSidebar(activeView) {
    const links = [
      { id: 'calendars', label: 'Calendars' },
      { id: 'booking-types', label: 'Booking Types' },
      { id: 'availability', label: 'Availability' },
      { id: 'bookings', label: 'Bookings' },
      { id: 'import', label: 'Import' },
      { id: 'subscriptions', label: 'Subscriptions' },
      { id: 'settings', label: 'Settings' }
    ];
    return `
      <aside class="sidebar">
        <nav class="sidebar-nav">
          ${links.map(l => `
            <a href="#/${l.id}" class="sidebar-link ${activeView === l.id ? 'is-active' : ''}">${l.label}</a>
          `).join('')}
        </nav>
        <div class="sidebar-calendars">
          <span class="sidebar-label">Calendars</span>
          ${this.calendars.map(c => {
            const isSub = this.subscriptions.some(s => s['calendar-id'] === c.id);
            return `
            <label class="cal-toggle">
              <input type="checkbox" ${this.selectedCalendars.has(c.id) ? 'checked' : ''}
                onchange="App.toggleCalendar('${c.id}')">
              <span class="cal-dot" style="background:${this.hexColor(c.color)}"></span>
              ${this.esc(c.name)}
              ${isSub ? '<span class="cal-sync-icon" title="Subscribed">&#8635;</span>' : ''}
            </label>`;
          }).join('')}
        </div>
      </aside>
    `;
  },

  // Calendar grid views

  async renderMonth(el) {
    const events = await this.loadEvents();
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const startDow = firstDay.getDay();
    const totalDays = lastDay.getDate();
    const gridStart = new Date(firstDay);
    gridStart.setDate(gridStart.getDate() - startDow);

    let html = '<div class="month-grid"><div class="month-header">';
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    dayNames.forEach(d => html += `<div class="month-day-name">${d}</div>`);
    html += '</div><div class="month-body">';

    for (let i = 0; i < 42; i++) {
      const date = new Date(gridStart);
      date.setDate(date.getDate() + i);
      const isToday = this.isSameDay(date, new Date());
      const isMonth = date.getMonth() === month;
      const dayStart = Math.floor(date.getTime() / 1000);
      const dayEnd = dayStart + 86400;
      const dayEvents = events.filter(e =>
        e.start < dayEnd && e.end > dayStart
      );

      html += `
        <div class="month-cell ${isToday ? 'is-today' : ''} ${isMonth ? '' : 'is-outside'}"
             onclick="App.showCreateEventAt(${dayStart})">
          <div class="month-date">${date.getDate()}</div>
          ${dayEvents.slice(0, 3).map(e => {
            const cal = this.calendars.find(c => c.id === e['calendar-id']);
            const color = cal ? this.hexColor(cal.color) : '#d4600a';
            const time = e['all-day'] ? '' : `<span class="month-event-time">${this.formatTime(e.start)}</span> `;
            return `<a href="#/event/${e.id}" class="month-event" onclick="event.stopPropagation()">
                      <span class="month-event-dot" style="background:${color}"></span>
                      ${time}${this.esc(e.title)}</a>`;
          }).join('')}
          ${dayEvents.length > 3 ? `<div class="month-overflow">+${dayEvents.length - 3} more</div>` : ''}
        </div>
      `;
    }
    html += '</div></div>';
    el.innerHTML = html;
  },

  async renderWeek(el) {
    const events = await this.loadEvents();
    const startOfWeek = new Date(this.currentDate);
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    let html = '<div class="week-grid">';
    html += '<div class="week-header"><div class="week-gutter"></div>';
    for (let d = 0; d < 7; d++) {
      const date = new Date(startOfWeek);
      date.setDate(date.getDate() + d);
      const isToday = this.isSameDay(date, new Date());
      html += `<div class="week-day-head ${isToday ? 'is-today' : ''}">
        ${['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d]} ${date.getDate()}
      </div>`;
    }
    html += '</div><div class="week-body">';

    // Time labels
    html += '<div class="week-times">';
    for (let h = 0; h < 24; h++) {
      html += `<div class="week-time">${h === 0 ? '12 AM' : h < 12 ? h + ' AM' : h === 12 ? '12 PM' : (h-12) + ' PM'}</div>`;
    }
    html += '</div>';

    for (let d = 0; d < 7; d++) {
      const date = new Date(startOfWeek);
      date.setDate(date.getDate() + d);
      const dayStart = Math.floor(date.getTime() / 1000);
      const dayEnd = dayStart + 86400;
      const dayEvents = events.filter(e => e.start < dayEnd && e.end > dayStart);

      html += '<div class="week-col">';
      for (let h = 0; h < 24; h++) {
        html += `<div class="week-hour" onclick="App.showCreateEventAt(${dayStart + h * 3600})"></div>`;
      }
      dayEvents.forEach(e => {
        const eStart = Math.max(e.start, dayStart);
        const eEnd = Math.min(e.end, dayEnd);
        const top = ((eStart - dayStart) / 3600) * 60;
        const height = Math.max(((eEnd - eStart) / 3600) * 60, 20);
        const cal = this.calendars.find(c => c.id === e['calendar-id']);
        const color = cal ? this.hexColor(cal.color) : '#d4600a';
        html += `<a href="#/event/${e.id}" class="week-event" style="top:${top}px;height:${height}px;--event-color:${color}"
                    onclick="event.stopPropagation()">
          <span class="week-event-title">${this.esc(e.title)}</span>
          <span class="week-event-time">${this.formatTime(e.start)}</span>
        </a>`;
      });
      html += '</div>';
    }
    html += '</div></div>';
    el.innerHTML = html;
  },

  async renderDay(el) {
    const events = await this.loadEvents();
    const dayStart = Math.floor(new Date(this.currentDate.getFullYear(), this.currentDate.getMonth(), this.currentDate.getDate()).getTime() / 1000);
    const dayEnd = dayStart + 86400;
    const dayEvents = events.filter(e => e.start < dayEnd && e.end > dayStart);

    let html = '<div class="day-grid"><div class="day-body">';
    html += '<div class="week-times">';
    for (let h = 0; h < 24; h++) {
      html += `<div class="week-time">${h === 0 ? '12 AM' : h < 12 ? h + ' AM' : h === 12 ? '12 PM' : (h-12) + ' PM'}</div>`;
    }
    html += '</div><div class="day-column">';
    for (let h = 0; h < 24; h++) {
      html += `<div class="week-hour" onclick="App.showCreateEventAt(${dayStart + h * 3600})"></div>`;
    }
    dayEvents.forEach(e => {
      const eStart = Math.max(e.start, dayStart);
      const eEnd = Math.min(e.end, dayEnd);
      const top = ((eStart - dayStart) / 3600) * 60;
      const height = Math.max(((eEnd - eStart) / 3600) * 60, 20);
      const cal = this.calendars.find(c => c.id === e['calendar-id']);
      const color = cal ? this.hexColor(cal.color) : '#d4600a';
      html += `<a href="#/event/${e.id}" class="day-event" style="top:${top}px;height:${height}px;--event-color:${color}"
                  onclick="event.stopPropagation()">
        <span class="day-event-title">${this.esc(e.title)}</span>
        <span class="day-event-time">${this.formatTime(e.start)} - ${this.formatTime(e.end)}</span>
      </a>`;
    });
    html += '</div></div></div>';
    el.innerHTML = html;
  },

  async renderAgenda(el) {
    const events = await this.loadEvents();
    events.sort((a, b) => a.start - b.start);
    const upcoming = events.filter(e => e.end > Math.floor(Date.now() / 1000));

    let html = '<div class="agenda-list">';
    if (upcoming.length === 0) {
      html += '<p class="empty">No upcoming events</p>';
    }
    let lastDate = '';
    upcoming.forEach(e => {
      const d = new Date(e.start * 1000).toLocaleDateString();
      if (d !== lastDate) {
        html += `<div class="agenda-date">${d}</div>`;
        lastDate = d;
      }
      const cal = this.calendars.find(c => c.id === e['calendar-id']);
      const color = cal ? this.hexColor(cal.color) : '#d4600a';
      html += `
        <a href="#/event/${e.id}" class="agenda-event">
          <span class="agenda-dot" style="background:${color}"></span>
          <div class="agenda-info">
            <div class="agenda-title">${this.esc(e.title)}</div>
            <div class="agenda-time">${this.formatTime(e.start)} - ${this.formatTime(e.end)}</div>
          </div>
        </a>
      `;
    });
    html += '</div>';
    el.innerHTML = html;
  },

  // Management views

  async renderCalendars(el) {
    el.innerHTML = `
      <div class="manage">
        <div class="manage-head">
          <h2>Calendars</h2>
          <button onclick="App.showCreateCalendar()" class="btn-primary">New calendar</button>
        </div>
        <div class="manage-items">
          ${this.calendars.map(c => `
            <div class="manage-item">
              <span class="cal-dot" style="background:${this.hexColor(c.color)}"></span>
              <div class="manage-body">
                <div class="manage-name">${this.esc(c.name)}</div>
                <div class="manage-meta">${c['event-count'] || 0} events</div>
              </div>
              <div class="manage-actions">
                <button onclick="App.editCalendar('${c.id}')" class="btn-sm">Edit</button>
                <button onclick="App.deleteCalendar('${c.id}')" class="btn-danger">Delete</button>
                <button onclick="App.exportCalendar('${c.id}')" class="btn-sm">Export .ics</button>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  },

  async renderEventDetail(el, eventId) {
    if (!eventId) { el.innerHTML = '<p>Event not found</p>'; return; }
    try {
      const data = await CalendarAPI.getEvent(eventId);
      const cal = this.calendars.find(c => c.id === data['calendar-id']);
      el.innerHTML = `
        <article class="event-detail">
          <div class="event-header">
            <h2>${this.esc(data.title)}</h2>
            <div class="event-actions">
              <button onclick="App.editEvent('${eventId}')" class="btn-primary">Edit</button>
              <button onclick="App.confirmDeleteEvent('${eventId}')" class="btn-danger">Delete</button>
            </div>
          </div>
          <div class="event-meta">
            <dl>
              <dt>When</dt>
              <dd>${new Date(data.start * 1000).toLocaleString()} - ${new Date(data.end * 1000).toLocaleString()}</dd>
              ${data.location ? `<dt>Where</dt><dd>${this.esc(data.location)}</dd>` : ''}
              ${cal ? `<dt>Calendar</dt><dd><span class="cal-dot" style="background:${this.hexColor(cal.color)}"></span> ${this.esc(cal.name)}</dd>` : ''}
              ${data.description ? `<dt>Description</dt><dd>${this.esc(data.description)}</dd>` : ''}
              ${data['all-day'] ? '<dt>Type</dt><dd>All day event</dd>' : ''}
            </dl>
          </div>
        </article>
      `;
    } catch (e) {
      el.innerHTML = '<p>Event not found</p>';
    }
  },

  async renderBookingTypes(el) {
    try {
      const data = await CalendarAPI.getBookingTypes();
      const pageData = await CalendarAPI.getBookingPage();
      const types = data['booking-types'] || [];
      el.innerHTML = `
        <div class="manage">
          <div class="manage-head">
            <h2>Booking Types</h2>
            <button onclick="App.showCreateBookingType()" class="btn-primary">New booking type</button>
          </div>
          <div class="booking-page-toggle">
            <label>
              <input type="checkbox" ${pageData.enabled ? 'checked' : ''} onchange="CalendarAPI.toggleBookingPage().then(()=>App.refresh())">
              Public booking page ${pageData.enabled ? 'enabled' : 'disabled'}
            </label>
            ${pageData.enabled ? `<div class="booking-url">Booking page: <code>${location.origin}/apps/time/#/book/</code></div>` : ''}
          </div>
          <div class="manage-items">
            ${types.map(bt => `
              <div class="manage-item">
                <span class="cal-dot" style="background:${this.hexColor(bt.color)}"></span>
                <div class="manage-body">
                  <div class="manage-name">${this.esc(bt.name)}</div>
                  <div class="manage-meta">${bt.duration} min${bt.active ? '' : ' (inactive)'}</div>
                </div>
                <div class="manage-actions">
                  <button onclick="App.editBookingType('${bt.id}')" class="btn-sm">Edit</button>
                  <button onclick="App.deleteBookingType('${bt.id}')" class="btn-danger">Delete</button>
                  ${pageData.enabled && bt.active ? `<button onclick="navigator.clipboard.writeText('${location.origin}/apps/time/#/book/${bt.id}')" class="btn-sm">Copy Link</button>` : ''}
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      `;
    } catch (e) {
      el.innerHTML = '<p>Error loading booking types</p>';
    }
  },

  async renderAvailability(el) {
    try {
      const data = await CalendarAPI.getAvailability();
      const utcRules = data.rules || [];
      const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      const offset = new Date().getTimezoneOffset();
      const localRules = [];
      for (const rule of utcRules) {
        let startLocal = rule.start - offset;
        let endLocal = rule.end - offset;
        let localDay = rule.day;
        if (startLocal < 0) { startLocal += 1440; localDay = (localDay + 6) % 7; }
        if (startLocal >= 1440) { startLocal -= 1440; localDay = (localDay + 1) % 7; }
        if (endLocal < 0) { endLocal += 1440; }
        if (endLocal >= 1440) { endLocal -= 1440; }
        localRules.push({ day: localDay, start: startLocal, end: endLocal });
      }
      const merged = new Map();
      for (const r of localRules) {
        const existing = merged.get(r.day);
        if (existing) {
          existing.start = Math.min(existing.start, r.start);
          existing.end = Math.max(existing.end, r.end);
        } else {
          merged.set(r.day, { ...r });
        }
      }
      el.innerHTML = `
        <div class="manage">
          <h2>Bookable Hours</h2>
          <p>Set hours when bookings are allowed. Events from selected conflict calendars are automatically blocked.</p>
          <form id="avail-form" onsubmit="App.saveAvailability(event)">
            ${days.map((d, i) => {
              const rule = merged.get(i);
              return `
                <div class="avail-row">
                  <label class="avail-day">
                    <input type="checkbox" name="day-${i}" ${rule ? 'checked' : ''}>
                    ${d}
                  </label>
                  <input type="time" name="start-${i}" value="${rule ? this.minToTime(rule.start) : '09:00'}" class="time-input">
                  <span>to</span>
                  <input type="time" name="end-${i}" value="${rule ? this.minToTime(rule.end) : '17:00'}" class="time-input">
                </div>
              `;
            }).join('')}
            <button type="submit" class="btn-primary">Save Availability</button>
          </form>
        </div>
      `;
    } catch (e) {
      el.innerHTML = '<p>Error loading availability</p>';
    }
  },

  async renderBookings(el) {
    try {
      const data = await CalendarAPI.getBookings();
      const bookings = data.bookings || [];
      el.innerHTML = `
        <div class="manage">
          <h2>Bookings</h2>
          ${bookings.length === 0 ? '<p class="empty">No bookings yet</p>' : ''}
          <div class="manage-items">
            ${bookings.map(b => `
              <div class="manage-item">
                <div class="manage-body">
                  <div class="manage-name">${this.esc(b['booker-name'])}</div>
                  <div class="manage-meta">${new Date(b.start * 1000).toLocaleString()}</div>
                </div>
                <span class="status-badge status-${b.status}">${b.status}</span>
                <div class="manage-actions">
                  ${b.status === 'pending' ? `
                    <button onclick="CalendarAPI.confirmBooking('${b.id}').then(()=>App.refresh())" class="btn-sm">Confirm</button>
                  ` : ''}
                  ${b.status !== 'cancelled' ? `
                    <button onclick="CalendarAPI.cancelBooking('${b.id}').then(()=>App.refresh())" class="btn-danger">Cancel</button>
                  ` : ''}
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      `;
    } catch (e) {
      el.innerHTML = '<p>Error loading bookings</p>';
    }
  },

  async renderSettings(el) {
    el.innerHTML = `
      <div class="manage">
        <h2>Settings</h2>
        <form id="settings-form" onsubmit="App.saveSettings(event)">
          <div class="field">
            <label>Default View</label>
            <select name="defaultView">
              <option value="month" ${this.settings['default-view'] === 'month' ? 'selected' : ''}>Month</option>
              <option value="week" ${this.settings['default-view'] === 'week' ? 'selected' : ''}>Week</option>
              <option value="day" ${this.settings['default-view'] === 'day' ? 'selected' : ''}>Day</option>
              <option value="agenda" ${this.settings['default-view'] === 'agenda' ? 'selected' : ''}>Agenda</option>
            </select>
          </div>
          <div class="field">
            <label>Week Starts On</label>
            <select name="weekStartDay">
              <option value="0" ${this.settings['week-start-day'] === 0 ? 'selected' : ''}>Sunday</option>
              <option value="1" ${this.settings['week-start-day'] === 1 ? 'selected' : ''}>Monday</option>
            </select>
          </div>
          <div class="field">
            <label>Timezone</label>
            <input type="text" name="timezone" value="${this.settings['default-timezone'] || 'UTC'}" placeholder="UTC">
          </div>
          <button type="submit" class="btn-primary">Save Settings</button>
        </form>
      </div>
    `;
  },

  renderImport(el) {
    el.innerHTML = `
      <div class="manage">
        <h2>Import Calendar</h2>
        <form id="import-form" onsubmit="App.handleImport(event)">
          <div class="field">
            <label>Calendar Name</label>
            <input type="text" name="calName" placeholder="My Calendar" required>
          </div>
          <div class="field">
            <label>Select .ics File</label>
            <input type="file" name="icsFile" accept=".ics" required>
          </div>
          <button type="submit" class="btn-primary">Import</button>
        </form>
      </div>
    `;
  },

  renderSubscriptions(el) {
    const subs = this.subscriptions;
    el.innerHTML = `
      <div class="manage">
        <div class="manage-head">
          <h2>Subscriptions</h2>
          <button onclick="App.showSubscribeCalendar()" class="btn-primary">Subscribe</button>
        </div>
        ${subs.length === 0 ? '<p class="empty">No subscriptions yet. Subscribe to an external .ics URL to sync events.</p>' : ''}
        <div class="manage-items">
          ${subs.map(s => {
            const cal = this.calendars.find(c => c.id === s['calendar-id']);
            const calName = cal ? this.esc(cal.name) : 'Unknown';
            const lastFetched = s['last-fetched'] ? new Date(s['last-fetched'] * 1000).toLocaleString() : 'Never';
            return `
            <div class="manage-item">
              ${cal ? `<span class="cal-dot" style="background:${this.hexColor(cal.color)}"></span>` : ''}
              <div class="manage-body">
                <div class="manage-name">${calName}</div>
                <div class="sub-url" title="${this.esc(s.url)}">${this.esc(s.url)}</div>
              </div>
              <div class="manage-meta">Every ${s['refresh-interval']} min &middot; ${lastFetched}</div>
              ${s.error ? `<span class="sub-error" title="${this.esc(s.error)}">Error</span>` : ''}
              <div class="manage-actions">
                <button onclick="CalendarAPI.refreshSubscription('${s.id}').then(()=>App.refresh())" class="btn-sm">Refresh</button>
                <button onclick="App.confirmUnsubscribe('${s.id}')" class="btn-danger">Unsubscribe</button>
              </div>
            </div>`;
          }).join('')}
        </div>
      </div>
    `;
  },

  confirmUnsubscribe(subId) {
    if (confirm('Unsubscribe from this calendar? The calendar and its events will remain.')) {
      CalendarAPI.unsubscribeCalendar(subId).then(() => this.refresh());
    }
  },

  showSubscribeCalendar() {
    this.showModal(`
      <h2>Subscribe to Calendar</h2>
      <form onsubmit="App.submitSubscribe(event)">
        <div class="field">
          <label>iCal URL (.ics)</label>
          <input type="url" name="url" required autofocus placeholder="https://calendar.google.com/...basic.ics">
        </div>
        <div class="field">
          <label>Calendar Name</label>
          <input type="text" name="calName" required placeholder="My Google Calendar">
        </div>
        <div class="field">
          <label>Refresh Interval (minutes)</label>
          <input type="number" name="refreshMinutes" value="60" min="5" required>
        </div>
        <div class="dialog-actions">
          <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
          <button type="submit" class="btn-primary">Subscribe</button>
        </div>
      </form>
    `);
  },

  async submitSubscribe(e) {
    e.preventDefault();
    const f = e.target;
    await CalendarAPI.subscribeCalendar(f.url.value, f.calName.value, parseInt(f.refreshMinutes.value));
    this.closeModal();
    location.hash = '#/subscriptions';
  },

  // Data loading

  async loadEvents() {
    const d = this.currentDate;
    const start = Math.floor(new Date(d.getFullYear(), d.getMonth() - 1, 1).getTime() / 1000);
    const end = Math.floor(new Date(d.getFullYear(), d.getMonth() + 2, 0).getTime() / 1000);
    try {
      const data = await CalendarAPI.getEvents(start, end);
      return (data.events || []).filter(e => this.selectedCalendars.has(e['calendar-id']));
    } catch (e) {
      console.error('Failed to load events:', e);
      return [];
    }
  },

  // Navigation

  prevPeriod() {
    const hash = location.hash || '#/month';
    const view = hash.slice(2).split('/')[0] || 'month';
    if (view === 'day') this.currentDate.setDate(this.currentDate.getDate() - 1);
    else if (view === 'week') this.currentDate.setDate(this.currentDate.getDate() - 7);
    else this.currentDate.setMonth(this.currentDate.getMonth() - 1);
    this.route();
  },

  nextPeriod() {
    const hash = location.hash || '#/month';
    const view = hash.slice(2).split('/')[0] || 'month';
    if (view === 'day') this.currentDate.setDate(this.currentDate.getDate() + 1);
    else if (view === 'week') this.currentDate.setDate(this.currentDate.getDate() + 7);
    else this.currentDate.setMonth(this.currentDate.getMonth() + 1);
    this.route();
  },

  goToday() {
    this.currentDate = new Date();
    this.route();
  },

  toggleCalendar(id) {
    if (this.selectedCalendars.has(id)) this.selectedCalendars.delete(id);
    else this.selectedCalendars.add(id);
    this.route();
  },

  // Dialogs

  showCreateEvent() {
    const now = Math.floor(Date.now() / 1000);
    this.showCreateEventAt(now);
  },

  showCreateEventAt(unixStart) {
    const end = unixStart + 3600;
    const startDt = new Date(unixStart * 1000);
    const endDt = new Date(end * 1000);
    this.showModal(`
      <h2>Create Event</h2>
      <form onsubmit="App.submitCreateEvent(event)">
        <div class="field">
          <label>Title</label>
          <input type="text" name="title" required autofocus>
        </div>
        <div class="field">
          <label>Calendar</label>
          <select name="calendarId" required>
            ${this.calendars.map(c => `<option value="${c.id}">${this.esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="field">
          <label>Start</label>
          <input type="datetime-local" name="start" value="${this.toLocalIso(startDt)}" required>
        </div>
        <div class="field">
          <label>End</label>
          <input type="datetime-local" name="end" value="${this.toLocalIso(endDt)}" required>
        </div>
        <div class="field">
          <label><input type="checkbox" name="allDay"> All day</label>
        </div>
        <div class="field">
          <label>Location</label>
          <input type="text" name="location">
        </div>
        <div class="field">
          <label>Description</label>
          <textarea name="description" rows="3"></textarea>
        </div>
        <div class="field">
          <label><input type="checkbox" name="recurring" onchange="document.getElementById('rrule-opts').style.display=this.checked?'':'none'"> Repeats</label>
        </div>
        <div id="rrule-opts" style="display:none">
          <div class="field">
            <label>Frequency</label>
            <select name="rruleFreq">
              <option value="daily">Daily</option>
              <option value="weekly" selected>Weekly</option>
              <option value="monthly">Monthly</option>
              <option value="yearly">Yearly</option>
            </select>
          </div>
          <div class="field">
            <label>Every</label>
            <input type="number" name="rruleInterval" value="1" min="1" max="99" style="width:60px">
            <span id="rrule-interval-label">week(s)</span>
          </div>
        </div>
        <div class="dialog-actions">
          <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
          <button type="submit" class="btn-primary">Create</button>
        </div>
      </form>
    `);
  },

  async submitCreateEvent(e) {
    e.preventDefault();
    const f = e.target;
    const start = Math.floor(new Date(f.start.value).getTime() / 1000);
    const end = Math.floor(new Date(f.end.value).getTime() / 1000);
    const ev = {
      title: f.title.value,
      description: f.description.value || '',
      'calendar-id': f.calendarId.value,
      start, end,
      location: f.location.value || '',
      'all-day': f.allDay.checked,
      reminders: []
    };
    if (f.recurring.checked) {
      ev.rrule = {
        freq: f.rruleFreq.value,
        interval: parseInt(f.rruleInterval.value) || 1
      };
    }
    await CalendarAPI.createEvent(ev);
    this.closeModal();
  },

  editEvent(eventId) {
    CalendarAPI.getEvent(eventId).then(ev => {
      const startDt = new Date(ev.start * 1000);
      const endDt = new Date(ev.end * 1000);
      this.showModal(`
        <h2>Edit Event</h2>
        <form onsubmit="App.submitEditEvent(event, '${eventId}')">
          <div class="field">
            <label>Title</label>
            <input type="text" name="title" value="${this.esc(ev.title)}" required>
          </div>
          <div class="field">
            <label>Calendar</label>
            <select name="calendarId" required>
              ${this.calendars.map(c => `<option value="${c.id}" ${c.id === ev['calendar-id'] ? 'selected' : ''}>${this.esc(c.name)}</option>`).join('')}
            </select>
          </div>
          <div class="field">
            <label>Start</label>
            <input type="datetime-local" name="start" value="${this.toLocalIso(startDt)}" required>
          </div>
          <div class="field">
            <label>End</label>
            <input type="datetime-local" name="end" value="${this.toLocalIso(endDt)}" required>
          </div>
          <div class="field">
            <label><input type="checkbox" name="allDay" ${ev['all-day'] ? 'checked' : ''}> All day</label>
          </div>
          <div class="field">
            <label>Location</label>
            <input type="text" name="location" value="${this.esc(ev.location || '')}">
          </div>
          <div class="field">
            <label>Description</label>
            <textarea name="description" rows="3">${this.esc(ev.description || '')}</textarea>
          </div>
          <div class="dialog-actions">
            <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
            <button type="submit" class="btn-primary">Save</button>
          </div>
        </form>
      `);
    });
  },

  async submitEditEvent(e, eventId) {
    e.preventDefault();
    const f = e.target;
    const start = Math.floor(new Date(f.start.value).getTime() / 1000);
    const end = Math.floor(new Date(f.end.value).getTime() / 1000);
    await CalendarAPI.updateEvent(eventId, {
      title: f.title.value,
      description: f.description.value || '',
      'calendar-id': f.calendarId.value,
      start, end,
      location: f.location.value || '',
      'all-day': f.allDay.checked,
      reminders: []
    });
    this.closeModal();
  },

  async confirmDeleteEvent(eventId) {
    if (confirm('Delete this event?')) {
      await CalendarAPI.deleteEvent(eventId);
      location.hash = '#/month';
    }
  },

  showCreateCalendar() {
    this.showModal(`
      <h2>Create Calendar</h2>
      <form onsubmit="App.submitCreateCalendar(event)">
        <div class="field">
          <label>Name</label>
          <input type="text" name="name" required autofocus>
        </div>
        <div class="field">
          <label>Color</label>
          <input type="color" name="color" value="#d4600a">
        </div>
        <div class="field">
          <label>Description</label>
          <textarea name="description" rows="2"></textarea>
        </div>
        <div class="dialog-actions">
          <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
          <button type="submit" class="btn-primary">Create</button>
        </div>
      </form>
    `);
  },

  async submitCreateCalendar(e) {
    e.preventDefault();
    const f = e.target;
    const hex = this.toUrbitHex(f.color.value);
    await CalendarAPI.createCalendar(f.name.value, hex, f.description.value || '');
    this.closeModal();
  },

  editCalendar(id) {
    const cal = this.calendars.find(c => c.id === id);
    if (!cal) return;
    this.showModal(`
      <h2>Edit Calendar</h2>
      <form onsubmit="App.submitEditCalendar(event, '${id}')">
        <div class="field">
          <label>Name</label>
          <input type="text" name="name" value="${this.esc(cal.name)}" required>
        </div>
        <div class="field">
          <label>Color</label>
          <input type="color" name="color" value="${this.hexColor(cal.color)}">
        </div>
        <div class="field">
          <label>Description</label>
          <textarea name="description" rows="2">${this.esc(cal.description || '')}</textarea>
        </div>
        <div class="dialog-actions">
          <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
          <button type="submit" class="btn-primary">Save</button>
        </div>
      </form>
    `);
  },

  async submitEditCalendar(e, id) {
    e.preventDefault();
    const f = e.target;
    const hex = this.toUrbitHex(f.color.value);
    await CalendarAPI.updateCalendar(id, f.name.value, hex, f.description.value || '');
    this.closeModal();
  },

  async deleteCalendar(id) {
    if (confirm('Delete this calendar and all its events?')) {
      await CalendarAPI.deleteCalendar(id);
    }
  },

  async exportCalendar(id) {
    try {
      const ics = await CalendarAPI.exportIcal(id);
      const blob = new Blob([ics], { type: 'text/calendar' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = 'calendar.ics'; a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      alert('Export failed: ' + e.message);
    }
  },

  showCreateBookingType() {
    this.showModal(`
      <h2>Create Booking Type</h2>
      <form onsubmit="App.submitCreateBookingType(event)">
        <div class="field">
          <label>Name</label>
          <input type="text" name="name" required autofocus placeholder="30 Minute Meeting">
        </div>
        <div class="field">
          <label>Duration (minutes)</label>
          <input type="number" name="duration" value="30" min="5" required>
        </div>
        <div class="field">
          <label>Buffer Time (minutes)</label>
          <input type="number" name="bufferTime" value="15" min="0">
        </div>
        <div class="field">
          <label>Calendar</label>
          <select name="calendarId" required>
            ${this.calendars.map(c => `<option value="${c.id}">${this.esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="field">
          <label>Check conflicts against</label>
          <div class="checkbox-group">
            ${this.calendars.map(c => `
              <label><input type="checkbox" name="conflictCal" value="${c.id}" checked> ${this.esc(c.name)}</label>
            `).join('')}
          </div>
          <small>If none selected, all calendars are checked</small>
        </div>
        <div class="field">
          <label>Color</label>
          <input type="color" name="color" value="#e056a0">
        </div>
        <div class="field">
          <label>Description</label>
          <textarea name="description" rows="2"></textarea>
        </div>
        <div class="field">
          <label><input type="checkbox" name="active" checked> Active</label>
        </div>
        <div class="dialog-actions">
          <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
          <button type="submit" class="btn-primary">Create</button>
        </div>
      </form>
    `);
  },

  async submitCreateBookingType(e) {
    e.preventDefault();
    const f = e.target;
    const conflictCals = Array.from(f.querySelectorAll('input[name="conflictCal"]:checked')).map(cb => cb.value);
    await CalendarAPI.createBookingType({
      name: f.name.value,
      duration: parseInt(f.duration.value),
      description: f.description.value || '',
      color: this.toUrbitHex(f.color.value),
      'calendar-id': f.calendarId.value,
      'buffer-time': parseInt(f.bufferTime.value) || 0,
      active: f.active.checked,
      'conflict-calendars': conflictCals
    });
    this.closeModal();
  },

  async editBookingType(id) {
    const data = await CalendarAPI.getBookingTypes();
    const bt = (data['booking-types'] || []).find(t => t.id === id);
    if (!bt) return;
    this.showModal(`
      <h2>Edit Booking Type</h2>
      <form onsubmit="App.submitEditBookingType(event, '${id}')">
        <div class="field">
          <label>Name</label>
          <input type="text" name="name" value="${this.esc(bt.name)}" required autofocus>
        </div>
        <div class="field">
          <label>Duration (minutes)</label>
          <input type="number" name="duration" value="${bt.duration}" min="5" required>
        </div>
        <div class="field">
          <label>Buffer Time (minutes)</label>
          <input type="number" name="bufferTime" value="${bt['buffer-time'] || 0}" min="0">
        </div>
        <div class="field">
          <label>Calendar</label>
          <select name="calendarId" required>
            ${this.calendars.map(c => `<option value="${c.id}" ${c.id === bt['calendar-id'] ? 'selected' : ''}>${this.esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="field">
          <label>Check conflicts against</label>
          <div class="checkbox-group">
            ${this.calendars.map(c => `
              <label><input type="checkbox" name="conflictCal" value="${c.id}" ${(bt['conflict-calendars'] || []).includes(c.id) ? 'checked' : ''}> ${this.esc(c.name)}</label>
            `).join('')}
          </div>
          <small>If none selected, all calendars are checked</small>
        </div>
        <div class="field">
          <label>Color</label>
          <input type="color" name="color" value="${this.hexColor(bt.color)}">
        </div>
        <div class="field">
          <label>Description</label>
          <textarea name="description" rows="2">${this.esc(bt.description || '')}</textarea>
        </div>
        <div class="field">
          <label><input type="checkbox" name="active" ${bt.active ? 'checked' : ''}> Active</label>
        </div>
        <div class="dialog-actions">
          <button type="button" onclick="App.closeModal()" class="btn-sm">Cancel</button>
          <button type="submit" class="btn-primary">Save</button>
        </div>
      </form>
    `);
  },

  async submitEditBookingType(e, id) {
    e.preventDefault();
    const f = e.target;
    const conflictCals = Array.from(f.querySelectorAll('input[name="conflictCal"]:checked')).map(cb => cb.value);
    await CalendarAPI.updateBookingType(id, {
      name: f.name.value,
      duration: parseInt(f.duration.value),
      description: f.description.value || '',
      color: this.toUrbitHex(f.color.value),
      'calendar-id': f.calendarId.value,
      'buffer-time': parseInt(f.bufferTime.value) || 0,
      active: f.active.checked,
      'conflict-calendars': conflictCals
    });
    this.closeModal();
  },

  async deleteBookingType(id) {
    if (confirm('Delete this booking type?')) {
      await CalendarAPI.deleteBookingType(id);
    }
  },

  async saveAvailability(e) {
    e.preventDefault();
    const f = e.target;
    const rules = [];
    const offset = new Date().getTimezoneOffset();
    for (let i = 0; i < 7; i++) {
      if (f[`day-${i}`].checked) {
        const [sh, sm] = f[`start-${i}`].value.split(':').map(Number);
        const [eh, em] = f[`end-${i}`].value.split(':').map(Number);
        let startUtc = sh * 60 + sm + offset;
        let endUtc = eh * 60 + em + offset;
        let day = i;
        if (startUtc < 0) { startUtc += 1440; day = (day + 6) % 7; }
        if (startUtc >= 1440) { startUtc -= 1440; day = (day + 1) % 7; }
        if (endUtc < 0) { endUtc += 1440; }
        if (endUtc >= 1440) { endUtc -= 1440; }
        if (endUtc <= startUtc) {
          rules.push({ day: day, start: startUtc, end: 1440 });
          rules.push({ day: (day + 1) % 7, start: 0, end: endUtc });
        } else {
          rules.push({ day: day, start: startUtc, end: endUtc });
        }
      }
    }
    await CalendarAPI.setAvailability(rules);
    this.refresh();
  },

  async saveSettings(e) {
    e.preventDefault();
    const f = e.target;
    await CalendarAPI.updateSettings({
      defaultTimezone: f.timezone.value,
      weekStartDay: parseInt(f.weekStartDay.value),
      defaultView: f.defaultView.value
    });
  },

  async handleImport(e) {
    e.preventDefault();
    const f = e.target;
    const file = f.icsFile.files[0];
    if (!file) return;
    const text = await file.text();
    await CalendarAPI.importIcal(f.calName.value, text);
    alert('Import complete!');
    this.refresh();
    location.hash = '#/calendars';
  },

  // Modal

  showModal(content) {
    let overlay = document.getElementById('modal-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'modal-overlay';
      overlay.onclick = (e) => { if (e.target === overlay) this.closeModal(); };
      document.body.appendChild(overlay);
    }
    overlay.innerHTML = `<div class="dialog">${content}</div>`;
    overlay.style.display = 'flex';
  },

  closeModal() {
    const overlay = document.getElementById('modal-overlay');
    if (overlay) overlay.style.display = 'none';
    this.refresh();
  },

  // Utilities

  formatCurrentDate(view) {
    const d = this.currentDate;
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    if (view === 'day') return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
    if (view === 'week') return `${months[d.getMonth()]} ${d.getFullYear()}`;
    return `${months[d.getMonth()]} ${d.getFullYear()}`;
  },

  formatTime(unix) {
    return new Date(unix * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  },

  isSameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  },

  toLocalIso(d) {
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  },

  minToTime(mins) {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;
  },

  hexColor(urbitHex) {
    if (!urbitHex) return '#d4600a';
    const clean = urbitHex.replace(/^0x\.?/, '').replace(/\./g, '');
    return '#' + clean.padStart(6, '0');
  },

  toUrbitHex(cssColor) {
    const raw = cssColor.replace('#', '').toLowerCase();
    const chunks = [];
    let i = raw.length;
    while (i > 0) {
      const start = Math.max(0, i - 4);
      chunks.unshift(raw.slice(start, i));
      i = start;
    }
    return '0x' + chunks.join('.');
  },

  esc(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }
};

// Initialize
document.addEventListener('DOMContentLoaded', () => App.init());
