require 'test_helper'

class Admin::NewsArticlesControllerTest < ActionController::TestCase
  setup do
    login_as :policy_writer
  end

  should_be_an_admin_controller

  should_allow_creating_of :news_article
  should_allow_editing_of :news_article

  should_allow_speed_tagging_of :news_article
  should_allow_setting_first_published_at_during_speed_tagging :news_article
  should_allow_related_policies_for :news_article
  should_allow_organisations_for :news_article
  should_allow_role_appointments_for :news_article
  should_allow_association_between_world_locations_and :news_article
  should_allow_attached_images_for :news_article
  should_prevent_modification_of_unmodifiable :news_article
  should_allow_overriding_of_first_published_at_for :news_article
  should_have_summary :news_article
  should_allow_assignment_to_document_series :news_article
  should_allow_scheduled_publication_of :news_article
  should_allow_access_limiting_of :news_article
  should_allow_association_with_topical_events :news_article
  should_allow_attachments_for :news_article

  view_test "new displays news article fields" do
    get :new

    assert_select "form#new_edition" do
      assert_select "select[name*='edition[news_article_type_id']"
    end
  end

  view_test "show renders the summary" do
    draft_news_article = create(:draft_news_article, summary: "a-simple-summary")

    get :show, id: draft_news_article

    assert_select ".summary", text: "a-simple-summary"
  end

  test "POST on :create redirects to new attachment page when attachment indicator is present" do
    params = attributes_for(:news_article).merge(lead_organisation_ids: [create(:organisation).id])

    assert_difference 'NewsArticle.count' do
      post :create, edition: params, adding_attachment: 'Button text not important'
    end

    article = NewsArticle.last
    assert_redirected_to new_admin_edition_attachment_url(article)
  end

  private

  def controller_attributes_for(edition_type, attributes = {})
    super.except(:news_article_type).reverse_merge(
      news_article_type_id: NewsArticleType::GovernmentResponse
    )
  end
end
