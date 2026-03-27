class CreateRequirements < ActiveRecord::Migration[8.1]
  def change
    create_table :requirements do |t|
      t.references :section, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string :uid, null: false
      t.string :title, null: false
      t.text :body
      t.integer :requirement_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 0, null: false
      t.integer :asil_level, default: 0, null: false
      t.jsonb :custom_attributes, default: {}, null: false
      t.integer :position
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :requirements, :uid, unique: true
    add_index :requirements, [:section_id, :position]
    add_index :requirements, [:project_id, :requirement_type]
    add_index :requirements, [:project_id, :status]
  end
end
