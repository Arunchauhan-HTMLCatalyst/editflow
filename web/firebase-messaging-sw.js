// Give the service worker access to Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's FirebaseConfig object.
firebase.initializeApp({
  apiKey: "AIzaSyCzSPU_gFKZHHYjXDIGs5Byn8GZw5FjVMc",
  authDomain: "editflow-editorsworkspace.firebaseapp.com",
  projectId: "editflow-editorsworkspace",
  storageBucket: "editflow-editorsworkspace.firebasestorage.app",
  messagingSenderId: "376711198932",
  appId: "1:376711198932:web:8b03004865315659cd2341"
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title || 'EditFlow Update';
  const notificationOptions = {
    body: payload.notification.body || '',
    icon: '/app/logo.svg',
    badge: '/app/favicon.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
