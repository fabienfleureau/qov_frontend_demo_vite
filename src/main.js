import './style.css'
import { createRouter } from './router.js'

// Create navigation
const nav = document.createElement('nav');
nav.innerHTML = `
  <div class="nav-container">
    <div class="nav-brand">Claude Code</div>
    <div class="nav-links">
      <a href="#home" class="active">Home</a>
      <a href="#features">Features</a>
    </div>
  </div>
`;

// Create main content container
const main = document.createElement('main');

// Setup the app
const app = document.querySelector('#app');
app.appendChild(nav);
app.appendChild(main);

// Initialize router
const router = createRouter(main);
router.init();
