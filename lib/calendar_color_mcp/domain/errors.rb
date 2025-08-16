module Domain
  class DomainError < StandardError; end
  class InvalidTimeSpanError < DomainError; end
  class InvalidEventDataError < DomainError; end
end