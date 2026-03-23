// Calendar API client
// Communicates with the %time agent via JSON HTTP API

const CalendarAPI = {
  base: '/apps/time/api',
  publicBase: '/apps/time/api/public',

  // GET request to authenticated endpoint
  async get(path) {
    const res = await fetch(`${this.base}/${path}`, {
      credentials: 'include'
    });
    if (!res.ok) throw new Error(`API error: ${res.status}`);
    return res.json();
  },

  // GET request to public endpoint
  async publicGet(path) {
    const res = await fetch(`${this.publicBase}/${path}`);
    if (!res.ok) throw new Error(`API error: ${res.status}`);
    return res.json();
  },

  // POST action to agent
  async poke(action) {
    const res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action)
    });
    if (!res.ok) throw new Error(`Poke error: ${res.status}`);
    const data = await res.json();
    window.dispatchEvent(new CustomEvent('calendar-state-changed'));
    return data;
  },

  // POST to public booking endpoint
  async publicBook(booking) {
    const res = await fetch(`${this.publicBase}/book`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(booking)
    });
    if (!res.ok) throw new Error(`Booking error: ${res.status}`);
    return res.json();
  },

  // Calendar operations
  getCalendars() { return this.get('calendars'); },
  getCalendar(id) { return this.get(`calendar/${id}`); },

  getEvents(start, end, calId) {
    let path = `events?start=${start}&end=${end}`;
    if (calId) path += `&cal=${calId}`;
    return this.get(path);
  },

  getEvent(id) { return this.get(`event/${id}`); },

  createCalendar(name, color, description) {
    return this.poke({ action: 'create-calendar', name, color, description: description || '' });
  },

  updateCalendar(calendarId, name, color, description) {
    return this.poke({ action: 'update-calendar', 'calendar-id': calendarId, name, color, description: description || '' });
  },

  deleteCalendar(calendarId) {
    return this.poke({ action: 'delete-calendar', 'calendar-id': calendarId });
  },

  createEvent(event) {
    return this.poke({
      action: 'create-event',
      ...event,
      reminders: event.reminders || []
    });
  },

  updateEvent(eventId, event) {
    return this.poke({
      action: 'update-event',
      'event-id': eventId,
      ...event,
      reminders: event.reminders || []
    });
  },

  deleteEvent(eventId) {
    return this.poke({ action: 'delete-event', 'event-id': eventId });
  },

  moveEvent(eventId, start, end) {
    return this.poke({ action: 'move-event', 'event-id': eventId, start, end });
  },

  // Booking type operations
  getBookingTypes() { return this.get('booking-types'); },

  createBookingType(bt) {
    return this.poke({ action: 'create-booking-type', ...bt });
  },

  updateBookingType(id, bt) {
    return this.poke({ action: 'update-booking-type', 'booking-type-id': id, ...bt });
  },

  deleteBookingType(id) {
    return this.poke({ action: 'delete-booking-type', 'booking-type-id': id });
  },

  // Availability
  getAvailability() { return this.get('availability'); },

  setAvailability(rules) {
    return this.poke({ action: 'set-availability', rules });
  },

  // Bookings
  getBookings() { return this.get('bookings'); },

  cancelBooking(id) {
    return this.poke({ action: 'cancel-booking', 'booking-id': id });
  },

  confirmBooking(id) {
    return this.poke({ action: 'confirm-booking', 'booking-id': id });
  },

  // Booking page
  getBookingPage() { return this.get('booking-page'); },

  toggleBookingPage() {
    return this.poke({ action: 'toggle-booking-page' });
  },

  updateBookingPage(title, description) {
    return this.poke({ action: 'update-booking-page', title, description });
  },

  // Settings
  getSettings() { return this.get('settings'); },

  updateSettings(settings) {
    return this.poke({
      action: 'update-settings',
      'default-timezone': settings.defaultTimezone || 'UTC',
      'week-start-day': settings.weekStartDay || 0,
      'default-view': settings.defaultView || 'month',
      'default-calendar': settings.defaultCalendar || null
    });
  },

  // Import/Export
  importIcal(calName, icsData) {
    return this.poke({ action: 'import-ical', 'cal-name': calName, 'ics-data': icsData });
  },

  async exportIcal(calendarId) {
    const path = calendarId ? `export-ical/${calendarId}` : 'export-ical';
    const res = await fetch(`${this.base}/${path}`, { credentials: 'include' });
    if (!res.ok) throw new Error(`Export error: ${res.status}`);
    return res.text();
  },

  // Subscriptions
  getSubscriptions() { return this.get('subscriptions'); },

  subscribeCalendar(url, calName, refreshMinutes) {
    return this.poke({
      action: 'subscribe-calendar',
      url,
      'cal-name': calName,
      'refresh-minutes': refreshMinutes
    });
  },

  unsubscribeCalendar(subscriptionId) {
    return this.poke({
      action: 'unsubscribe-calendar',
      'subscription-id': subscriptionId
    });
  },

  refreshSubscription(subscriptionId) {
    return this.poke({
      action: 'refresh-subscription',
      'subscription-id': subscriptionId
    });
  },

  // Contact calendar operations
  getContactCalendars() { return this.get('contact-calendars'); },
  getContacts() { return this.get('contacts'); },

  togglePublic(calendarId) {
    return this.poke({ action: 'toggle-public', 'calendar-id': calendarId });
  },

  discoverContactCalendars(ship) {
    return this.poke({ action: 'discover-contact-calendars', ship });
  },

  subscribeContactCalendar(ship, calendarId) {
    return this.poke({
      action: 'subscribe-contact-calendar',
      ship,
      'calendar-id': calendarId
    });
  },

  unsubscribeContactCalendar(contactCalendarId) {
    return this.poke({
      action: 'unsubscribe-contact-calendar',
      'contact-calendar-id': contactCalendarId
    });
  },

  toggleContactCalendar(contactCalendarId) {
    return this.poke({
      action: 'toggle-contact-calendar',
      'contact-calendar-id': contactCalendarId
    });
  },

  // Public booking endpoints
  getPublicBookingTypes() { return this.publicGet('booking-types'); },
  getPublicInfo() { return this.publicGet('info'); },

  getAvailableSlots(typeId, dateUnix) {
    return this.publicGet(`available-slots/${typeId}/${dateUnix}`);
  },

  bookSlot(bookingTypeId, bookerName, bookerEmail, start, notes) {
    return this.publicBook({
      'booking-type-id': bookingTypeId,
      'booker-name': bookerName,
      'booker-email': bookerEmail,
      start,
      notes: notes || ''
    });
  }
};
