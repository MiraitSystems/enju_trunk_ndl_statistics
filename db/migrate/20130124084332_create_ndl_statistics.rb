class CreateNdlStatistics < ActiveRecord::Migration
  def change
    create_table :ndl_statistics do |t|
      t.integer :term_id, :null => false

      t.timestamps
    end
  end
end
