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

ActiveRecord::Schema[8.1].define(version: 2026_03_27_025346) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "reviews", force: :cascade do |t|
    t.jsonb "baseline_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.bigint "project_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_reviews_on_created_by_id"
    t.index ["project_id", "status"], name: "index_reviews_on_project_id_and_status"
    t.index ["project_id"], name: "index_reviews_on_project_id"
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

  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "organizations"
  add_foreign_key "requirement_modules", "projects"
  add_foreign_key "requirements", "projects"
  add_foreign_key "requirements", "sections"
  add_foreign_key "requirements", "users", column: "created_by_id"
  add_foreign_key "reviews", "projects"
  add_foreign_key "reviews", "users", column: "created_by_id"
  add_foreign_key "sections", "requirement_modules"
  add_foreign_key "sections", "sections", column: "parent_section_id"
  add_foreign_key "traceability_links", "requirements", column: "source_requirement_id"
  add_foreign_key "traceability_links", "requirements", column: "target_requirement_id"
  add_foreign_key "traceability_links", "users", column: "created_by_id"
end
