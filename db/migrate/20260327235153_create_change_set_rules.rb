class CreateChangeSetRules < ActiveRecord::Migration[8.1]
  def change
    create_table :change_set_rules do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.integer :min_approvals, null: false, default: 1
      t.boolean :require_all_conversations_resolved, null: false, default: true
      t.boolean :auto_merge_on_approval, null: false, default: false

      t.timestamps
    end
  end
end
