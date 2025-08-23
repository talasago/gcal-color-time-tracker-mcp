# Calendar Color Time Tracker MCP Server

**日本語版**→ [README_ja.md](README_ja.md)

MCP (Model Context Protocol) server for Google Calendar color-based time analysis. Built with Clean Architecture pattern and the official MCP Ruby SDK.

## Features

- **Color-based time aggregation**: Aggregate calendar events by color for specified time periods
- **Participated events only**: Analyzes only accepted events, hosted events, and private events
- **Color filtering**: Include or exclude specific colors from analysis
- **Clean Architecture**: Maintainable and extensible design pattern
- **OAuth 2.0 Authentication**: Secure authentication for Google Calendar API access
- **Single-user support**: Database-free local file management

## Installation & Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Google Cloud Console Setup

#### 2.1. Create or Select Project
1. Access [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing project
3. Confirm the correct project is selected at the top of the console

#### 2.2. Enable Google Calendar API
1. Confirm the correct project is selected
2. Access [Calendar API library page](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)
3. Click "Enable"

#### 2.3. Create OAuth 2.0 Credentials
1. Select "Credentials" from the left menu
2. Click "Create Credentials" → "OAuth client ID"
3. Configure OAuth consent screen (first time only):
   - Select "External" (accessible to users outside your organization)
   - Enter application name
   - Set user support email
   - Enter developer contact information
   - Add scopes (optional):
     - `https://www.googleapis.com/auth/calendar.events`
     - `https://www.googleapis.com/auth/calendar`
4. Select "Desktop application" for application type
5. Enter a name (e.g., Calendar Color MCP)
6. Click "Create"

#### 2.4. Get Credentials
1. Copy the "Client ID" and "Client Secret" from the created OAuth client
2. Configure these settings in the JSON file below

#### 2.5. Add Test Users
1. Go to OAuth consent screen settings and navigate to "Test users" section
2. Click "Add users" and add the email address of the Google account that will access the calendar
3. ⚠️ **Note**: Adding test users may take a few minutes

### 3. Claude Desktop Configuration

Configure environment variables in the Claude Desktop configuration file (`claude_desktop_config.json`).
See the "Claude Desktop Usage Examples" section for configuration details.

### 4. Grant Execution Permissions

```bash
chmod +x bin/calendar-color-mcp
```

## Usage

### Claude Desktop Usage Examples

#### Claude Desktop Configuration (claude_desktop_config.json)

```json
{
  "mcpServers": {
    "calendar-color-mcp": {
      "command": "/path/to/calendar-color-mcp/bin/calendar-color-mcp",
      "env": {
        "GOOGLE_CLIENT_ID": "your_google_client_id",
        "GOOGLE_CLIENT_SECRET": "your_google_client_secret",
        "DEBUG": false
      }
    }
  }
}
```

### MCP Tool Usage Examples

#### Calendar Analysis (Participated Events Only)

Basic usage example:
```json
{
  "name": "analyze_calendar",
  "arguments": {
    "start_date": "2024-07-01",
    "end_date": "2024-07-07"
  }
}
```

Color filtering usage example:
```json
{
  "name": "analyze_calendar", 
  "arguments": {
    "start_date": "2024-07-01",
    "end_date": "2024-07-07",
    "include_colors": ["Sage", "Peacock", 1, "オレンジ"],
    "exclude_colors": ["Graphite", "Tomato", 11]
  }
}
```

**Events included in analysis:**
- Events where the user is the organizer
- Events where invitations are accepted (`responseStatus: "accepted"`)
- Private events with no attendee information

**Events excluded from analysis:**
- Declined events (`responseStatus: "declined"`)
- Tentative events (`responseStatus: "tentative"`)
- Events needing action (`responseStatus: "needsAction"`)

**Color filtering parameters:**
- `include_colors`: Colors to include in analysis (color ID 1-11 or color names)
- `exclude_colors`: Colors to exclude from analysis (color ID 1-11 or color names)
- Mixed specification of color IDs and color names is supported
- exclude_colors takes priority over include_colors

## Project Structure (Clean Architecture)

```
calendar-color-mcp/
├── lib/
│   ├── calendar_color_mcp.rb            # Main entry point
│   └── calendar_color_mcp/
│       ├── server.rb                    # MCP server implementation
│       ├── loggable.rb                  # Logging functionality
│       ├── logger_manager.rb            # Log management
│       ├── interface_adapters/          # Interface Adapters layer
│       │   ├── tools/                   # MCP tool implementations
│       │   └── presenters/              # Data presentation format conversion
│       ├── application/                 # Application layer
│       │   └── use_cases/               
│       ├── domain/                      # Domain layer
│       │   ├── entities/                
│       │   └── services/                
│       └── infrastructure/              # Infrastructure layer
│           ├── repositories/            
│           └── services/                
├── spec/                                # Test suite (RSpec)
│   ├── CLAUDE.md                        
│   └── [Test structure corresponding to each layer]
├── docs/                                # Development documentation
├── bin/
│   └── calendar-color-mcp               # Executable file
├── Gemfile                              # Dependency definitions
├── LICENSE                              
├── CLAUDE.md                            # Project description for Claude Code
```

## Calendar Color Definitions

| Color ID | English Name | Japanese Name |
|----------|--------------|---------------|
| 1 | Lavender | 薄紫 |
| 2 | Sage | 緑 |
| 3 | Grape | 紫 |
| 4 | Flamingo | 赤 |
| 5 | Banana | 黄 |
| 6 | Tangerine | オレンジ |
| 7 | Turquoise | 水色 |
| 8 | Graphite | 灰色 |
| 9 | Peacock | 青（デフォルト） |
| 10 | Basil | 濃い緑 |
| 11 | Tomato | 濃い赤 |

Color filtering supports color IDs (1-11), English names, or Japanese names.

## Authentication Flow

1. Authentication is required on first use
2. Authentication URL is provided when running `start_auth` tool or `analyze_calendar`
3. Access the URL to complete Google authentication
4. Authentication information is saved to local file
5. Refresh tokens minimize re-authentication frequency

## Development & Testing

### Development Environment

```bash
bundle install
```

### Run Tests

```bash
bundle exec rspec
```

### Debug

Set environment variable `DEBUG=true` to enable debug logging

## Architecture

This project adopts the Clean Architecture pattern. For detailed architecture information, refer to the following documents:

- **[lib/CLAUDE.md](lib/CLAUDE.md)**: Library architecture, design patterns, and business logic details
- **[spec/CLAUDE.md](spec/CLAUDE.md)**: Test architecture, test rules, and test execution methods

## License

MIT License
