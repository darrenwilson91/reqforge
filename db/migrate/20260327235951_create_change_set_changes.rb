class CreateChangeSetChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :change_set_changes do |t|
      t.references :change_set, null: false, foreign_key: true
      t.references :requirement, null: false, foreign_key: true
      t.integer :change_type, null: false, default: 0
      t.jsonb :before_snapshot, default: {}
      t.jsonb :after_snapshot, default: {}

      t.timestamps
    end

    add_index :change_set_changes, [:change_set_id, :requirement_id], unique: true
    add_index :change_set_changes, [:change_set_id, :change_type]
  end
end
