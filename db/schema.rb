# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_28_005621) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_analysis_results", force: :cascade do |t|
    t.string "analysis_type", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "requirement_id", null: false
    t.jsonb "result_data", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_type"], name: "index_ai_analysis_results_on_analysis_type"
    t.index ["requirement_id", "analysis_type"], name: "index_ai_analysis_results_on_requirement_id_and_analysis_type", unique: true
    t.index ["requirement_id"], name: "index_ai_analysis_results_on_requirement_id"
    t.index ["status"], name: "index_ai_analysis_results_on_status"
  end

  create_table "change_set_approvals", force: :cascade do |t|
    t.text "body"
    t.bigint "change_set_id", null: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["change_set_id", "status"], name: "index_change_set_approvals_on_change_set_id_and_status"
    t.index ["change_set_id", "user_id"], name: "index_change_set_approvals_on_change_set_id_and_user_id", unique: true
    t.index ["change_set_id"], name: "index_change_set_approvals_on_change_set_id"
    t.index ["user_id"], name: "index_change_set_approvals_on_user_id"
  end

  create_table "change_set_changes", force: :cascade do |t|
    t.jsonb "after_snapshot", default: {}
    t.jsonb "before_snapshot", default: {}
    t.bigint "change_set_id", null: false
    t.integer "change_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "requirement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["change_set_id", "change_type"], name: "index_change_set_changes_on_change_set_id_and_change_type"
    t.index ["change_set_id", "requirement_id"], name: "index_change_set_changes_on_change_set_id_and_requirement_id", unique: true
    t.index ["change_set_id"], name: "index_change_set_changes_on_change_set_id"
    t.index ["requirement_id"], name: "index_change_set_changes_on_requirement_id"
  end

  create_table "change_set_comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "change_set_change_id"
    t.bigint "change_set_id", null: false
    t.datetime "created_at", null: false
    t.bigint "parent_comment_id"
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["change_set_change_id", "created_at"], name: "idx_on_change_set_change_id_created_at_7ad5502177"
    t.index ["change_set_change_id"], name: "index_change_set_comments_on_change_set_change_id"
    t.index ["change_set_id", "created_at"], name: "index_change_set_comments_on_change_set_id_and_created_at"
    t.index ["change_set_id"], name: "index_change_set_comments_on_change_set_id"
    t.index ["parent_comment_id"], name: "index_change_set_comments_on_parent_comment_id"
    t.index ["resolved_by_id"], name: "index_change_set_comments_on_resolved_by_id"
    t.index ["user_id"], name: "index_change_set_comments_on_user_id"
  end

  create_table "change_set_rules", force: :cascade do |t|
    t.boolean "auto_merge_on_approval", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "min_approvals", default: 1, null: false
    t.bigint "project_id", null: false
    t.boolean "require_all_conversations_resolved", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_change_set_rules_on_project_id", unique: true
  end

  create_table "change_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.text "merge_commit_message"
    t.datetime "merged_at"
    t.bigint "merged_by_id"
    t.bigint "project_id", null: false
    t.bigint "source_baseline_id"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_change_sets_on_created_by_id"
    t.index ["merged_by_id"], name: "index_change_sets_on_merged_by_id"
    t.index ["project_id", "status"], name: "index_change_sets_on_project_id_and_status"
    t.index ["project_id"], name: "index_change_sets_on_project_id"
    t.index ["source_baseline_id"], name: "index_change_sets_on_source_baseline_id"
  end

  create_table "compliance_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "standard", null: false
    t.jsonb "template_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_compliance_templates_on_active"
    t.index ["name"], name: "index_compliance_templates_on_name", unique: true
    t.index ["standard"], name: "index_compliance_templates_on_standard"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "settings", default: {}
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "searchable_id"
    t.string "searchable_type"
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "projects", force: :cascade do |t|
    t.jsonb "attribute_schema", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "prefix", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_projects_on_organization_id_and_name", unique: true
    t.index ["organization_id", "prefix"], name: "index_projects_on_organization_id_and_prefix", unique: true
    t.index ["organization_id"], name: "index_projects_on_organization_id"
  end

  create_table "requirement_modules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position"
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_requirement_modules_on_project_id_and_name", unique: true
    t.index ["project_id", "position"], name: "index_requirement_modules_on_project_id_and_position"
    t.index ["project_id"], name: "index_requirement_modules_on_project_id"
  end

  create_table "requirements", force: :cascade do |t|
    t.integer "asil_level", default: 0, null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.jsonb "custom_attributes", default: {}, null: false
    t.integer "position"
    t.integer "priority", default: 0, null: false
    t.bigint "project_id", null: false
    t.integer "requirement_type", default: 0, null: false
    t.bigint "section_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_requirements_on_created_by_id"
    t.index ["project_id", "requirement_type"], name: "index_requirements_on_project_id_and_requirement_type"
    t.index ["project_id", "status"], name: "index_requirements_on_project_id_and_status"
    t.index ["project_id"], name: "index_requirements_on_project_id"
    t.index ["section_id", "position"], name: "index_requirements_on_section_id_and_position"
    t.index ["section_id"], name: "index_requirements_on_section_id"
    t.index ["uid"], name: "index_requirements_on_uid", unique: true
  end

  create_table "review_comments", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "parent_comment_id"
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.bigint "review_item_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["parent_comment_id"], name: "index_review_comments_on_parent_comment_id"
    t.index ["resolved_by_id"], name: "index_review_comments_on_resolved_by_id"
    t.index ["review_item_id", "created_at"], name: "index_review_comments_on_review_item_id_and_created_at"
    t.index ["review_item_id"], name: "index_review_comments_on_review_item_id"
    t.index ["user_id"], name: "index_review_comments_on_user_id"
  end

  create_table "review_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "requirement_id", null: false
    t.bigint "review_id", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["requirement_id"], name: "index_review_items_on_requirement_id"
    t.index ["review_id", "requirement_id"], name: "index_review_items_on_review_id_and_requirement_id", unique: true
    t.index ["review_id", "status"], name: "index_review_items_on_review_id_and_status"
    t.index ["review_id"], name: "index_review_items_on_review_id"
  end

  create_table "review_participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "review_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["review_id", "role"], name: "index_review_participants_on_review_id_and_role"
    t.index ["review_id", "user_id"], name: "index_review_participants_on_review_id_and_user_id", unique: true
    t.index ["review_id"], name: "index_review_participants_on_review_id"
    t.index ["user_id"], name: "index_review_participants_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.jsonb "baseline_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.bigint "project_id", null: false
    t.string "share_token"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_reviews_on_created_by_id"
    t.index ["project_id", "status"], name: "index_reviews_on_project_id_and_status"
    t.index ["project_id"], name: "index_reviews_on_project_id"
    t.index ["share_token"], name: "index_reviews_on_share_token", unique: true, where: "(share_token IS NOT NULL)"
  end

  create_table "sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_section_id"
    t.integer "position"
    t.bigint "requirement_module_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_section_id"], name: "index_sections_on_parent_section_id"
    t.index ["requirement_module_id", "parent_section_id", "name"], name: "index_sections_on_module_parent_and_name", unique: true
    t.index ["requirement_module_id", "position"], name: "index_sections_on_requirement_module_id_and_position"
    t.index ["requirement_module_id"], name: "index_sections_on_requirement_module_id"
  end

  create_table "test_cases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.text "expected_result"
    t.text "preconditions"
    t.integer "priority", default: 0, null: false
    t.bigint "project_id", null: false
    t.bigint "requirement_id"
    t.integer "status", default: 5, null: false
    t.text "steps"
    t.integer "test_type", default: 0, null: false
    t.string "title", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_test_cases_on_created_by_id"
    t.index ["project_id", "status"], name: "index_test_cases_on_project_id_and_status"
    t.index ["project_id", "test_type"], name: "index_test_cases_on_project_id_and_test_type"
    t.index ["project_id"], name: "index_test_cases_on_project_id"
    t.index ["requirement_id"], name: "index_test_cases_on_requirement_id"
    t.index ["uid"], name: "index_test_cases_on_uid", unique: true
  end

  create_table "traceability_links", force: :cascade do |t|
    t.boolean "ai_suggested", default: false, null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.integer "link_type", default: 0, null: false
    t.bigint "source_requirement_id", null: false
    t.bigint "target_requirement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_traceability_links_on_created_by_id"
    t.index ["link_type"], name: "index_traceability_links_on_link_type"
    t.index ["source_requirement_id", "target_requirement_id", "link_type"], name: "idx_traceability_links_unique", unique: true
    t.index ["source_requirement_id"], name: "index_traceability_links_on_source_requirement_id"
    t.index ["target_requirement_id"], name: "index_traceability_links_on_target_requirement_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "ai_analysis_results", "requirements"
  add_foreign_key "change_set_approvals", "change_sets"
  add_foreign_key "change_set_approvals", "users"
  add_foreign_key "change_set_changes", "change_sets"
  add_foreign_key "change_set_changes", "requirements"
  add_foreign_key "change_set_comments", "change_set_changes"
  add_foreign_key "change_set_comments", "change_set_comments", column: "parent_comment_id"
  add_foreign_key "change_set_comments", "change_sets"
  add_foreign_key "change_set_comments", "users"
  add_foreign_key "change_set_comments", "users", column: "resolved_by_id"
  add_foreign_key "change_set_rules", "projects"
  add_foreign_key "change_sets", "projects"
  add_foreign_key "change_sets", "reviews", column: "source_baseline_id"
  add_foreign_key "change_sets", "users", column: "created_by_id"
  add_foreign_key "change_sets", "users", column: "merged_by_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "organizations"
  add_foreign_key "requirement_modules", "projects"
  add_foreign_key "requirements", "projects"
  add_foreign_key "requirements", "sections"
  add_foreign_key "requirements", "users", column: "created_by_id"
  add_foreign_key "review_comments", "review_comments", column: "parent_comment_id"
  add_foreign_key "review_comments", "review_items"
  add_foreign_key "review_comments", "users"
  add_foreign_key "review_comments", "users", column: "resolved_by_id"
  add_foreign_key "review_items", "requirements"
  add_foreign_key "review_items", "reviews"
  add_foreign_key "review_participants", "reviews"
  add_foreign_key "review_participants", "users"
  add_foreign_key "reviews", "projects"
  add_foreign_key "reviews", "users", column: "created_by_id"
  add_foreign_key "sections", "requirement_modules"
  add_foreign_key "sections", "sections", column: "parent_section_id"
  add_foreign_key "test_cases", "projects"
  add_foreign_key "test_cases", "requirements"
  add_foreign_key "test_cases", "users", column: "created_by_id"
  add_foreign_key "traceability_links", "requirements", column: "source_requirement_id"
  add_foreign_key "traceability_links", "requirements", column: "target_requirement_id"
  add_foreign_key "traceability_links", "users", column: "created_by_id"
end
