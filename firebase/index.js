// Import stylesheets
import './style.css';
// Firebase App (the core Firebase SDK) is always required
import { initializeApp } from 'firebase/app';

// Add the Firebase products and methods that you want to use
import {} from 'firebase/auth';
import {
  getFirestore,
  addDoc,
  collection,
  query,
  orderBy,
  onSnapshot
} from 'firebase/firestore';

import * as firebaseui from 'firebaseui';

// Document elements
const startRsvpButton = document.getElementById('startRsvp');
const guestbookContainer = document.getElementById('guestbook-container');

const form = document.getElementById('leave-message');
const input = document.getElementById('message');
const guestbook = document.getElementById('guestbook');
const numberAttending = document.getElementById('number-attending');
const rsvpYes = document.getElementById('rsvp-yes');
const rsvpNo = document.getElementById('rsvp-no');

let rsvpListener = null;
let guestbookListener = null;

let db, auth;

async function main() {
  // Add Firebase project configuration object here
  const firebaseConfig = {
    apiKey: "AIzaSyBU2pWbJbWwE8MhIlFG3ek-DHtr74DmTWw",
    authDomain: "secops-project-348011.firebaseapp.com",
    projectId: "secops-project-348011",
    storageBucket: "secops-project-348011.appspot.com",
    messagingSenderId: "938947520409",
    appId: "1:938947520409:web:a080da21ef4037590e5508"
  };

  initializeApp(firebaseConfig);

  db = getFirestore();

  // Create query for messages
  const q = query(collection(db, 'security-ctf-challenges'), orderBy('id', 'desc'));
  onSnapshot(q, snaps => {
    // Reset page
    guestbook.innerHTML = '';
    // Loop through documents in database
    snaps.forEach(doc => {
      // Create an HTML entry for each document and add it to the chat
      const entry = document.createElement('p');
      entry.textContent = doc.data().scenario + ': ' + doc.data().answer;
      guestbook.appendChild(entry);
    });
  });
}
main();
