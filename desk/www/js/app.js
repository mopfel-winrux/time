// Calendar App - Main SPA
// Hash-based routing with month/week/day/agenda views

const App = {
  currentDate: new Date(),
  calendars: [],
  events: [],
  settings: {},
  subscriptions: [],
  selectedCalendars: new Set(),

  async init() {
    window.addEventListener('hashchange', () => this.route());
    window.addEventListener('calendar-state-changed', () => this.refresh());
    await this.loadData();
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
    return `
      <nav class="top-nav">
        <div class="nav-left">
          <h1 class="app-title">Calendar</h1>
          <div class="nav-date">
            <button onclick="App.prevPeriod()" class="btn-icon">&larr;</button>
            <button onclick="App.goToday()" class="btn-sm">Today</button>
            <button onclick="App.nextPeriod()" class="btn-icon">&rarr;</button>
            <span class="current-date">${this.formatCurrentDate(activeView)}</span>
          </div>
        </div>
        <div class="nav-views">
          ${views.map(v => `
            <a href="#/${v.id}" class="view-btn ${activeView === v.id ? 'active' : ''}">${v.label}</a>
          `).join('')}
        </div>
        <div class="nav-right">
          <button onclick="App.showCreateEvent()" class="btn-primary">+ Event</button>
        </div>
      </nav>
    `;
  },

  renderSidebar(activeView) {
    const links = [
      { id: 'calendars', label: 'Calendars', icon: 'cal' },
      { id: 'booking-types', label: 'Booking Types', icon: 'book' },
      { id: 'availability', label: 'Availability', icon: 'clock' },
      { id: 'bookings', label: 'Bookings', icon: 'list' },
      { id: 'import', label: 'Import', icon: 'upload' },
      { id: 'subscriptions', label: 'Subscriptions', icon: 'sync' },
      { id: 'settings', label: 'Settings', icon: 'gear' }
    ];
    return `
      <aside class="sidebar">
        <div class="sidebar-section">
          <h3>Manage</h3>
          ${links.map(l => `
            <a href="#/${l.id}" class="sidebar-link ${activeView === l.id ? 'active' : ''}">${l.label}</a>
          `).join('')}
        </div>
        <div class="sidebar-section">
          <h3>Calendars</h3>
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
    dayNames.forEach(d => html += `<div class="day-name">${d}</div>`);
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
        <div class="month-cell ${isToday ? 'today' : ''} ${isMonth ? '' : 'other-month'}"
             onclick="App.showCreateEventAt(${dayStart})">
          <div class="cell-date">${date.getDate()}</div>
          ${dayEvents.slice(0, 3).map(e => {
            const cal = this.calendars.find(c => c.id === e['calendar-id']);
            const color = cal ? this.hexColor(cal.color) : '#398be2';
            return `<div class="month-event" style="border-left:3px solid ${color}"
                         onclick="event.stopPropagation();location.hash='#/event/${e.id}'"
                    >${this.esc(e.title)}</div>`;
          }).join('')}
          ${dayEvents.length > 3 ? `<div class="more-events">+${dayEvents.length - 3} more</div>` : ''}
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
    html += '<div class="week-header"><div class="time-gutter"></div>';
    for (let d = 0; d < 7; d++) {
      const date = new Date(startOfWeek);
      date.setDate(date.getDate() + d);
      const isToday = this.isSameDay(date, new Date());
      html += `<div class="week-day-header ${isToday ? 'today' : ''}">
        ${['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d]} ${date.getDate()}
      </div>`;
    }
    html += '</div><div class="week-body">';

    // Time labels
    html += '<div class="time-column">';
    for (let h = 0; h < 24; h++) {
      html += `<div class="time-label">${h === 0 ? '12 AM' : h < 12 ? h + ' AM' : h === 12 ? '12 PM' : (h-12) + ' PM'}</div>`;
    }
    html += '</div>';

    for (let d = 0; d < 7; d++) {
      const date = new Date(startOfWeek);
      date.setDate(date.getDate() + d);
      const dayStart = Math.floor(date.getTime() / 1000);
      const dayEnd = dayStart + 86400;
      const dayEvents = events.filter(e => e.start < dayEnd && e.end > dayStart);

      html += '<div class="week-day-column">';
      for (let h = 0; h < 24; h++) {
        html += `<div class="hour-cell" onclick="App.showCreateEventAt(${dayStart + h * 3600})"></div>`;
      }
      dayEvents.forEach(e => {
        const eStart = Math.max(e.start, dayStart);
        const eEnd = Math.min(e.end, dayEnd);
        const top = ((eStart - dayStart) / 3600) * 60;
        const height = Math.max(((eEnd - eStart) / 3600) * 60, 20);
        const cal = this.calendars.find(c => c.id === e['calendar-id']);
        const color = cal ? this.hexColor(cal.color) : '#398be2';
        html += `<div class="week-event" style="top:${top}px;height:${height}px;background:${color}"
                      onclick="event.stopPropagation();location.hash='#/event/${e.id}'">
          ${this.esc(e.title)}
        </div>`;
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
    html += '<div class="time-column">';
    for (let h = 0; h < 24; h++) {
      html += `<div class="time-label">${h === 0 ? '12 AM' : h < 12 ? h + ' AM' : h === 12 ? '12 PM' : (h-12) + ' PM'}</div>`;
    }
    html += '</div><div class="day-column">';
    for (let h = 0; h < 24; h++) {
      html += `<div class="hour-cell" onclick="App.showCreateEventAt(${dayStart + h * 3600})"></div>`;
    }
    dayEvents.forEach(e => {
      const eStart = Math.max(e.start, dayStart);
      const eEnd = Math.min(e.end, dayEnd);
      const top = ((eStart - dayStart) / 3600) * 60;
      const height = Math.max(((eEnd - eStart) / 3600) * 60, 20);
      const cal = this.calendars.find(c => c.id === e['calendar-id']);
      const color = cal ? this.hexColor(cal.color) : '#398be2';
      html += `<div class="week-event" style="top:${top}px;height:${height}px;background:${color}"
                    onclick="event.stopPropagation();location.hash='#/event/${e.id}'">
        <strong>${this.esc(e.title)}</strong><br>${this.formatTime(e.start)} - ${this.formatTime(e.end)}
      </div>`;
    });
    html += '</div></div></div>';
    el.innerHTML = html;
  },

  async renderAgenda(el) {
    const events = await this.loadEvents();
    events.sort((a, b) => a.start - b.start);
    const upcoming = events.filter(e => e.end > Math.floor(Date.now() / 1000));

    let html = '<div class="agenda-list"><h2>Upcoming Events</h2>';
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
      const color = cal ? this.hexColor(cal.color) : '#398be2';
      html += `
        <div class="agenda-event" onclick="location.hash='#/event/${e.id}'">
          <div class="agenda-color" style="background:${color}"></div>
          <div class="agenda-info">
            <div class="agenda-title">${this.esc(e.title)}</div>
            <div class="agenda-time">${this.formatTime(e.start)} - ${this.formatTime(e.end)}</div>
          </div>
        </div>
      `;
    });
    html += '</div>';
    el.innerHTML = html;
  },

  // Management views

  async renderCalendars(el) {
    el.innerHTML = `
      <div class="manage-view">
        <div class="manage-header">
          <h2>Calendars</h2>
          <button onclick="App.showCreateCalendar()" class="btn-primary">+ Calendar</button>
        </div>
        <div class="manage-list" id="cal-list">
          ${this.calendars.map(c => `
            <div class="manage-item">
              <span class="cal-dot" style="background:${this.hexColor(c.color)}"></span>
              <span class="manage-name">${this.esc(c.name)}</span>
              <span class="manage-meta">${c['event-count'] || 0} events</span>
              <button onclick="App.editCalendar('${c.id}')" class="btn-sm">Edit</button>
              <button onclick="App.deleteCalendar('${c.id}')" class="btn-sm btn-danger">Delete</button>
              <button onclick="App.exportCalendar('${c.id}')" class="btn-sm">Export .ics</button>
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
        <div class="event-detail">
          <div class="event-header">
            <h2>${this.esc(data.title)}</h2>
            <div class="event-actions">
              <button onclick="App.editEvent('${eventId}')" class="btn-primary">Edit</button>
              <button onclick="App.confirmDeleteEvent('${eventId}')" class="btn-danger">Delete</button>
            </div>
          </div>
          <div class="event-meta">
            <div><strong>When:</strong> ${new Date(data.start * 1000).toLocaleString()} - ${new Date(data.end * 1000).toLocaleString()}</div>
            ${data.location ? `<div><strong>Where:</strong> ${this.esc(data.location)}</div>` : ''}
            ${cal ? `<div><strong>Calendar:</strong> <span class="cal-dot" style="background:${this.hexColor(cal.color)}"></span> ${this.esc(cal.name)}</div>` : ''}
            ${data.description ? `<div><strong>Description:</strong> ${this.esc(data.description)}</div>` : ''}
            ${data['all-day'] ? '<div><strong>All day event</strong></div>' : ''}
          </div>
        </div>
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
        <div class="manage-view">
          <div class="manage-header">
            <h2>Booking Types</h2>
            <button onclick="App.showCreateBookingType()" class="btn-primary">+ Booking Type</button>
          </div>
          <div class="booking-page-toggle">
            <label>
              <input type="checkbox" ${pageData.enabled ? 'checked' : ''} onchange="CalendarAPI.toggleBookingPage().then(()=>App.refresh())">
              Public booking page ${pageData.enabled ? 'enabled' : 'disabled'}
            </label>
            ${pageData.enabled ? `<div class="booking-url">Booking page: <code>${location.origin}/apps/time/#/book/</code></div>` : ''}
          </div>
          <div class="manage-list">
            ${types.map(bt => `
              <div class="manage-item">
                <span class="cal-dot" style="background:${this.hexColor(bt.color)}"></span>
                <span class="manage-name">${this.esc(bt.name)}</span>
                <span class="manage-meta">${bt.duration} min${bt.active ? '' : ' (inactive)'}</span>
                <button onclick="App.editBookingType('${bt.id}')" class="btn-sm">Edit</button>
                <button onclick="App.deleteBookingType('${bt.id}')" class="btn-sm btn-danger">Delete</button>
                ${pageData.enabled && bt.active ? `<button onclick="navigator.clipboard.writeText('${location.origin}/apps/time/#/book/${bt.id}')" class="btn-sm">Copy Link</button>` : ''}
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
      // Convert UTC rules to local time for display
      const offset = new Date().getTimezoneOffset(); // minutes to subtract for local
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
      // Merge split rules back: if two rules on adjacent days form a contiguous block, merge
      // (e.g. Mon 23:00-24:00 + Tue 0:00-7:00 => Mon 23:00-7:00 displayed as one)
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
        <div class="manage-view">
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
        <div class="manage-view">
          <h2>Bookings</h2>
          ${bookings.length === 0 ? '<p class="empty">No bookings yet</p>' : ''}
          <div class="manage-list">
            ${bookings.map(b => `
              <div class="manage-item">
                <span class="manage-name">${this.esc(b['booker-name'])}</span>
                <span class="manage-meta">${new Date(b.start * 1000).toLocaleString()}</span>
                <span class="status-badge status-${b.status}">${b.status}</span>
                ${b.status === 'pending' ? `
                  <button onclick="CalendarAPI.confirmBooking('${b.id}').then(()=>App.refresh())" class="btn-sm">Confirm</button>
                ` : ''}
                ${b.status !== 'cancelled' ? `
                  <button onclick="CalendarAPI.cancelBooking('${b.id}').then(()=>App.refresh())" class="btn-sm btn-danger">Cancel</button>
                ` : ''}
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
      <div class="manage-view">
        <h2>Settings</h2>
        <form id="settings-form" onsubmit="App.saveSettings(event)">
          <div class="form-group">
            <label>Default View</label>
            <select name="defaultView">
              <option value="month" ${this.settings['default-view'] === 'month' ? 'selected' : ''}>Month</option>
              <option value="week" ${this.settings['default-view'] === 'week' ? 'selected' : ''}>Week</option>
              <option value="day" ${this.settings['default-view'] === 'day' ? 'selected' : ''}>Day</option>
              <option value="agenda" ${this.settings['default-view'] === 'agenda' ? 'selected' : ''}>Agenda</option>
            </select>
          </div>
          <div class="form-group">
            <label>Week Starts On</label>
            <select name="weekStartDay">
              <option value="0" ${this.settings['week-start-day'] === 0 ? 'selected' : ''}>Sunday</option>
              <option value="1" ${this.settings['week-start-day'] === 1 ? 'selected' : ''}>Monday</option>
            </select>
          </div>
          <div class="form-group">
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
      <div class="manage-view">
        <h2>Import Calendar</h2>
        <form id="import-form" onsubmit="App.handleImport(event)">
          <div class="form-group">
            <label>Calendar Name</label>
            <input type="text" name="calName" placeholder="My Calendar" required>
          </div>
          <div class="form-group">
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
      <div class="manage-view">
        <div class="manage-header">
          <h2>Subscriptions</h2>
          <button onclick="App.showSubscribeCalendar()" class="btn-primary">+ Subscribe</button>
        </div>
        ${subs.length === 0 ? '<p class="empty">No subscriptions yet. Subscribe to an external .ics URL to sync events.</p>' : ''}
        <div class="manage-list">
          ${subs.map(s => {
            const cal = this.calendars.find(c => c.id === s['calendar-id']);
            const calName = cal ? this.esc(cal.name) : 'Unknown';
            const lastFetched = s['last-fetched'] ? new Date(s['last-fetched'] * 1000).toLocaleString() : 'Never';
            return `
            <div class="manage-item">
              ${cal ? `<span class="cal-dot" style="background:${this.hexColor(cal.color)}"></span>` : ''}
              <div class="manage-name">
                ${calName}
                <div class="sub-url" title="${this.esc(s.url)}">${this.esc(s.url)}</div>
              </div>
              <span class="manage-meta">Every ${s['refresh-interval']} min &middot; ${lastFetched}</span>
              ${s.error ? `<span class="sub-error" title="${this.esc(s.error)}">Error</span>` : ''}
              <button onclick="CalendarAPI.refreshSubscription('${s.id}').then(()=>App.refresh())" class="btn-sm">Refresh</button>
              <button onclick="App.confirmUnsubscribe('${s.id}')" class="btn-sm btn-danger">Unsubscribe</button>
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
        <div class="form-group">
          <label>iCal URL (.ics)</label>
          <input type="url" name="url" required autofocus placeholder="https://calendar.google.com/...basic.ics">
        </div>
        <div class="form-group">
          <label>Calendar Name</label>
          <input type="text" name="calName" required placeholder="My Google Calendar">
        </div>
        <div class="form-group">
          <label>Refresh Interval (minutes)</label>
          <input type="number" name="refreshMinutes" value="60" min="5" required>
        </div>
        <div class="form-actions">
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
        <div class="form-group">
          <label>Title</label>
          <input type="text" name="title" required autofocus>
        </div>
        <div class="form-group">
          <label>Calendar</label>
          <select name="calendarId" required>
            ${this.calendars.map(c => `<option value="${c.id}">${this.esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Start</label>
          <input type="datetime-local" name="start" value="${this.toLocalIso(startDt)}" required>
        </div>
        <div class="form-group">
          <label>End</label>
          <input type="datetime-local" name="end" value="${this.toLocalIso(endDt)}" required>
        </div>
        <div class="form-group">
          <label><input type="checkbox" name="allDay"> All day</label>
        </div>
        <div class="form-group">
          <label>Location</label>
          <input type="text" name="location">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea name="description" rows="3"></textarea>
        </div>
        <div class="form-group">
          <label><input type="checkbox" name="recurring" onchange="document.getElementById('rrule-opts').style.display=this.checked?'':'none'"> Repeats</label>
        </div>
        <div id="rrule-opts" style="display:none">
          <div class="form-group">
            <label>Frequency</label>
            <select name="rruleFreq">
              <option value="daily">Daily</option>
              <option value="weekly" selected>Weekly</option>
              <option value="monthly">Monthly</option>
              <option value="yearly">Yearly</option>
            </select>
          </div>
          <div class="form-group">
            <label>Every</label>
            <input type="number" name="rruleInterval" value="1" min="1" max="99" style="width:60px">
            <span id="rrule-interval-label">week(s)</span>
          </div>
        </div>
        <div class="form-actions">
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
          <div class="form-group">
            <label>Title</label>
            <input type="text" name="title" value="${this.esc(ev.title)}" required>
          </div>
          <div class="form-group">
            <label>Calendar</label>
            <select name="calendarId" required>
              ${this.calendars.map(c => `<option value="${c.id}" ${c.id === ev['calendar-id'] ? 'selected' : ''}>${this.esc(c.name)}</option>`).join('')}
            </select>
          </div>
          <div class="form-group">
            <label>Start</label>
            <input type="datetime-local" name="start" value="${this.toLocalIso(startDt)}" required>
          </div>
          <div class="form-group">
            <label>End</label>
            <input type="datetime-local" name="end" value="${this.toLocalIso(endDt)}" required>
          </div>
          <div class="form-group">
            <label><input type="checkbox" name="allDay" ${ev['all-day'] ? 'checked' : ''}> All day</label>
          </div>
          <div class="form-group">
            <label>Location</label>
            <input type="text" name="location" value="${this.esc(ev.location || '')}">
          </div>
          <div class="form-group">
            <label>Description</label>
            <textarea name="description" rows="3">${this.esc(ev.description || '')}</textarea>
          </div>
          <div class="form-actions">
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
        <div class="form-group">
          <label>Name</label>
          <input type="text" name="name" required autofocus>
        </div>
        <div class="form-group">
          <label>Color</label>
          <input type="color" name="color" value="#398be2">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea name="description" rows="2"></textarea>
        </div>
        <div class="form-actions">
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
        <div class="form-group">
          <label>Name</label>
          <input type="text" name="name" value="${this.esc(cal.name)}" required>
        </div>
        <div class="form-group">
          <label>Color</label>
          <input type="color" name="color" value="${this.hexColor(cal.color)}">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea name="description" rows="2">${this.esc(cal.description || '')}</textarea>
        </div>
        <div class="form-actions">
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
        <div class="form-group">
          <label>Name</label>
          <input type="text" name="name" required autofocus placeholder="30 Minute Meeting">
        </div>
        <div class="form-group">
          <label>Duration (minutes)</label>
          <input type="number" name="duration" value="30" min="5" required>
        </div>
        <div class="form-group">
          <label>Buffer Time (minutes)</label>
          <input type="number" name="bufferTime" value="15" min="0">
        </div>
        <div class="form-group">
          <label>Calendar</label>
          <select name="calendarId" required>
            ${this.calendars.map(c => `<option value="${c.id}">${this.esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Check conflicts against</label>
          <div class="checkbox-group">
            ${this.calendars.map(c => `
              <label><input type="checkbox" name="conflictCal" value="${c.id}" checked> ${this.esc(c.name)}</label>
            `).join('')}
          </div>
          <small>If none selected, all calendars are checked</small>
        </div>
        <div class="form-group">
          <label>Color</label>
          <input type="color" name="color" value="#e056a0">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea name="description" rows="2"></textarea>
        </div>
        <div class="form-group">
          <label><input type="checkbox" name="active" checked> Active</label>
        </div>
        <div class="form-actions">
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
        <div class="form-group">
          <label>Name</label>
          <input type="text" name="name" value="${this.esc(bt.name)}" required autofocus>
        </div>
        <div class="form-group">
          <label>Duration (minutes)</label>
          <input type="number" name="duration" value="${bt.duration}" min="5" required>
        </div>
        <div class="form-group">
          <label>Buffer Time (minutes)</label>
          <input type="number" name="bufferTime" value="${bt['buffer-time'] || 0}" min="0">
        </div>
        <div class="form-group">
          <label>Calendar</label>
          <select name="calendarId" required>
            ${this.calendars.map(c => `<option value="${c.id}" ${c.id === bt['calendar-id'] ? 'selected' : ''}>${this.esc(c.name)}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Check conflicts against</label>
          <div class="checkbox-group">
            ${this.calendars.map(c => `
              <label><input type="checkbox" name="conflictCal" value="${c.id}" ${(bt['conflict-calendars'] || []).includes(c.id) ? 'checked' : ''}> ${this.esc(c.name)}</label>
            `).join('')}
          </div>
          <small>If none selected, all calendars are checked</small>
        </div>
        <div class="form-group">
          <label>Color</label>
          <input type="color" name="color" value="${this.hexColor(bt.color)}">
        </div>
        <div class="form-group">
          <label>Description</label>
          <textarea name="description" rows="2">${this.esc(bt.description || '')}</textarea>
        </div>
        <div class="form-group">
          <label><input type="checkbox" name="active" ${bt.active ? 'checked' : ''}> Active</label>
        </div>
        <div class="form-actions">
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
    const offset = new Date().getTimezoneOffset(); // minutes to add for UTC
    for (let i = 0; i < 7; i++) {
      if (f[`day-${i}`].checked) {
        const [sh, sm] = f[`start-${i}`].value.split(':').map(Number);
        const [eh, em] = f[`end-${i}`].value.split(':').map(Number);
        let startUtc = sh * 60 + sm + offset;
        let endUtc = eh * 60 + em + offset;
        let day = i;
        // Handle day-of-week wrap when offset shifts past midnight
        if (startUtc < 0) { startUtc += 1440; day = (day + 6) % 7; }
        if (startUtc >= 1440) { startUtc -= 1440; day = (day + 1) % 7; }
        if (endUtc < 0) { endUtc += 1440; }
        if (endUtc >= 1440) { endUtc -= 1440; }
        // If start and end land on different UTC days, split into two rules
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
    overlay.innerHTML = `<div class="modal">${content}</div>`;
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
    if (!urbitHex) return '#398be2';
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
