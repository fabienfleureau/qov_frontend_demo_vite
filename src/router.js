import { HomePage } from './pages/home.js';
import { FeaturesPage } from './pages/features.js';

const routes = {
  home: HomePage,
  features: FeaturesPage,
};

export function createRouter(container) {
  function navigate(route) {
    const page = routes[route] || routes.home;
    render(page());
    updateActiveLink(route);
  }

  function render(html) {
    container.innerHTML = html;
  }

  function updateActiveLink(currentRoute) {
    document.querySelectorAll('nav a').forEach(link => {
      link.classList.remove('active');
      if (link.getAttribute('href') === `#${currentRoute}`) {
        link.classList.add('active');
      }
    });
  }

  function init() {
    // Handle hash changes
    window.addEventListener('hashchange', () => {
      const route = window.location.hash.slice(1) || 'home';
      navigate(route);
    });

    // Handle initial load
    const initialRoute = window.location.hash.slice(1) || 'home';
    navigate(initialRoute);
  }

  return { init };
}
