# Ragdoll UI Integration Guide

## Overview

Ragdoll provides a complete web interface for document management, semantic search, and analytics. The UI is built with Bootstrap 5, modern JavaScript, and responsive design principles. This guide covers how to integrate, customize, and extend the Ragdoll user interface in your Rails application.

## UI Components Overview

### Available Interfaces

1. **Dashboard** - System overview and analytics
2. **Document Management** - Upload, edit, and organize documents
3. **Semantic Search** - Advanced search with filtering
4. **Analytics** - Usage statistics and performance metrics
5. **Configuration** - Engine settings management

### Technology Stack

- **Bootstrap 5.1.3** - Responsive CSS framework
- **Font Awesome 6.0.0** - Icon library
- **Chart.js** - Data visualization
- **Vanilla JavaScript** - No heavy framework dependencies
- **Progressive Web App** support

## Basic Integration

### 1. Mount the Engine Routes

Add ragdoll routes to your Rails application:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Mount ragdoll at root (standalone app)
  mount Ragdoll::Engine => "/"
  
  # Or mount under a namespace
  mount Ragdoll::Engine => "/admin/ragdoll"
  
  # Or integrate into existing admin
  namespace :admin do
    mount Ragdoll::Engine => "/documents"
  end
end
```

### 2. Include Required Assets

The engine uses CDN resources by default, but you can customize:

```erb
<!-- In your application layout -->
<!DOCTYPE html>
<html>
<head>
  <!-- Bootstrap CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
  
  <!-- Font Awesome -->
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
  
  <!-- Your custom styles -->
  <%= stylesheet_link_tag 'application' %>
</head>
<body>
  <%= yield %>
  
  <!-- Bootstrap JS -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
  
  <!-- Chart.js -->
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  
  <!-- Your custom scripts -->
  <%= javascript_importmap_tags %>
</body>
</html>
```

### 3. Basic Authentication

Add authentication to ragdoll controllers:

```ruby
# In your application controller or base controller
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :authorize_ragdoll_access!
  
  private
  
  def authorize_ragdoll_access!
    redirect_to root_path unless current_user&.admin?
  end
end
```

## Dashboard Interface

### Main Dashboard Features

The dashboard provides a comprehensive system overview:

```erb
<!-- Dashboard sections -->
<div class="row">
  <!-- Statistics Cards -->
  <div class="col-md-3">
    <div class="card border-primary mb-3">
      <div class="card-body text-center">
        <i class="fas fa-file-alt text-primary fa-2x"></i>
        <h5 class="card-title text-primary">Documents</h5>
        <h2 class="text-primary"><%= @stats[:total_documents] %></h2>
      </div>
    </div>
  </div>
  
  <!-- Charts -->
  <div class="col-md-6">
    <canvas id="documentTypesChart"></canvas>
  </div>
  
  <!-- Recent Activity -->
  <div class="col-md-3">
    <h5>Recent Documents</h5>
    <% @recent_documents.each do |document| %>
      <div class="d-flex justify-content-between mb-2">
        <%= link_to document.title, document_path(document), 
            class: "text-decoration-none" %>
        <span class="badge bg-<%= status_color(document.status) %>">
          <%= document.status %>
        </span>
      </div>
    <% end %>
  </div>
</div>
```

### Dashboard Analytics

Interactive charts and metrics:

```javascript
// Document types distribution
const ctx = document.getElementById('documentTypesChart').getContext('2d');
const chart = new Chart(ctx, {
  type: 'doughnut',
  data: {
    labels: <%= @document_types.keys.to_json.html_safe %>,
    datasets: [{
      data: <%= @document_types.values.to_json.html_safe %>,
      backgroundColor: [
        '#007bff', '#28a745', '#ffc107', '#dc3545', '#6f42c1'
      ]
    }]
  },
  options: {
    responsive: true,
    plugins: {
      legend: { position: 'bottom' }
    }
  }
});
```

## Document Management Interface

### Document Upload

Multi-tab upload interface with different input methods:

```erb
<!-- Upload tabs -->
<ul class="nav nav-tabs" id="uploadTabs">
  <li class="nav-item">
    <a class="nav-link active" data-bs-toggle="tab" href="#file-upload">
      <i class="fas fa-upload"></i> Upload Files
    </a>
  </li>
  <li class="nav-item">
    <a class="nav-link" data-bs-toggle="tab" href="#text-content">
      <i class="fas fa-keyboard"></i> Text Content
    </a>
  </li>
  <li class="nav-item">
    <a class="nav-link" data-bs-toggle="tab" href="#directory-upload">
      <i class="fas fa-folder"></i> Directory
    </a>
  </li>
</ul>

<!-- File upload tab -->
<div class="tab-content">
  <div class="tab-pane fade show active" id="file-upload">
    <%= form_with model: Ragdoll::Document.new, url: documents_path, multipart: true do |form| %>
      <div class="mb-3">
        <%= form.file_field :files, multiple: true, 
            accept: ".pdf,.docx,.txt,.md,.html,.json,.xml,.csv",
            class: "form-control", required: true %>
        <div class="form-text">
          Supported formats: PDF, DOCX, TXT, MD, HTML, JSON, XML, CSV
        </div>
      </div>
      
      <div class="row">
        <div class="col-md-6">
          <%= form.number_field :chunk_size, value: 1000, 
              class: "form-control", min: 100, max: 5000 %>
        </div>
        <div class="col-md-6">
          <%= form.number_field :chunk_overlap, value: 200, 
              class: "form-control", min: 0, max: 1000 %>
        </div>
      </div>
      
      <%= form.submit "Upload Documents", class: "btn btn-primary" %>
    <% end %>
  </div>
</div>
```

### Document List with Actions

Feature-rich document management interface:

```erb
<!-- Document filters -->
<div class="row mb-3">
  <%= form_with url: documents_path, method: :get, class: "col-md-12" do |form| %>
    <div class="row">
      <div class="col-md-3">
        <%= form.select :status, 
            options_for_select([['All', ''], ['Processed', 'processed'], ['Processing', 'processing'], ['Failed', 'failed']], params[:status]),
            {}, { class: "form-select" } %>
      </div>
      <div class="col-md-3">
        <%= form.select :document_type,
            options_for_select(@document_types.map { |type, count| [type.humanize, type] }, params[:document_type]),
            { include_blank: 'All Types' }, { class: "form-select" } %>
      </div>
      <div class="col-md-4">
        <%= form.text_field :search, placeholder: "Search documents...", 
            value: params[:search], class: "form-control" %>
      </div>
      <div class="col-md-2">
        <%= form.submit "Filter", class: "btn btn-outline-primary w-100" %>
      </div>
    </div>
  <% end %>
</div>

<!-- Document table -->
<div class="table-responsive">
  <table class="table table-striped">
    <thead class="table-dark">
      <tr>
        <th><input type="checkbox" id="select-all"></th>
        <th>Title</th>
        <th>Type</th>
        <th>Status</th>
        <th>Embeddings</th>
        <th>Updated</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% @documents.each do |document| %>
        <tr>
          <td>
            <input type="checkbox" name="document_ids[]" value="<%= document.id %>">
          </td>
          <td>
            <%= link_to document.title, document_path(document), 
                class: "text-decoration-none" %>
          </td>
          <td>
            <span class="badge bg-secondary">
              <%= document.document_type&.humanize || 'Unknown' %>
            </span>
          </td>
          <td>
            <span class="badge bg-<%= status_color(document.status) %>">
              <%= document.status %>
            </span>
          </td>
          <td><%= document.ragdoll_embeddings.count %></td>
          <td><%= time_ago_in_words(document.updated_at) %> ago</td>
          <td>
            <div class="btn-group btn-group-sm">
              <%= link_to document_path(document), 
                  class: "btn btn-outline-primary", 
                  data: { bs_toggle: "tooltip", bs_placement: "top", bs_title: "View" } do %>
                <i class="fas fa-eye"></i>
              <% end %>
              
              <%= link_to edit_document_path(document), 
                  class: "btn btn-outline-secondary",
                  data: { bs_toggle: "tooltip", bs_placement: "top", bs_title: "Edit" } do %>
                <i class="fas fa-edit"></i>
              <% end %>
              
              <%= link_to reprocess_document_path(document), method: :post,
                  class: "btn btn-outline-info",
                  data: { bs_toggle: "tooltip", bs_placement: "top", bs_title: "Reprocess" } do %>
                <i class="fas fa-redo"></i>
              <% end %>
              
              <%= link_to document_path(document), method: :delete,
                  class: "btn btn-outline-danger",
                  data: { 
                    bs_toggle: "tooltip", 
                    bs_placement: "top", 
                    bs_title: "Delete",
                    confirm: "Are you sure?" 
                  } do %>
                <i class="fas fa-trash"></i>
              <% end %>
            </div>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>

<!-- Bulk actions -->
<div class="d-flex justify-content-between align-items-center">
  <div>
    <button type="button" class="btn btn-primary" onclick="bulkReprocess()">
      <i class="fas fa-redo"></i> Reprocess Selected
    </button>
    <button type="button" class="btn btn-danger" onclick="bulkDelete()">
      <i class="fas fa-trash"></i> Delete Selected
    </button>
  </div>
  
  <!-- Pagination -->
  <%= paginate @documents if respond_to?(:paginate) %>
</div>
```

### Bulk Operations JavaScript

```javascript
// Bulk operations with CSRF protection
function bulkReprocess() {
  const selectedIds = getSelectedDocumentIds();
  if (selectedIds.length === 0) {
    alert('Please select documents to reprocess.');
    return;
  }
  
  if (confirm(`Reprocess ${selectedIds.length} selected documents?`)) {
    submitBulkAction('bulk_reprocess', selectedIds);
  }
}

function bulkDelete() {
  const selectedIds = getSelectedDocumentIds();
  if (selectedIds.length === 0) {
    alert('Please select documents to delete.');
    return;
  }
  
  if (confirm(`Delete ${selectedIds.length} selected documents? This cannot be undone.`)) {
    submitBulkAction('bulk_delete', selectedIds);
  }
}

function submitBulkAction(action, documentIds) {
  const form = document.createElement('form');
  form.method = 'POST';
  form.action = `/documents/${action}`;
  
  // Add CSRF token
  const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
  const csrfInput = document.createElement('input');
  csrfInput.type = 'hidden';
  csrfInput.name = 'authenticity_token';
  csrfInput.value = csrfToken;
  form.appendChild(csrfInput);
  
  // Add document IDs
  documentIds.forEach(id => {
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'document_ids[]';
    input.value = id;
    form.appendChild(input);
  });
  
  document.body.appendChild(form);
  form.submit();
}

function getSelectedDocumentIds() {
  const checkboxes = document.querySelectorAll('input[name="document_ids[]"]:checked');
  return Array.from(checkboxes).map(cb => cb.value);
}

// Select all functionality
document.getElementById('select-all').addEventListener('change', function() {
  const checkboxes = document.querySelectorAll('input[name="document_ids[]"]');
  checkboxes.forEach(cb => cb.checked = this.checked);
});
```

## Search Interface

### Advanced Search Form

Comprehensive search with multiple filters:

```erb
<!-- Search form -->
<%= form_with url: search_path, method: :post, class: "search-form" do |form| %>
  <div class="row mb-4">
    <div class="col-md-8">
      <div class="input-group input-group-lg">
        <%= form.text_field :query, 
            placeholder: "Enter your search query...", 
            class: "form-control", 
            required: true %>
        <%= form.submit "Search", class: "btn btn-primary" %>
      </div>
    </div>
  </div>
  
  <!-- Advanced filters -->
  <div class="accordion" id="advancedFilters">
    <div class="accordion-item">
      <h2 class="accordion-header">
        <button class="accordion-button collapsed" type="button" 
                data-bs-toggle="collapse" data-bs-target="#filterOptions">
          Advanced Filters
        </button>
      </h2>
      <div id="filterOptions" class="accordion-collapse collapse">
        <div class="accordion-body">
          <div class="row">
            <div class="col-md-3">
              <%= form.select :document_type, 
                  options_for_select(@document_types, params[:document_type]),
                  { include_blank: 'All Types' }, 
                  { class: "form-select" } %>
            </div>
            <div class="col-md-3">
              <%= form.number_field :limit, 
                  value: params[:limit] || 10,
                  min: 1, max: 50, 
                  class: "form-control" %>
              <div class="form-text">Results limit</div>
            </div>
            <div class="col-md-3">
              <%= form.number_field :threshold, 
                  value: params[:threshold] || 0.7,
                  min: 0.0, max: 1.0, step: 0.1,
                  class: "form-control" %>
              <div class="form-text">Similarity threshold</div>
            </div>
            <div class="col-md-3">
              <div class="form-check">
                <%= form.check_box :use_usage_ranking, 
                    checked: params[:use_usage_ranking],
                    class: "form-check-input" %>
                <%= form.label :use_usage_ranking, 
                    "Smart ranking", 
                    class: "form-check-label" %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
<% end %>
```

### Search Results Display

Rich result presentation with metadata:

```erb
<!-- Search results -->
<% if @results&.any? %>
  <div class="search-results">
    <h4>Search Results (<%= @results.length %>)</h4>
    
    <% @detailed_results.each_with_index do |result, index| %>
      <div class="card mb-3 search-result-card">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-start">
            <h6 class="card-title">
              <%= link_to result[:document].title, 
                  document_path(result[:document]), 
                  class: "text-decoration-none" %>
            </h6>
            <span class="badge bg-info ms-2">
              <%= number_with_precision(result[:similarity], precision: 3) %>
            </span>
          </div>
          
          <p class="card-text"><%= result[:content] %></p>
          
          <div class="card-footer bg-light">
            <small class="text-muted">
              <i class="fas fa-file"></i> <%= result[:document].document_type&.humanize %>
              <i class="fas fa-calendar ms-2"></i> <%= result[:document].created_at.strftime("%B %d, %Y") %>
              <% if result[:metadata]&.any? %>
                <i class="fas fa-tags ms-2"></i> 
                <% result[:metadata].each do |key, value| %>
                  <span class="badge bg-secondary ms-1"><%= "#{key}: #{value}" %></span>
                <% end %>
              <% end %>
            </small>
          </div>
        </div>
      </div>
    <% end %>
  </div>
<% elsif @query.present? %>
  <div class="alert alert-info">
    <i class="fas fa-info-circle"></i>
    No results found for "<%= @query %>". Try adjusting your search terms or lowering the similarity threshold.
  </div>
<% end %>
```

## Analytics Interface

### Search Analytics Dashboard

```erb
<!-- Analytics overview -->
<div class="row mb-4">
  <div class="col-md-12">
    <h3>Search Analytics</h3>
    <p class="text-muted">Search patterns and performance metrics for the last <%= @days %> days</p>
  </div>
</div>

<!-- Metrics cards -->
<div class="row mb-4">
  <div class="col-md-3">
    <div class="card bg-primary text-white">
      <div class="card-body text-center">
        <h5><i class="fas fa-search"></i> Total Searches</h5>
        <h2><%= @analytics[:total_searches] %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card bg-success text-white">
      <div class="card-body text-center">
        <h5><i class="fas fa-clock"></i> Avg Response Time</h5>
        <h2><%= @analytics[:avg_response_time] %>ms</h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card bg-info text-white">
      <div class="card-body text-center">
        <h5><i class="fas fa-bullseye"></i> Avg Results</h5>
        <h2><%= @analytics[:avg_results] %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card bg-warning text-white">
      <div class="card-body text-center">
        <h5><i class="fas fa-percentage"></i> Success Rate</h5>
        <h2><%= @analytics[:success_rate] %>%</h2>
      </div>
    </div>
  </div>
</div>

<!-- Charts -->
<div class="row">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">
        <h5>Search Activity Over Time</h5>
      </div>
      <div class="card-body">
        <canvas id="searchActivityChart"></canvas>
      </div>
    </div>
  </div>
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h5>Popular Queries</h5>
      </div>
      <div class="card-body">
        <% @popular_queries.each_with_index do |query_data, index| %>
          <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="badge bg-primary me-2"><%= index + 1 %></span>
            <span class="flex-grow-1"><%= truncate(query_data[:query], length: 30) %></span>
            <span class="badge bg-secondary"><%= query_data[:count] %></span>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

## Configuration Interface

### Engine Settings Management

```erb
<!-- Configuration form -->
<%= form_with url: configuration_path, method: :post do |form| %>
  <div class="row">
    <!-- LLM Provider Selection -->
    <div class="col-md-6">
      <div class="card">
        <div class="card-header">
          <h5><i class="fas fa-robot"></i> LLM Provider</h5>
        </div>
        <div class="card-body">
          <%= form.select :llm_provider, 
              options_for_select([
                ['OpenAI', 'openai'],
                ['Anthropic', 'anthropic'],
                ['Google', 'google'],
                ['Azure OpenAI', 'azure'],
                ['Ollama', 'ollama'],
                ['HuggingFace', 'huggingface']
              ], @configuration.llm_provider),
              {}, { class: "form-select", onchange: "updateProviderFields()" } %>
              
          <div id="provider-specific-fields">
            <!-- Dynamic fields based on provider -->
          </div>
        </div>
      </div>
    </div>
    
    <!-- Processing Settings -->
    <div class="col-md-6">
      <div class="card">
        <div class="card-header">
          <h5><i class="fas fa-cogs"></i> Processing Settings</h5>
        </div>
        <div class="card-body">
          <div class="mb-3">
            <%= form.label :chunk_size, class: "form-label" %>
            <%= form.number_field :chunk_size, 
                value: @configuration.chunk_size,
                min: 100, max: 5000, step: 100,
                class: "form-control" %>
          </div>
          
          <div class="mb-3">
            <%= form.label :chunk_overlap, class: "form-label" %>
            <%= form.number_field :chunk_overlap,
                value: @configuration.chunk_overlap,
                min: 0, max: 1000, step: 50,
                class: "form-control" %>
          </div>
          
          <div class="mb-3">
            <%= form.label :search_similarity_threshold, "Similarity Threshold", class: "form-label" %>
            <%= form.number_field :search_similarity_threshold,
                value: @configuration.search_similarity_threshold,
                min: 0.0, max: 1.0, step: 0.1,
                class: "form-control" %>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <!-- Feature Toggles -->
  <div class="row mt-3">
    <div class="col-md-12">
      <div class="card">
        <div class="card-header">
          <h5><i class="fas fa-toggle-on"></i> Features</h5>
        </div>
        <div class="card-body">
          <div class="row">
            <div class="col-md-4">
              <div class="form-check">
                <%= form.check_box :enable_search_analytics,
                    checked: @configuration.enable_search_analytics,
                    class: "form-check-input" %>
                <%= form.label :enable_search_analytics, "Search Analytics", class: "form-check-label" %>
              </div>
            </div>
            <div class="col-md-4">
              <div class="form-check">
                <%= form.check_box :enable_usage_tracking,
                    checked: @configuration.enable_usage_tracking,
                    class: "form-check-input" %>
                <%= form.label :enable_usage_tracking, "Usage Tracking", class: "form-check-label" %>
              </div>
            </div>
            <div class="col-md-4">
              <div class="form-check">
                <%= form.check_box :enable_document_summarization,
                    checked: @configuration.enable_document_summarization,
                    class: "form-check-input" %>
                <%= form.label :enable_document_summarization, "Document Summarization", class: "form-check-label" %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <div class="mt-3">
    <%= form.submit "Save Configuration", class: "btn btn-primary" %>
    <button type="button" class="btn btn-secondary" onclick="resetToDefaults()">
      Reset to Defaults
    </button>
  </div>
<% end %>
```

## Customization and Theming

### Override Default Views

Create views in your application to override engine views:

```ruby
# Create directory structure
mkdir -p app/views/ragdoll/documents
mkdir -p app/views/ragdoll/search

# Override specific views
cp [engine_path]/app/views/ragdoll/documents/index.html.erb app/views/ragdoll/documents/
```

### Custom Styling

```scss
// app/assets/stylesheets/ragdoll_custom.scss

// Override Bootstrap variables
$primary: #your-brand-color;
$success: #your-success-color;

// Custom ragdoll styles
.ragdoll-dashboard {
  .stats-card {
    transition: transform 0.2s;
    
    &:hover {
      transform: translateY(-2px);
    }
  }
}

.search-result-card {
  border-left: 4px solid $primary;
  
  .similarity-badge {
    background: linear-gradient(45deg, $primary, lighten($primary, 20%));
  }
}

// Dark mode support
@media (prefers-color-scheme: dark) {
  .ragdoll-dashboard {
    background-color: #1a1a1a;
    color: #ffffff;
  }
}
```

### Extend Controllers

```ruby
# app/controllers/ragdoll/documents_controller.rb
class Ragdoll::DocumentsController < Ragdoll::ApplicationController
  before_action :authenticate_user!
  before_action :authorize_document_access!
  
  # Override index to add custom filtering
  def index
    @documents = current_user.accessible_documents
    @documents = apply_custom_filters(@documents)
    # ... rest of implementation
  end
  
  private
  
  def authorize_document_access!
    redirect_to root_path unless current_user.can_access_documents?
  end
  
  def apply_custom_filters(documents)
    # Add user-specific or organization-specific filtering
    documents = documents.where(organization: current_user.organization)
    documents = documents.where(created_by: current_user) unless current_user.admin?
    documents
  end
end
```

## Mobile Responsiveness

The UI is fully responsive and mobile-optimized:

```erb
<!-- Mobile navigation -->
<nav class="navbar navbar-expand-lg navbar-dark bg-primary">
  <div class="container-fluid">
    <a class="navbar-brand" href="/">Ragdoll</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <!-- Navigation items -->
    </div>
  </div>
</nav>

<!-- Mobile-optimized search -->
<div class="d-block d-md-none">
  <div class="input-group mb-3">
    <%= form.text_field :query, class: "form-control", placeholder: "Search..." %>
    <%= form.submit "Go", class: "btn btn-primary" %>
  </div>
</div>
```

## Progressive Web App Features

Enable PWA capabilities:

```json
// app/views/pwa/manifest.json.erb
{
  "name": "Your App - Ragdoll",
  "short_name": "Ragdoll",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#007bff",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    }
  ]
}
```

## Best Practices

1. **Authentication**: Always implement authentication before deploying
2. **Authorization**: Add role-based access control for different features
3. **Customization**: Start with default UI and customize gradually
4. **Performance**: Use pagination for large document lists
5. **Mobile**: Test interface on mobile devices
6. **Accessibility**: Ensure proper ARIA labels and keyboard navigation
7. **Integration**: Use existing design system colors and fonts when possible
8. **Analytics**: Enable analytics to understand usage patterns