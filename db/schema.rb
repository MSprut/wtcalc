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

ActiveRecord::Schema[7.2].define(version: 2025_09_25_073854) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "citext"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "companies", force: :cascade do |t|
    t.citext "name", null: false
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_companies_on_name", unique: true
  end

  create_table "company_divisions", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "division_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "division_id"], name: "idx_company_divisions_unique", unique: true
    t.index ["company_id"], name: "index_company_divisions_on_company_id"
    t.index ["division_id"], name: "index_company_divisions_on_division_id"
  end

  create_table "divisions", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "idx_divisions_name_lower_unique", unique: true
  end

  create_table "import_files", force: :cascade do |t|
    t.string "filename", null: false
    t.string "checksum", null: false
    t.integer "rows_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum"], name: "index_import_files_on_checksum", unique: true
  end

  create_table "lunch_breaks", force: :cascade do |t|
    t.bigint "user_id"
    t.date "on_date"
    t.integer "minutes", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(1)", name: "idx_lb_global_default_one", unique: true, where: "((user_id IS NULL) AND (on_date IS NULL))"
    t.index ["user_id", "on_date"], name: "idx_lb_user_ondate_unique", unique: true
    t.index ["user_id"], name: "idx_lb_user_default_unique", unique: true, where: "(on_date IS NULL)"
    t.index ["user_id"], name: "index_lunch_breaks_on_user_id"
  end

  create_table "passes", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "happened_at", null: false
    t.string "direction", null: false
    t.citext "door"
    t.citext "comment"
    t.citext "calculation_basis"
    t.citext "zone"
    t.jsonb "raw", default: {}, null: false
    t.bigint "import_file_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["happened_at"], name: "index_passes_on_happened_at"
    t.index ["import_file_id"], name: "index_passes_on_import_file_id"
    t.index ["user_id", "happened_at"], name: "index_passes_on_user_id_and_happened_at"
    t.index ["user_id"], name: "index_passes_on_user_id"
    t.check_constraint "direction::text = ANY (ARRAY['in'::character varying, 'out'::character varying]::text[])", name: "chk_passes_direction"
  end

  create_table "personal_identifier_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "personal_identifier_id", null: false
    t.tstzrange "period", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["personal_identifier_id", "period"], name: "idx_pia_ident_period_gist", using: :gist
    t.index ["personal_identifier_id"], name: "idx_on_personal_identifier_id_0de2f02b32"
    t.index ["user_id", "period"], name: "idx_pia_user_period_gist", using: :gist
    t.index ["user_id"], name: "index_personal_identifier_assignments_on_user_id"
    t.exclusion_constraint "personal_identifier_id WITH =, period WITH &&", using: :gist, name: "excl_pia_ident_overlap"
    t.exclusion_constraint "user_id WITH =, period WITH &&", using: :gist, name: "excl_pia_user_overlap"
  end

  create_table "personal_identifiers", force: :cascade do |t|
    t.string "value", null: false
    t.string "normalized_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_value"], name: "index_personal_identifiers_on_normalized_value", unique: true
  end

  create_table "user_division_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "division_id", null: false
    t.tstzrange "period", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["division_id"], name: "index_user_division_memberships_on_division_id"
    t.index ["user_id", "period"], name: "index_user_division_memberships_on_user_id_and_period", using: :gist
    t.index ["user_id"], name: "index_user_division_memberships_on_user_id"
    t.exclusion_constraint "user_id WITH =, period WITH &&", using: :gist, name: "excl_udm_user_overlap"
  end

  create_table "users", force: :cascade do |t|
    t.citext "last_name", null: false
    t.citext "first_name", null: false
    t.citext "middle_name"
    t.date "dob"
    t.bigint "current_division_id"
    t.citext "position"
    t.string "auth_login", null: false
    t.string "pin_digest"
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(((((COALESCE((last_name)::text, ''::text) || ' '::text) || COALESCE((first_name)::text, ''::text)) || ' '::text) || COALESCE((middle_name)::text, ''::text))) gin_trgm_ops", name: "idx_users_fullname_trgm", using: :gin
    t.index ["auth_login"], name: "index_users_on_auth_login", unique: true
    t.index ["current_division_id"], name: "index_users_on_current_division_id"
  end

  add_foreign_key "company_divisions", "companies"
  add_foreign_key "company_divisions", "divisions"
  add_foreign_key "lunch_breaks", "users"
  add_foreign_key "passes", "import_files"
  add_foreign_key "passes", "users"
  add_foreign_key "personal_identifier_assignments", "personal_identifiers"
  add_foreign_key "personal_identifier_assignments", "users"
  add_foreign_key "user_division_memberships", "divisions"
  add_foreign_key "user_division_memberships", "users"
  add_foreign_key "users", "divisions", column: "current_division_id"
end
