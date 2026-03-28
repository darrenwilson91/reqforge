class CreateChangeSetComments < ActiveRecord::Migration[8.1]
  def change
    create_table :change_set_comments do |t|
      t.references :change_set, null: false, foreign_key: true
      t.references :change_set_change, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.references :parent_comment, foreign_key: { to_table: :change_set_comments }
      t.boolean :resolved, null: false, default: false
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :change_set_comments, [:change_set_id, :created_at]
    add_index :change_set_comments, [:change_set_change_id, :created_at]
  end
end
