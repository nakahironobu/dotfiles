---
name: wiki
description: >
  This skill handles all LLM Wiki knowledge base operations for the Knowledge_Base project.
  Use when the user invokes /wiki with subcommands: ingest, query, lint, or status.
  The wiki is a persistent, cross-linked markdown knowledge base that grows and improves over time.
argument-hint: <ingest <file> | query <question> | lint | status>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# LLM Wiki Skill

This skill manages the LLM Wiki — a persistent, compounding personal knowledge base. The wiki lives in the Knowledge_Base project and is governed by CLAUDE.md in the project root.

## Subcommands

### `/wiki ingest <file>`

Ingest a new source document from the `raw/` directory and integrate it into the wiki.

**Workflow:**

1. **Verify file exists** in `raw/` directory:
   - Use Read tool to load the file
   - If not found, report error

2. **Summarize and discuss**:
   - Read CLAUDE.md to understand the schema
   - Identify main ideas, entities, and concepts
   - Present to user: "Key takeaways from [title]:
     - Point 1
     - Point 2
     - Point 3
     
     Which of these should I emphasize? Any entities or concepts to prioritize?"
   - Wait for user feedback before proceeding

3. **Create source page**:
   - Create `wiki/sources/<slug>.md` where `<slug>` is kebab-case derived from the document title
   - Frontmatter:
     ```yaml
     ---
     type: source
     tags: [tag1, tag2]
     created: [TODAY's date YYYY-MM-DD]
     updated: [TODAY's date YYYY-MM-DD]
     sources: []
     ---
     ```
   - Content: title, metadata (author, date, URL if applicable), key takeaways (bullet list), summary (1-2 paragraphs), topics/entities mentioned with [[wikilinks]]

4. **Update or create entity pages** (`wiki/entities/`):
   - For each person, organization, or place mentioned, check if a page exists
   - If yes: append new information to the existing page, update the `updated` date, add the source slug to the `sources:` list
   - If no: create a new entity page with appropriate frontmatter and initial content
   - Use [[wikilinks]] to reference related entities

5. **Update or create concept pages** (`wiki/concepts/`):
   - For each idea, theory, or technique mentioned, check if a page exists
   - If yes: strengthen the page with new insights, update `updated` date, add source slug to `sources:`
   - If no: create a new concept page with frontmatter and initial definition/explanation
   - Add [[wikilinks]] to related concepts and entities

6. **Update index.md**:
   - Read the current index
   - Add new pages to the appropriate section (Sources, Entities, Concepts)
   - If the source page or entity/concept pages already exist, update the row with new links or metadata
   - Maintain alphabetical order within sections
   - Update the "Last updated" date

7. **Append to log.md**:
   - Add an entry: `## [YYYY-MM-DD] ingest | <source title>`

8. **Report to user**:
   - Summarize what was created/updated: "Created X new pages, updated Y existing pages. Here's what's new in the wiki:"
   - List the new pages with brief descriptions

---

### `/wiki query <question>`

Search the wiki for information relevant to the user's question and synthesize an answer.

**Workflow:**

1. **Read index.md**:
   - Load the wiki index to understand page structure and contents
   - Identify pages likely to contain relevant information based on title and category

2. **Read relevant pages**:
   - Load the identified pages into context
   - If many pages match, prioritize: sources first, then entities, then concepts
   - Use Grep if needed to search within pages for specific keywords

3. **Synthesize answer**:
   - Compose a clear, well-organized response with citations
   - Reference specific pages: "According to [[page-name]], ..."
   - Note contradictions or areas of debate: "However, [[another-page]] suggests..."
   - Include concrete examples where available

4. **Offer to file**:
   - If the answer is substantive and represents new synthesis, ask the user:
     "This is a valuable synthesis. Should I save it as a wiki page? I could create `wiki/synthesis/<slug>.md`"
   - If user says yes:
     - Create the synthesis page with the query as the headline and the answer as content
     - Add appropriate frontmatter with relevant source slugs
     - Update index.md to include the new synthesis page
     - Append to log.md: `## [YYYY-MM-DD] query | <query title>`

5. **Report**:
   - Present the synthesized answer to the user

---

### `/wiki lint`

Perform a health check on the wiki, identify issues, and suggest or execute fixes.

**Workflow:**

1. **Load all pages**:
   - Use Glob to find all pages in `wiki/` (sources/, entities/, concepts/, synthesis/)
   - Read each page to understand content and frontmatter

2. **Check for issues**:
   - **Contradictions**: Identify claims in different pages that conflict. Flag with quotes and file names.
   - **Stale information**: Check if a page's claims have been superseded by a newer source. Look for dates in frontmatter.
   - **Orphan pages**: Pages with no inbound [[wikilinks]] and not referenced in index. List them.
   - **Missing pages**: Concepts or entities mentioned with [[wikilinks]] but no corresponding file. List broken links.
   - **Incomplete linking**: Related pages that should link to each other but don't.

3. **Generate report**:
   - Group findings by severity (high, medium, low)
   - Example output:
     ```
     ## Lint Report
     
     ### High Priority (Broken links, contradictions)
     - broken-link: [[nonexistent-page]] referenced in entities/alan-turing.md but file doesn't exist
     - contradiction: entities/alan-turing.md says "born 1912" but sources/birth-records.md says "1911"
     
     ### Medium Priority (Orphans, stale info)
     - orphan: concepts/obsolete-theory.md has no inbound links
     - stale: entities/newton.md last updated 2026-01-15; newer sources mention him
     
     ### Low Priority (Incomplete linking)
     - concepts/gravity.md should link to [[newton-laws]]
     ```

4. **Execute fixes** (with user approval):
   - **Broken links**: Create missing pages or remove dead links (user choice)
   - **Contradictions**: Don't resolve — present both views. Add note explaining the discrepancy.
   - **Orphans**: Either add inbound links from related pages, or archive/delete (user choice)
   - **Stale info**: Revisit pages, update with new information, note evolution across sources
   - **Incomplete linking**: Add [[wikilinks]] where appropriate

5. **Update log.md**:
   - Append: `## [YYYY-MM-DD] lint | Found X issues, resolved Y`

6. **Report**:
   - Show user the final state: "Fixed 3 broken links, merged 2 contradictory claims, linked 5 orphan pages"

---

### `/wiki status`

Display a quick overview of the wiki's current state.

**Workflow:**

1. **Read index.md** and **log.md**
2. **Gather stats**:
   - Count pages by type (sources, entities, concepts, synthesis)
   - Extract last update date (from log.md most recent entry)
   - Count total sources ingested
   - Quick scan for obvious issues (orphans, broken links)

3. **Display report**:
   ```
   📚 Wiki Status
   
   Total Pages: 47
   ├─ Sources: 12
   ├─ Entities: 18
   ├─ Concepts: 14
   └─ Synthesis: 3
   
   Activity:
   ├─ Last update: [YYYY-MM-DD] (N days ago)
   ├─ Total ingests: 12
   ├─ Last ingest: [title] on [YYYY-MM-DD]
   
   Health:
   ├─ Orphan pages: 0
   ├─ Broken links: 0
   └─ Last lint: [YYYY-MM-DD]
   ```

---

## Important Notes for LLM

- **CLAUDE.md is your source of truth**: Read it at the start of every /wiki operation to stay aligned with the schema and conventions
- **Avoid over-ingestion**: If a file is too large or covers many unrelated topics, ask the user if they want to split it
- **User-driven emphasis**: During ingest, always ask the user which themes to prioritize. Don't make those calls alone
- **Maintain freshness**: On ingest, revisit related existing pages (not just create new ones). Update them with connections to the new source
- **File good syntheses**: Query responses that represent genuine new insights should become synthesis pages — they're as valuable as source pages
- **Language consistency**: Each page's language should match its source language(s). If a page merges sources in different languages, use the dominant language and note other languages in content
