# /save-knowledge2 — セッション終了時の知識分類・保存

このセッションで得た学習項目を以下の判断ツリーに従って分類し、適切な保存先を提案してください。

## 手順

1. このセッションで新たに判明したこと・学んだこと・決定したことをリストアップする
2. 各項目を以下の判断ツリーで分類する
3. 各保存先ごとにまとめて提案し、ユーザーの確認を得てから保存する

## 判断ツリー

```
【学習項目】
  ↓
「複数のプロジェクトで再利用できるノウハウか？」
  ├─ YES → Infrastructure/ に保存
  │        例）Ubuntu デプロイ手順、PDF→JSON変換
  └─ NO  → 「コマンドとして定期的に実行する内容か？」
            ├─ YES → ~/.claude/commands/ に Skill として保存
            │        例）/save-knowledge, /pdf-to-json
            └─ NO  → 「このプロジェクト固有の context 情報か？」
                      ├─ YES → Memory に保存
                      │        例）4STEPはUbuntuで本番運用中
                      └─ NO  → 「判断基準・ベストプラクティスか？」
                                ├─ YES → Feedback として Memory に保存
                                │        例）exercises.dbにforeign_keys=ONを設定しない
                                └─ NO  → 「このプロジェクト固有の設計か？」
                                          ├─ YES → [プロジェクト]/docs/CLAUDE.md に保存
                                          └─ NO  → Skip
```

## 保存先の詳細

| 保存先 | パス例 | 内容 |
|--------|--------|------|
| Infrastructure | `~/Desktop/Projects/Infrastructure/*/CLAUDE.md` | 複数PJで使えるノウハウ |
| Skill（コマンド） | `~/.claude/commands/*.md` | 繰り返し実行するコマンド |
| Memory（project） | `~/.claude/projects/…/memory/project_*.md` | プロジェクトの状態・制約 |
| Memory（feedback） | `~/.claude/projects/…/memory/feedback_*.md` | 判断基準・ベストプラクティス |
| CLAUDE.md | `[プロジェクト]/docs/CLAUDE.md` | プロジェクト固有の設計・実装 |

## フォーマット

**Feedback の場合：**
```
【判断基準】
Why: ○○という理由で
How to apply: こういう場面で、こう判断する
```

**Memory（project）の場合：**
```
【事実・状態】
Why: なぜそれが重要か
How to apply: 次回どう活かすか
```
