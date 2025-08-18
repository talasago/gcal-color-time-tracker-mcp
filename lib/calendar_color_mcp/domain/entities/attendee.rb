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

    # TODO:使ってなさそう。必要？
    def accepted?
      @response_status == 'accepted'
    end

    # TODO:使ってなさそう。必要？
    def declined?
      @response_status == 'declined'
    end

    # TODO:使ってなさそう。必要？
    def tentative?
      @response_status == 'tentative'
    end

    # TODO:使ってなさそう。必要？
    def needs_action?
      @response_status == 'needsAction'
    end
  end
end
