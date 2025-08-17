/**
 * Ragdoll Rails Engine JavaScript
 * Core functionality for the Ragdoll Engine interface
 */

window.Ragdoll = window.Ragdoll || {};

// Initialize Ragdoll namespace
Ragdoll.init = function() {
  console.log('🤖 Ragdoll Engine JavaScript initialized');
  
  // Initialize components
  Ragdoll.initTooltips();
  Ragdoll.initFormValidation();
  Ragdoll.initSearchEnhancements();
  Ragdoll.initActionCable();
};

// Initialize Bootstrap tooltips
Ragdoll.initTooltips = function() {
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
  var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl, {
      delay: { "show": 500, "hide": 100 },
      placement: 'top',
      boundary: 'viewport',
      fallbackPlacements: ['top', 'bottom']
    });
  });
};

// Form validation helpers
Ragdoll.initFormValidation = function() {
  // Add basic form validation
  var forms = document.querySelectorAll('.needs-validation');
  forms.forEach(function(form) {
    form.addEventListener('submit', function(event) {
      if (!form.checkValidity()) {
        event.preventDefault();
        event.stopPropagation();
      }
      form.classList.add('was-validated');
    });
  });
};

// Search enhancements
Ragdoll.initSearchEnhancements = function() {
  // Auto-submit search form on Enter
  var searchInputs = document.querySelectorAll('input[type="search"], input[name="query"]');
  searchInputs.forEach(function(input) {
    input.addEventListener('keypress', function(e) {
      if (e.key === 'Enter') {
        var form = input.closest('form');
        if (form) {
          form.submit();
        }
      }
    });
  });
};

// ActionCable initialization
Ragdoll.initActionCable = function() {
  // Wait for ActionCable to be available (might be loaded via CDN)
  function waitForActionCable() {
    if (typeof ActionCable !== 'undefined') {
      console.log('🔗 Initializing ActionCable for Ragdoll Engine');
      
      // Initialize App namespace if not exists
      if (!window.App) {
        window.App = {};
      }
      
      // Create ActionCable consumer if not exists
      if (!window.App.cable) {
        try {
          window.App.cable = ActionCable.createConsumer('/cable');
          console.log('📡 ActionCable consumer created for Ragdoll');
          console.log('✅ App.cable ready:', window.App.cable);
        } catch (e) {
          console.error('❌ Failed to create ActionCable consumer:', e);
        }
      } else {
        console.log('✅ App.cable already exists');
      }
    } else {
      console.warn('⚠️ ActionCable not available - real-time features will be limited');
      // Retry after a short delay in case ActionCable is still loading
      setTimeout(waitForActionCable, 100);
    }
  }
  
  // Start waiting for ActionCable
  waitForActionCable();
};

// Utility functions
Ragdoll.showLoading = function(element) {
  element.classList.add('ragdoll-loading');
};

Ragdoll.hideLoading = function(element) {
  element.classList.remove('ragdoll-loading');
};

Ragdoll.showAlert = function(message, type = 'info') {
  var alertDiv = document.createElement('div');
  alertDiv.className = `alert alert-${type} alert-dismissible fade show ragdoll-alert`;
  alertDiv.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  `;
  
  var container = document.querySelector('.container');
  if (container) {
    container.insertBefore(alertDiv, container.firstChild);
  }
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  Ragdoll.init();
});

// Re-initialize on Turbo navigation (if using Turbo)
document.addEventListener('turbo:load', function() {
  Ragdoll.init();
});