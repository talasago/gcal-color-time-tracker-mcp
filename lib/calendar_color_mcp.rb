require 'mcp'
require_relative 'calendar_color_mcp/server'

module CalendarColorMCP
  def self.run
    server = CalendarColorMCP::Server.new
    server.run
  end
end