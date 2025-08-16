module Application
  class UseCaseError < StandardError; end
  class AuthenticationRequiredError < UseCaseError; end
  class CalendarAccessError < UseCaseError; end
  class InvalidParameterError < UseCaseError; end
end