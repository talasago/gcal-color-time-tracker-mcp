# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Installation
```bash
bundle install              # Install Ruby dependencies
cp .env.example .env        # Setup environment variables
chmod +x bin/calendar-color-mcp  # Make binary executable
```

### Running the Server
```bash
./bin/calendar-color-mcp    # Start MCP server
DEBUG=true ./bin/calendar-color-mcp  # Start with debug logging
```

### Testing
```bash
bundle exec rspec           # Run all tests
bundle exec rspec spec/specific_test.rb  # Run single test file
```

### Development Tools
```bash
bundle exec pry            # Interactive Ruby console for debugging
```


## Architecture Overview

This is an **MCP (Model Context Protocol) server** built with the official **`mcp` Ruby SDK** that provides Google Calendar color-based time analytics. The architecture follows a modular design with clear separation of concerns:

### Core Components

- **`CalendarColorMCP::Server`** (lib/calendar_color_mcp/server.rb): Main MCP server class that uses `MCP::Server` and `StdioTransport`, handles tool registration and request routing
- **Tool Classes** (lib/calendar_color_mcp/tools/): Class-based MCP tool implementations
  - `AnalyzeCalendarTool`: Main calendar analysis functionality
  - `StartAuthTool`: OAuth authentication initiation
  - `CheckAuthStatusTool`: Authentication status validation
- **`GoogleCalendarClient`**: Handles Google Calendar API interactions and OAuth token management
- **`TimeAnalyzer`**: Core business logic for analyzing calendar events by color and calculating time summaries
- **`UserManager`**: File-based user credential storage and management (no database required)
- **`AuthManager`**: OAuth 2.0 flow management for Google Calendar API access

### MCP Protocol Implementation

The server exposes **3 tools** via the MCP protocol (implemented as class-based tools):
- `AnalyzeCalendarTool`: Main analysis tool (requires user_id, start_date, end_date)
- `StartAuthTool`: Initiates OAuth flow for new users  
- `CheckAuthStatusTool`: Validates user authentication state

**Note**: Resources (`auth://users`, `calendar://colors`) are planned for future implementation in the new SDK.

### Authentication Flow

Uses **file-based token storage** in `user_tokens/` directory:
- User IDs are SHA256 hashed for privacy
- OAuth tokens stored as JSON with refresh capability
- No database dependencies - purely local file management

### Key Design Patterns

- **Official MCP SDK Integration**: Uses official `mcp` gem with `StdioTransport` for command-line MCP server
- **Class-based Tool Architecture**: Each MCP tool implemented as separate class inheriting from `MCP::Tool`
- **Server Context Sharing**: User and auth managers shared across tools via `server_context`
- **OAuth 2.0 OOB (out-of-band) flow**: CLI-friendly authentication without local web server
- **Modular separation**: Each major concern (auth, calendar, analysis, users) in separate classes
- **Error boundary handling**: Google API authorization errors are caught and trigger re-auth flow
- **Color-based aggregation**: Events grouped by Google Calendar color IDs (1-11) with Japanese color names

### Environment Configuration

Requires Google Cloud Console OAuth 2.0 credentials:
- `GOOGLE_CLIENT_ID`: OAuth client ID
- `GOOGLE_CLIENT_SECRET`: OAuth client secret  
- `DEBUG`: Optional debug logging flag

The server is designed to run as a long-lived process that Claude can communicate with via the MCP protocol for calendar analysis tasks.