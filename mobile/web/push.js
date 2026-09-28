window.registerSchemePush = async function(options, vapidKey) {
  if (!("Notification" in window) || !("serviceWorker" in navigator)) throw new Error("Notifications are not supported by this browser.");
  if (await Notification.requestPermission() !== "granted") throw new Error("Notification permission was not granted.");
  const appSdk = await import('https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js');
  const messagingSdk = await import('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging.js');
  const app = appSdk.getApps().length ? appSdk.getApp() : appSdk.initializeApp(options);
  const registration = await navigator.serviceWorker.register('firebase-messaging-sw.js?config=' + encodeURIComponent(JSON.stringify(options)), {scope: '/firebase-cloud-messaging-push-scope'});
  if (!registration.active) await new Promise(resolve => {
    const worker = registration.installing || registration.waiting;
    if (!worker) return resolve();
    worker.addEventListener('statechange', () => { if (worker.state === 'activated') resolve(); });
  });
  return messagingSdk.getToken(messagingSdk.getMessaging(app), {vapidKey, serviceWorkerRegistration: registration});
};
