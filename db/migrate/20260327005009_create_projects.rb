class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :prefix, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :attribute_schema, null: false, default: {}

      t.timestamps
    end

    add_index :projects, [:organization_id, :prefix], unique: true
    add_index :projects, [:organization_id, :name], unique: true
  end
end
