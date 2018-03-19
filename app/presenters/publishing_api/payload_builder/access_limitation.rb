module PublishingApi
  module PayloadBuilder
    class AccessLimitation
      def self.for(item)
        if (uuids = item.authorized_uuids)
          { access_limited: { users: uuids } }
        else
          {}
        end
      end
    end
  end
end
