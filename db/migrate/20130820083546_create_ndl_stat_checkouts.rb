class CreateNdlStatCheckouts < ActiveRecord::Migration
  def change
    create_table :ndl_stat_checkouts do |t|
      t.integer :checkout_type_id, :null => false
      t.integer :carrier_type_id, :null => false
      t.integer :users_count, :null => false
      t.integer :items_count, :null => false
      t.references :ndl_statistic, :null => false

      t.timestamps
    end
    add_index :ndl_stat_checkouts, :ndl_statistic_id
  end
end
