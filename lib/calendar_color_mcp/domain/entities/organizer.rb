# frozen_string_literal: true

module Domain
  class Organizer
    attr_reader :email, :display_name

    def initialize(email:, display_name: nil, self: false)
      @email = email
      @display_name = display_name
      @is_self = binding.local_variable_get(:self)
    end


    def self?
      @is_self
    end
  end
end
