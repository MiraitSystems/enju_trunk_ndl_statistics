class NdlStatCheckout < ActiveRecord::Base
  belongs_to :ndl_statistic

  validates_presence_of :checkout_type_id, :carrier_type_id, :users_count, :items_count
  validates_numericality_of :checkout_type_id, :carrier_type_id, :users_count, :items_count
end
