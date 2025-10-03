/**
 * PHPA Wiki JavaScript - Interactive Documentation Features
 */

class PHPAWiki {
  constructor() {
    this.init();
  }

  init() {
    this.setupMobileToggle();
    this.setupSearch();
    this.setupSmoothScrolling();
    this.setupCodeCopyButtons();
    this.setupTooltips();
    this.setupPageNavigation();
    this.setupThemeToggle();
    this.highlightActiveNavItem();
  }

  /**
   * Mobile sidebar toggle functionality
   */
  setupMobileToggle() {
    const toggle = document.querySelector('.wiki-mobile-toggle');
    const sidebar = document.querySelector('.wiki-sidebar');
    const overlay = document.querySelector('.wiki-overlay');

    if (toggle && sidebar) {
      toggle.addEventListener('click', () => {
        sidebar.classList.toggle('open');
        document.body.classList.toggle('sidebar-open');
      });

      // Close sidebar when clicking outside on mobile
      document.addEventListener('click', (e) => {
        if (window.innerWidth <= 768 &&
            !sidebar.contains(e.target) &&
            !toggle.contains(e.target) &&
            sidebar.classList.contains('open')) {
          sidebar.classList.remove('open');
          document.body.classList.remove('sidebar-open');
        }
      });
    }
  }

  /**
   * Search functionality
   */
  setupSearch() {
    const searchInput = document.querySelector('.wiki-search-input');
    const searchResults = document.querySelector('.wiki-search-results');

    if (searchInput) {
      let searchTimeout;

      searchInput.addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        const query = e.target.value.trim();

        if (query.length < 2) {
          this.hideSearchResults();
          return;
        }

        searchTimeout = setTimeout(() => {
          this.performSearch(query);
        }, 300);
      });

      // Hide search results when clicking outside
      document.addEventListener('click', (e) => {
        if (!e.target.closest('.wiki-search')) {
          this.hideSearchResults();
        }
      });
    }
  }

  /**
   * Perform search across wiki content
   */
  performSearch(query) {
    // This would typically integrate with a search API or index
    // For now, we'll simulate search results
    const mockResults = this.getMockSearchResults(query);
    this.displaySearchResults(mockResults);
  }

  /**
   * Mock search results (replace with actual search implementation)
   */
  getMockSearchResults(query) {
    const pages = [
      { title: 'Getting Started', url: 'pages/getting-started.html', excerpt: 'Quick start guide for PHPA' },
      { title: 'Models Overview', url: 'pages/models.html', excerpt: 'Available prediction models and configuration' },
      { title: 'GBDT Model', url: 'pages/models.html#gbdt', excerpt: 'Gradient Boosted Decision Trees implementation' },
      { title: 'XGBoost Model', url: 'pages/models.html#xgboost', excerpt: 'XGBoost machine learning model' },
      { title: 'Configuration Reference', url: 'pages/configuration.html', excerpt: 'Complete configuration options' },
      { title: 'Troubleshooting', url: 'pages/troubleshooting.html', excerpt: 'Common issues and solutions' }
    ];

    return pages.filter(page =>
      page.title.toLowerCase().includes(query.toLowerCase()) ||
      page.excerpt.toLowerCase().includes(query.toLowerCase())
    ).slice(0, 5);
  }

  /**
   * Display search results
   */
  displaySearchResults(results) {
    let resultsContainer = document.querySelector('.wiki-search-results');

    if (!resultsContainer) {
      resultsContainer = document.createElement('div');
      resultsContainer.className = 'wiki-search-results';
      document.querySelector('.wiki-search').appendChild(resultsContainer);
    }

    if (results.length === 0) {
      resultsContainer.innerHTML = '<div class="wiki-search-no-results">No results found</div>';
    } else {
      resultsContainer.innerHTML = results.map(result => `
        <a href="${result.url}" class="wiki-search-result">
          <div class="wiki-search-result-title">${result.title}</div>
          <div class="wiki-search-result-excerpt">${result.excerpt}</div>
        </a>
      `).join('');
    }

    resultsContainer.style.display = 'block';
  }

  /**
   * Hide search results
   */
  hideSearchResults() {
    const resultsContainer = document.querySelector('.wiki-search-results');
    if (resultsContainer) {
      resultsContainer.style.display = 'none';
    }
  }

  /**
   * Smooth scrolling for anchor links
   */
  setupSmoothScrolling() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
          target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          });
        }
      });
    });
  }

  /**
   * Add copy buttons to code blocks
   */
  setupCodeCopyButtons() {
    document.querySelectorAll('pre code').forEach(codeBlock => {
      const button = document.createElement('button');
      button.className = 'wiki-code-copy-btn';
      button.innerHTML = '📋 Copy';
      button.title = 'Copy to clipboard';

      button.addEventListener('click', () => {
        this.copyToClipboard(codeBlock.textContent);
        button.innerHTML = '✅ Copied!';
        setTimeout(() => {
          button.innerHTML = '📋 Copy';
        }, 2000);
      });

      const wrapper = document.createElement('div');
      wrapper.className = 'wiki-code-wrapper';
      codeBlock.parentNode.insertBefore(wrapper, codeBlock);
      wrapper.appendChild(codeBlock);
      wrapper.appendChild(button);
    });
  }

  /**
   * Copy text to clipboard
   */
  async copyToClipboard(text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch (err) {
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = text;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
    }
  }

  /**
   * Setup tooltips for technical terms
   */
  setupTooltips() {
    const tooltipTriggers = document.querySelectorAll('[data-tooltip]');

    tooltipTriggers.forEach(trigger => {
      trigger.addEventListener('mouseenter', (e) => {
        this.showTooltip(e.target, e.target.dataset.tooltip);
      });

      trigger.addEventListener('mouseleave', () => {
        this.hideTooltip();
      });
    });
  }

  /**
   * Show tooltip
   */
  showTooltip(element, text) {
    const tooltip = document.createElement('div');
    tooltip.className = 'wiki-tooltip';
    tooltip.textContent = text;
    document.body.appendChild(tooltip);

    const rect = element.getBoundingClientRect();
    tooltip.style.left = rect.left + (rect.width / 2) - (tooltip.offsetWidth / 2) + 'px';
    tooltip.style.top = rect.top - tooltip.offsetHeight - 8 + 'px';
  }

  /**
   * Hide tooltip
   */
  hideTooltip() {
    const tooltip = document.querySelector('.wiki-tooltip');
    if (tooltip) {
      tooltip.remove();
    }
  }

  /**
   * Setup page navigation (previous/next)
   */
  setupPageNavigation() {
    // This would be populated based on the site structure
    const pageOrder = [
      'index.html',
      'pages/getting-started.html',
      'pages/installation.html',
      'pages/models.html',
      'pages/configuration.html',
      'pages/examples.html',
      'pages/benchmarking.html',
      'pages/operations.html',
      'pages/troubleshooting.html',
      'pages/api-reference.html'
    ];

    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const currentIndex = pageOrder.indexOf(currentPage);

    if (currentIndex !== -1) {
      const navContainer = document.querySelector('.wiki-page-navigation');
      if (navContainer) {
        const prevPage = currentIndex > 0 ? pageOrder[currentIndex - 1] : null;
        const nextPage = currentIndex < pageOrder.length - 1 ? pageOrder[currentIndex + 1] : null;

        navContainer.innerHTML = `
          ${prevPage ? `<a href="${prevPage}" class="wiki-nav-prev">← Previous</a>` : ''}
          ${nextPage ? `<a href="${nextPage}" class="wiki-nav-next">Next →</a>` : ''}
        `;
      }
    }
  }

  /**
   * Theme toggle functionality
   */
  setupThemeToggle() {
    const themeToggle = document.querySelector('.wiki-theme-toggle');
    if (themeToggle) {
      themeToggle.addEventListener('click', () => {
        document.body.classList.toggle('dark-theme');
        const isDark = document.body.classList.contains('dark-theme');
        localStorage.setItem('wiki-theme', isDark ? 'dark' : 'light');
        themeToggle.textContent = isDark ? '☀️' : '🌙';
      });

      // Load saved theme
      const savedTheme = localStorage.getItem('wiki-theme');
      if (savedTheme === 'dark') {
        document.body.classList.add('dark-theme');
        themeToggle.textContent = '☀️';
      }
    }
  }

  /**
   * Highlight active navigation item
   */
  highlightActiveNavItem() {
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const navLinks = document.querySelectorAll('.wiki-nav a');

    navLinks.forEach(link => {
      const linkPage = link.getAttribute('href').split('/').pop();
      if (linkPage === currentPage) {
        link.classList.add('active');
      }
    });
  }

  /**
   * Table of contents generation
   */
  generateTableOfContents() {
    const tocContainer = document.querySelector('.wiki-toc');
    if (!tocContainer) return;

    const headings = document.querySelectorAll('h2, h3, h4');
    if (headings.length === 0) {
      tocContainer.style.display = 'none';
      return;
    }

    const tocList = document.createElement('ul');
    tocList.className = 'wiki-toc-list';

    headings.forEach((heading, index) => {
      const id = heading.id || `heading-${index}`;
      if (!heading.id) {
        heading.id = id;
      }

      const level = parseInt(heading.tagName.charAt(1));
      const listItem = document.createElement('li');
      listItem.className = `wiki-toc-item wiki-toc-level-${level}`;

      const link = document.createElement('a');
      link.href = `#${id}`;
      link.textContent = heading.textContent;
      link.className = 'wiki-toc-link';

      listItem.appendChild(link);
      tocList.appendChild(listItem);
    });

    tocContainer.innerHTML = '<h3>Table of Contents</h3>';
    tocContainer.appendChild(tocList);
  }

  /**
   * Initialize syntax highlighting (if Prism.js is loaded)
   */
  initSyntaxHighlighting() {
    if (typeof Prism !== 'undefined') {
      Prism.highlightAll();
    }
  }
}

// Initialize wiki functionality when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  const wiki = new PHPAWiki();

  // Generate table of contents if needed
  wiki.generateTableOfContents();

  // Initialize syntax highlighting
  wiki.initSyntaxHighlighting();
});

// Additional CSS for dynamic elements
const dynamicStyles = `
.wiki-search-results {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: var(--bg-primary);
  border: 1px solid var(--border-color);
  border-top: none;
  border-radius: 0 0 0.375rem 0.375rem;
  box-shadow: var(--shadow-md);
  max-height: 300px;
  overflow-y: auto;
  z-index: 1000;
  display: none;
}

.wiki-search-result {
  display: block;
  padding: var(--spacing-md);
  border-bottom: 1px solid var(--border-light);
  color: var(--text-primary);
  text-decoration: none;
  transition: background-color 0.15s ease;
}

.wiki-search-result:hover {
  background-color: var(--bg-light);
  text-decoration: none;
}

.wiki-search-result:last-child {
  border-bottom: none;
}

.wiki-search-result-title {
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
}

.wiki-search-result-excerpt {
  font-size: 0.875rem;
  color: var(--text-secondary);
}

.wiki-search-no-results {
  padding: var(--spacing-md);
  text-align: center;
  color: var(--text-muted);
  font-style: italic;
}

.wiki-code-wrapper {
  position: relative;
}

.wiki-code-copy-btn {
  position: absolute;
  top: var(--spacing-sm);
  right: var(--spacing-sm);
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 0.25rem;
  padding: var(--spacing-xs) var(--spacing-sm);
  font-size: 0.75rem;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.15s ease;
}

.wiki-code-wrapper:hover .wiki-code-copy-btn {
  opacity: 1;
}

.wiki-code-copy-btn:hover {
  background: var(--bg-tertiary);
}

.wiki-tooltip {
  position: absolute;
  background: var(--bg-dark);
  color: var(--text-light);
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: 0.25rem;
  font-size: 0.75rem;
  white-space: nowrap;
  z-index: 1000;
  pointer-events: none;
}

.wiki-page-navigation {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: var(--spacing-xl);
  padding-top: var(--spacing-lg);
  border-top: 1px solid var(--border-light);
}

.wiki-nav-prev,
.wiki-nav-next {
  display: inline-flex;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing-md);
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 0.375rem;
  text-decoration: none;
  color: var(--text-primary);
  transition: all 0.15s ease;
}

.wiki-nav-prev:hover,
.wiki-nav-next:hover {
  background: var(--primary-color);
  color: var(--text-light);
  text-decoration: none;
}

.wiki-toc {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 0.5rem;
  padding: var(--spacing-lg);
  margin: var(--spacing-lg) 0;
}

.wiki-toc h3 {
  margin-top: 0;
  margin-bottom: var(--spacing-md);
}

.wiki-toc-list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.wiki-toc-item {
  margin-bottom: var(--spacing-xs);
}

.wiki-toc-level-3 {
  margin-left: var(--spacing-md);
}

.wiki-toc-level-4 {
  margin-left: var(--spacing-lg);
}

.wiki-toc-link {
  color: var(--text-link);
  text-decoration: none;
  font-size: 0.875rem;
}

.wiki-toc-link:hover {
  text-decoration: underline;
}

@media (max-width: 768px) {
  .wiki-page-navigation {
    flex-direction: column;
    gap: var(--spacing-md);
  }
}
`;

// Inject dynamic styles
const styleElement = document.createElement('style');
styleElement.textContent = dynamicStyles;
document.head.appendChild(styleElement);