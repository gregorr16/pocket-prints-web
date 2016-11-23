Pocketprints::Application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :products, only: [:index]
      post 'preflight' => 'products#preflight'
      resources :photos, path: 'photo', only: [:create]
      resources :orders, path: 'order', only: [:create]
      post 'token' => 'customers#token'
    end
  end

  match "api/products" => "api/v1/products#index", via: :get
  match "api/preflight" => "api/v1/products#preflight", via: :post

  match "api/token" => "api/v1/customers#token", via: :post
  match "api/update_customer" => "api/v1/customers#update", via: :put

  match "api/order" => "api/v1/orders#create", via: :post

  match "api/stripe_payment" => "api/v1/orders#stripe_payment", via: :post

  match "api/photo" => "api/v1/photos#create", via: :post

  match "email_template" => "api/v1/customers#email_template", via: :get

  match "gift_email_template" => "api/v1/customers#gift_email_template", via: :get

  match "is_alive" => "application#is_alive", via: :get

  match "gift" => "application#gift", via: :get, as: 'gift'

  devise_for :users
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin' 
  root :to => redirect('/admin')

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
