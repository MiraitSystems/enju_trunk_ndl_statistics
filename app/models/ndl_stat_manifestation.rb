class NdlStatManifestation < ActiveRecord::Base
  belongs_to :ndl_statistic
  attr_accessible :stat_type, :checkout_type_id, :region, :carrier_type_id, :count

  stat_type_list = ['all_items', 'removed', 'removed_sum']
  region_list = ['domestic', 'foreign']
  
  validates_presence_of :stat_type, :checkout_type_id, :region, :carrier_type_id, :count
  validates_inclusion_of :stat_type, :in => stat_type_list
  validates_inclusion_of :region, :in => region_list
  validates_numericality_of :checkout_type_id, :carrier_type_id, :count
end
