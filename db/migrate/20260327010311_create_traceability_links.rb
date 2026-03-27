class CreateTraceabilityLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :traceability_links do |t|
      t.references :source_requirement, null: false, foreign_key: { to_table: :requirements }
      t.references :target_requirement, null: false, foreign_key: { to_table: :requirements }
      t.integer :link_type, null: false, default: 0
      t.text :description
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.boolean :ai_suggested, null: false, default: false
      t.float :confidence

      t.timestamps
    end

    add_index :traceability_links, [:source_requirement_id, :target_requirement_id, :link_type],
              unique: true, name: "idx_traceability_links_unique"
    add_index :traceability_links, :link_type
  end
end
