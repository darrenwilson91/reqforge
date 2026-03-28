class CreateRequirementModules < ActiveRecord::Migration[8.1]
  def change
    create_table :requirement_modules do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :position

      t.timestamps
    end

    add_index :requirement_modules, [:project_id, :name], unique: true
    add_index :requirement_modules, [:project_id, :position]
  end
end
