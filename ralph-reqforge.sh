#!/bin/bash

# Ralph Wiggum loop for ReqForge — AI-first requirements management app
# Usage: ./ralph-reqforge.sh

PLAN_FILE="Plans/issue-2-build-reqforge.md"
PROGRESS_FILE="Plans/build-reqforge-progress.txt"
MAX_ITERATIONS=120

# Ensure we're in the project root
cd "$(dirname "$0")" || exit 1

# Ensure PostgreSQL binaries are available
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
    echo "# ReqForge Implementation Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
fi

for i in $(seq 1 $MAX_ITERATIONS); do
    echo "=========================================="
    echo "Ralph iteration $i of $MAX_ITERATIONS — $(date '+%H:%M:%S')"
    echo "=========================================="

    OUTPUT=$(/Users/darrenwilson/.local/bin/claude --dangerously-skip-permissions -p "You are implementing ReqForge, an AI-first requirements management web application built with Rails 8, PostgreSQL, Tailwind CSS, and Hotwire. It replaces IBM DOORS for automotive requirements management with full compliance traceability (ISO 26262, ASPICE), in-browser reviews, and LLM-powered quality analysis.

IMPORTANT ENVIRONMENT SETUP: PostgreSQL binaries are at /opt/homebrew/opt/postgresql@17/bin — ensure this is in your PATH before running any database commands. Run: export PATH=\"/opt/homebrew/opt/postgresql@17/bin:\$PATH\"

## Plan File
$(cat "$PLAN_FILE")

## Progress So Far
$(cat "$PROGRESS_FILE")

## Instructions
1. Review the plan and progress above
2. Identify the NEXT SINGLE incomplete task (strict order: Phase 1 Task 1 -> Phase 1 Task 2 -> Phase 2 Task 1 -> etc.)
3. Implement ONLY that ONE task
4. After implementing, run 'bundle exec rspec' to verify tests pass (SKIP if: you only modified non-code files like the plan, OR you already ran tests as part of TDD this iteration)
5. Commit your changes with a descriptive message
6. Write ONE log entry to $PROGRESS_FILE:
   --- Iteration $i: \$(date) ---
   Task: [task name]
   Status: [completed/in-progress/blocked]
   Changes: [files modified]
   Notes: [any notes]

7. Then STOP. Do not continue to the next task.
8. Only output <promise>COMPLETE</promise> if ALL tasks in the entire plan are done.
9. Only output <promise>BLOCKED</promise> if you cannot proceed.

## CRITICAL RULES:
- Do NOT implement multiple tasks — only ONE task per iteration
- Do NOT write multiple log entries — only ONE entry with iteration number $i
- Do NOT continue after writing the log entry — STOP immediately
- Do NOT say COMPLETE unless every single task in the plan is finished
- Do NOT fake or simulate multiple iterations — you are iteration $i only
- Do NOT create generic AI slop UI — make it look professional, clean, distinctive
- DO write proper tests (RSpec) using TDD where the plan specifies it
- DO use Tailwind CSS classes properly — no inline styles
- DO use Hotwire (Turbo Frames/Streams + Stimulus) for interactivity — no heavy JS frameworks
- DO ensure the app is multi-tenant scoped to current_organization throughout
- DO use Paper Trail for audit history on requirements and links
- For the LLM service, wrap 'claude -p \"prompt\"' CLI calls — this is a placeholder for rapid iteration
- When creating UI, use a refined color palette: slate-900 for sidebar, amber-500 for accents, clean whites/grays for content

The bash loop will call you again for the next task. Your job is ONE task, ONE commit, ONE log entry, then STOP.")

    echo "$OUTPUT"

    # Check for completion
    if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
        echo ""
        echo "=========================================="
        echo "Implementation complete!"
        echo "=========================================="
        exit 0
    fi

    # Check for blocked state
    if echo "$OUTPUT" | grep -q "<promise>BLOCKED</promise>"; then
        echo ""
        echo "=========================================="
        echo "Implementation blocked - manual intervention needed"
        echo "=========================================="
        exit 1
    fi

    # Small delay between iterations
    sleep 2
done

echo "=========================================="
echo "Max iterations reached without completion"
echo "=========================================="
exit 1
