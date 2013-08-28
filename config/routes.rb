Rails.application.routes.draw do
  resources :ndl_statistics do
    post :get_ndl_report, :on => :collection
  end
end
