// Booking Page - Public booking interface
// Uses only /api/public/ endpoints (no auth required)
// Week/day calendar grid showing available time slots

const BookingPage = {
  slotCache: {},
  currentWeekStart: null,
  selectedSlot: null,
  viewMode: window.innerWidth <= 768 ? 'day' : 'week',
  currentDayOffset: 0,
  bookingType: null,
  pageInfo: null,

  async render(el, bookingTypeId) {
    el.innerHTML = '<div class="booking"><p>Loading...</p></div>';
    try {
      const [info, typesData] = await Promise.all([
        CalendarAPI.getPublicInfo(),
        CalendarAPI.getPublicBookingTypes()
      ]);

      if (!info.enabled) {
        el.innerHTML = '<div class="booking"><h2>Booking Unavailable</h2><p>This booking page is not currently active.</p></div>';
        return;
      }

      const types = typesData['booking-types'] || [];
      const bt = types.find(t => t.id === bookingTypeId);
      if (!bt) {
        el.innerHTML = `
          <div class="booking">
            <h2>${App.esc(info.title)}</h2>
            <p>${App.esc(info.description)}</p>
            <p class="booking-ship">hosted by ${App.esc(info.ship)}</p>
            <div class="booking-types-list">
              ${types.length === 0 ? '<p>No booking types available</p>' : ''}
              ${types.map(t => `
                <a href="#/book/${t.id}" class="booking-type-card">
                  <div class="booking-type-color" style="background:${App.hexColor(t.color)}"></div>
                  <div class="booking-type-info">
                    <div class="booking-type-name">${App.esc(t.name)}</div>
                    <div class="booking-type-meta">${t.duration} minutes</div>
                    ${t.description ? `<div class="booking-type-desc">${App.esc(t.description)}</div>` : ''}
                  </div>
                </a>
              `).join('')}
            </div>
          </div>
        `;
        return;
      }

      this.bookingType = bt;
      this.pageInfo = info;
      this.slotCache = {};
      this.selectedSlot = null;
      this.currentDayOffset = 0;
      this.renderBookingFlow(el, bt, info);
    } catch (e) {
      el.innerHTML = '<div class="booking"><h2>Error</h2><p>Could not load booking page.</p></div>';
    }
  },

  renderBookingFlow(el, bt, info) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const dow = today.getDay();
    this.currentWeekStart = new Date(today);
    this.currentWeekStart.setDate(today.getDate() - dow);

    el.innerHTML = `
      <div class="booking">
        <div class="booking-header">
          <a href="#/book/" class="back-link">&larr; Back</a>
          <h2>${App.esc(bt.name)}</h2>
          <p>${bt.duration} minutes</p>
          ${bt.description ? `<p>${App.esc(bt.description)}</p>` : ''}
        </div>
        <div class="booking-week-nav">
          <button onclick="BookingPage.prevWeek()" class="btn-icon">&larr;</button>
          <span class="booking-week-label"></span>
          <button onclick="BookingPage.nextWeek()" class="btn-icon">&rarr;</button>
        </div>
        <div class="booking-cal-view"></div>
        <div class="booking-form-panel" style="display:none"></div>
      </div>
    `;

    window.removeEventListener('resize', BookingPage._resizeHandler);
    BookingPage._resizeHandler = () => {
      const newMode = window.innerWidth <= 768 ? 'day' : 'week';
      if (newMode !== BookingPage.viewMode) {
        BookingPage.viewMode = newMode;
        BookingPage.loadWeekAndRender();
      }
    };
    window.addEventListener('resize', BookingPage._resizeHandler);

    this.loadWeekAndRender();
  },

  async loadWeekAndRender() {
    const container = document.querySelector('.booking-cal-view');
    if (!container) return;

    const bt = this.bookingType;
    const ws = this.currentWeekStart;

    const allCached = Array.from({length: 7}, (_, d) => {
      const date = new Date(ws);
      date.setDate(date.getDate() + d);
      return this.slotCache[`${bt.id}-${Math.floor(date.getTime() / 1000)}`];
    }).every(Boolean);
    if (!allCached) container.innerHTML = '<p>Loading available times...</p>';

    // Update week label
    const weekEnd = new Date(ws);
    weekEnd.setDate(weekEnd.getDate() + 6);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const label = document.querySelector('.booking-week-label');
    if (label) {
      if (ws.getMonth() === weekEnd.getMonth()) {
        label.textContent = `${months[ws.getMonth()]} ${ws.getDate()} - ${weekEnd.getDate()}, ${ws.getFullYear()}`;
      } else {
        label.textContent = `${months[ws.getMonth()]} ${ws.getDate()} - ${months[weekEnd.getMonth()]} ${weekEnd.getDate()}, ${weekEnd.getFullYear()}`;
      }
    }

    // Fetch slots for all 7 days in parallel
    const fetches = [];
    for (let d = 0; d < 7; d++) {
      const date = new Date(ws);
      date.setDate(date.getDate() + d);
      const dateUnix = Math.floor(date.getTime() / 1000);
      const cacheKey = `${bt.id}-${dateUnix}`;
      if (this.slotCache[cacheKey]) {
        fetches.push(Promise.resolve(this.slotCache[cacheKey]));
      } else {
        fetches.push(
          CalendarAPI.getAvailableSlots(bt.id, dateUnix)
            .then(data => {
              const slots = data.slots || [];
              this.slotCache[cacheKey] = slots;
              return slots;
            })
            .catch(() => [])
        );
      }
    }

    const weekSlots = await Promise.all(fetches);

    if (this.viewMode === 'week') {
      this.renderWeekView(container, weekSlots);
    } else {
      this.renderDayView(container, weekSlots);
    }
  },

  renderWeekView(container, weekSlots) {
    const ws = this.currentWeekStart;
    const bt = this.bookingType;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const durationSec = bt.duration * 60;

    // Detect visible hour range from slot data
    let minHour = 23, maxHour = 0;
    let hasSlots = false;
    weekSlots.forEach(daySlots => {
      daySlots.forEach(s => {
        hasSlots = true;
        const d = new Date(s * 1000);
        minHour = Math.min(minHour, d.getHours());
        const endD = new Date((s + durationSec) * 1000);
        maxHour = Math.max(maxHour, endD.getHours() + (endD.getMinutes() > 0 ? 1 : 0));
      });
    });
    if (!hasSlots) { minHour = 9; maxHour = 17; }
    minHour = Math.max(0, minHour - 1);
    maxHour = Math.min(24, maxHour + 1);
    const totalHours = maxHour - minHour;

    const dayNames = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    let html = '<div class="bgrid">';

    // Header row
    html += '<div class="bgrid-header"><div class="bgrid-gutter"></div>';
    for (let d = 0; d < 7; d++) {
      const date = new Date(ws);
      date.setDate(date.getDate() + d);
      const isToday = date.getTime() === today.getTime();
      const isPast = date < today;
      html += `<div class="bgrid-day-head ${isToday ? 'is-today' : ''} ${isPast ? 'is-past' : ''}">${dayNames[d]} ${date.getDate()}</div>`;
    }
    html += '</div>';

    // Body: time gutter + 7 day columns
    html += `<div class="bgrid-body" style="height:${totalHours * 60}px">`;

    // Time labels
    html += '<div class="bgrid-times">';
    for (let h = minHour; h < maxHour; h++) {
      const lbl = h === 0 ? '12 AM' : h < 12 ? h + ' AM' : h === 12 ? '12 PM' : (h-12) + ' PM';
      html += `<div class="bgrid-time">${lbl}</div>`;
    }
    html += '</div>';

    // Day columns with slots
    for (let d = 0; d < 7; d++) {
      const date = new Date(ws);
      date.setDate(date.getDate() + d);
      const slots = weekSlots[d];

      html += '<div class="bgrid-col">';
      for (let h = minHour; h < maxHour; h++) {
        html += '<div class="bgrid-hour"></div>';
      }
      slots.forEach(s => {
        const sDate = new Date(s * 1000);
        const hourFrac = sDate.getHours() + sDate.getMinutes() / 60;
        const top = (hourFrac - minHour) * 60;
        const height = Math.max((durationSec / 3600) * 60, 20);
        const timeStr = sDate.toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});
        const selected = this.selectedSlot === s;
        html += `<button class="bgrid-slot ${selected ? 'is-selected' : ''}" style="top:${top}px;height:${height}px"
                      onclick="BookingPage.pickSlot(${s})" title="${timeStr}">${timeStr}</button>`;
      });
      html += '</div>';
    }
    html += '</div></div>';
    container.innerHTML = html;
  },

  renderDayView(container, weekSlots) {
    const ws = this.currentWeekStart;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (this.currentDayOffset < 0) this.currentDayOffset = 0;
    if (this.currentDayOffset > 6) this.currentDayOffset = 6;

    const currentDay = new Date(ws);
    currentDay.setDate(currentDay.getDate() + this.currentDayOffset);
    const dayNames = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const slots = weekSlots[this.currentDayOffset] || [];

    let html = `
      <div class="booking-day-view">
        <div class="booking-day-nav">
          <button onclick="BookingPage.prevDay()" class="btn-icon" ${this.currentDayOffset === 0 ? 'disabled' : ''}>&larr;</button>
          <span>${dayNames[currentDay.getDay()]}, ${months[currentDay.getMonth()]} ${currentDay.getDate()}</span>
          <button onclick="BookingPage.nextDay()" class="btn-icon" ${this.currentDayOffset === 6 ? 'disabled' : ''}>&rarr;</button>
        </div>
        <div class="booking-day-slots">
    `;

    if (slots.length === 0) {
      html += '<p class="empty">No available times for this day</p>';
    } else {
      html += '<div class="slot-list">';
      slots.forEach(s => {
        const timeStr = new Date(s * 1000).toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});
        const selected = this.selectedSlot === s;
        html += `<button class="slot-btn ${selected ? 'is-selected' : ''}" onclick="BookingPage.pickSlot(${s})">${timeStr}</button>`;
      });
      html += '</div>';
    }
    html += '</div></div>';
    container.innerHTML = html;
  },

  pickSlot(startUnix) {
    this.selectedSlot = startUnix;
    const bt = this.bookingType;
    const date = new Date(startUnix * 1000);
    const endDate = new Date((startUnix + bt.duration * 60) * 1000);
    const dateStr = date.toLocaleDateString([], {weekday: 'long', month: 'long', day: 'numeric'});
    const timeStr = date.toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});
    const endTimeStr = endDate.toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'});

    const panel = document.querySelector('.booking-form-panel');
    if (panel) {
      panel.style.display = 'block';
      panel.innerHTML = `
        <div class="booking-form-card">
          <div class="booking-form-summary">
            <strong>${dateStr}</strong><br>
            ${timeStr} - ${endTimeStr} (${bt.duration} min)
          </div>
          <form onsubmit="BookingPage.submitBooking(event, '${bt.id}', ${startUnix})">
            <div class="field">
              <label>Your Name</label>
              <input type="text" name="bookerName" required autofocus>
            </div>
            <div class="field">
              <label>Email</label>
              <input type="email" name="email" required>
            </div>
            <div class="field">
              <label>Notes (optional)</label>
              <textarea name="notes" rows="3"></textarea>
            </div>
            <div class="dialog-actions">
              <button type="button" onclick="BookingPage.cancelSelection()" class="btn-sm">Cancel</button>
              <button type="submit" class="btn-primary">Confirm Booking</button>
            </div>
          </form>
        </div>
      `;
    }

    // Re-render calendar to highlight selected slot
    this.loadWeekAndRender();
  },

  cancelSelection() {
    this.selectedSlot = null;
    const panel = document.querySelector('.booking-form-panel');
    if (panel) panel.style.display = 'none';
    this.loadWeekAndRender();
  },

  prevWeek() {
    this.currentWeekStart.setDate(this.currentWeekStart.getDate() - 7);
    this.selectedSlot = null;
    const panel = document.querySelector('.booking-form-panel');
    if (panel) panel.style.display = 'none';
    this.loadWeekAndRender();
  },

  nextWeek() {
    this.currentWeekStart.setDate(this.currentWeekStart.getDate() + 7);
    this.selectedSlot = null;
    const panel = document.querySelector('.booking-form-panel');
    if (panel) panel.style.display = 'none';
    this.loadWeekAndRender();
  },

  prevDay() {
    if (this.currentDayOffset > 0) {
      this.currentDayOffset--;
      this.loadWeekAndRender();
    }
  },

  nextDay() {
    if (this.currentDayOffset < 6) {
      this.currentDayOffset++;
      this.loadWeekAndRender();
    }
  },

  async submitBooking(e, btId, startUnix) {
    e.preventDefault();
    const f = e.target;
    const bookerName = f.bookerName.value;
    const bookerEmail = f.email.value;
    const notes = f.notes.value || '';
    try {
      await CalendarAPI.bookSlot(btId, bookerName, bookerEmail, startUnix, notes);
      // Invalidate cached slots for the booked day
      const dayStart = new Date(startUnix * 1000);
      dayStart.setHours(0, 0, 0, 0);
      const dayCacheKey = `${btId}-${Math.floor(dayStart.getTime() / 1000)}`;
      delete this.slotCache[dayCacheKey];
      const panel = document.querySelector('.booking-form-panel');
      const container = document.querySelector('.booking-cal-view');
      if (container) container.innerHTML = '';
      if (panel) {
        panel.innerHTML = `
          <div class="booking-confirmed">
            <h3>Booking Confirmed!</h3>
            <p>You're all set. A meeting has been scheduled for ${new Date(startUnix * 1000).toLocaleString()}.</p>
            <p>Thank you, ${App.esc(bookerName)}!</p>
            <div class="booking-confirmed-links">
              <a href="#/book/${btId}" class="btn-primary">Book Another</a>
              <a href="#/book/" class="btn-sm">Back to Booking Types</a>
            </div>
          </div>
        `;
      }
    } catch (e) {
      alert('Booking failed: ' + e.message);
    }
  }
};
