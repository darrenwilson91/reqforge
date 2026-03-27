class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :requirement_module, null: false, foreign_key: true
      t.references :parent_section, null: true, foreign_key: { to_table: :sections }
      t.string :name, null: false
      t.integer :position

      t.timestamps
    end

    add_index :sections, [:requirement_module_id, :parent_section_id, :name],
              unique: true, name: "index_sections_on_module_parent_and_name"
    add_index :sections, [:requirement_module_id, :position]
  end
end
