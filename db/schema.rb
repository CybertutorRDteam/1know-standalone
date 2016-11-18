# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161118024801) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "activation_codes", force: true do |t|
    t.string   "code",            limit: 32
    t.string   "permission_name"
    t.string   "role"
    t.integer  "ref_user_id"
    t.integer  "duration",                   default: 0
    t.datetime "activation_time"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "admin_accounts", force: true do |t|
    t.string   "account",    null: false
    t.string   "password",   null: false
    t.string   "acc_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "appgo_domain", force: true do |t|
    t.text   "name"
    t.string "domain", limit: 32
  end

  add_index "appgo_domain", ["domain"], name: "uniq_appgo_domain", unique: true, using: :btree

  create_table "appgo_domain_channel", force: true do |t|
    t.integer "ref_domain_id",  limit: 8
    t.integer "ref_channel_id", limit: 8
    t.string  "uqid",           limit: 32
  end

  add_index "appgo_domain_channel", ["ref_channel_id"], name: "appgo_domain_channel_ref_channel_id_idx", using: :btree
  add_index "appgo_domain_channel", ["ref_domain_id", "ref_channel_id"], name: "uniq_appgo_domain_channel", unique: true, using: :btree
  add_index "appgo_domain_channel", ["ref_domain_id"], name: "appgo_domain_channel_ref_domain_id_idx", using: :btree

  create_table "bookmark", force: true do |t|
    t.decimal  "video_time"
    t.text     "content"
    t.datetime "update_time"
    t.integer  "ref_user_id",   limit: 8
    t.integer  "ref_unit_id",   limit: 8
    t.string   "uqid",          limit: 32
    t.text     "content_type"
    t.boolean  "is_public"
    t.text     "content_color"
  end

  add_index "bookmark", ["ref_unit_id"], name: "bookmark_ref_unit_id_idx", using: :btree
  add_index "bookmark", ["ref_user_id"], name: "bookmark_ref_user_id_idx", using: :btree

  create_table "cancel_code_logs", force: true do |t|
    t.string   "old_code"
    t.string   "new_code"
    t.string   "permission_name"
    t.string   "role"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "category", force: true do |t|
    t.string  "uqid",            limit: 32
    t.text    "name"
    t.text    "logo"
    t.integer "ref_channel_id",  limit: 8
    t.integer "ref_category_id", limit: 8
    t.integer "priority"
  end

  add_index "category", ["ref_category_id"], name: "category_ref_category_id_idx", using: :btree
  add_index "category", ["ref_channel_id"], name: "category_ref_channel_id_idx", using: :btree

  create_table "category_knowledge", force: true do |t|
    t.integer "ref_category_id", limit: 8
    t.integer "ref_know_id",     limit: 8
    t.integer "ref_channel_id",  limit: 8
    t.string  "uqid",            limit: 32
    t.text    "url"
    t.integer "priority"
  end

  add_index "category_knowledge", ["ref_category_id"], name: "category_knowledge_ref_category_id_idx", using: :btree
  add_index "category_knowledge", ["ref_channel_id"], name: "category_knowledge_ref_channel_id_idx", using: :btree
  add_index "category_knowledge", ["ref_know_id"], name: "category_knowledge_ref_know_id_idx", using: :btree

  create_table "channel", force: true do |t|
    t.string   "uqid",                limit: 32
    t.text     "name"
    t.text     "description"
    t.text     "logo"
    t.datetime "last_update"
    t.integer  "ref_organization_id", limit: 8
  end

  create_table "channel_editor", force: true do |t|
    t.integer "ref_channel_id", limit: 8
    t.integer "ref_user_id",    limit: 8
    t.string  "uqid",           limit: 32
    t.integer "order"
    t.boolean "is_show"
    t.text    "role"
  end

  add_index "channel_editor", ["ref_channel_id", "ref_user_id"], name: "uniq_channel_editor", unique: true, using: :btree

  create_table "channel_member", force: true do |t|
    t.integer  "ref_user_id",    limit: 8
    t.integer  "ref_channel_id", limit: 8
    t.datetime "sign_time"
    t.text     "role"
    t.text     "status"
    t.integer  "order"
    t.text     "uqid"
  end

  add_index "channel_member", ["ref_channel_id"], name: "channel_member_ref_channel_id_idx", using: :btree
  add_index "channel_member", ["ref_user_id"], name: "channel_member_ref_user_id_idx", using: :btree

  create_table "channel_user", force: true do |t|
    t.integer "ref_user_id",    limit: 8
    t.integer "ref_channel_id", limit: 8
    t.boolean "default"
    t.string  "uqid",           limit: 32
  end

  add_index "channel_user", ["ref_user_id", "ref_channel_id"], name: "uniq_channel_user", unique: true, using: :btree

  create_table "chapter", force: true do |t|
    t.text     "name"
    t.integer  "ref_know_id",  limit: 8
    t.integer  "priority"
    t.datetime "last_update"
    t.text     "uqid"
    t.boolean  "is_destroyed"
  end

  add_index "chapter", ["ref_know_id"], name: "chapter_ref_know_id_idx", using: :btree

  create_table "classroom", force: true do |t|
    t.datetime "last_update"
    t.datetime "create_time"
    t.boolean  "lock_screen"
    t.boolean  "teacher_offline"
    t.integer  "ref_group_id",    limit: 8
    t.integer  "ref_target_id",   limit: 8
    t.integer  "ref_unit_id",     limit: 8
    t.text     "ref_target_type"
    t.integer  "ref_know_id",     limit: 8
    t.text     "dispatch_url"
    t.text     "hangouts_url"
  end

  add_index "classroom", ["ref_group_id"], name: "classroom_ref_group_id_idx", using: :btree
  add_index "classroom", ["ref_target_id"], name: "classroom_ref_target_id_idx", using: :btree
  add_index "classroom", ["ref_unit_id"], name: "classroom_ref_unit_id_idx", using: :btree

  create_table "classroom_member", force: true do |t|
    t.integer  "ref_user_id",      limit: 8
    t.integer  "ref_classroom_id", limit: 8
    t.datetime "join_time"
  end

  add_index "classroom_member", ["ref_classroom_id"], name: "classroom_member_ref_classroom_id_idx", using: :btree
  add_index "classroom_member", ["ref_user_id"], name: "classroom_member_ref_user_id_idx", using: :btree

  create_table "coach", force: true do |t|
    t.integer  "ref_user_id",     limit: 8
    t.integer  "ref_know_id",     limit: 8
    t.integer  "ref_coach_id",    limit: 8
    t.datetime "add_time"
    t.datetime "user_sign_time"
    t.datetime "coach_sign_time"
    t.integer  "submit_by",       limit: 8
    t.string   "result",          limit: 20
  end

  add_index "coach", ["ref_user_id", "ref_know_id", "ref_coach_id"], name: "uniq_coach", unique: true, using: :btree

  create_table "draft_chapter", force: true do |t|
    t.text     "name"
    t.integer  "ref_know_id",  limit: 8
    t.integer  "priority"
    t.datetime "last_update"
    t.text     "uqid"
    t.datetime "release_time"
  end

  add_index "draft_chapter", ["ref_know_id"], name: "draft_chapter_ref_know_id_idx", using: :btree

  create_table "draft_knowledge", force: true do |t|
    t.text     "name"
    t.text     "description"
    t.string   "uqid",                limit: 32
    t.decimal  "total_time"
    t.datetime "last_update"
    t.datetime "release_time"
    t.text     "logo"
    t.boolean  "is_public"
    t.text     "code"
    t.integer  "ref_organization_id", limit: 8
  end

  create_table "draft_knowledge_editor", force: true do |t|
    t.integer "ref_know_id", limit: 8
    t.integer "ref_user_id", limit: 8
    t.string  "uqid",        limit: 32
    t.integer "order"
    t.boolean "is_show"
    t.text    "role"
  end

  add_index "draft_knowledge_editor", ["ref_know_id", "ref_user_id"], name: "uniq_draft_knowledge_editor", unique: true, using: :btree
  add_index "draft_knowledge_editor", ["ref_know_id"], name: "draft_knowledge_editor_ref_know_id_idx", using: :btree
  add_index "draft_knowledge_editor", ["ref_user_id"], name: "draft_knowledge_editor_ref_user_id_idx", using: :btree

  create_table "draft_question", force: true do |t|
    t.integer  "ref_unit_id",  limit: 8
    t.integer  "q_no"
    t.text     "q_type"
    t.text     "content"
    t.text     "answer"
    t.text     "explain"
    t.text     "options"
    t.text     "explain_url"
    t.string   "uqid",         limit: 32
    t.datetime "release_time"
    t.text     "solution"
    t.decimal  "video_time"
    t.text     "content_ext"
  end

  add_index "draft_question", ["ref_unit_id"], name: "draft_question_ref_unit_id_idx", using: :btree

  create_table "draft_unit", force: true do |t|
    t.text     "name"
    t.integer  "ref_chapter_id",            limit: 8
    t.integer  "priority"
    t.text     "unit_type"
    t.text     "content_url"
    t.datetime "create_time"
    t.string   "uqid",                      limit: 32
    t.decimal  "content_time"
    t.text     "supplementary_description"
    t.datetime "last_update"
    t.datetime "release_time"
    t.boolean  "is_preview"
    t.text     "content"
    t.integer  "ref_know_id",               limit: 8
  end

  add_index "draft_unit", ["ref_chapter_id"], name: "draft_unit_ref_chapter_id_idx", using: :btree
  add_index "draft_unit", ["ref_know_id"], name: "draft_unit_ref_know_id_idx", using: :btree

  create_table "friend", force: true do |t|
    t.integer  "ref_from_user_id", limit: 8
    t.integer  "ref_to_user_id",   limit: 8
    t.text     "status"
    t.datetime "request_time"
    t.datetime "response_time"
    t.string   "uqid",             limit: 32
  end

  add_index "friend", ["ref_from_user_id"], name: "friend_ref_user_id_idx1", using: :btree
  add_index "friend", ["ref_to_user_id"], name: "friend_ref_user_id_idx2", using: :btree

  create_table "group", force: true do |t|
    t.text     "name"
    t.text     "description"
    t.datetime "last_update"
    t.string   "uqid",                limit: 32
    t.text     "logo"
    t.boolean  "is_public"
    t.text     "content"
    t.text     "code"
    t.boolean  "is_destroyed"
    t.text     "link"
    t.text     "file"
    t.integer  "ref_organization_id", limit: 8
  end

  create_table "group_activity", force: true do |t|
    t.string   "uqid",         limit: 32
    t.datetime "maturity"
    t.text     "description"
    t.text     "goal"
    t.integer  "ref_group_id", limit: 8
    t.text     "name"
    t.boolean  "is_show"
    t.integer  "priority"
    t.text     "tag"
    t.datetime "create_time"
    t.datetime "update_time"
  end

  add_index "group_activity", ["ref_group_id"], name: "group_activity_ref_group_id_idx", using: :btree

  create_table "group_behavior", force: true do |t|
    t.integer "ref_group_id", limit: 8
    t.text    "name"
    t.integer "points"
    t.integer "icon"
    t.text    "uqid"
  end

  add_index "group_behavior", ["ref_group_id"], name: "group_behavior_ref_group_id_idx", using: :btree

  create_table "group_knowledge", force: true do |t|
    t.integer  "ref_group_id", limit: 8
    t.integer  "ref_know_id",  limit: 8
    t.datetime "last_update"
    t.text     "approve_code"
    t.string   "uqid",         limit: 32
    t.integer  "priority"
    t.boolean  "is_show"
  end

  add_index "group_knowledge", ["ref_group_id", "ref_know_id"], name: "uniq_group_knowledge", unique: true, using: :btree
  add_index "group_knowledge", ["ref_group_id"], name: "group_knowledge_ref_group_id_idx", using: :btree
  add_index "group_knowledge", ["ref_know_id"], name: "group_knowledge_ref_know_id_idx", using: :btree

  create_table "group_member", force: true do |t|
    t.integer  "ref_user_id",    limit: 8
    t.integer  "ref_group_id",   limit: 8
    t.datetime "sign_time"
    t.text     "status"
    t.text     "role"
    t.integer  "order"
    t.datetime "last_view_time"
    t.string   "uqid",           limit: 32
    t.boolean  "notification"
    t.text     "ref_email"
    t.text     "first_name"
    t.text     "last_name"
  end

  add_index "group_member", ["ref_group_id"], name: "group_member_ref_group_id_idx", using: :btree
  add_index "group_member", ["ref_user_id", "ref_group_id"], name: "uniq_group_member", unique: true, using: :btree
  add_index "group_member", ["ref_user_id"], name: "group_member_ref_user_id_idx", using: :btree

  create_table "group_member_behavior", force: true do |t|
    t.integer  "ref_behavior_id", limit: 8
    t.integer  "ref_member_id",   limit: 8
    t.datetime "gained_time"
    t.text     "uqid"
    t.integer  "points"
    t.integer  "ref_group_id",    limit: 8
    t.integer  "ref_user_id",     limit: 8
  end

  add_index "group_member_behavior", ["ref_behavior_id"], name: "group_member_behavior_ref_behavior_id_idx", using: :btree
  add_index "group_member_behavior", ["ref_group_id"], name: "group_member_behavior_ref_group_id_idx", using: :btree
  add_index "group_member_behavior", ["ref_member_id"], name: "group_member_behavior_ref_member_id_idx", using: :btree

  create_table "group_message", force: true do |t|
    t.integer  "ref_group_id",   limit: 8
    t.integer  "ref_user_id",    limit: 8
    t.integer  "ref_message_id", limit: 8
    t.text     "content"
    t.datetime "publish_time"
    t.string   "uqid",           limit: 32
    t.boolean  "is_top"
    t.decimal  "note_time"
    t.integer  "ref_unit_id",    limit: 8
  end

  add_index "group_message", ["ref_group_id"], name: "group_message_ref_group_id_idx", using: :btree
  add_index "group_message", ["ref_message_id"], name: "group_message_ref_message_id_idx", using: :btree
  add_index "group_message", ["ref_user_id"], name: "group_message_ref_user_id_idx", using: :btree

  create_table "group_message_like", force: true do |t|
    t.integer "ref_user_id",    limit: 8
    t.integer "ref_message_id", limit: 8
  end

  add_index "group_message_like", ["ref_message_id"], name: "group_message_like_ref_message_id_idx", using: :btree
  add_index "group_message_like", ["ref_user_id"], name: "group_message_like_ref_user_id_idx", using: :btree

  create_table "knowledge", force: true do |t|
    t.text     "name"
    t.text     "description"
    t.string   "uqid",                limit: 32
    t.decimal  "total_time"
    t.datetime "last_update"
    t.boolean  "is_public"
    t.text     "code"
    t.text     "logo"
    t.boolean  "is_destroyed"
    t.integer  "ref_organization_id", limit: 8
  end

  create_table "konzesys_accounts", force: true do |t|
    t.integer  "ref_user_id", limit: 8
    t.text     "account"
    t.text     "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "map", force: true do |t|
    t.string   "uqid",        limit: 32
    t.text     "name"
    t.text     "description"
    t.datetime "last_update"
  end

  create_table "map_member", force: true do |t|
    t.integer  "ref_user_id", limit: 8
    t.integer  "ref_map_id",  limit: 8
    t.datetime "sign_time"
    t.text     "role"
    t.text     "status"
    t.integer  "order"
    t.string   "uqid",        limit: 32
  end

  add_index "map_member", ["ref_map_id"], name: "map_member_ref_map_id_idx", using: :btree
  add_index "map_member", ["ref_user_id"], name: "map_member_ref_user_id_idx", using: :btree

  create_table "map_node", force: true do |t|
    t.string  "uqid",         limit: 32
    t.text    "name"
    t.text    "description"
    t.text    "location"
    t.text    "relationship"
    t.integer "ref_map_id",   limit: 8
  end

  add_index "map_node", ["ref_map_id"], name: "map_node_ref_map_id_idx", using: :btree

  create_table "map_unit", force: true do |t|
    t.integer "ref_node_id", limit: 8
    t.integer "ref_unit_id", limit: 8
    t.integer "ref_map_id",  limit: 8
    t.string  "uqid",        limit: 32
  end

  add_index "map_unit", ["ref_map_id"], name: "map_unit_ref_map_id_idx", using: :btree
  add_index "map_unit", ["ref_node_id"], name: "map_unit_ref_node_id_idx", using: :btree
  add_index "map_unit", ["ref_unit_id"], name: "map_unit_ref_unit_id_idx", using: :btree

  create_table "message", force: true do |t|
    t.integer  "from",           limit: 8
    t.integer  "to",             limit: 8
    t.text     "subject"
    t.text     "content"
    t.integer  "ref_unit_id",    limit: 8
    t.integer  "ref_message_id", limit: 8
    t.datetime "send_time"
    t.datetime "view_time"
  end

  create_table "organization", force: true do |t|
    t.string "uqid",        limit: 32
    t.text   "name"
    t.text   "description"
    t.text   "domain"
  end

  create_table "organization_member", force: true do |t|
    t.integer  "ref_organization_id", limit: 8
    t.integer  "ref_user_id",         limit: 8
    t.text     "role"
    t.datetime "sign_time"
    t.text     "status"
    t.text     "uqid"
    t.text     "ref_email"
    t.text     "first_name"
    t.text     "last_name"
  end

  create_table "publisher", force: true do |t|
    t.text   "name"
    t.text   "description"
    t.text   "twitter"
    t.text   "facebook"
    t.text   "photo"
    t.text   "banner"
    t.text   "url"
    t.text   "website"
    t.string "uqid",        limit: 32
  end

  add_index "publisher", ["url"], name: "uniq_publisher", unique: true, using: :btree

  create_table "publisher_member", force: true do |t|
    t.integer "ref_user_id",      limit: 8
    t.integer "ref_publisher_id", limit: 8
    t.text    "description"
    t.date    "sign_time"
    t.text    "status"
    t.text    "role"
    t.string  "uqid",             limit: 32
  end

  add_index "publisher_member", ["ref_user_id", "ref_publisher_id"], name: "uniq_publisher_member", unique: true, using: :btree

  create_table "question", force: true do |t|
    t.integer "ref_unit_id",  limit: 8
    t.integer "q_no"
    t.text    "q_type"
    t.text    "content"
    t.text    "answer"
    t.text    "explain"
    t.text    "explain_url"
    t.string  "uqid",         limit: 32
    t.text    "options"
    t.text    "solution"
    t.boolean "is_destroyed"
    t.decimal "video_time"
    t.text    "content_ext"
  end

  add_index "question", ["ref_unit_id"], name: "question_ref_unit_id_idx", using: :btree

  create_table "reader", force: true do |t|
    t.integer  "ref_user_id",    limit: 8
    t.integer  "ref_know_id",    limit: 8
    t.text     "approve_code"
    t.datetime "last_update"
    t.boolean  "is_archived"
    t.integer  "rating"
    t.text     "hashtag"
    t.text     "category_uqid"
    t.datetime "subscribe_time"
  end

  add_index "reader", ["category_uqid"], name: "reader_category_uqid_idx", using: :btree
  add_index "reader", ["ref_know_id"], name: "reader_ref_know_id_idx", using: :btree
  add_index "reader", ["ref_user_id", "ref_know_id"], name: "uniq_reader", unique: true, using: :btree
  add_index "reader", ["ref_user_id"], name: "reader_ref_user_id_idx", using: :btree

  create_table "reader_subscriber", force: true do |t|
    t.string  "uqid",              limit: 32
    t.integer "ref_user_id",       limit: 8
    t.integer "ref_reader_id",     limit: 8
    t.integer "ref_subscriber_id", limit: 8
  end

  create_table "sessions", force: true do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", using: :btree
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

  create_table "study_result", force: true do |t|
    t.integer  "ref_know_id",   limit: 8
    t.integer  "ref_unit_id",   limit: 8
    t.integer  "ref_user_id",   limit: 8
    t.text     "content"
    t.datetime "learning_time"
  end

  add_index "study_result", ["ref_know_id"], name: "study_result_ref_know_id_idx", using: :btree
  add_index "study_result", ["ref_unit_id"], name: "study_result_ref_unit_id_idx", using: :btree
  add_index "study_result", ["ref_user_id"], name: "study_result_ref_user_id_idx", using: :btree

  create_table "sysconfigs", force: true do |t|
    t.string   "target",                null: false
    t.string   "name"
    t.text     "content"
    t.integer  "ref_admin_accounts_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "unit", force: true do |t|
    t.text     "name"
    t.integer  "ref_chapter_id",            limit: 8
    t.integer  "priority"
    t.text     "unit_type"
    t.text     "content_url"
    t.string   "uqid",                      limit: 32
    t.decimal  "content_time"
    t.text     "supplementary_description"
    t.datetime "last_update"
    t.boolean  "is_preview"
    t.text     "content"
    t.integer  "ref_know_id",               limit: 8
    t.boolean  "is_destroyed"
  end

  add_index "unit", ["ref_chapter_id"], name: "unit_ref_chapter_id_idx", using: :btree
  add_index "unit", ["ref_know_id"], name: "unit_ref_know_id_idx", using: :btree

  create_table "unit_feedback", force: true do |t|
    t.integer "ref_unit_id",  limit: 8
    t.integer "ref_user_id",  limit: 8
    t.integer "ref_group_id", limit: 8
    t.decimal "score"
    t.text    "comment"
    t.string  "uqid",         limit: 32
  end

  add_index "unit_feedback", ["ref_group_id"], name: "unit_feedback_ref_group_id_idx", using: :btree
  add_index "unit_feedback", ["ref_unit_id"], name: "unit_feedback_ref_unit_id_idx", using: :btree
  add_index "unit_feedback", ["ref_user_id"], name: "unit_feedback_ref_user_id_idx", using: :btree

  create_table "unit_status", force: true do |t|
    t.integer  "ref_user_id",    limit: 8
    t.integer  "ref_unit_id",    limit: 8
    t.integer  "status"
    t.decimal  "gained"
    t.decimal  "total"
    t.datetime "last_view_time"
    t.integer  "ref_know_id",    limit: 8
  end

  add_index "unit_status", ["ref_know_id"], name: "unit_status_ref_know_id_idx", using: :btree
  add_index "unit_status", ["ref_unit_id"], name: "unit_status_ref_unit_id_idx", using: :btree
  add_index "unit_status", ["ref_user_id"], name: "unit_status_ref_user_id_idx", using: :btree

  create_table "upload_files", force: true do |t|
    t.integer  "ref_user_id"
    t.text     "file_name"
    t.string   "uqid",        limit: 32
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "file_size"
    t.text     "file_ext"
    t.text     "file_type"
  end

  create_table "user", force: true do |t|
    t.text     "userid",                      null: false
    t.datetime "create_time"
    t.datetime "last_login_time"
    t.text     "first_name"
    t.text     "last_name"
    t.text     "password"
    t.text     "twitter"
    t.text     "facebook"
    t.text     "photo"
    t.text     "banner"
    t.text     "description"
    t.text     "website"
    t.string   "uqid",             limit: 32
    t.boolean  "nouser"
    t.text     "last_login_ip"
    t.text     "language"
    t.text     "account_type"
    t.datetime "expired_date"
    t.text     "last_geolocation"
  end

  add_index "user", ["userid"], name: "uniq_user", unique: true, using: :btree

  create_table "user_reader_category", force: true do |t|
    t.string  "uqid",        limit: 32
    t.text    "name"
    t.integer "ref_user_id", limit: 8
  end

  create_table "view_history", force: true do |t|
    t.integer  "ref_user_id",         limit: 8
    t.integer  "ref_unit_id",         limit: 8
    t.decimal  "last_second_watched"
    t.decimal  "seconds_watched"
    t.datetime "time_watched"
    t.integer  "ref_know_id",         limit: 8
  end

  add_index "view_history", ["ref_know_id"], name: "view_history_ref_know_id_idx", using: :btree
  add_index "view_history", ["ref_unit_id"], name: "view_history_ref_unit_id_idx", using: :btree
  add_index "view_history", ["ref_user_id"], name: "view_history_ref_user_id_idx", using: :btree

end
