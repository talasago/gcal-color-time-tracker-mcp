# frozen_string_literal: true

module Domain
  class DomainError < StandardError; end
  class BusinessRuleViolationError < DomainError; end
  class DataIntegrityError < DomainError; end
end
