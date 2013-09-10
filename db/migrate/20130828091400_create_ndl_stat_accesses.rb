class CreateNdlStatAccesses < ActiveRecord::Migration
  def change
    create_table :ndl_stat_accesses do |t|
      t.string :log_type, :null => false
      t.boolean :internal, :null => false
      t.integer :count, :null => false
      t.references :ndl_statistic, :null => false

      t.timestamps
    end
    add_index :ndl_stat_accesses, :ndl_statistic_id
  end

end
