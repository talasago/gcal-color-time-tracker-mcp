# frozen_string_literal: true

module Domain
  class Attendee
    attr_reader :email, :response_status

    def initialize(email:, response_status:, self: false)
      @email = email
      @response_status = response_status
      @is_self = binding.local_variable_get(:self)
    end

    def self?
      @is_self
    end

    def accepted?
      @response_status == 'accepted'
    end
  end
end
