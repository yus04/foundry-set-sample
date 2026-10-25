# Microsoft Foundry デプロイガイド

## プロジェクト概要

このプロジェクトは、Microsoft Foundry とその周辺の Azure AI サービスを一括デプロイするための統合 Bicep テンプレート集です。

### 特徴

✅ **Azure Developer CLI (azd) 対応**: `azd up` コマンドで完全自動デプロイ
✅ **統一された命名規則**: baseName + environment による一貫したリソース命名
✅ **モジュール化されたアーキテクチャ**: 機能別に整理されたBicepモジュール
✅ **既存リソースの活用**: AI Search、Storage、Cosmos DB の既存リソース利用可能
✅ **自動ロール割り当て**: 必要な Azure RBAC ロールを自動設定
✅ **エージェント機能対応**: AI Agent Service の標準セットアップ

## クイックスタートガイド

### 前提条件

```bash
# Azure Developer CLI のインストール確認
azd version

# Azure Developer CLI のインストール（未インストールの場合）
# Windows (PowerShell)
powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"

# macOS/Linux
curl -fsSL https://aka.ms/install-azd.sh | bash
```

### デプロイ手順

#### ステップ1: Azure にログイン

```bash
azd auth login
```

#### ステップ2: 初期化とデプロイ

```bash
# プロジェクトディレクトリに移動
cd foundry-set-sample

# 一括デプロイ（対話式）
azd up
```

`azd up` を実行すると、以下を対話的に入力します：
- **環境名**: 例: `dev`, `test`, `prod`
- **Azure サブスクリプション**: デプロイ先のサブスクリプション
- **リージョン**: 例: `eastus`, `westus2`, `japaneast`

リソースグループは自動的に作成されます（命名: `rg-{環境名}-{baseName}`）

#### ステップ3: デプロイ状態の確認

```bash
# デプロイされたリソースの情報を表示
azd show

# 環境変数と出力値を表示
azd env get-values

# Azure Portal で確認
azd show --output json | jq -r '.services[].target.resourceIds[]'
```

## パラメータ設定ガイド

azd では、環境変数を使用してパラメータを設定します。

#### 方法 1: 対話式設定（推奨）

```bash
azd up
# プロンプトに従って入力：
# - 環境名（例: dev, test, prod）
# - サブスクリプション
# - リージョン（例: eastus, japaneast）
```

#### 方法 2: 環境変数で設定

```bash
# 環境の初期化
azd init

# 環境変数の設定
azd env set AZURE_LOCATION eastus
azd env set BASE_NAME myaiagent
azd env set MODEL_NAME gpt-4o
azd env set MODEL_CAPACITY 100

# デプロイ実行
azd up
```

#### 方法 3: .env ファイルで設定

`.azure/{環境名}/.env` ファイルを編集:

```env
AZURE_LOCATION=eastus
AZURE_ENV_NAME=dev
BASE_NAME=myaiagent
MODEL_NAME=gpt-4o
MODEL_VERSION=2024-08-06
MODEL_CAPACITY=100
USER_OBJECT_ID=your-user-object-id
```

### パラメータ詳細

#### 必須パラメータ

| パラメータ | 型 | 説明 | 例 |
|-----------|----|----|---|
| `baseName` | string | リソース名のベース (3-15文字) | `aiagent` |
| `environmentName` | string | 環境名 (dev/test/prod) | `dev` |

#### オプションパラメータ

| パラメータ | 型 | デフォルト値 | 説明 |
|-----------|----|-----------|----|
| `location` | string | リソースグループの場所 | デプロイリージョン |
| `modelName` | string | `gpt-4o` | AIモデル名 |
| `modelFormat` | string | `OpenAI` | モデルフォーマット |
| `modelVersion` | string | `2024-08-06` | モデルバージョン |
| `modelSkuName` | string | `GlobalStandard` | モデルSKU |
| `modelCapacity` | int | `100` | モデルキャパシティ |
| `projectDisplayName` | string | `AI Agent Project` | プロジェクト表示名 |
| `projectDescription` | string | - | プロジェクト説明 |
| `existingAiSearchResourceId` | string | `""` | 既存AI Search ID |
| `existingStorageAccountResourceId` | string | `""` | 既存Storage ID |
| `existingCosmosDbAccountResourceId` | string | `""` | 既存Cosmos DB ID |

## デプロイされるリソース

### コアリソース

| リソース | 命名規則 | 説明 |
|---------|---------|------|
| AI Services Account | `{baseName}-{env}-aiservices` | Azure OpenAI などの AI サービス |
| AI Project | `{baseName}-{env}-project` | AI エージェントプロジェクト |

### 依存リソース

| リソース | 命名規則 | 説明 |
|---------|---------|------|
| AI Search | `{baseName}-{env}-search` | ベクトル検索サービス |
| Storage Account | `{baseName}{env}storage` | Blob ストレージ |
| Cosmos DB | `{baseName}-{env}-cosmos` | ドキュメントデータベース |

### 自動設定されるロール

#### AI Search
- `Search Index Data Contributor`
- `Search Service Contributor`

#### AI Search のマネージド ID → Foundry
- `Cognitive Services OpenAI User`
- `Cognitive Services User`

上記 2 ロールは、この IaC がデプロイする Foundry の AI Services Account 単位で付与します。

#### Cosmos DB
- `Cosmos DB Operator`
- `Cosmos DB Built-in Data Contributor`

#### Storage Account
- `Storage Blob Data Contributor`
- `Storage Blob Data Owner` (コンテナスコープ)

### Foundry IQ の Embedding モデルへのプライベート接続

`azure.yaml` が参照する `infra/main.bicep` / `infra/main.resources.bicep` では、次の設定を自動実行します。旧テンプレートの `azuredeploy.json` は対象外です。

1. AI Search のシステム割り当てマネージド ID に上記 2 ロールを付与します。
2. AI Search に Shared Private Link を作成します。
   - Resource Type: `Microsoft.CognitiveServices/accounts`
   - Resource: この IaC でデプロイする Foundry リソース（追加の Cognitive Services リソースではありません）
   - Target sub-resource (group ID): `openai_account`
   - Request message: Search 名と、Search / Foundry のリソース ID から生成した識別子を含むメッセージ
3. Shared Private Link の作成完了後、Foundry 側で同じメッセージを持つ接続だけを `Approved` に更新します。他の接続は承認しません。対象が 0 件または複数件の場合はデプロイを失敗させます。

承認後も識別用メッセージを保持するため、同じリソースへの再デプロイでも対象の接続を再利用できます。既存 AI Search を指定した場合も、そのサブスクリプションとリソースグループに Shared Private Link を作成します。既存サービスでは、システム割り当てマネージド ID を事前に有効にしてください。

デプロイ実行者には、Foundry 側の `Microsoft.CognitiveServices/accounts/privateEndpointConnections/write` と、Search 側の `Microsoft.Search/searchServices/sharedPrivateLinkResources/write`（および両リソースの読み取り）の権限が必要です。通常の Contributor に加え、ロール割り当て用の権限も必要です。Search が別のサブスクリプションやリソースグループにある場合は、そちらにもデプロイ権限が必要です。

デプロイ後は、AI Search の **Networking → Shared private access** で対象接続が `Approved` / `Succeeded`、Foundry の **Networking → Private endpoint connections** で対象接続が `Approved` になっていることを確認してください。RBAC と接続状態の反映には数分かかる場合があります。

この変更は Embedding モデル自体をデプロイしません。Foundry IQ で利用する Embedding モデルは、同じ Foundry リソースに別途デプロイし、Search のベクトライザーなどでそのデプロイ名とマネージド ID 認証を指定してください。インデクサーを使用する場合は、[Shared Private Link の公式手順](https://learn.microsoft.com/azure/search/search-indexer-howto-access-private)に従い、プライベート実行環境も設定してください。既存の VNet 用 Private Endpoint とパブリックアクセス無効の設定は変更しません。

## 高度な使用例

### 既存リソースの使用

`.azure/{環境名}/.env` ファイルまたは環境変数で設定:

```bash
azd env set EXISTING_AI_SEARCH_RESOURCE_ID "/subscriptions/xxx/resourceGroups/rg-shared/providers/Microsoft.Search/searchServices/shared-search"
azd env set EXISTING_STORAGE_ACCOUNT_RESOURCE_ID "/subscriptions/xxx/resourceGroups/rg-shared/providers/Microsoft.Storage/storageAccounts/sharedstorage"
azd env set EXISTING_COSMOS_DB_ACCOUNT_RESOURCE_ID "/subscriptions/xxx/resourceGroups/rg-shared/providers/Microsoft.DocumentDB/databaseAccounts/shared-cosmos"

azd up
```

### カスタムタグの追加

`infra/main.resources.bicep` のtagsセクションを編集:

```bicep
param tags object = {
  environment: environmentName
  managedBy: 'bicep'
  project: 'azure-ai-foundry'
  costCenter: 'engineering'
  owner: 'ai-team'
}
```

### 複数環境へのデプロイ

```bash
# 開発環境
azd env new dev
azd env set MODEL_CAPACITY 50
azd up

# ステージング環境
azd env new test
azd env set MODEL_CAPACITY 100
azd up

# 本番環境
azd env new prod
azd env set MODEL_CAPACITY 200
azd up

# 環境の切り替え
azd env select dev
azd show
```

## トラブルシューティング

### よくあるエラーと解決方法

#### 1. リソース名の競合

```
Error: The resource name 'xxx' already exists
```

**解決方法**: `baseName` パラメータを変更してください。

```bash
azd env set BASE_NAME aiagent2
azd up
```

#### 2. クォータ超過

```
Error: Operation could not be completed as it results in exceeding approved quota
```

**解決方法**: 
- Azure ポータルでクォータを確認
- クォータ増加をリクエスト
- 別のリージョンを試す

#### 3. 権限エラー

```
Error: The client 'xxx' does not have authorization to perform action
```

**解決方法**: 以下のロールが必要です:
- `Contributor` (リソース作成用)
- `Role Based Access Control Administrator` (ロール割り当て用)

### デバッグ方法

```bash
# デプロイ状態の詳細確認
azd show --output json

# 環境変数の確認
azd env get-values

# ログの確認
azd deploy --debug
```

## クリーンアップ

```bash
# 環境の完全削除（リソースグループとすべてのリソース）
azd down --force --purge

# 特定の環境のみ削除
azd env select dev
azd down
```

## ベストプラクティス

### セキュリティ

1. **最小権限の原則**: 必要最小限のロールのみ付与
2. **プライベートエンドポイント**: 本番環境では推奨
3. **キーの管理**: Azure Key Vault の使用を推奨
4. **ネットワークACL**: 必要に応じてIP制限を設定

### 運用

1. **タグ付け**: コスト管理のため適切なタグを設定
2. **モニタリング**: Application Insights の有効化
3. **環境分離**: 開発・テスト・本番環境を明確に分離
4. **バージョン管理**: Bicep ファイルを Git で管理

### CI/CD パイプライン

#### Azure Developer CLI を使用

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install azd
        uses: Azure/setup-azd@v0.1.0
      
      - name: Azure Login
        uses: Azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy
        run: azd up --no-prompt
        env:
          AZURE_ENV_NAME: ${{ secrets.AZURE_ENV_NAME }}
          AZURE_LOCATION: ${{ secrets.AZURE_LOCATION }}
          BASE_NAME: ${{ secrets.BASE_NAME }}
```

### コスト最適化

1. **適切なSKU選択**: ワークロードに応じたSKUを選択
2. **リソースの共有**: 開発/テスト環境でのリソース共有
3. **自動スケーリング**: 使用状況に応じた自動調整
4. **定期的なレビュー**: 未使用リソースの特定と削除

## サポートとリソース

### ドキュメント

- [Microsoft Foundry](https://learn.microsoft.com/azure/ai-studio/)
- [Azure Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/cognitive-services/openai/)

### コミュニティ

- [Microsoft Q&A](https://learn.microsoft.com/answers/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/azure-ai)
- [GitHub Discussions](https://github.com/Azure/azure-quickstart-templates/discussions)

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。
