// Import stylesheets
import './style.css';
// Firebase App (the core Firebase SDK) is always required
import { initializeApp } from 'firebase/app';

// Add the Firebase products and methods that you want to use
import {
  getAuth,
  GoogleAuthProvider,
  signOut,
  onAuthStateChanged
} from 'firebase/auth';

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
const countdown_container = document.getElementById('countdown-container');

const form = document.getElementById('leave-message');
const input = document.getElementById('message');
const challenges = document.getElementById('challenges');
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
  auth = getAuth();

  // Initialize the FirebaseUI widget using Firebase
  const ui = new firebaseui.auth.AuthUI(auth);

  // FirebaseUI config
  const uiConfig = {
    // Popup signin flow rather than redirect flow.
    signInFlow: 'popup',
    signInOptions: [
      GoogleAuthProvider.PROVIDER_ID
    ],
    callbacks: {
      signInSuccessWithAuthResult: function(authResult, redirectUrl) {
        // Handle sign-in.
        // Return false to avoid redirect.
        return false;
      }
    }
  };

  // Listen to RSVP button clicks
  startRsvpButton.addEventListener('click', () => {
    if (auth.currentUser) {
      // User is signed in; allows user to sign out
      signOut(auth);
    } else {
      // No user is signed in; allows user to sign in
      ui.start('#firebaseui-auth-container', uiConfig);
    }
  });

  // Listen to the current Auth state
  onAuthStateChanged(auth, user => {
    if (user) {
      startRsvpButton.textContent = 'LOGOUT';
      challenges.style.display = 'block';
    } else {
      startRsvpButton.textContent = 'RSVP';
      challenges.style.display = 'none';
    }
  });

  // Display Challenges
  const c = query(collection(db, 'security-ctf-challenges'));
  onSnapshot(c, snaps => {
    // Reset page
    challenges.innerHTML = '';

    const categoryList = ["Easy", "Medium", "Hard"];
    for (var i = 0; i < 3; i++) {
      var tr = document.createElement('tr'); // category row
      var th = document.createElement('th'); // header column
      var text = document.createTextNode(categoryList[i]); // header cell
      th.appendChild(text);
      tr.appendChild(th);

      snaps.forEach(doc => {
        // Create a column entry for each challenge
        if (doc.data().category == categoryList[i]) {
          var td = document.createElement('td'); //column
          var text = document.createTextNode(doc.data().name); //cell
          td.appendChild(text);
          tr.appendChild(td);
        }
      });
      challenges.appendChild(tr);
    }
  });

  // Display Leaderboard
  const game_name = await getGame(db)
  if (game_name !== "" ) {
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
        // Create a row entry for each player on the leaderboard
        let tr = document.createElement('tr'); // row
        
        var td = document.createElement('td'); //column
        var text = document.createTextNode(doc.data().player_name); //cell
        td.appendChild(text);
        tr.appendChild(td);

        var td = document.createElement('td'); //column
        var text = document.createTextNode(doc.data().total_score); //cell
        td.appendChild(text);
        tr.appendChild(td);

        var td = document.createElement('td'); //column
        var text = document.createTextNode(doc.data().current_challenge); //cell
        td.appendChild(text);
        tr.appendChild(td);

        players.appendChild(tr);
      });

      // Add ending line breaks after the leaderboard
      const linebreak1 = document.createElement("br");
      players.appendChild(linebreak1);
      const linebreak2 = document.createElement("br");
      players.appendChild(linebreak2);
    });

    const countdown_break = document.createElement('hr')
    countdown_container.appendChild(countdown_break);

    const countdown_title = document.createElement('h2');
    countdown_title.setAttribute("id", "countdown-title")
    countdown_title.textContent = "10 Minute Timer";
    countdown_container.appendChild(countdown_title);

    const countdown_clock = document.createElement('span');
    countdown_clock.setAttribute("id", "time")
    countdown_clock.textContent = "10:00";
    countdown_container.appendChild(countdown_clock);

    const timer_buttons = document.createElement('div');
    timer_buttons.setAttribute("class","function-buttons");
    document.body.appendChild(timer_buttons);

    const reset_button = document.createElement('button');
    reset_button.setAttribute("class","reset-btn");
    reset_button.setAttribute("id","btn-reset");
    reset_button.textContent = 'Reset';
    reset_button.addEventListener('click', function(){
      location.reload();
    })
    timer_buttons.appendChild(reset_button);

    const start_button = document.createElement('button');
    start_button.setAttribute("class","start-btn");
    start_button.setAttribute("id","btn-start");
    start_button.textContent = 'Start';
    start_button.addEventListener('click', function(){
      var minute = 10;
      var sec = 0;
      setInterval(function(){
          if(sec < 0){
              minute--;
              sec = 59;
          }
          if(sec <=9){
              sec = "0" + sec;
          }
          if(sec == 0 && minute == 0){
              alert("Time Up!");
              location.reload();
          }
          document.getElementById("time").innerHTML = minute + ":" + sec;
          sec--;
      }, 1000);
    });
    timer_buttons.appendChild(start_button);
  }
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
