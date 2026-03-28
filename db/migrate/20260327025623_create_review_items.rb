class CreateReviewItems < ActiveRecord::Migration[8.1]
  def change
    create_table :review_items do |t|
      t.references :review, null: false, foreign_key: true
      t.references :requirement, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.jsonb :snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :review_items, [ :review_id, :requirement_id ], unique: true
    add_index :review_items, [ :review_id, :status ]
  end
end
