class CreateAiAnalysisResults < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_analysis_results do |t|
      t.references :requirement, null: false, foreign_key: true
      t.string :analysis_type, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :result_data, null: false, default: {}
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ai_analysis_results, [:requirement_id, :analysis_type], unique: true
    add_index :ai_analysis_results, :analysis_type
    add_index :ai_analysis_results, :status
  end
end
