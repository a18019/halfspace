# halfspace

macOS で日本語 IME 使用時に全角スペースを半角スペースに自動変換するツールです。

## 機能

- **Space** → 半角スペース (`U+0020`)
- **Shift+Space** → 全角スペース (`U+3000`)
- IME 変換中のスペースはそのまま（変換操作を妨げません）

## インストール

```bash
brew tap a18019/halfspace
brew install halfspace
```

## 使い方

### バックグラウンドで常駐（ログイン時に自動起動）

```bash
brew services start halfspace
```

### 停止

```bash
brew services stop halfspace
```

## アクセシビリティ権限

初回起動時にアクセシビリティ権限の許可が必要です。

**システム設定 > プライバシーとセキュリティ > アクセシビリティ** で `halfspace` を許可してください。

## 要件

- macOS
- 日本語 IME

## ライセンス

MIT
