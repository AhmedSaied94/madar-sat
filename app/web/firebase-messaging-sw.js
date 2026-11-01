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

  self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const route = (event.notification.data || {}).route || '/';
    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
        for (const client of windows) {
          if ('focus' in client) {
            client.focus();
            return client.navigate(route);
          }
        }
        return clients.openWindow(route);
      }),
    );
  });
}
