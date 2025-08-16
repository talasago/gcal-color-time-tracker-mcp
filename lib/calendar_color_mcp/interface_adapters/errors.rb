module InterfaceAdapters
  class ToolError < StandardError; end
  class ParameterValidationError < ToolError; end
  class ResponseFormattingError < ToolError; end
end