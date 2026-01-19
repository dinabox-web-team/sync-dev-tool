(function(){
  const storageKey = 'sync-dev-theme';
  const className = 'theme-dark';

  function getPreferredTheme(){
    const stored = localStorage.getItem(storageKey);
    if(stored) return stored;
    if(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) return 'dark';
    return 'light';
  }

  function applyTheme(theme){
    if(theme === 'dark'){
      document.documentElement.classList.add(className);
    } else {
      document.documentElement.classList.remove(className);
    }
  }

  function toggleTheme(){
    const current = document.documentElement.classList.contains(className) ? 'dark' : 'light';
    const next = current === 'dark' ? 'light' : 'dark';
    applyTheme(next);
    localStorage.setItem(storageKey, next);
  }

  function createButton(){
    const btn = document.createElement('button');
    btn.className = 'theme-toggle';
    btn.setAttribute('aria-label', 'Toggle dark / light theme');
    btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="5"></circle><path d="M12 1v2"></path><path d="M12 21v2"></path><path d="M4.22 4.22l1.42 1.42"></path><path d="M18.36 18.36l1.42 1.42"></path><path d="M1 12h2"></path><path d="M21 12h2"></path><path d="M4.22 19.78l1.42-1.42"></path><path d="M18.36 5.64l1.42-1.42"></path></svg>';
    btn.addEventListener('click', toggleTheme);
    document.body.appendChild(btn);
  }

  document.addEventListener('DOMContentLoaded', function(){
    applyTheme(getPreferredTheme());
    createButton();
  });
})();
