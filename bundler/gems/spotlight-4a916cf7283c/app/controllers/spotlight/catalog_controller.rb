module Spotlight
  ##
  # Spotlight's catalog controller. Note that this subclasses
  # the host application's CatalogController to get its configuration,
  # partial overrides, etc
  # rubocop:disable Metrics/ClassLength
  class CatalogController < ::CatalogController
    include Spotlight::Concerns::ApplicationController
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit, prepend: true
    include Spotlight::Catalog
    include Spotlight::Concerns::CatalogSearchContext
    	
    require "json"
    
    before_action :authenticate_user!, only: [:admin, :edit, :make_public, :make_private, :create_annotation, :update_annotation, :show_annotation]
    before_action :check_authorization, only: [:admin, :edit, :make_public, :make_private, :create_annotation, :update_annotation, :show_annotation]
    before_action :redirect_to_exhibit_home_without_search_params!, only: :index
    before_action :add_breadcrumb_with_search_params, only: :index
    skip_before_filter :verify_authenticity_token, :only => [:create_annotation, :update_annotation, :show_annotation]
    before_action :attach_breadcrumbs

    before_action only: :show do
      blacklight_config.show.partials.unshift 'curation_mode_toggle'
    end

    before_action only: :admin do
      blacklight_config.view.select! { |k, _v| k == :admin_table }
      blacklight_config.view.admin_table.partials = [:index_compact]
      blacklight_config.view.admin_table.document_actions = []

      #unless blacklight_config.sort_fields.key? "timestamp"
      #  blacklight_config.add_sort_field :timestamp, sort: "#{blacklight_config.index.timestamp_field} desc"
      #end
    end

    before_action only: :edit do
      blacklight_config.view.edit.partials = blacklight_config.view_config(:show).partials.dup
      blacklight_config.view.edit.partials.insert(2, :edit)
    end

    def show
      super

      if @document.private? current_exhibit
        authenticate_user! && authorize!(:curate, current_exhibit)
      end

      add_document_breadcrumbs(@document)
    end

    # "id_ng" and "full_title_ng" should be defined in the Solr core's schema.xml.
    # It's expected that these fields will be set up to have  EdgeNGram filter
    # setup within their index analyzer. This will ensure that this method returns
    # results when a partial match is passed in the "q" parameter.
    def autocomplete
      search_params = params.merge(search_field: Spotlight::Engine.config.autocomplete_search_field)
      (_, @document_list) = search_results(search_params.merge(public: true), search_params_logic)

      respond_to do |format|
        format.json do
          render json: { docs: autocomplete_json_response(@document_list) }
        end
      end
    end

    def admin
      add_breadcrumb t(:'spotlight.curation.sidebar.header'), exhibit_dashboard_path(@exhibit)
      add_breadcrumb t(:'spotlight.curation.sidebar.items'), admin_exhibit_catalog_index_path(@exhibit)
      (@response, @document_list) = search_results(params, search_params_logic)
      @filters = params[:f] || []

      respond_to do |format|
        format.html
      end
    end

    def update
      @response, @document = fetch params[:id]
      @document.update(current_exhibit, solr_document_params)
      @document.save

      try_solr_commit!

      redirect_to exhibit_catalog_path(current_exhibit, @document)
    end

    def edit
      @response, @document = fetch params[:id]
    end
    
    def show_annotation
      @response, @document = fetch params[:id]
      @width = @document._source["spotlight_full_image_width_ssm"].first.to_f
      @height = @document._source["spotlight_full_image_height_ssm"].first.to_f
      @imageLink = @document._source["full_image_url_ssm"].first
		@annotations = {}
		@sidecar = Spotlight::SolrDocumentSidecar.where(document_id: @document["id"]).first
		count = @sidecar.data["configured_fields"]["spotlight_annotation_count_is"].to_i
		for i in 0..count-1
			@annotations[i] = {}
			@sidecar.data["configured_fields"].keys.each do |key|
				if key.include? "annotation"
					new_key = key
					new_key = new_key.gsub(/spotlight_annotation_/, '').split('_').first
					@annotations[i][new_key] = @sidecar.data["configured_fields"][key][i]
				end
			end
		end
    end
    
    def create_annotation
    	begin
			@response, @document = fetch params[:id]
			@resource = Spotlight::Resource.find(@document["id"].split("-").last)
			count = @resource.data["spotlight_annotation_count_is"].to_i
			@sidecar = Spotlight::SolrDocumentSidecar.where(document_id: @document["id"]).first
			Spotlight::Engine.config.upload_fields.each do |f|
				f = f.field_name.to_s
				if f.include? "annotation"
					p = params[f.gsub(/spotlight_annotation_/, '').split('_').first]
					p = p + "T00:00:00Z" if (f.include? "date") && (!p.blank?)
					p = "0001-01-01T00:00:00Z" if (f.include? "date") && (p.blank?)
					if (@sidecar.data["configured_fields"][f] == nil)
						@sidecar.data["configured_fields"][f] = [p] 
					else
						@sidecar.data["configured_fields"][f].push(p)
					end
					if (@resource.data[f] == nil)
						@resource.data[f] = [p] 
					else
						@resource.data[f].push(p)
					end
				end
			end
			
			@sidecar.data["configured_fields"]["spotlight_annotation_count_is"] = count+1
			@resource.data["spotlight_annotation_count_is"] = count+1
			@sidecar.save
			@resource.save_and_index
			path = request.path
			redirect_to path.sub('create','show'), notice: "Annotation Submitted Successfully"
		rescue
			path = request.path
			redirect_to path.sub('create','show'), notice: "Annotation Failed to Submit Properly"
		end
	end
	
	def update_annotation
		begin
			@response, @document = fetch params[:id]
			@resource = Spotlight::Resource.find(@document["id"].split("-").last)
			@sidecar = Spotlight::SolrDocumentSidecar.where(document_id: @document["id"]).first
			annotation_id = params[:annotation_id].to_i
			Spotlight::Engine.config.upload_fields.each do |f|
				f = f.field_name.to_s
				if f.include? "annotation"
					p = params[f.sub(/spotlight_annotation_/, '').split('_').first]
					next if p == nil
					p = p + "T00:00:00Z" if (f.include? "date") && (!p.blank?)
					p = "0001-01-01T00:00:00Z" if (f.include? "date") && (p.blank?)
					@sidecar.data["configured_fields"][f][annotation_id] = p
					@resource.data[f][annotation_id] = p
				end
			end
			@sidecar.save
			@resource.save_and_index
			path = request.path
			redirect_to path.sub('update','show'), notice: "Annotation Submitted Successfully"
		rescue => e
			path = request.path
			redirect_to path.sub('update','show'), notice: "Annotation Failed to Submit Properly"
		end
	end
	
	def get_annotation 
    	@response, @document = fetch params[:id]
    	annotations = []
    	@sidecar = Spotlight::SolrDocumentSidecar.where(document_id: @document["id"])
    	count = @sidecar.data["configured_fields"]["spotlight_annotation_count_is"].to_i
    	for i in 0..count
			@sidecar.data["configured_fields"].each_with_index do |f, key|
				if key.include? "annotation"
					annotations[0][key.gsub(/spotlight_annotation_/, '').split('_').first] = f
					
					
				end
				
			end
		end
	end
    
    def make_private
      @response, @document = fetch params[:catalog_id]
      @document.make_private!(current_exhibit)
      @document.save

      respond_to do |format|
        format.html { redirect_to :back }
        format.json { render json: true }
      end
    end

    def make_public
      @response, @document = fetch params[:catalog_id]
      @document.make_public!(current_exhibit)
      @document.save

      respond_to do |format|
        format.html { redirect_to :back }
        format.json { render json: true }
      end
    end

    protected

    # TODO: move this out of app/helpers/blacklight/catalog_helper_behavior.rb and into blacklight/catalog.rb
    # rubocop:disable Style/PredicateName
    def has_search_parameters?
      !params[:q].blank? || !params[:f].blank? || !params[:search_field].blank?
    end
    # rubocop:enable Style/PredicateName

    def attach_breadcrumbs
      # The "q: ''" is necessary so that the breadcrumb builder recognizes that a path like this:
      # /exhibits/1?f%5Bgenre_sim%5D%5B%5D=map&q= is not the same as /exhibits/1
      # Otherwise the exhibit breadcrumb won't be a link.
      # see http://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-current_page-3F
      add_breadcrumb t(:'spotlight.exhibits.breadcrumb', title: @exhibit.title), exhibit_root_path(@exhibit, q: '')
    end

    ##
    # Override Blacklight's #setup_next_and_previous_documents to handle
    # browse categories too
    def setup_next_and_previous_documents
      if current_search_session_from_browse_category?
        setup_next_and_previous_documents_from_browse_category if current_browse_category
      elsif current_search_session_from_page? || current_search_session_from_home_page?
        # TODO: figure out how to construct previous/next documents
      else
        super
      end
    end

    def setup_next_and_previous_documents_from_browse_category
      index = search_session['counter'].to_i - 1
      response, _docs = get_previous_and_next_documents_for_search index, current_browse_category.query_params.with_indifferent_access

      return unless response

      search_session['total'] = response.total
      @previous_document = response.documents.first
      @next_document = response.documents.last
    end

    def _prefixes
      @_prefixes ||= super + ['catalog']
    end

    ##
    # Admin catalog controller should not create a new search
    # session in the blacklight context
    def start_new_search_session?
      super || params[:action] == 'admin'
    end

    def solr_document_params
      params.require(:solr_document).permit(:exhibit_tag_list,
                                            uploaded_resource: [:url],
                                            sidecar: [:public, data: [editable_solr_document_params]])
    end

    def editable_solr_document_params
      custom_field_params + uploaded_resource_params
    end

    def uploaded_resource_params
      if @document.uploaded_resource?
        [{ configured_fields: Spotlight::Resources::Upload.fields(current_exhibit).map(&:field_name) }]
      else
        []
      end
    end

    def custom_field_params
      current_exhibit.custom_fields.pluck(:field)
    end

    def check_authorization
      authorize! :curate, @exhibit
    end

    def redirect_to_exhibit_home_without_search_params!
      redirect_to spotlight.exhibit_root_path(@exhibit) unless has_search_parameters?
    end

    def add_breadcrumb_with_search_params
      add_breadcrumb t(:'spotlight.catalog.breadcrumb.index'), request.fullpath if has_search_parameters?
    end

    # rubocop:disable Metrics/AbcSize
    def add_document_breadcrumbs(document)
      if current_browse_category
        add_breadcrumb current_browse_category.exhibit.main_navigations.browse.label_or_default, exhibit_browse_index_path(current_browse_category.exhibit)
        add_breadcrumb current_browse_category.title, exhibit_browse_path(current_browse_category.exhibit, current_browse_category)
      elsif current_page_context && current_page_context.title.present? && !current_page_context.is_a?(Spotlight::HomePage)
        add_breadcrumb current_page_context.title, [current_page_context.exhibit, current_page_context]
      elsif current_search_session
        add_breadcrumb t(:'spotlight.catalog.breadcrumb.index'), search_action_url(current_search_session.query_params)
      end

      add_breadcrumb Array(document[blacklight_config.view_config(:show).title_field]).join(', '), exhibit_catalog_path(current_exhibit, document)
    end
    # rubocop:enable Metrics/AbcSize

    def additional_export_formats(document, format)
      super

      format.solr_json do
        authorize! :update_solr, @exhibit
        render json: document.to_solr.merge(@exhibit.solr_data)
      end
    end

    def try_solr_commit!
      repository.connection.commit
    rescue => e
      Rails.logger.info "Failed to commit document updates: #{e}"
    end
  end
end
