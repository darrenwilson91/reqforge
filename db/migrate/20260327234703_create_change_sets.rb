class CreateChangeSets < ActiveRecord::Migration[8.1]
  def change
    create_table :change_sets do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :source_baseline, null: true, foreign_key: { to_table: :reviews }
      t.text :merge_commit_message
      t.references :merged_by, null: true, foreign_key: { to_table: :users }
      t.datetime :merged_at

      t.timestamps
    end

    add_index :change_sets, [:project_id, :status]
  end
end
