class CreateTestCases < ActiveRecord::Migration[8.1]
  def change
    create_table :test_cases do |t|
      t.references :project, null: false, foreign_key: true
      t.references :requirement, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.text :preconditions
      t.text :steps
      t.text :expected_result
      t.integer :test_type, null: false, default: 0
      t.integer :status, null: false, default: 5
      t.integer :priority, null: false, default: 0
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :uid, null: false

      t.timestamps
    end
    add_index :test_cases, :uid, unique: true
    add_index :test_cases, [:project_id, :test_type]
    add_index :test_cases, [:project_id, :status]
  end
end
