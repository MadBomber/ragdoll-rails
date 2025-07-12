# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_11_153612) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "fuzzystrmatch"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "vector"

  create_table "ragdoll_documents", force: :cascade do |t|
    t.string "location", null: false
    t.text "content"
    t.text "summary"
    t.string "document_type"
    t.string "title"
    t.string "source_type"
    t.integer "chunk_size"
    t.integer "chunk_overlap"
    t.jsonb "metadata", default: {}
    t.datetime "processing_started_at"
    t.datetime "processing_finished_at"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "summary_generated_at", precision: nil
    t.string "summary_model"
    t.index ["document_type"], name: "index_ragdoll_documents_on_document_type"
    t.index ["location"], name: "index_ragdoll_documents_on_location", unique: true
    t.index ["metadata"], name: "index_ragdoll_documents_on_metadata", using: :gin
    t.index ["processing_started_at"], name: "index_ragdoll_documents_on_processing_started_at"
    t.index ["status"], name: "index_ragdoll_documents_on_status"
    t.index ["summary_generated_at"], name: "index_ragdoll_documents_on_summary_generated_at"
    t.index ["summary_model"], name: "index_ragdoll_documents_on_summary_model"
  end

  create_table "ragdoll_embeddings", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.text "content", null: false
    t.text "embedding"
    t.string "model_name"
    t.integer "token_count"
    t.integer "chunk_index"
    t.jsonb "metadata", default: {}
    t.string "embedding_type", default: "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "embedding_dimensions"
    t.integer "usage_count", default: 0, null: false
    t.datetime "returned_at", precision: nil
    t.index ["chunk_index"], name: "index_ragdoll_embeddings_on_chunk_index"
    t.index ["document_id"], name: "index_ragdoll_embeddings_on_document_id"
    t.index ["embedding_dimensions"], name: "index_ragdoll_embeddings_on_embedding_dimensions"
    t.index ["embedding_type"], name: "index_ragdoll_embeddings_on_embedding_type"
    t.index ["metadata"], name: "index_ragdoll_embeddings_on_metadata", using: :gin
    t.index ["model_name", "embedding_dimensions"], name: "index_ragdoll_embeddings_on_model_and_dimensions"
    t.index ["returned_at"], name: "index_ragdoll_embeddings_on_returned_at"
    t.index ["usage_count", "returned_at"], name: "index_ragdoll_embeddings_on_usage_and_recency"
    t.index ["usage_count"], name: "index_ragdoll_embeddings_on_usage_count"
  end

  create_table "ragdoll_searches", force: :cascade do |t|
    t.text "query", null: false
    t.text "query_embedding"
    t.string "search_type", default: "semantic"
    t.jsonb "filters", default: {}
    t.jsonb "results", default: {}
    t.integer "result_count", default: 0
    t.float "search_time"
    t.string "model_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ragdoll_searches_on_created_at"
    t.index ["search_type"], name: "index_ragdoll_searches_on_search_type"
  end

  add_foreign_key "ragdoll_embeddings", "ragdoll_documents", column: "document_id"
end
