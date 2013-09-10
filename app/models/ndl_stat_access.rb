class NdlStatAccess < ActiveRecord::Base
  belongs_to :ndl_statistic
  
  validates_presence_of :log_type, :internal
end
