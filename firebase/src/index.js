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
  onSnapshot,
  where, 
  getDocs,
  querySnapshot
} from 'firebase/firestore';

import * as firebaseui from 'firebaseui';

// Document elements
const startRsvpButton = document.getElementById('startRsvp');
const leaderboardContainer = document.getElementById('leaderboard-container');

const form = document.getElementById('leave-message');
const input = document.getElementById('message');
const players = document.getElementById('players');
const numberAttending = document.getElementById('number-attending');
const rsvpYes = document.getElementById('rsvp-yes');
const rsvpNo = document.getElementById('rsvp-no');

let rsvpListener = null;
let leaderboardListener = null;

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
  const game_name = await getGame(db)
  
  const entry = document.createElement('h2');
  entry.textContent = "Leaderboard for " + game_name;
  leaderboardContainer.appendChild(entry);
  
  // Create query for scores
  const q = query(collection(db, 'security-ctf-games', game_name, "playerList"), orderBy('total_score', 'desc'));
  onSnapshot(q, snaps => {
    // Reset page
    players.innerHTML = '';

    let tr = document.createElement('tr'); // header row
    const headerList = ["Player", "Score", "Challenge"];
    for (var j = 0; j < 3; j++) {
      var th = document.createElement('th'); //column
      var text = document.createTextNode(headerList[j]); //cell
      th.appendChild(text);
      tr.appendChild(th);
    }
    players.appendChild(tr);

    // Loop through documents in database
    snaps.forEach(doc => {
      // Create an row entry for each player on the leaderboard
      let tr = document.createElement('tr'); // row
      
      var td = document.createElement('td'); //column
      var text = document.createTextNode(doc.data().player_name); //cell
      td.appendChild(text);
      tr.appendChild(td);

      var td = document.createElement('td'); //column
      var text = document.createTextNode(doc.data().total_score); //cell
      td.appendChild(text);
      tr.appendChild(td);

      if (doc.data().current_challenge == 0) {
        var text = document.createTextNode("Enrolled");
      } else if (doc.data().current_challenge == 10) {
        var text = document.createTextNode("Ended");
      } else {
        var text = document.createTextNode(doc.data().current_challenge);
      }

      var td = document.createElement('td'); //column
      td.appendChild(text);
      tr.appendChild(td);

      players.appendChild(tr);
    });
  });
}

async function getGame(db) {
  let game = "";
  // Create query for game
  const q = query(collection(db, 'security-ctf-games'), where("state", "==", "Started"));
  const querySnapshot = await getDocs(q);
  querySnapshot.forEach((doc) => {
    game = doc.id;
  });
  return game;
}

main();
