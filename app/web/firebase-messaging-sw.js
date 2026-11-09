/*
 * FCM's background service worker (research R26). It lives at the origin root, next to the
 * app, and Firefox/Chrome fetch it from there without a query string.
 *
 * The Firebase JS SDK is pinned to the exact version firebase_core_web 4.1.0 loads
 * (`supportedFirebaseJsSdkVersion = 13.1.0`); a mismatch makes the page and this worker use
 * two SDKs in one origin. Change both together.
 *
 * `firebase-config.js` carries the public web identifiers from env/<flavor>.json and is
 * written by `tool/write_firebase_config.sh`; it holds no secret (R25).
 */
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js');
importScripts('firebase-config.js');

// The routes a push may open, the same shapes as `parsePushRoute` in
// lib/core/platform/push_routes.dart. test/web/messaging_sw_routes_test.dart reads this pattern
// between its markers and checks it against that function's table. Change both.
// push-route-pattern:start
const PUSH_ROUTE_PATTERN = /^\/(?:match\/[1-9][0-9]{0,9}(?:\?section=channels)?|channel\/[1-9][0-9]{0,9})?$/;
// push-route-pattern:end

if (self.MADAR_FIREBASE_CONFIG && self.MADAR_FIREBASE_CONFIG.apiKey) {
  firebase.initializeApp(self.MADAR_FIREBASE_CONFIG);

  const messaging = firebase.messaging();

  // A data-only message (the API sends `tag` = match_<id> and `fcm_options.link`), shown
  // with the same tag the notification carries so an update replaces it, never stacks.
  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    const data = payload.data || {};
    self.registration.showNotification(notification.title || '', {
      body: notification.body || '',
      tag: data.tag || '-',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { route: data.route || '/' },
    });
  });

  // A route of no known shape opens the app and goes nowhere (FR-059). `navigate` rejects on a
  // window this worker doesn't control, such as a PWA open in a background tab, so that falls
  // back to a new window.
  self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const raw = (event.notification.data || {}).route;
    const route = typeof raw === 'string' && PUSH_ROUTE_PATTERN.test(raw) ? raw : null;
    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
        for (const client of windows) {
          if ('focus' in client) {
            client.focus();
            if (route === null) return undefined;
            return client.navigate(route).catch(() => clients.openWindow(route));
          }
        }
        return clients.openWindow(route === null ? '/' : route);
      }),
    );
  });
}
