// Upcoming calendar events (from 1 h ago to 12 h ahead) as a JSON array, read through EventKit.
ObjC.import('Foundation'); ObjC.import('EventKit');
function run() {
  const store = $.EKEventStore.alloc.init;
  let status = $.EKEventStore.authorizationStatusForEntityType(0); // 0 = events
  if (status === 0) { // not determined yet: ask once and wait for the answer
    let done = false;
    const cb = (ok, err) => { done = true; };
    if (store.respondsToSelector('requestFullAccessToEventsWithCompletion:')) store.requestFullAccessToEventsWithCompletion(cb);
    else store.requestAccessToEntityTypeCompletion(0, cb);
    const until = $.NSDate.dateWithTimeIntervalSinceNow(60);
    while (!done && $.NSDate.date.compare(until) < 0) $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.2));
    status = $.EKEventStore.authorizationStatusForEntityType(0);
  }
  if (status !== 3 && status !== 4) return JSON.stringify({ error: 'denied', status });
  const now = $.NSDate.date;
  const pred = store.predicateForEventsWithStartDateEndDateCalendars(now.dateByAddingTimeInterval(-3600), now.dateByAddingTimeInterval(12 * 3600), $());
  const evs = store.eventsMatchingPredicate(pred), out = [];
  const LINK = /https:\/\/teams\.microsoft\.com\/l\/meetup-join\/[^\s>"]+|https:\/\/[a-z0-9.-]*zoom\.us\/j\/[^\s>"]+|https:\/\/meet\.google\.com\/[a-z-]+/i;
  for (let i = 0; i < evs.count; i++) {
    const e = evs.objectAtIndex(i);
    if (e.allDay) continue;
    const s = x => (x && !x.isNil()) ? x.js : '';
    const url = e.URL && !e.URL.isNil() ? e.URL.absoluteString.js : '';
    const hay = [s(e.location), s(e.notes), url].join(' ');
    const m = hay.match(LINK);
    out.push({ id: s(e.eventIdentifier), title: s(e.title), location: s(e.location), calendar: s(e.calendar.title),
      start: e.startDate.timeIntervalSince1970, end: e.endDate.timeIntervalSince1970, url: m ? m[0] : url });
  }
  return JSON.stringify(out);
}
