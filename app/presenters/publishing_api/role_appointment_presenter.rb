module PublishingApi
  class RoleAppointmentPresenter
    attr_accessor :appointment
    attr_accessor :update_type

    def initialize(appointment, update_type: nil)
      self.appointment = appointment
      self.update_type = update_type || "major"
    end

    def content_id
      appointment.content_id
    end

    def content
      content = BaseItemPresenter.new(
        appointment,
        title: appointment.name,
        update_type: update_type,
      ).base_attributes

      content.merge!(
        description: nil,
        details: {
          started_at: appointment.started_at,
          ended_at: appointment.ended_at,
        },
        document_type: "appointment",
        public_updated_at: appointment.updated_at,
        rendering_app: Whitehall::RenderingApp::WHITEHALL_FRONTEND,
        schema_name: "appointment",
        links: links,
      )
      content.merge!(routes)
    end

    def links
      {
        role: [appointment.role.content_id],
        person: [appointment.person.content_id],
      }
    end

    def routes
      { base_path: base_path }.merge(PayloadBuilder::Routes.for(base_path))
    end

    def base_path
      person_base_path = Whitehall.url_maker.polymorphic_path(appointment.person)
      "#{person_base_path}/#{appointment.started_at}-appointment-as-#{appointment.role.slug}"
    end
  end
end
