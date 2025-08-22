# Calendar Color MCP Test Documentation

## テストアーキテクチャ

このプロジェクトは、関心の分離と責任の明確化による包括的テストスイートを使用しています。すべてのテストは実際のMCPサーバーバイナリ実行を使用してリアルな統合テストを保証します。

### テストのルール

#### RSpecの記法について
- `describe`、`context`、`it`ブロックを使用してテストを構造化する
- `it`ブロックにはshouldを使用して期待すべき動作を記述する
- `context`を使用してテストの前提条件を記述する
  - テスト内でif文を使用しない（代わりに`context`を使用して条件分岐を表現する） 
    - if文による分岐はテストの理解と保守を困難にするため
  - 同じインデントで`context`が5つ以上存在する場合、`rspec-parameterized `を使用してパラメータ駆動テストとする
  - 1つの`describe`に複数の前回条件がある場合は、`context`を使用して分ける。
    - 一方で、1つの`describe`に1つの`context`は冗長化するため不要
- `let`の遅延評価を使うことで、適切にコード量を減らす
- `subject`を使用して、わかりやすくSUT（System Under Test）を表す
  - `subject`はAAAパターンの`Act`部分に相当できる
  - `subject` は 各`describe`の下にメソッドごとに定義する

#### RSpecによらない一般的なテストコードのルールについて
- また、AAA（Arrange-Act-Assert）パターンに従って構造化する
  - **Arrange**: テストの前提条件を設定
  - **Act**: テスト対象のコードを実行 
  - **Assert**: 結果を検証
- テストは実装の詳細ではなく、公開されている振る舞いをテストする
- 外部の依存はテストダブルを使用する
- 各テストは独立して実行可能で、他のテストに依存しない
- テストは明確な目的を持ち、何をテストしているかを明示する
- テストは実行順序に依存しない
- テストは実装の変更に対して堅牢であるべきで、実装の詳細に依存しない
  - つまりprivateメソッドを直接テストしない
- テストは読みやすく、理解しやすいコードであるべき
- テストは失敗することが期待される場合、明示的に失敗するように記述する
- C0、C1カバレッジの目安は80%
  - 100%にすることを目指すが、実装の複雑さを増すために無理に達成しないため

### テスト構造

```
spec/
├── mcp_standard_spec.rb                    # MCPプロトコル標準準拠テスト
├── application/use_cases/                  # アプリケーション層のユースケーステスト
├── domain/services/                        # ドメイン層のサービステスト
├── infrastructure/repositories/            # インフラ層のリポジトリテスト
├── infrastructure/services/                # インフラ層のサービステスト
├── interface_adapters/tool/                # Interface Adapters層のツールテスト
└── integration/                           # 複数層間のエンドツーエンドフローテスト
```

### テストカテゴリ

#### 層別テスト

**Application層テスト** (`spec/application/use_cases/`)
- Use Casesのビジネスロジック
- 依存するRepositoryやServiceのモック使用

**Domain層テスト** (`spec/domain/services/`)
- ドメインサービスの純粋なビジネスロジック
- エンティティの振る舞い

**Infrastructure層テスト** (`spec/infrastructure/`)
- 外部システム連携の境界テスト
- Google API、ファイルシステムとの連携

**Interface Adapters層テスト** (`spec/interface_adapters/tool/`)
- MCPツールの機能を独立してテスト
- **パラメータ検証**: 必須/オプションパラメータ、型チェック
- **レスポンスフォーマット**: 一貫したJSON構造、エラーハンドリング
- **ツール固有機能**: 各ツールの責務とエッジケース

#### 統合テスト (`spec/integration/`)
**目的**: 複数層間のエンドツーエンドフローをテスト
- **認証フロー**: 認証開始 → 状態確認 → 認証完了 → 分析
- **層間連携**: Interface Adapters → Application → Domain → Infrastructure
- ただし、実際のGoogle Calendar API呼び出しは行わず、モックを使用

### テスト実行

```bash
bundle exec rspec                           # 全テストを実行
bundle exec rspec spec/mcp_standard_spec.rb # MCPプロトコルテストを実行
bundle exec rspec spec/interface_adapters/tool/ # 個別ツールテストを実行
bundle exec rspec spec/integration/         # 統合テストを実行
bundle exec rspec spec/[test_file].rb       # 単一テストファイルを実行
```