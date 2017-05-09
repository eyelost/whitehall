require 'test_helper'

class ServiceListeners::AuthorNotifierTest < ActiveSupport::TestCase
  setup { ActionMailer::Base.deliveries.clear }

  test 'notifies users' do
    edition = create(:edition)
    creator = edition.creator
    second_author = create(:gds_editor)
    edition.authors << second_author

    ServiceListeners::AuthorNotifier.new(edition).notify!

    first_notification = ActionMailer::Base.deliveries.first
    assert_equal creator.email, first_notification.to[0]
    assert_match(/\'#{edition.title}\' has been published/, first_notification.subject)

    second_notification = ActionMailer::Base.deliveries.last
    assert_equal second_author.email, second_notification.to[0]
    assert_match(/\'#{edition.title}\' has been published/, second_notification.subject)
  end

  test 'skips any users that are passed in' do
    edition = create(:edition)
    creator = edition.creator
    second_author = create(:gds_editor)
    edition.authors << second_author

    ServiceListeners::AuthorNotifier.new(edition, second_author).notify!

    assert_equal 1, ActionMailer::Base.deliveries.size

    first_notification = ActionMailer::Base.deliveries.first
    assert_equal creator.email, first_notification.to[0]
    assert_match(/\'#{edition.title}\' has been published/, first_notification.subject)
  end

  test 'sets a suitable "from" including a quoted display name' do
    edition = create(:edition)

    ServiceListeners::AuthorNotifier.new(edition).notify!

    assert_equal 1, ActionMailer::Base.deliveries.size

    first_notification = ActionMailer::Base.deliveries.first
    # GovukAdminTemplate.environment_label isn't set in tests, hence the space inside the brackets
    assert_equal '"[GOV.UK ] GOV.UK publishing" <inside-government@digital.cabinet-office.gov.uk>', first_notification[:from].to_s
  end
end
