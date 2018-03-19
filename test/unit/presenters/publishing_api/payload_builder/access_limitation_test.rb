require "test_helper"

module PublishingApi
  module PayloadBuilder
    class AccessLimitationTest < ActiveSupport::TestCase
      test "returns access limitation data for the item" do
        user = create(:user)

        stubbed_item = stub(
          authorized_uuids: [user.uid]
        )
        expected_hash = {
          access_limited: {
            users: [user.uid]
          }
        }

        assert_equal AccessLimitation.for(stubbed_item), expected_hash
      end

      test "it returns an empty hash if authorized_uuids is nil" do
        stubbed_item = stub(authorized_uuids: nil)

        assert_equal({}, AccessLimitation.for(stubbed_item))
      end
    end
  end
end
