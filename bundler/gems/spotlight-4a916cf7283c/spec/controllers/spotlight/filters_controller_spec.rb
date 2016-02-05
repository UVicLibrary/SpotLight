require 'spec_helper'

describe Spotlight::FiltersController do
  routes { Spotlight::Engine.routes }

  describe '#create' do
    let(:exhibit) { FactoryGirl.create(:exhibit) }
    let(:exhibit_filter) { exhibit.filters.first }

    before do
	  p "\n\n ben comment filters_controller_spec.rb line 12 \n\n";
      allow(Spotlight::Engine.config).to receive(:filter_resources_by_exhibit).and_return(false)
    end

    context 'when not signed in' do
      it 'is not successful' do
        post :create, exhibit_id: exhibit, filter: { field: 'foo_ssi', value: 'bar_ssi' }
        expect(:response).to redirect_to main_app.new_user_session_path
      end
    end

    context 'when signed in as a site admin' do
      before { sign_in user }
      let(:user) { FactoryGirl.create(:site_admin) }

      it 'is successful' do
        post :create, exhibit_id: exhibit, filter: { field: 'foo_ssi', value: 'bar' }
        expect(:response).to redirect_to edit_exhibit_path(exhibit, anchor: 'filter')
        expect(assigns[:exhibit].solr_data).to eq('foo_ssi' => 'bar')
      end

      it 'valids filter values' do
        post :create, exhibit_id: exhibit, filter: { field: 'foo_ssi', value: '' }
        expect(:response).to redirect_to edit_exhibit_path(exhibit, anchor: 'filter')
        expect(flash[:alert]).to include "Value can't be blank"
      end
    end
  end

  describe '#update' do
    let(:exhibit) { FactoryGirl.create(:exhibit) }
    let(:exhibit_filter) { exhibit.filters.first }

    before do
      allow(Spotlight::Engine.config).to receive(:filter_resources_by_exhibit).and_return(true)
    end

    context 'when not signed in' do
      it 'is not successful' do
        patch :update, exhibit_id: exhibit, id: exhibit_filter, filter: { field: 'foo_ssi', value: 'bar_ssi' }
        expect(:response).to redirect_to main_app.new_user_session_path
      end
    end

    context 'when signed in as a site admin' do
      before { sign_in user }
      let(:user) { FactoryGirl.create(:site_admin) }

      it 'is successful' do
        patch :update, exhibit_id: exhibit, id: exhibit_filter, filter: { field: 'foo_ssi', value: 'bar' }
        expect(:response).to redirect_to edit_exhibit_path(exhibit, anchor: 'filter')
        expect(assigns[:exhibit].solr_data).to eq('foo_ssi' => 'bar')
      end

      it 'valids filter values' do
        patch :update, exhibit_id: exhibit, id: exhibit_filter, filter: { field: 'foo_ssi', value: '' }
        expect(:response).to redirect_to edit_exhibit_path(exhibit, anchor: 'filter')
        expect(flash[:alert]).to include "Value can't be blank"
      end
    end
  end
end
