class CreateNdlStatAccepts < ActiveRecord::Migration
  def change
    create_table :ndl_stat_accepts do |t|
      t.string :region, :null => false
      t.integer :accept_type_id, :null => false
      t.integer :checkout_type_id, :null => false
      t.integer :carrier_type_id, :null => false
      t.integer :count, :null => false
      t.boolean :pub_flg, :null => false
      t.references :ndl_statistic, :null => false

      t.timestamps
    end
    add_index :ndl_stat_accepts, :ndl_statistic_id
  end
end
