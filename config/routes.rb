require "sidekiq/web" # require the web UI

Rails.application.routes.draw do
  Spree::Core::Engine.add_routes do
    # Storefront routes
    scope '(:locale)', locale: /#{Spree.available_locales.join('|')}/, defaults: { locale: nil } do
      devise_for(
        Spree.user_class.model_name.singular_route_key,
        class_name: Spree.user_class.to_s,
        path: :user,
        controllers: {
          sessions: 'spree/user_sessions',
          passwords: 'spree/user_passwords',
          registrations: 'spree/user_registrations'
        },
        router_name: :spree
      )
    end

    # Admin authentication
    devise_for(
      Spree.admin_user_class.model_name.singular_route_key,
      class_name: Spree.admin_user_class.to_s,
      controllers: {
        sessions: 'spree/admin/user_sessions',
        passwords: 'spree/admin/user_passwords'
      },
      skip: :registrations,
      path: :admin_user,
      router_name: :spree
    )
    
    # Admin address images routes
    namespace :admin do
      resources :address_images, only: [:show] do
        member do
          get :show_a4
          get :escpos
        end
        collection do
          get :qz_certificate
          post :qz_sign
          post :print_via_printnode
          post :upload_image
          post :send_whatsapp_invoice
          post :upload_and_send_whatsapp_invoice
        end
      end
      get 'address_images_test', to: 'address_images#test'
      
      # Balance system routes
      resources :transactions, only: [:index] do
        collection do
          get :daily_balance
        end
      end
      resources :expenses
      resources :expense_categories
      resources :expense_reports, only: [:index]
      
      # Sold products routes
      resources :sold_products, only: [:index]
      
      # BCV routes
      resources :bcvs, only: [:edit, :update]
      
      # Product variants sales report
      resources :products, only: [] do
        resources :product_variants_sales, only: [:index]
        resources :product_orders, only: [:index]
      end
      
      # Top variants global report
      resources :top_variants, only: [:index]

      # Historial de cambios de variantes
      resources :variant_change_logs, only: [:index], path: 'historial-cambios-variantes'

      # Top products global report
      resources :top_products, only: [:index]
      
      # Rutas para adjustments
      resources :orders, only: [:show] do
        resources :adjustments, except: [:show] do
          member do
            put :toggle_state
          end
        end
        
                     # Rutas para abrir/cerrar todos los adjustments
             member do
               get :open_adjustments
               get :close_adjustments
               post :mark_as_completed
               post :upload_tracking_image
               delete :remove_tracking_image
               post :send_tracking_whatsapp
               patch :update_special_instructions
             end
      end
    end
  end
  # This line mounts Spree's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to
  # Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the
  # :at option to something different.
  #
  # We ask that you don't use the :as option, as Spree relies on it being
  # the default of "spree".
  mount Spree::Core::Engine, at: '/'

  mount Sidekiq::Web => "/sidekiq" # access it at http://localhost:3000/sidekiq

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Estado del pedido (público, por número en query: ?order=R123456)
  get "estado-pedido", to: "order_status#show", as: :order_status

  # Defines the root path route ("/")
  root "spree/home#index"
end
