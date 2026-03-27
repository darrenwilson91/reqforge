# Issue #2: Build ReqForge: AI-first requirements management to replace IBM DOORS

## Original Issue

An AI-first, modern web application for requirements management that directly addresses every major IBM DOORS pain point. Multi-tenant, full compliance traceability (ISO 26262, ASPICE, AUTOSAR), in-browser reviews with change tracking, and LLM-powered quality analysis, link suggestion, and impact analysis.

## Success Criteria

- [ ] User can sign up, create an organization, and invite team members with roles
- [ ] User can create projects with configurable requirement schemas (custom attributes via JSONB)
- [ ] User can create, edit, delete, and organize requirements hierarchically (modules > sections > requirements)
- [ ] Requirements have full version history with diff view (Paper Trail)
- [ ] User can create typed traceability links between requirements (derives-from, satisfies, verifies, etc.)
- [ ] Traceability matrix view shows coverage and gaps with filtering
- [ ] User can create review sessions, invite reviewers, and manage approval workflows
- [ ] Reviewers can comment inline on specific requirements with threaded discussions
- [ ] Review shows diff of changes since last baseline/review
- [ ] AI quality analysis runs on requirements using INCOSE rules (ambiguity, completeness, singularity)
- [ ] AI suggests traceability links based on semantic similarity
- [ ] AI performs impact analysis when requirements change
- [ ] CSV import/export works
- [ ] ISO 26262 and ASPICE compliance templates are available
- [ ] App has a polished, professional UI — clean, fast, no AI slop
- [ ] All core features have test coverage (RSpec + system tests)

## Implementation Plan

### Phase 1: Foundation — Database, Auth, Multi-tenancy

- [ ] Create git branch `feature/build-reqforge`
- [ ] Add core gems to Gemfile: `devise`, `pundit`, `paper_trail`, `pg_search`, `acts_as_list`, `sidekiq`, `rspec-rails`, `factory_bot_rails`, `faker`, `shoulda-matchers`, `capybara`, `selenium-webdriver`
- [ ] Run `bundle install`
- [ ] Set up RSpec: `rails generate rspec:install`, configure `rails_helper.rb` with FactoryBot, Shoulda Matchers, DatabaseCleaner
- [ ] Create and migrate development/test databases: `rails db:create`
- [ ] Install Devise: `rails generate devise:install`, configure mailer defaults
- [ ] Generate User model with Devise: `rails generate devise User first_name:string last_name:string`
- [ ] Generate Organization model: `rails generate model Organization name:string slug:string:uniq settings:jsonb`
- [ ] Generate Membership model (join table): `rails generate model Membership user:references organization:references role:integer` — roles: admin=0, project_manager=1, author=2, reviewer=3, viewer=4
- [ ] Write model specs for User, Organization, Membership (validations, associations, role enum)
- [ ] Run specs to verify they pass
- [ ] Set up Pundit: `rails generate pundit:install`
- [ ] Create ApplicationController with `include Pundit::Authorization`, current_organization helper, set_current_organization from session/subdomain
- [ ] Add multi-tenancy scoping: default_scope or controller-level scoping via current_organization
- [ ] Write and run tests for multi-tenancy scoping

**Verification checkpoint:** `bundle exec rspec` — all specs green. User can sign up, organization exists in DB.

### Phase 2: Project & Requirement Data Model

- [ ] Generate Project model: `rails generate model Project organization:references name:string description:text prefix:string status:integer attribute_schema:jsonb`
- [ ] Generate RequirementModule model: `rails generate model RequirementModule project:references name:string description:text position:integer`
- [ ] Generate Section model: `rails generate model Section requirement_module:references parent_section:references name:string position:integer`
- [ ] Generate Requirement model: `rails generate model Requirement section:references project:references uid:string:uniq title:string body:text requirement_type:integer status:integer priority:integer asil_level:integer custom_attributes:jsonb position:integer created_by:references`
  - requirement_type enum: functional=0, non_functional=1, safety=2, interface=3, design_constraint=4
  - status enum: draft=0, in_review=1, approved=2, implemented=3, verified=4, obsolete=5
  - priority enum: must_have=0, should_have=1, could_have=2, wont_have=3
  - asil_level enum: qm=0, asil_a=1, asil_b=2, asil_c=3, asil_d=4
- [ ] Add `acts_as_list` to RequirementModule, Section, Requirement for ordering
- [ ] Add `has_paper_trail` to Requirement model for full audit history
- [ ] Generate UID auto-generation concern: before_create callback using project prefix + sequence
- [ ] Write model specs for Project, RequirementModule, Section, Requirement (validations, associations, enums, UID generation)
- [ ] Run specs to verify they pass
- [ ] Add `pg_search` multisearch scope to Requirement model for full-text search

**Verification checkpoint:** `bundle exec rspec` — all specs green. Requirement hierarchy works in console.

### Phase 3: Traceability Links

- [ ] Generate TraceabilityLink model: `rails generate model TraceabilityLink source_requirement:references target_requirement:references link_type:integer description:text created_by:references ai_suggested:boolean confidence:float`
  - link_type enum: derives_from=0, satisfies=1, verifies=2, conflicts_with=3, refines=4, implements=5, parent_child=6
- [ ] Add model validations: no self-links, no duplicate links, bidirectional accessor methods
- [ ] Add `has_paper_trail` to TraceabilityLink
- [ ] Write specs for TraceabilityLink model (validations, link types, reverse link lookup)
- [ ] Run specs to verify they pass
- [ ] Create TraceabilityMatrix service: given a project, generate a matrix of source requirements vs target requirements with link types
- [ ] Write specs for TraceabilityMatrix service
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 4: Core UI — Layout, Navigation, Dashboard

- [ ] Create application layout with Tailwind: sidebar navigation, top bar with org/user info, main content area
- [ ] Design color palette and typography — professional, clean, NOT generic AI slop. Use a refined color scheme: deep navy primary (#1e293b), warm accent (#f59e0b), clean whites and grays
- [ ] Create shared partials: `_sidebar.html.erb`, `_topbar.html.erb`, `_flash_messages.html.erb`
- [ ] Create Stimulus controllers: `sidebar_controller.js` (collapse/expand), `dropdown_controller.js`, `flash_controller.js`
- [ ] Set up Devise views with Tailwind styling (sign up, sign in, forgot password)
- [ ] Create organization setup flow: after sign up, prompt to create or join organization
- [ ] Create dashboard controller and view: show recent requirements, review status, project overview
- [ ] Write system specs for sign up → organization creation → dashboard flow
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. Visual inspection of sign up and dashboard pages.

### Phase 5: Project Management UI

- [ ] Create ProjectsController with full CRUD (index, new, create, show, edit, update, destroy)
- [ ] Create ProjectPolicy (Pundit) — admin/PM can create/edit, all members can view
- [ ] Create project views with Tailwind: index (card grid), new/edit (form), show (project overview with modules tree)
- [ ] Add attribute schema editor (Stimulus): dynamic form to define custom attributes per project (name, type, required)
- [ ] Write controller specs and system specs for project CRUD
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 6: Requirements Management UI

- [ ] Create RequirementsController with CRUD (nested under project)
- [ ] Create RequirementPolicy — authors can create/edit, viewers can only read
- [ ] Create requirement tree view: left panel shows module/section/requirement hierarchy (Stimulus tree controller)
- [ ] Create requirement detail view: right panel shows selected requirement with all attributes, editable form
- [ ] Create requirement form with rich text editing (Trix or ActionText), custom attribute fields rendered from project schema
- [ ] Add inline editing: click to edit requirement fields in place (Turbo Frames)
- [ ] Create requirement status workflow UI: status badge, transition buttons based on current status
- [ ] Add drag-and-drop reordering for requirements within sections (Stimulus sortable controller)
- [ ] Create version history panel: show Paper Trail versions with diff highlighting
- [ ] Write controller specs and system specs for requirement CRUD, status transitions, version history
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. Visual inspection of requirement tree and detail views.

### Phase 7: Traceability UI

- [ ] Create TraceabilityLinksController: create, destroy links between requirements
- [ ] Create link creation UI: search for target requirement, select link type, create link (Turbo Frame)
- [ ] Create requirement detail panel showing linked requirements grouped by link type
- [ ] Create traceability matrix view: filterable grid showing source vs target requirements with link indicators
- [ ] Create traceability graph visualization using inline SVG or lightweight JS (show requirement as nodes, links as edges)
- [ ] Add coverage metrics: percentage of requirements with forward/backward links per link type
- [ ] Write specs for traceability controller and views
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 8: Review System (THE killer feature)

- [ ] Generate Review model: `rails generate model Review project:references title:string description:text status:integer created_by:references baseline_snapshot:jsonb`
  - status enum: draft=0, open=1, in_progress=2, completed=3, cancelled=4
- [ ] Generate ReviewItem model: `rails generate model ReviewItem review:references requirement:references status:integer snapshot:jsonb`
  - status enum: pending=0, approved=1, rejected=2, needs_changes=3
- [ ] Generate ReviewComment model: `rails generate model ReviewComment review_item:references user:references body:text parent_comment:references resolved:boolean resolved_by:references resolved_at:datetime`
- [ ] Generate ReviewParticipant model: `rails generate model ReviewParticipant review:references user:references role:integer`
  - role enum: author=0, reviewer=1, approver=2, observer=3
- [ ] Write model specs for Review, ReviewItem, ReviewComment, ReviewParticipant
- [ ] Run specs to verify they pass
- [ ] Create ReviewsController with full workflow: create review (snapshot requirements), open for review, complete review
- [ ] Create review creation UI: select requirements to include, set reviewers, create review
- [ ] Create review dashboard: show all reviews with status, progress bar (approved/total items)
- [ ] Create review detail view: list of review items with current status, comment counts
- [ ] Create review item detail view: show requirement snapshot vs current version (diff), inline commenting with threading
- [ ] Create diff rendering service: compare requirement snapshot to current version, highlight changes (Diffy gem or custom)
- [ ] Add approval workflow UI: reviewer can approve/reject/request changes on each item
- [ ] Add review completion logic: auto-complete when all items have decisions, compute overall status
- [ ] Set up Action Cable for real-time review updates: new comments, status changes appear live
- [ ] Create shareable review link (public token): external stakeholders can view review read-only without login
- [ ] Write controller specs and system specs for complete review workflow
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. Complete review workflow works end-to-end.

### Phase 9: LLM Service & AI Features

- [ ] Create LlmService class in `app/services/llm_service.rb`: wraps `claude -p "prompt"` CLI call with timeout, error handling, JSON parsing
- [ ] Write specs for LlmService (mock CLI calls)
- [ ] Run specs to verify they pass
- [ ] Create QualityAnalyzer service: sends requirement text to LLM with INCOSE rules prompt, returns quality scores and suggestions
  - Prompt checks: ambiguity (vague terms like "adequate", "appropriate"), completeness (no pronouns, measurable criteria), singularity (one thought per requirement), active voice, defined terms
- [ ] Create LinkSuggester service: given a requirement, finds semantically similar requirements and suggests trace links
  - Sends requirement text + candidate requirements to LLM, asks for similarity ranking and link type suggestions
- [ ] Create ImpactAnalyzer service: given a changed requirement, identifies all potentially affected downstream requirements
  - Sends changed requirement + linked requirements to LLM for impact assessment
- [ ] Create RequirementGenerator service: given natural language description, generates structured requirement drafts
- [ ] Create Sidekiq jobs for each AI service: QualityAnalysisJob, LinkSuggestionJob, ImpactAnalysisJob
- [ ] Add AI results storage: generate AiAnalysisResult model to cache AI results per requirement
- [ ] Create AI panel in requirement detail view: show quality score, suggestions, suggested links
- [ ] Add "Analyze" button that triggers quality analysis via Turbo Stream
- [ ] Add "Suggest Links" button that triggers link suggestion via Turbo Stream
- [ ] Add impact analysis notification: when requirement is saved, enqueue ImpactAnalysisJob, show results as notification
- [ ] Write specs for all AI services and jobs
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. AI features trigger and display results.

### Phase 10: Import/Export

- [ ] Create CsvImporter service: parse CSV, map columns to requirement attributes, create requirements in bulk
- [ ] Create CsvExporter service: export project requirements to CSV with all attributes
- [ ] Create ReqifExporter service: generate ReqIF 1.2 XML with SpecObjects, Specifications, SpecHierarchy, SpecRelations
- [ ] Create ReqifImporter service: parse ReqIF XML, create requirements and links from SpecObjects and SpecRelations
- [ ] Add import/export UI: project settings page with import (file upload) and export (download) buttons
- [ ] Write specs for all import/export services
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. CSV round-trip works. ReqIF export generates valid XML.

### Phase 11: Compliance Templates

- [ ] Create ComplianceTemplate model or seed data: pre-defined project templates for ISO 26262 and ASPICE
- [ ] ISO 26262 template: creates modules for each V-model phase (System Req, SW Req, Architecture, Design, Unit Test, Integration Test, System Test) with predefined link types between phases
- [ ] ASPICE template: creates modules aligned with SWE.1-SWE.6, SUP.7, SUP.9/10 process areas
- [ ] Add template selection during project creation: user picks a compliance standard, project is pre-populated
- [ ] Create compliance dashboard: show traceability coverage per phase, highlight gaps, ASIL coverage
- [ ] Write specs for compliance templates
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 12: Polish & Final UI

- [ ] Review and refine all views for consistency: spacing, typography, color usage
- [ ] Add loading states (Turbo progress bar, skeleton screens)
- [ ] Add empty states for all list views (no projects, no requirements, no reviews)
- [ ] Add breadcrumb navigation throughout the app
- [ ] Add keyboard shortcuts: `n` for new requirement, `e` for edit, `s` for save, `Esc` to cancel
- [ ] Add search: global search bar in top nav, searches requirements by title, body, UID (pg_search)
- [ ] Add responsive design: sidebar collapses on mobile
- [ ] Add dark mode toggle (Tailwind dark variant)
- [ ] Create seed data: demo organization, demo project with ISO 26262 template, sample requirements and reviews
- [ ] Run full test suite
- [ ] Fix any failing tests
- [ ] Visual review of all pages for UI quality — no generic/slop elements

**Verification checkpoint:** `bundle exec rspec` — all specs green. App looks professional and polished.

### Phase 13: Flow-State Authoring Mode

The current requirement creation form requires filling out a full form with mouse interactions. Engineers need a rapid-entry mode where they can get into flow state — type a requirement, hit Enter, next requirement. No mouse, no form completion. Attributes (type, ASIL, priority) can be bulk-edited afterwards.

- [ ] Create a new "Quick Entry" view at `/projects/:id/requirements/quick_entry` — a clean, minimal full-width editor (no sidebar tree, no filters, just a focused writing surface)
- [ ] The view shows: project name, selected module/section at the top (changeable via dropdown), then a vertical list of requirement input rows
- [ ] Each row is a single text input spanning the full width, with a subtle UID badge on the left (auto-assigned). Pressing **Enter** creates the requirement and immediately adds a new empty row below with focus — no page reload (Turbo Stream append)
- [ ] Pressing **Shift+Enter** allows multi-line within a single requirement (the body field)
- [ ] Pressing **Tab** on an empty row opens a minimal inline attribute bar: type, priority, ASIL selectable via keyboard (arrow keys + Enter). Pressing **Escape** closes the attribute bar
- [ ] Pressing **Up/Down arrows** when not editing navigates between requirements. **Backspace** on an empty row deletes it (with confirmation if it has content)
- [ ] Add a floating action bar at the bottom: shows count of requirements entered this session, "Done" button that goes to the requirements list, and a module/section switcher
- [ ] Each requirement is saved immediately on Enter (optimistic create via Turbo) — no "Save" button needed, no data loss if browser closes
- [ ] Create Stimulus controller `quick_entry_controller.js` handling all keyboard interactions: Enter (create + focus next), Shift+Enter (newline), Tab (attributes), Up/Down (navigate), Backspace (delete empty), Escape (close attributes)
- [ ] Style the quick entry view: clean white background, generous line spacing, subtle separators between requirements, the UID badge in monospace on the left, a soft amber focus ring on the active row
- [ ] Add a "Quick Entry" button/link on the requirements index page and project show page (prominent — this is the primary authoring flow)
- [ ] Write request specs for quick entry: create requirement on Enter, auto-UID assignment, section scoping, attribute editing, deletion
- [ ] Write system specs for keyboard flow: Enter creates next, Shift+Enter for multiline, navigation, attribute bar
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. Quick entry feels fast and keyboard-driven.

### Phase 14: Bulk Attribute Editing

After rapid entry, users need to quickly tag requirements with attributes. Rather than editing each one individually, provide a bulk editor.

- [ ] Create a "Bulk Edit" view at `/projects/:id/requirements/bulk_edit` — a spreadsheet-like table view of requirements
- [ ] Columns: checkbox (select), UID, Title (editable inline), Type (dropdown), Status (dropdown), Priority (dropdown), ASIL (dropdown), Section (dropdown)
- [ ] Clicking a cell makes it editable. Tab moves to the next cell, Shift+Tab moves back. Enter confirms and moves down
- [ ] Checkbox column allows selecting multiple requirements. Toolbar above the table has bulk actions: "Set Type", "Set Priority", "Set ASIL", "Move to Section", "Delete Selected"
- [ ] Bulk actions open a small popover to pick the value, then apply to all selected requirements in one request (single Turbo Stream update)
- [ ] Create Stimulus controller `bulk_edit_controller.js` handling: cell navigation (Tab/Shift+Tab/Enter/Arrow keys), inline editing, checkbox selection (Shift+click for range select), bulk action toolbar visibility
- [ ] Add "Bulk Edit" button on requirements index page next to "Quick Entry"
- [ ] Write request specs for bulk edit: inline update, bulk type/priority/ASIL change, bulk move, bulk delete
- [ ] Write system specs for keyboard navigation and bulk selection
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 15: Change Sets (PR-Style Reviews)

Replace the current review system with a PR-style model. A Change Set is like a branch — users make changes to requirements within it, and those changes don't affect the approved baseline until the Change Set is reviewed and merged.

- [ ] Generate ChangeSet model: `rails generate model ChangeSet project:references title:string description:text status:integer created_by:references source_baseline:references merge_commit_message:text merged_by:references merged_at:datetime`
  - status enum: draft=0, open=1, in_review=2, approved=3, merged=4, closed=5
- [ ] Generate ChangeSetRule model: `rails generate model ChangeSetRule project:references min_approvals:integer require_all_conversations_resolved:boolean auto_merge_on_approval:boolean`
  - Configurable per project: how many approvals needed, whether unresolved comments block merge, whether to auto-merge
- [ ] Generate ChangeSetApproval model: `rails generate model ChangeSetApproval change_set:references user:references status:integer body:text`
  - status enum: pending=0, approved=1, changes_requested=2, commented=3
- [ ] Generate ChangeSetChange model: `rails generate model ChangeSetChange change_set:references requirement:references change_type:integer before_snapshot:jsonb after_snapshot:jsonb`
  - change_type enum: created=0, modified=1, deleted=2
  - before_snapshot: requirement attributes at time of change set creation (null for new requirements)
  - after_snapshot: current state of the requirement within this change set
  - This tracks every individual requirement change within the change set
- [ ] Add has_paper_trail to ChangeSet, ChangeSetApproval, ChangeSetChange
- [ ] Write model specs for all four models (validations, associations, enums, snapshots)
- [ ] Run specs to verify they pass
- [ ] Create ChangeSetsController with full workflow:
  - `new/create`: Create a change set (starts as draft)
  - `show`: Display the change set with all changes as a diff view (like a PR diff)
  - `edit/update`: Edit title/description while in draft/open
  - Workflow actions: `open` (submit for review), `approve`, `request_changes`, `merge`, `close`
- [ ] Create change set **diff view** (the core PR experience):
  - List all changed requirements grouped by: Added, Modified, Deleted
  - Each modified requirement shows a side-by-side or unified diff of changed fields (title, body, type, status, priority, ASIL)
  - New requirements show as green additions, deleted as red strikethroughs
  - Each requirement change has its own comment thread (like line comments on a PR)
  - Overall change set has a "conversation" tab for general discussion
- [ ] Create change set **approval UI**:
  - Reviewers can "Approve", "Request Changes", or just "Comment"
  - Show approval status next to each reviewer's avatar (green check, orange dot, red X)
  - Show merge eligibility: "X of Y required approvals", "N unresolved conversations"
  - "Merge" button enabled only when approval rules are met
- [ ] Create change set **merge logic**:
  - On merge: apply all after_snapshots to the actual requirements (create new, update modified, soft-delete deleted)
  - Record merge commit message, merged_by, merged_at
  - Create Paper Trail versions for all affected requirements
  - If a requirement was modified by someone else since the change set was created (conflict), show a conflict warning and require resolution before merge
- [ ] Integrate change sets into requirement editing:
  - When a user edits a requirement, if they're working within a change set, the edit is recorded as a ChangeSetChange (before/after snapshot) rather than directly modifying the requirement
  - Add "Start Change Set" button in the requirement detail view and requirements list
  - When working in a change set, show a banner at the top: "You're editing in Change Set: [title]" with a link to the change set
- [ ] Create ChangeSetPolicy: all members can view, authors/PMs/admins can create, configurable who can approve (based on ChangeSetRule), only PMs/admins can merge
- [ ] Add change set approval rules configuration to project settings page
- [ ] Update sidebar: rename "Reviews" to "Change Sets" (or keep both — Change Sets for requirement changes, Reviews for formal compliance reviews)
- [ ] Create change set dashboard: list of open change sets with status, approval progress, age
- [ ] Write comprehensive request specs for change set CRUD, workflow transitions, approval flow, merge logic, conflict detection
- [ ] Write system specs for the full PR flow: create change set → edit requirements → submit for review → approve → merge
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green. Full PR-style workflow works end-to-end.

### Phase 16: Test Cases

Test engineers need to write test cases linked to requirements, providing verification traceability.

- [ ] Generate TestCase model: `rails generate model TestCase project:references requirement:references title:string description:text preconditions:text steps:text expected_result:text test_type:integer status:integer priority:integer created_by:references uid:string:uniq`
  - test_type enum: unit=0, integration=1, system=2, acceptance=3, safety=4
  - status enum: draft=0, ready=1, passed=2, failed=3, blocked=4, not_run=5
  - Auto-generate UID with project prefix + "TC" + sequence (e.g., BRK-TC-001)
- [ ] Add has_paper_trail to TestCase
- [ ] Add has_many :test_cases to Requirement and Project
- [ ] Write model specs for TestCase (validations, associations, UID generation, enums)
- [ ] Run specs to verify they pass
- [ ] Create TestCasesController with CRUD nested under projects
- [ ] Create TestCasePolicy: authors/PMs/admins can create/edit, all members can view
- [ ] Create test case list view: table with UID, title, linked requirement UID, type, status, priority
- [ ] Create test case detail view: shows all fields, linked requirement with traceability link, version history
- [ ] Create test case form: title, description, preconditions, steps (multi-line), expected result, type, status, priority, linked requirement (searchable dropdown)
- [ ] Add "Test Cases" section to the requirement detail view: shows linked test cases with their status, quick-add button
- [ ] Add test coverage metrics to the traceability matrix: percentage of requirements with at least one test case, grouped by test status (passed/failed/not run)
- [ ] Add "Test Cases" to sidebar navigation under "Requirements" section
- [ ] Update compliance dashboard to show test coverage per V-model phase
- [ ] Write request specs and system specs for test case CRUD and traceability
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 17: Dashboard Improvements for Managers

Managers and chasers need at-a-glance dashboards showing project health, progress, and bottlenecks.

- [ ] Enhance the main dashboard with role-aware content:
  - For admins/PMs: show org-wide metrics (total requirements, approval rates, review velocity, overdue reviews)
  - For engineers: show their assigned work (requirements they authored, pending reviews they need to action)
- [ ] Create a project-level dashboard (replace current project show page stats with richer metrics):
  - Requirements breakdown: pie chart or bar showing draft/in-review/approved/verified/obsolete counts
  - Traceability health: percentage of requirements with forward links, backward links, test cases
  - Change set velocity: open/merged/closed change sets over time
  - Review bottlenecks: change sets waiting for review > 3 days, reviewers with outstanding approvals
  - ASIL coverage: requirements by ASIL level with approval status
- [ ] Add a "My Work" page: personal view showing requirements the user authored (filterable by status), change sets they created or need to review, test cases assigned to them
- [ ] Write specs for dashboard metrics and my-work page
- [ ] Run specs to verify they pass

**Verification checkpoint:** `bundle exec rspec` — all specs green.

### Phase 18: Final Polish & QA

- [ ] Rebuild CSS assets to ensure all new views use the design system correctly
- [ ] Run full test suite: `bundle exec rspec`
- [ ] Fix any failing tests
- [ ] Start the Rails server and verify the complete flow:
  - Sign up → create org → create project with ISO 26262 template
  - Quick entry: rapid-fire 5 requirements using only keyboard
  - Bulk edit: select all, set ASIL to ASIL-D
  - Create a change set, modify 2 requirements, submit for review
  - As another user (or same), approve and merge the change set
  - Create test cases linked to requirements
  - View traceability matrix with test coverage
  - View project dashboard metrics
  - CSV export and re-import
  - AI quality analysis on a requirement
- [ ] Visual review: ensure all pages are clean, professional, consistent, responsive
- [ ] If any verification fails, add fix tasks and re-verify
- [ ] Update seed data to include sample change sets, test cases, and richer dashboard data

**Verification checkpoint:** `bundle exec rspec` — all specs green. App is polished and complete.

### Phase 19: PR & Code Review

- [ ] Run `/pr` to create a pull request with all changes
- [ ] Review PR feedback and create fix tasks for any issues scoring 50% or higher confidence
- [ ] Implement fixes and push
- [ ] Comment on PR with summary of changes

### Phase 20: Cleanup

- [ ] Reflect on learnings and document any non-obvious decisions
- [ ] Ensure all services are properly shut down
