require 'test_helper'

class Admin::EditionWorkflowControllerTest < ActionController::TestCase
  should_be_an_admin_controller

  setup do
    @edition = create(:submitted_policy)
    @user = login_as(:departmental_editor)
  end

  test 'publish publishes the given edition on behalf of the current user and notifies the author' do
    post :publish, id: @edition, lock_version: @edition.lock_version

    assert_redirected_to admin_editions_path(state: :published)
    assert_equal "The document #{@edition.title} has been published", flash[:notice]
    assert @edition.reload.published?
    assert_equal @user, @edition.published_by
    assert_match /\'#{@edition.title}\' has now been published/, ActionMailer::Base.deliveries.last.body.to_s
  end

  test 'publish only notifies authors with emails' do
    author_with_email, author_without_email = create(:user), create(:user, email: nil)
    @edition.authors = [author_with_email, author_without_email]

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      post :publish, id: @edition, lock_version: @edition.lock_version
    end
  end

  test 'publish only notifies authors once' do
    author = create(:user)
    @edition.authors = [author, author]

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      post :publish, id: @edition, lock_version: @edition.lock_version
    end
  end

  test "publish doesn't notify the publisher" do
    @edition.authors =  [@user]
    Notifications.expects(:edition_published).never
    post :publish, id: @edition, lock_version: @edition.lock_version
  end

  test 'publish redirects back to the edition with an error message if edition cannot be published' do
    published_edition = create(:published_policy)

    post :publish, id: published_edition, lock_version: published_edition.lock_version
    assert_redirected_to admin_policy_path(published_edition)
    assert_equal 'This edition has already been published', flash[:alert]
  end

  test 'publish redirects back to the edition with an error message if the edition is stale' do
    old_lock_version = @edition.lock_version
    @edition.touch
    post :publish, id: @edition, lock_version: old_lock_version

    assert_redirected_to admin_policy_path(@edition)
    assert_equal 'This document has been edited since you viewed it; you are now viewing the latest version', flash[:alert]
  end

  test 'publish responds with 422 if missing a lock version' do
    post :publish, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'GET #confirm_force_publish renders force publishing form'do
    get :confirm_force_publish, id: @edition, lock_version: @edition.lock_version

    assert_response :success
    assert_template :confirm_force_publish
  end

  test 'POST #force_publish force publishes the edition' do
    post :force_publish, id: @edition, lock_version: @edition.lock_version, reason: 'Urgent change'

    assert_redirected_to admin_editions_path(state: :published)
    assert @edition.reload.force_published?
  end

  test 'POST #force_publish without a reason is not allowed' do
    post :force_publish, id: @edition, lock_version: @edition.lock_version

    assert_redirected_to admin_policy_path(@edition)
    assert_equal 'You cannot force publish a document without a reason', flash[:alert]
    assert @edition.submitted?
  end

  test 'schedule schedules the given edition on behalf of the current user' do
    @edition.update_attribute(:scheduled_publication, 1.day.from_now)
    post :schedule, id: @edition, lock_version: @edition.lock_version

    assert_redirected_to admin_editions_path(state: :scheduled)
    assert @edition.reload.scheduled?
    assert_equal "The document #{@edition.title} has been scheduled for publication", flash[:notice]
  end

  test 'schedule passes through the force flag' do
    @edition.update_attribute(:scheduled_publication, 1.day.from_now)

    post :schedule, id: @edition, force: true, lock_version: @edition.lock_version

    assert_redirected_to admin_editions_path(state: :scheduled)
    assert @edition.reload.scheduled?
    assert @edition.force_published?
  end

  test 'schedule redirects back to the edition with an error message if scheduling reports a failure' do
    scheduled_edition = create(:submitted_policy)

    post :schedule, id: scheduled_edition, lock_version: scheduled_edition.lock_version

    assert_redirected_to admin_policy_path(scheduled_edition)
    assert_equal "This edition does not have a scheduled publication date set", flash[:alert]
  end

  test 'schedule redirects back to the edition with an error message if the edition is stale' do
    old_lock_version = @edition.lock_version
    @edition.update_attribute(:scheduled_publication, 1.day.from_now)
    @edition.touch
    post :schedule, id: @edition, lock_version: old_lock_version

    assert_redirected_to admin_policy_path(@edition)
    assert_equal 'This document has been edited since you viewed it; you are now viewing the latest version', flash[:alert]
  end

  test 'schedule responds with 422 if missing a lock version' do
    post :schedule, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'unschedule unschedules the given edition on behalf of the current user' do
    scheduled_edition = create(:scheduled_policy)
    post :unschedule, id: scheduled_edition, lock_version: scheduled_edition.lock_version

    assert_redirected_to admin_editions_path(state: :submitted)
    assert scheduled_edition.reload.submitted?
  end

  test 'unschedule redirects back to the edition with an error message if unscheduling reports a failure' do
    post :unschedule, id: @edition, lock_version: @edition.lock_version
    assert_redirected_to admin_policy_path(@edition)
    assert_equal 'This edition is not scheduled for publication', flash[:alert]
  end

  test 'unschedule responds with 422 if missing a lock version' do
    post :unschedule, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'submit submits the edition' do
    draft_edition = create(:draft_policy)
    post :submit, id: draft_edition, lock_version: draft_edition.lock_version

    assert_redirected_to admin_policy_path(draft_edition)
    assert draft_edition.reload.submitted?
    assert_equal "Your document has been submitted for review by a second pair of eyes", flash[:notice]
  end

  test 'submit rejects stale editions' do
    draft_edition = create(:draft_policy)
    old_lock_version = draft_edition.lock_version
    draft_edition.touch
    post :submit, id: draft_edition, lock_version: old_lock_version

    assert_redirected_to admin_policy_path(draft_edition)
    assert_equal 'This document has been edited since you viewed it; you are now viewing the latest version', flash[:alert]
  end

  test 'submit redirects back to the edition with an error message on validation error' do
    draft_edition = create(:draft_policy)
    draft_edition.update_attribute(:summary, nil)
    post :submit, id: draft_edition, lock_version: draft_edition.lock_version

    assert_redirected_to admin_policy_path(draft_edition)
    assert_equal "Unable to submit this edition because it is invalid (Summary can't be blank). Please edit it and try again.", flash[:alert]
  end

  test 'submit responds with 422 if missing a lock version' do
    post :submit, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'reject redirects to the new editorial remark page to explain why the edition has been rejected' do
    submitted_policy = create(:submitted_policy)
    post :reject, id: submitted_policy, lock_version: submitted_policy.lock_version

    assert_redirected_to new_admin_edition_editorial_remark_path(submitted_policy)
    assert submitted_policy.reload.rejected?
  end

  test 'reject notifies authors of rejection via email' do
    submitted_policy = create(:submitted_policy)
    post :reject, id: submitted_policy, lock_version: submitted_policy.lock_version

    assert_match /\'#{submitted_policy.title}\' was rejected by/, ActionMailer::Base.deliveries.last.body.to_s
  end

  test 'reject responds with 422 if missing a lock version' do
    post :reject, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'approve_retrospectively marks the document as having been approved retrospectively and redirects back to he edition' do
    editor = create(:departmental_editor)
    acting_as(editor) { @edition.publish_as(editor, force: true) }
    post :approve_retrospectively, id: @edition, lock_version: @edition.lock_version

    assert_redirected_to admin_policy_path(@edition)
    assert_equal "Thanks for reviewing; this document is no longer marked as force-published", flash[:notice]
  end

  test 'approve_retrospectively responds with 422 if missing a lock version' do
    post :approve_retrospectively, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'unpublish is forbidden to non-GDS editors' do
    post :unpublish, id: @edition, lock_version: @edition.lock_version
    assert_response :forbidden
  end

  test 'unpublish unpublishes the edition and redirects back with a message' do
    login_as create(:gds_editor)
    published_edition = create(:published_policy)
    unpublish_params = {
        'unpublishing_reason_id' => '1',
        'explanation' => 'Was classified',
        'alternative_url' => 'http://website.com/alt',
        'document_type' => 'Policy',
        'slug' => 'some-slug'
      }
    post :unpublish, id: published_edition, lock_version: published_edition.lock_version, unpublishing: unpublish_params

    assert_redirected_to admin_policy_path(published_edition)
    assert_equal "This document has been unpublished and will no longer appear on the public website", flash[:notice]
    assert_equal 'Was classified', published_edition.unpublishing.explanation
  end

  test 'unpublish responds with 422 if missing a lock version' do
    login_as create(:gds_editor)
    post :unpublish, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test 'convert_to_draft turns the given edition into a draft and redirects back to the imported editions page' do
    imported_edition = create(:imported_edition)
    post :convert_to_draft, id: imported_edition, lock_version: imported_edition.lock_version

    assert_equal "The imported document #{imported_edition.title} has been converted into a draft", flash[:notice]
    assert_redirected_to admin_editions_path(state: :imported)
  end

  test 'convert_to_draft responds with 422 if missing a lock version' do
    post :convert_to_draft, id: @edition

    assert_response :unprocessable_entity
    assert_equal 'All workflow actions require a lock version', response.body
  end

  test "should prevent access to inaccessible editions" do
    protected_edition = create(:protected_edition)

    post :submit, id: protected_edition.id
    assert_response :forbidden

    post :approve_retrospectively, id: protected_edition.id
    assert_response :forbidden

    post :reject, id: protected_edition.id
    assert_response :forbidden

    post :publish, id: protected_edition.id
    assert_response :forbidden

    post :unpublish, id: protected_edition.id
    assert_response :forbidden

    post :schedule, id: protected_edition.id
    assert_response :forbidden

    post :unschedule, id: protected_edition.id
    assert_response :forbidden
  end
end
