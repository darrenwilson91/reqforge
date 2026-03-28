class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.jsonb :baseline_snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :reviews, [:project_id, :status]
  end
end
