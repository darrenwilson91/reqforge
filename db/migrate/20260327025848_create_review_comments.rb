class CreateReviewComments < ActiveRecord::Migration[8.1]
  def change
    create_table :review_comments do |t|
      t.references :review_item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.references :parent_comment, null: true, foreign_key: { to_table: :review_comments }
      t.boolean :resolved, null: false, default: false
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :review_comments, [:review_item_id, :created_at]
  end
end
