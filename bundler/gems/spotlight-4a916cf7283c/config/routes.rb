Spotlight::Engine.routes.draw do
  devise_for :contact_email, class_name: 'Spotlight::ContactEmail', only: [:confirmations]

  concern :user_existable do
    collection do
      get :exists
    end
  end

  concern :user_invitable do
    collection do
      post :invite
    end
  end

  resource :site, only: [:edit, :update] do
    collection do
      get '/tags', to: 'sites#tags'
    end
  end

  get '/exhibits/edit', to: 'sites#edit_exhibits', as: 'edit_site_exhibits'
  get '/exhibits/new', to: 'exhibits#new', as: 'new_exhibit'
  resources :admin_users, only: [:index, :create, :destroy], concerns: [:user_existable, :user_invitable]

  resources :exhibits, path: '/', except: [:show] do
    member do
      get 'exhibit', to: 'exhibits#show', as: 'get'
      post 'import', to: 'exhibits#process_import'
      patch 'import', to: 'exhibits#process_import'
      post 'reindex', to: 'exhibits#reindex'
    end

    resources :attachments, only: :create
    resource :contact_form, path: 'contact', only: [:new, :create]
    resource :blacklight_configuration, only: [:update]

    resource :appearance, only: [:edit, :update]

    resource :metadata_configuration, only: [:show, :edit, :update]
    resource :search_configuration, only: [:show, :edit, :update]
    resource :view_configuration, only: [:show]

    resources :filters, only: [:create, :update]

    blacklight_for :catalog, only: [:export]

    resources :catalog, only: [:index, :show, :edit, :update] do
      collection do
        get 'admin'
        get 'autocomplete'
      end

      get 'facet/:id', to: 'catalog#facet', as: 'catalog_facet'

      put 'visiblity', to: 'catalog#make_public'
      delete 'visiblity', to: 'catalog#make_private'
    end

    get 'catalog/:id', to: 'catalog#show', as: 'solr_document'
    
    get 'annotation/:id/show', to: 'catalog#show_annotation', as: 'show_annotation'
    post 'annotation/:id/get', to: 'catalog#get_annotation'
    post 'annotation/:id/create', to: 'catalog#create_annotation'
    post 'annotation/:id/update', to: 'catalog#update_annotation'
    
    resources :solr_document, only: [:edit], to: 'catalog#edit'

    resources :custom_fields

    resource :dashboard, only: [:show] do
      get :analytics
    end

    resources :resources do
      collection do
        get :monitor
        post :reindex_all
      end
    end

    resources :resources_uploads, controller: 'resources/upload', path: 'upload_resources', only: [:create]

    resources :resources_csv_uploads, controller: 'resources/csv_upload', path: 'upload_csv', only: [:create] do
      collection do
        get :template
      end
    end

    resources :searches do
      collection do
        patch :update_all
      end
      member do
        get :autocomplete
      end
    end
    resources :browse, only: [:index, :show]
    resources :tags, only: [:index, :destroy]

    resources :contacts, only: [:edit, :update, :destroy]
    resources :about_pages, path: 'about' do
      collection do
        patch 'contacts' => 'about_pages#update_contacts'
        resources :contacts, only: [:new, :create]
        patch :update_all
      end
    end
    resources :feature_pages, path: 'feature' do
      collection do
        patch :update_all
      end
    end
    resource :home_page, path: 'home', controller: 'home_pages'
    post '/pages/:id/preview' => 'pages#preview', as: :preview_block

    resources :lock, only: [:destroy]

    resources :roles, path: 'users', only: [:index, :create, :destroy], concerns: [:user_existable, :user_invitable] do
      collection do
        patch :update_all
      end
    end
    post 'solr/update' => 'solr#update'
  end

  get '/:exhibit_id' => 'home_pages#show', as: :exhibit_root
  post 'versions/:id/revert' => 'versions#revert', as: :revert_version
end
