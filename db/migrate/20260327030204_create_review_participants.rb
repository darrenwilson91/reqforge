class CreateReviewParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :review_participants do |t|
      t.references :review, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :review_participants, [:review_id, :user_id], unique: true
    add_index :review_participants, [:review_id, :role]
  end
end
