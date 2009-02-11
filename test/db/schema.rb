ActiveRecord::Schema.define(:version => 0) do
  create_table "users", :force => true do |t|
    t.string   "email",                     :limit => 120, :default => "",    :null => false
    t.string   "hashed_password",           :limit => 40,  :default => "",    :null => false
    t.string   "name",                      :limit => 30,  :default => ""
    t.string   "slug",                      :limit => 30,  :default => ""
    t.string   "gender",                    :limit => 1
    t.string   "salt"
    t.boolean  "is_activated",                             :default => false, :null => false
    t.string   "activation_code",           :limit => 40
    t.datetime "activated_on"
    t.string   "autologin_token",           :limit => 40
    t.datetime "autologin_expires"
    t.boolean  "is_blocked",                               :default => false, :null => false
    t.string   "new_email",                 :limit => 120
    t.string   "new_email_activation_code", :limit => 40
    t.integer  "login_count",                              :default => 0,     :null => false
    t.string   "current_ip",                :limit => 20
    t.string   "last_ip",                   :limit => 20
    t.string   "last_failed_ip",            :limit => 20
    t.datetime "current_logged_on"
    t.datetime "last_logged_on"
    t.datetime "last_failed_logged_on"
    t.datetime "created_on"
    t.datetime "updated_on"
  end

  create_table "roles", :force => true do |t|
    t.string "name", :limit => 30, :default => "", :null => false
    t.string "slug", :limit => 30, :default => "", :null => false
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer "role_id", :null => false
    t.integer "user_id", :null => false
  end

  # STUB simply_settings plugin table here so we can test the plugin like it was installed
  create_table "options", :force => true do |t|
    t.string   "name",        :limit => 30, :default => "", :null => false
    t.string   "value",                     :default => "", :null => false
    t.string   "description",               :default => "", :null => false
    t.datetime "created_on"
    t.datetime "updated_on"
  end

end
