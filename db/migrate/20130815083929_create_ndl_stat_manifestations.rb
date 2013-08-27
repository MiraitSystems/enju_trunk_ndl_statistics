class CreateNdlStatManifestations < ActiveRecord::Migration
  def change
    create_table :ndl_stat_manifestations do |t|
      t.string :stat_type, :null => false
      t.string :region, :null => false
      t.integer :checkout_type_id, :null => false
      t.integer :carrier_type_id, :null => false
      t.integer :count, :null => false
      t.boolean :pub_flg, :null => false
      t.references :ndl_statistic, :null => false

      t.timestamps
    end
    add_index :ndl_stat_manifestations, :ndl_statistic_id
  end
end
