# lib/配下の依存関係図

```mermaid
graph LR
    %% Entry Point
    Main[calendar_color_mcp.rb] --> Server[server.rb]
    
    %% Server Dependencies
    Server --> TokenManager[token_manager.rb]
    Server --> AuthManager[google_calendar_auth_manager.rb]
    Server --> AnalyzeTool[tools/analyze_calendar_tool.rb]
    Server --> StartAuthTool[tools/start_auth_tool.rb]
    Server --> CheckAuthTool[tools/check_auth_status_tool.rb]
    Server --> CompleteAuthTool[tools/complete_auth_tool.rb]
    
    %% Tool Base Class
    BaseTool[tools/base_tool.rb] --> MCP[MCP SDK]
    AnalyzeTool --> BaseTool
    StartAuthTool --> BaseTool
    CheckAuthTool --> BaseTool
    CompleteAuthTool --> BaseTool
    
    %% Analyze Tool Dependencies
    AnalyzeTool --> GoogleCalendarClient[google_calendar_client.rb]
    AnalyzeTool --> TimeAnalyzer[time_analyzer.rb]
    AnalyzeTool --> ColorFilterManager[color_filter_manager.rb]
    AnalyzeTool --> ColorConstants[color_constants.rb]
    AnalyzeTool --> Errors[errors.rb]
    
    %% Google Calendar Client Dependencies
    GoogleCalendarClient --> TokenManager
    GoogleCalendarClient --> Errors
    GoogleCalendarClient --> GoogleAPI[Google APIs]
    
    %% Time Analyzer Dependencies
    TimeAnalyzer --> ColorConstants
    
    %% Color Filter Manager Dependencies
    ColorFilterManager --> ColorConstants
    
    %% Token Manager Dependencies
    TokenManager --> GoogleAuth[Google Auth]
    TokenManager --> FileSystem[File System]
    
    %% Auth Manager Dependencies (inferred)
    AuthManager --> TokenManager
    AuthManager --> GoogleAuth
    
    %% External Dependencies
    GoogleAPI --> HTTP[HTTP Requests]
    GoogleAuth --> OAuth[OAuth 2.0]
    
    %% Styling
    classDef entryPoint fill:#e1f5fe,color:#000
    classDef core fill:#f3e5f5,color:#000
    classDef tools fill:#e8f5e8,color:#000
    classDef managers fill:#fff3e0,color:#000
    classDef external fill:#fce4ec,color:#000
    
    class Main entryPoint
    class Server,TimeAnalyzer,ColorFilterManager core
    class AnalyzeTool,StartAuthTool,CheckAuthTool,CompleteAuthTool,BaseTool tools
    class TokenManager,AuthManager,GoogleCalendarClient managers
    class MCP,GoogleAPI,GoogleAuth,FileSystem,HTTP,OAuth external
```

## アーキテクチャ概要

### 階層構造

1. **エントリーポイント**: `calendar_color_mcp.rb`
   - アプリケーションの起動点

2. **コアサーバー**: `server.rb`
   - MCPツールの登録・管理
   - サーバーコンテキストの提供

3. **ツール層**: `tools/`
   - `analyze_calendar_tool.rb` - メインの分析機能
   - `start_auth_tool.rb` - 認証開始
   - `check_auth_status_tool.rb` - 認証状態確認
   - `complete_auth_tool.rb` - 認証完了
   - `base_tool.rb` - 共通基底クラス

4. **ビジネスロジック層**:
   - `time_analyzer.rb` - 時間分析ロジック
   - `color_filter_manager.rb` - 色フィルタリング

5. **インフラ層**:
   - `google_calendar_client.rb` - Google Calendar API連携
   - `token_manager.rb` - 認証情報管理
   - `google_calendar_auth_manager.rb` - OAuth管理

6. **共通モジュール**:
   - `color_constants.rb` - 色定義
   - `errors.rb` - エラークラス

### 主要な依存関係

- **AnalyzeCalendarTool** が最も複雑で、多くのコンポーネントに依存
- **ColorConstants** が共通の色定義として複数クラスから参照
- **TokenManager** がシングルトンとして認証情報を一元管理
- **BaseTool** が全てのツールクラスの基底クラスとして機能

### 外部依存

- **MCP SDK**: Model Context Protocol実装
- **Google APIs**: Calendar API v3
- **Google Auth**: OAuth 2.0認証
- **File System**: トークンファイル管理
