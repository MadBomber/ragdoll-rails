class BulkUploadStatus {
  constructor() {
    this.activeUploads = new Map();
    this.container = null;
    this.isMinimized = false;
    this.cable = null;
    this.subscriptions = new Map();
    this.init();
    this.restoreActiveUploads(); // Restore uploads from previous page
  }

  init() {
    this.createContainer();
    this.setupEventListeners();
    this.cable = ActionCable.createConsumer();
  }
  
  // Restore active uploads from sessionStorage when page loads
  restoreActiveUploads() {
    const storedUploads = sessionStorage.getItem('ragdoll_active_uploads');
    if (storedUploads) {
      try {
        const uploads = JSON.parse(storedUploads);
        console.log('🔄 Restoring active uploads:', uploads);
        
        uploads.forEach(upload => {
          // Only restore if upload is not completed or failed
          if (upload.status === 'processing' || upload.status === 'starting') {
            // Convert date strings back to Date objects
            upload.startTime = new Date(upload.startTime);
            if (upload.completedAt) upload.completedAt = new Date(upload.completedAt);
            if (upload.failedAt) upload.failedAt = new Date(upload.failedAt);
            
            this.activeUploads.set(upload.sessionId, upload);
            this.subscribeToSession(upload.sessionId);
          }
        });
        
        if (this.activeUploads.size > 0) {
          this.updateDisplay();
          this.show();
          
          // Restore minimized state
          const minimizedState = sessionStorage.getItem('ragdoll_popup_minimized');
          if (minimizedState === 'true') {
            this.isMinimized = true;
            this.container.classList.add('minimized');
            const icon = this.container.querySelector('.minimize-btn i');
            if (icon) icon.className = 'fas fa-plus';
          }
        }
      } catch (e) {
        console.error('Failed to restore uploads:', e);
      }
    }
  }
  
  // Save active uploads to sessionStorage whenever they change
  saveActiveUploads() {
    const uploadsToSave = Array.from(this.activeUploads.values()).filter(upload => 
      upload.status === 'processing' || upload.status === 'starting'
    );
    sessionStorage.setItem('ragdoll_active_uploads', JSON.stringify(uploadsToSave));
  }

  createContainer() {
    this.container = document.createElement('div');
    this.container.id = 'bulk-upload-status-container';
    this.container.className = 'bulk-upload-status-container';
    this.container.innerHTML = `
      <div class="bulk-upload-status-header">
        <span class="bulk-upload-status-title">
          <i class="fas fa-cloud-upload-alt"></i>
          <span class="title-text">Upload Progress</span>
        </span>
        <div class="bulk-upload-status-controls">
          <button class="minimize-btn" title="Minimize">
            <i class="fas fa-minus"></i>
          </button>
          <button class="close-btn" title="Close completed uploads">
            <i class="fas fa-times"></i>
          </button>
        </div>
      </div>
      <div class="bulk-upload-status-content">
        <div class="no-uploads-message">
          No active uploads
        </div>
      </div>
    `;
    
    document.body.appendChild(this.container);
    this.hide();
  }

  setupEventListeners() {
    // Minimize/maximize toggle
    this.container.querySelector('.minimize-btn').addEventListener('click', () => {
      this.toggle();
    });

    // Close completed uploads
    this.container.querySelector('.close-btn').addEventListener('click', () => {
      this.closeCompletedUploads();
    });

    // Make draggable
    this.makeDraggable();
  }

  makeDraggable() {
    const header = this.container.querySelector('.bulk-upload-status-header');
    let isDragging = false;
    let currentX;
    let currentY;
    let initialX;
    let initialY;
    let xOffset = 0;
    let yOffset = 0;

    header.addEventListener('mousedown', (e) => {
      if (e.target.closest('button')) return;
      
      initialX = e.clientX - xOffset;
      initialY = e.clientY - yOffset;
      isDragging = true;
      header.style.cursor = 'grabbing';
    });

    document.addEventListener('mousemove', (e) => {
      if (isDragging) {
        e.preventDefault();
        currentX = e.clientX - initialX;
        currentY = e.clientY - initialY;
        xOffset = currentX;
        yOffset = currentY;
        
        this.container.style.transform = `translate(${currentX}px, ${currentY}px)`;
      }
    });

    document.addEventListener('mouseup', () => {
      isDragging = false;
      header.style.cursor = 'grab';
    });
  }

  startUpload(sessionId, totalFiles) {
    const upload = {
      sessionId,
      totalFiles,
      processed: 0,
      failed: 0,
      currentFile: null,
      status: 'starting',
      startTime: new Date(),
      errors: []
    };

    this.activeUploads.set(sessionId, upload);
    this.subscribeToSession(sessionId);
    this.saveActiveUploads(); // Save to sessionStorage
    this.updateDisplay();
    this.show();
  }

  subscribeToSession(sessionId) {
    if (this.subscriptions.has(sessionId)) {
      return; // Already subscribed
    }

    const subscription = this.cable.subscriptions.create(
      { 
        channel: "Ragdoll::BulkUploadStatusChannel", 
        session_id: sessionId 
      },
      {
        received: (data) => {
          this.handleStatusUpdate(sessionId, data);
        },
        
        connected: () => {
          console.log(`Connected to bulk upload status for session ${sessionId}`);
        },
        
        disconnected: () => {
          console.log(`Disconnected from bulk upload status for session ${sessionId}`);
        }
      }
    );

    this.subscriptions.set(sessionId, subscription);
  }

  handleStatusUpdate(sessionId, data) {
    const upload = this.activeUploads.get(sessionId);
    if (!upload) return;

    switch (data.type) {
      case 'upload_start':
        upload.status = 'processing';
        upload.totalFiles = data.total_files;
        break;

      case 'file_start':
        upload.currentFile = data.filename;
        upload.processed = data.processed;
        break;

      case 'file_complete':
        upload.processed = data.processed;
        upload.currentFile = null;
        break;

      case 'file_error':
        upload.processed = data.processed;
        upload.failed++;
        upload.errors.push({
          filename: data.filename,
          error: data.error
        });
        break;

      case 'upload_complete':
        upload.status = 'completed';
        upload.processed = data.processed;
        upload.failed = data.failed;
        upload.currentFile = null;
        upload.completedAt = new Date();
        this.scheduleAutoClose(sessionId);
        
        // If all files processed successfully, optionally redirect to documents page
        if (data.failed === 0 && window.location.pathname.includes('/documents/new')) {
          setTimeout(() => {
            window.location.href = '/ragdoll/documents';
          }, 5000); // Redirect after 5 seconds to show completion message
        }
        break;

      case 'upload_error':
        upload.status = 'failed';
        upload.error = data.error;
        upload.failedAt = new Date();
        break;
    }

    this.saveActiveUploads(); // Save state after each update
    this.updateDisplay();
  }

  updateDisplay() {
    const content = this.container.querySelector('.bulk-upload-status-content');
    
    if (this.activeUploads.size === 0) {
      content.innerHTML = '<div class="no-uploads-message">No active uploads</div>';
      return;
    }

    const uploadsHTML = Array.from(this.activeUploads.entries()).map(([sessionId, upload]) => {
      return this.renderUpload(sessionId, upload);
    }).join('');

    content.innerHTML = uploadsHTML;
  }

  renderUpload(sessionId, upload) {
    const percentage = upload.totalFiles > 0 ? (upload.processed / upload.totalFiles * 100) : 0;
    const statusClass = this.getStatusClass(upload.status);
    const eta = this.calculateETA(upload);

    return `
      <div class="upload-item ${statusClass}" data-session-id="${sessionId}">
        <div class="upload-header">
          <span class="upload-title">
            <i class="${this.getStatusIcon(upload.status)}"></i>
            Bulk Upload (${upload.totalFiles} files)
          </span>
          <span class="upload-percentage">${percentage.toFixed(1)}%</span>
        </div>
        
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${percentage}%"></div>
        </div>
        
        <div class="upload-details">
          <div class="upload-stats">
            <span class="processed-count">${upload.processed}/${upload.totalFiles} processed</span>
            ${upload.failed > 0 ? `<span class="failed-count">${upload.failed} failed</span>` : ''}
            ${eta ? `<span class="eta">ETA: ${eta}</span>` : ''}
          </div>
          
          ${upload.currentFile ? `
            <div class="current-file">
              <i class="fas fa-file-alt"></i>
              Processing: ${upload.currentFile}
            </div>
          ` : ''}
          
          ${upload.status === 'completed' ? `
            <div class="completion-message">
              <i class="fas fa-check-circle"></i>
              Upload completed successfully
            </div>
          ` : ''}
          
          ${upload.status === 'failed' ? `
            <div class="error-message">
              <i class="fas fa-exclamation-triangle"></i>
              Upload failed: ${upload.error}
            </div>
          ` : ''}
          
          ${upload.errors.length > 0 ? `
            <div class="error-list">
              <details>
                <summary>${upload.errors.length} file(s) failed</summary>
                <ul>
                  ${upload.errors.map(err => `<li>${err.filename}: ${err.error}</li>`).join('')}
                </ul>
              </details>
            </div>
          ` : ''}
        </div>
      </div>
    `;
  }

  getStatusClass(status) {
    const classes = {
      'starting': 'status-starting',
      'processing': 'status-processing',
      'completed': 'status-completed',
      'failed': 'status-failed'
    };
    return classes[status] || '';
  }

  getStatusIcon(status) {
    const icons = {
      'starting': 'fas fa-clock',
      'processing': 'fas fa-spinner fa-spin',
      'completed': 'fas fa-check-circle',
      'failed': 'fas fa-exclamation-triangle'
    };
    return icons[status] || 'fas fa-circle';
  }

  calculateETA(upload) {
    if (upload.status !== 'processing' || upload.processed === 0) {
      return null;
    }

    const elapsed = (new Date() - upload.startTime) / 1000; // seconds
    const rate = upload.processed / elapsed; // files per second
    const remaining = upload.totalFiles - upload.processed;
    const etaSeconds = remaining / rate;

    if (etaSeconds > 60) {
      const minutes = Math.ceil(etaSeconds / 60);
      return `${minutes}m`;
    } else {
      return `${Math.ceil(etaSeconds)}s`;
    }
  }

  scheduleAutoClose(sessionId) {
    setTimeout(() => {
      this.removeUpload(sessionId);
    }, 30000); // Auto-close after 30 seconds
  }

  removeUpload(sessionId) {
    const subscription = this.subscriptions.get(sessionId);
    if (subscription) {
      subscription.unsubscribe();
      this.subscriptions.delete(sessionId);
    }
    
    this.activeUploads.delete(sessionId);
    this.saveActiveUploads(); // Update sessionStorage
    this.updateDisplay();
    
    if (this.activeUploads.size === 0) {
      this.hide();
      sessionStorage.removeItem('ragdoll_active_uploads'); // Clear storage when no uploads
    }
  }

  closeCompletedUploads() {
    const completedSessions = Array.from(this.activeUploads.entries())
      .filter(([_, upload]) => upload.status === 'completed' || upload.status === 'failed')
      .map(([sessionId, _]) => sessionId);
    
    completedSessions.forEach(sessionId => {
      this.removeUpload(sessionId);
    });
  }

  show() {
    this.container.classList.add('visible');
  }

  hide() {
    this.container.classList.remove('visible');
  }

  toggle() {
    this.isMinimized = !this.isMinimized;
    this.container.classList.toggle('minimized', this.isMinimized);
    
    const icon = this.container.querySelector('.minimize-btn i');
    icon.className = this.isMinimized ? 'fas fa-plus' : 'fas fa-minus';
    
    // Save minimized state
    sessionStorage.setItem('ragdoll_popup_minimized', this.isMinimized ? 'true' : 'false');
  }
}

// Global instance
window.BulkUploadStatus = BulkUploadStatus;

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  if (!window.bulkUploadStatus) {
    window.bulkUploadStatus = new BulkUploadStatus();
  }
});

// Handle Turbo page changes
document.addEventListener('turbo:load', () => {
  // Check if we already have an instance
  if (window.bulkUploadStatus) {
    // Destroy old instance properly
    if (window.bulkUploadStatus.container && window.bulkUploadStatus.container.parentNode) {
      window.bulkUploadStatus.container.parentNode.removeChild(window.bulkUploadStatus.container);
    }
  }
  // Always create a new instance on Turbo navigation to restore state
  window.bulkUploadStatus = new BulkUploadStatus();
});

// Save state before navigating away
document.addEventListener('turbo:before-cache', () => {
  if (window.bulkUploadStatus) {
    window.bulkUploadStatus.saveActiveUploads();
  }
});

// Also handle regular page unload for non-Turbo navigation
window.addEventListener('beforeunload', () => {
  if (window.bulkUploadStatus) {
    window.bulkUploadStatus.saveActiveUploads();
  }
});