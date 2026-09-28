importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');
const options = new URL(self.location).searchParams.get('config');
if (options) {
  firebase.initializeApp(JSON.parse(options));
  firebase.messaging();
}
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/?notifications=1'));
});
