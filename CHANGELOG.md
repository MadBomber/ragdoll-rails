# This file documents the changes and version history of the Ragdoll Rails Engine.

## [Unreleased]

## [0.1.12] - 2025-09-23

### Added
- Support for unified text-based RAG architecture with cross-modal search capabilities
- New factory definitions for unified content models (UnifiedDocument, UnifiedContent)
- Support for image and audio file uploads in unified text conversion workflow
- Text conversion settings in Rails configuration template (image_detail_level, audio_transcription_provider)
- Deprecation warnings for document_type filtering in views and controllers
- Enhanced file type support including images (jpg, jpeg, png, gif) and audio (mp3, wav, m4a)

### Changed
- **BREAKING**: Migrated from multi-modal architecture to unified text-based RAG system
- Updated ragdoll_config.rb template to use single embedding model (text-embedding-3-large)
- Added unified content architecture settings (use_unified_content, text_conversion)
- Enhanced documents index and search views with deprecation notices for document_type filtering
- Updated Rails configuration to support all media types for text conversion
- Modified search controller to log deprecation warnings when document_type filtering is used
- Updated factory specifications to reference unified content factories
- Deprecated ragdoll_text_content factory in favor of ragdoll_unified_content

### Fixed
- Updated factory tests to expect unified content and document factories
- Corrected references to deprecated text content factories

### Migration Notes
- All media types (images, audio, documents) are now converted to searchable text
- Document type filtering is deprecated but still functional for backward compatibility
- Single embedding model replaces previous type-specific embedding models
- Cross-modal search now supported (find images by descriptions, audio by transcripts)

## [0.1.11] - 2025-02-18

### Added
- BulkUploadStatus component for managing and displaying bulk upload progress
- Bulk document upload functionality with session tracking and batch processing
- Force option for document uploads to allow overwriting existing documents
- Safe logging methods to handle missing RagdollLogging module
- Detailed logging throughout bulk upload process
- Form-based search query submission for improved user experience
- Enhanced search parameter logging and results handling
- Popular search queries tracking with frequency sorting
- Document selection feature with checkboxes in document list view
- Table view support for document selection
- Document show and edit views with full document details
- Turbo method for delete links with confirmation dialogs
- ActionCable integration for real-time features
- Analytics dashboard with search statistics and trends
- Job queue dashboard for monitoring background jobs
- Document search page with similarity and full-text search options
- New application layout for Ragdoll Dashboard
- JavaScript and CSS files for Rails Engine
- Preview paths configuration in development environment

### Changed
- Replaced Rails logger with instance logger throughout for improved consistency
- Simplified bulk_upload method by removing excessive logging and comments
- Enhanced file filtering logic to exclude non-file objects in uploads
- Updated skip_before_action for create method in documents controller
- Changed BulkDocumentProcessingJob queue from 'ragdoll' to 'default'
- Replaced ActionCable Rails.logger references with standard logger
- Enhanced search threshold results handling
- Updated popular queries to count and sort by frequency
- Replaced query links with forms for better search handling
- Updated document list to display correct attributes
- Updated link helpers to use correct document paths
- Changed delete links to use turbo_method for better handling

### Fixed
- Fixed controller skip_before_action for create method
- Corrected reference to BulkDocumentProcessingJob in documentation
- Fixed channel logging to use logger instead of Rails.logger
- Fixed process_file_job to remove unnecessary document_url from completion data
- Fixed namespace isolation for Ragdoll engine
- Fixed safe addition of preview paths in development environment
- Fixed search controller threshold condition to respect Rails environment

### Removed
- Recent searches functionality from search controller and view
- Bold formatting from search query button
- Search tracking (disabled for privacy)
- Debug info from search results view
- Unnecessary document_url from process_file_job completion data


## [0.1.10] - 2025-02-18

## [0.1.9] - 2025-02-18

## [0.1.8] - 2025-02-18

## [0.1.7] - 2025-02-18

## [0.1.6] - 2025-02-18

## [0.1.5] - 2025-02-18

## [0.1.4] - 2025-02-18

## [0.1.3] - 2025-02-18

## [0.1.2] - 2025-02-18

## [0.1.1] - 2025-02-18

## [0.1.0] - 2025-02-18

- Initial release
