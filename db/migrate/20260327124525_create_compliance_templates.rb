class CreateComplianceTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :compliance_templates do |t|
      t.string :name, null: false
      t.string :standard, null: false
      t.text :description
      t.jsonb :template_data, null: false, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :compliance_templates, :standard
    add_index :compliance_templates, :name, unique: true
    add_index :compliance_templates, :active
  end
end
