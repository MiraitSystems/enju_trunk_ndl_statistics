class NdlStatAccept < ActiveRecord::Base
  default_scope :order => :region
  belongs_to :ndl_statistic
  
  region_list = ['domestic', 'foreign', 'none']
  
  validates_presence_of :region, :checkout_type_id, :carrier_type_id, :accept_type_id, :count, :pub_flg
  validates_inclusion_of :region, :in => region_list
  validates_numericality_of :checkout_type_id, :carrier_type_id, :accept_type_id, :count
end
