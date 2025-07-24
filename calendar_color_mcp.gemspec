Gem::Specification.new do |spec|
  spec.name          = "calendar_color_mcp"
  spec.version       = "1.0.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]
  spec.summary       = "Google Calendar Color-based Time Analytics MCP Server"
  spec.description   = "MCPサーバーでGoogleカレンダーの色別時間集計を行います"
  spec.homepage      = "https://github.com/yourusername/calendar-color-mcp"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{lib,bin}/**/*") + %w[README.md Gemfile]
  spec.bindir        = "bin"
  spec.executables   = ["calendar-color-mcp"]
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp-rb"
  spec.add_dependency "google-api-client"
  spec.add_dependency "dotenv"
end