---
name: remember
slug: remember
description: Save information to project memory for future sessions
---

# /remember

Saves information to the project memory system. Information is automatically loaded in future sessions when working on this project.

## Usage

```
/remember [MEMORY_TYPE] [CONTENT]
```

**Memory types:**
- `project` - Project-specific information (goals, workflows, architecture)
- `feedback` - Notes on what works / what doesn't (for your approach)
- `user` - Information about the user's preferences/role
- `reference` - Pointers to external resources

## Examples

### Save a project workflow
```
/remember project

4STEP workflow:
- JSON edit → ./scripts/sync_and_backup.sh → ./scripts/ubuntu-sync.sh push
- DB separation: problems.db (safe to update) vs exercises.db (never delete)
- Ubuntu deployment at /home/hiro/Deployments/4STEP
```

### Save feedback on an approach
```
/remember feedback

Don't use /projects/ path on Ubuntu - use /Deployments/ instead.
Why: Already has Projects/ folder, naming conflict.
How to apply: When setting up deployments, use Deployments/ for clarity.
```

### Save user preference
```
/remember user

Prefer VS Code interface, don't want to switch to Claude.ai web version.
```

## How it works

1. Copy your memory content to clipboard
2. Run `/remember [type]`
3. Claude will save it to `/Users/hironobu/.claude/projects/[CURRENT_PROJECT]/memory/`
4. Next session automatically loads it

The memory system ensures context persists across sessions without re-explaining.

## Quick tip

Memory content is **stored permanently** in this project's memory folder. You can review/edit anytime by checking the memory directory.
