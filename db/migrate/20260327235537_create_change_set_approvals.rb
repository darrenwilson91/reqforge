class CreateChangeSetApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :change_set_approvals do |t|
      t.references :change_set, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.text :body

      t.timestamps
    end

    add_index :change_set_approvals, [:change_set_id, :user_id], unique: true
    add_index :change_set_approvals, [:change_set_id, :status]
  end
end
