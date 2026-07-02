---
name: save-knowledge
slug: save-knowledge
description: Intelligently classify and save session learnings to the right home (Git repo, Skill, CLAUDE.md, hook, or Memory). Acts as a router/orchestrator — it does not invent its own storage format.
---

# /save-knowledge

セッション中に得られた学習を棚卸しして、**今ある正しい置き場**へ振り分ける。
このスキルは「分類オーケストレータ」であり、各置き場の独自フォーマットは持たない
（Memory への書き込みは `/remember` に、自動化フックは `/update-config` に委譲する）。

## 使い方

```
/save-knowledge
```

実行すると、直近のセッションログから学習項目を抽出し、各項目の保存先を提案する。
ユーザーが承認した項目だけを書き込む。

---

## 大原則

1. **コードはコードとして Git に置く。メモには置かない。**
   再利用できる動くもの（スクリプト/ツール/テンプレ）はリポジトリへ。説明文だけを memory に残さない。
2. **形式の二重管理をしない。**
   事実・状態は組み込み Memory（型付き frontmatter ＋ MEMORY.md 索引）に一本化。書き込みは `/remember` に委譲。
3. **常時ロードは安い順に使う。**
   CLAUDE.md と Memory は毎回コンテキストを食う。大きい/たまに使うものは Skill（オンデマンド）へ逃がす。
4. **不可逆・共有される置き場は書く前に必ず確認。**
   CLAUDE.md（dotfiles 含む）/ settings.json / 各リポジトリへの書き込みは、内容を見せて承認を取ってから実行する。
   Memory への書き込みは低リスクなので、まとめて提案→一括でよい。

---

## 判断ツリー

```
学習項目
│
├ 1. 動くコード/テンプレ/ツールとして再利用する？
│      ├ 設定・ルール（Claude/shell/環境）   → dotfiles リポジトリ
│      ├ 動くツール（CLIや変換器など）        → ~/tools/<name>/（専用 uv venv）
│      └ ユーザー向け成果物・アプリ            → その案件の GitHub リポジトリ
│
├ 2. 自分が能動的に呼ぶ「手順・コマンド」？（大きめ / たまに使う / 状況依存）
│      → Skill：~/.claude/skills/<name>/SKILL.md
│
├ 3. Claude が毎回守るべき「ルール／規約」？
│      ├ 自動で必ず実行が要る（「〜したら毎回Xする」） → hook（settings.json）※/update-config に委譲
│      └ それ以外（守るべき方針・規約）              → CLAUDE.md（スコープを選ぶ）
│            ├ 全マシン・全プロジェクト共通  → ~/.claude/CLAUDE.md   （dotfiles 実体）
│            ├ ~/Projects 配下に共通        → ~/Projects/CLAUDE.md  （dotfiles 実体）
│            └ 単一プロジェクト固有          → <project>/CLAUDE.md   （その repo に commit）
│
├ 4. プロジェクト／自分についての「事実・状態・経緯」？
│      → Memory（/remember に委譲）。型を選ぶ：
│            project   … 進行中の作業・目標・制約（コードから導けないもの）
│            feedback  … やり方の良し悪し（Why と How to apply を必ず添える）
│            user      … ユーザーの役割・好み・環境
│            reference … 外部リソースへのポインタ（URL・チケット等）
│
└ 5. どれにも当たらない → Skip
```

判断のコツ：迷ったら **①「動くコードか？」→ ②「自分で呼ぶ手順か？」→ ③「毎回効かせるルールか？」→ ④「ただの事実か？」** の順で上から落とす。

---

## 各置き場の詳細（検証済みパス）

### 1. Git リポジトリ（再利用コード）— 旧 Infrastructure の後継

「再利用できる動くもの」は説明メモではなく**コードそのもの**を置く。内容で振り分ける：

| 種類 | 置き場 | 備考 |
|---|---|---|
| 設定・ルール（Claude/shell/環境） | `~/dotfiles/`（`nakahironobu/dotfiles`） | 2台のMacで共有。stow 管理 |
| 動くツール（CLI・変換器など） | `~/tools/<name>/` | 専用 uv venv で動かす（例: `~/tools/ndlocr-lite`） |
| ユーザー向け成果物・アプリ | その案件の GitHub リポジトリ | グローバル CLAUDE.md の「コード=Git／原本=Drive」線引きに従う |

> リポジトリは Google Drive の外（ローカル）に置く。原本・中間生成物は Drive。

### 2. Skill — `~/.claude/skills/<name>/SKILL.md`

`/xxx` で能動的に呼ぶ、再利用可能な手順・コマンド。オンデマンドでロードされるので、
大きい・たまにしか使わない・状況依存なノウハウはここへ逃がす（常時ロードを汚さない）。

### 3. CLAUDE.md — 3レベルのスコープ

毎回コンテキストに載る「守るべきルール」。**スコープを必ず選ぶ**。

| スコープ | 実パス | 注意 |
|---|---|---|
| 全マシン共通 | `~/.claude/CLAUDE.md` | → `~/dotfiles/home/.claude/CLAUDE.md` の実体。**編集＝dotfiles 編集**。commit して両Mac同期 |
| ~/Projects 共通 | `~/Projects/CLAUDE.md` | → `~/dotfiles/home/Projects/CLAUDE.md` の実体。同上 |
| 単一プロジェクト | `<project>/CLAUDE.md` | その repo に commit。同僚にも効く |

判断：他PJでも応用できる→上位スコープ／このPJ独自の設計・スキーマ・制約→プロジェクト CLAUDE.md。

### 4. hook（自動化）— `settings.json` ※`/update-config` に委譲

「〜したら毎回 X する」は memory でも CLAUDE.md でも保証できない。ハーネスが実行する hook が要る。
このケースは内容を整理して **`/update-config` に渡す**（settings.json の hooks を直接いじらない）。

### 5. Memory — `~/.claude/projects/<PROJECT_ID>/memory/` ＋ `MEMORY.md` ※`/remember` に委譲

セッションを跨ぐ「事実・状態・経緯」。型付き frontmatter（user/feedback/project/reference）＋
`[[リンク]]` ＋ MEMORY.md 索引の組み込み形式。**書き込みは `/remember <type>` に委譲**して二重管理を避ける。
feedback と project は本文に **Why:** と **How to apply:** を添える。

---

## 実行フロー（このスキルが呼ばれたときの手順）

1. **棚卸し**：直近のセッションログを走査し、再利用価値のある学習を粒度ごとに列挙する。
2. **分類**：各項目を上の判断ツリーに通し、保存先（とスコープ/型）を決める。
3. **提案**：表で「項目 → 提案先 → 理由」を一覧提示する。
4. **確認**：CLAUDE.md / settings.json / 各リポジトリ への書き込みは項目ごとに承認を取る
   （Memory はまとめて提案→一括でよい）。
5. **委譲して書く**：
   - 事実・状態 → `/remember <type>` の形式で memory に。
   - 自動化ルール → `/update-config` に渡す。
   - コード → 該当リポジトリへ（dotfiles / ~/tools / 案件 repo）。
   - 手順 → Skill を新規/更新。
   - ルール → 該当スコープの CLAUDE.md に追記。
6. **同期の注意を添える**：dotfiles 実体（~/.claude/CLAUDE.md, ~/Projects/CLAUDE.md）や
   プロジェクト CLAUDE.md を変更したら、commit して両Mac/同僚へ反映するよう促す。

---

## 旧版からの変更点（2026-06 改訂）

- **Infrastructure/ バケツを廃止**：`~/Desktop/Projects/Infrastructure/` は実在しない。
  再利用コードは Git（dotfiles / ~/tools / 案件 repo）へ振り分ける方式に変更。
- **Memory/Feedback を組み込み Memory に一本化**：独自フォーマットをやめ、`/remember` に委譲。
- **hook を保存先に追加**：「毎回〜する」自動化は `/update-config` 経由で settings.json へ。
- **CLAUDE.md を3スコープに明確化**：全マシン / ~/Projects / 単一PJ。dotfiles 実体であることを明記。

---

## 関連スキル

- `/remember` — Memory に型付きで直接保存（このスキルが委譲する先）
- `/update-config` — settings.json / hooks / permissions の変更（自動化ルールの委譲先）
