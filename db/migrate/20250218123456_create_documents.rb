# This migration creates the documents table with necessary extensions for PostgreSQL.

module Ragdoll
  class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pg_trgm'
    enable_extension 'fuzzystrmatch'

    create_table :documents do |t|
      t.string :location
      t.string :summary
      t.string :type
      t.datetime :processing_started_at
      t.datetime :processing_finished_at

      t.timestamps
    end
  end
  end
end
