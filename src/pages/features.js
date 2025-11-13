export function FeaturesPage() {
  return `
    <div class="page">
      <h1>Claude Code Features</h1>
      <p class="subtitle">Powerful capabilities at your fingertips</p>

      <div class="content">
        <div class="features-grid">
          <div class="feature-card">
            <h3>🔧 Tool Integration</h3>
            <p>Read, write, and edit files. Execute bash commands. Search codebases with grep and glob patterns.</p>
          </div>

          <div class="feature-card">
            <h3>🤖 AI-Powered Assistance</h3>
            <p>Get intelligent code suggestions, refactoring help, and bug fixes powered by Claude's advanced AI.</p>
          </div>

          <div class="feature-card">
            <h3>📝 Context Awareness</h3>
            <p>Claude understands your entire project structure and maintains context throughout your session.</p>
          </div>

          <div class="feature-card">
            <h3>🚀 Task Automation</h3>
            <p>Automate complex workflows with specialized agents for testing, reviewing, and deploying code.</p>
          </div>

          <div class="feature-card">
            <h3>🔍 Code Search</h3>
            <p>Quickly find files and code patterns across your entire codebase with intelligent search.</p>
          </div>

          <div class="feature-card">
            <h3>💬 Natural Language</h3>
            <p>Describe what you want in plain English, and Claude translates it into working code.</p>
          </div>
        </div>

        <div class="cta">
          <a href="#home" class="button">← Back to Home</a>
        </div>
      </div>
    </div>
  `;
}
