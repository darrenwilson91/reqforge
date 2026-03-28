class AddShareTokenToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :share_token, :string
    add_index :reviews, :share_token, unique: true, where: "share_token IS NOT NULL"
  end
end
