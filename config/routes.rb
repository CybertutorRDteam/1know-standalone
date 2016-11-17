Oneknow::Application.routes.draw do
  root 'main#index'

  match  'watch' => 'main#watch', :via => [:get, :post]
  get    'version' => 'application#version'
  get    'discover/:target', to: redirect('/#!/discover/%{target}')
  get    'discover/:kind/:target', to: redirect('/#!/discover/%{kind}/%{target}')
  get    'learn/:target', to: redirect('/#!/learn/%{target}')
  get    'learn/:kind/:target', to: redirect('/#!/learn/%{kind}/%{target}')
  get    'join/:target', to: redirect('/#!/join/%{target}')
  get    'join/:kind/:target', to: redirect('/#!/join/%{kind}/%{target}')
  get    'create/:target', to: redirect('/#!/create/%{target}')
  get    'create/:kind/:target', to: redirect('/#!/create/%{kind}/%{target}')
  get    'embed/:target', to: redirect('/watch?k=%{target}')

  # landing page
  get    'knowledge/:uqid' => 'page#knowledge'
  get    'group/:uqid' => 'page#group'
  get    'channel/:uqid' => 'page#channel'
  get    'user/:uqid' => 'page#user'
  get    'package/:uqid' => 'page#package_knowledge'

  # admin page
  post   'admin/login' => 'admin_accounts#login'
  get    'admin/logout' => 'admin_accounts#logout'
  get    'admin/index' => 'admin_accounts#sys_index'
  get    'superadmin/index' => 'admin_accounts#super_index'
  get    'admin' => 'admin_accounts#index'

  # --------------- #
  # account service #
  # --------------- #
  match  'account/user' => 'account#user', :via => [:get]
  match  'account/login' => 'account#login', :via => [:get, :post]
  match  'account/logout' => 'account#logout', :via => [:get, :post]
  match  'account/switch' => 'account#switch', :via => [:get, :post]
  match  'account/guest' => 'account#guest', :via => [:get, :post]
  get    'account/setup' => 'account#setup'
  post   'account/setACode' => 'account#setACode'

  # --------------- #
  # chooser service #
  # --------------- #
  get    'chooser/account' => 'chooser#account'
  post   'chooser/upload_file' => 'chooser#upload_file'
  get    'chooser' => 'chooser#index'
  post   'chooser/set_konzesys_account' => 'chooser#set_konzesys_account'
  post   'chooser/parsevideo' => 'chooser#parse_video'
  constraints(type: /video|doc|image/, uqid: /\w{8}/) do
    get ':type/:uqid', to: 'chooser#get_file'
  end
  constraints(type: /doc|image/ ) do
    get ':type/:uqid', to: 'chooser#get_file',constraints: { uqid: /\w{12}/ }
  end

  # ------------- #
  # oauth service #
  # ------------- #
  match  'main/callback' => 'main#callback', :via => [:get, :post]
  match  'oauth/index', to: redirect('/oauth/callback'), :via => [:get, :post]
  match  'oauth/callback' => 'oauth#callback', :via => [:get, :post]
  match  'oauth/ischool' => 'oauth#ischool', :via => [:get, :post]
  match  'oauth/chooser' => 'oauth#chooser', :via => [:get, :post]

  # --------------- #
  # private service #
  # --------------- #
  namespace :private do

    # -------------
    # utility
    # -------------

    match  'utility/parseURL' => 'utility#parse_url', :via => [:get, :post]
    get    'utility/cacheImage' => 'utility#cache_image'
    post   'utility/syncFile' => 'utility#sync_file'
    post   'utility/sendMail' => 'utility#send_mail'

    # -------------
    # management
    # -------------
    get    'background/user' => 'background#user'
    get    'background/knowledge' => 'background#knowledge'
    get    'background/group' => 'background#group'
    get    'background/channel' => 'background#channel'

    # -------------
    # personal
    # -------------
    get    'personal/profile' => 'personal#get_profile'
    put    'personal/profile' => 'personal#set_profile'
    put    'personal/password' => 'personal#set_password'

    # -------------
    # discovery
    # -------------
    get    'discovery/channels' => 'discovery#list_channel'
    get    'discovery/channels/:channelUqid' => 'discovery#channel'
    post   'discovery/channels/:channelUqid/subscribe' => 'discovery#subscribe_channel'
    delete 'discovery/channels/:channelUqid/unsubscribe' => 'discovery#unsubscribe_channel'
    get    'discovery/channels/:channelUqid/categories/:itemUqid' => 'discovery#channel_category'
    get    'discovery/channels/:channelUqid/knowledges' => 'discovery#channel_knowledge'
    get    'discovery/knowledges' => 'discovery#knowledge'
    get    'discovery/knowledges/:itemUqid/units' => 'discovery#list_unit'

    # -------------
    # learning
    # -------------

    get    'learning/:type/:itemUqid/history' => 'learning#query_study_history'
    get    'learning/groups' => 'learning#list_group'

    # 活動
    get    'learning/activities' => 'learning#list_activity'
    get    'learning/activities/:activityUqid' => 'learning#list_activity'
    get    'learning/activities/:activityUqid/units' => 'learning#list_activity_unit'

    # 知識分類
    get    'learning/categories' => 'learning#list_category'
    post   'learning/categories' => 'learning#create_category'
    put    'learning/categories/:itemUqid' => 'learning#update_category'
    delete 'learning/categories/:itemUqid' => 'learning#delete_category'

    # 學習筆記
    get    'learning/notes' => 'learning#list_note'
    get    'learning/notes/:itemUqid' => 'learning#list_note'
    put    'learning/notes/:itemUqid' => 'learning#update_unit_note'
    delete 'learning/notes/:itemUqid' => 'learning#delete_unit_note'

    # 學習單元
    get    'learning/units' => 'learning#list_unit'
    get    'learning/units/:unitUqid' => 'learning#list_unit'
    get    'learning/units/:unitUqid/notes' => 'learning#list_note'
    post   'learning/units/:unitUqid/notes' => 'learning#add_unit_note'
    get    'learning/units/:unitUqid/quizzes' => 'learning#list_quiz'
    put    'learning/units/:unitUqid/status' => 'learning#set_unit_status'
    post   'learning/units/:unitUqid/studyHistory' => 'learning#add_study_history'
    put    'learning/units/:unitUqid/studyResult' => 'learning#update_study_result'

    get    'learning' => 'learning#list_knowledge'
    get    'learning/knowledges' => 'learning#list_knowledge_size'
    get    'learning/:knowUqid' => 'learning#list_knowledge'
    post   'learning/:knowUqid/subscribe' => 'learning#subscribe_knowledge'
    delete 'learning/:knowUqid/unsubscribe' => 'learning#unsubscribe_knowledge'
    put    'learning/:knowUqid/rating' => 'learning#rate_knowledge'
    get    'learning/:knowUqid/units' => 'learning#list_unit'
    get    'learning/:knowUqid/notes' => 'learning#list_note'
    put    'learning/:knowUqid/category' => 'learning#set_category'
    get    'learning/:knowUqid/subscribers' => 'learning#list_subscriber'
    post   'learning/:knowUqid/subscribers' => 'learning#add_subscriber'
    delete 'learning/:knowUqid/subscribers/:itemUqid' => 'learning#remove_subscriber'
    get    'learning/:knowUqid/exportNotes' => 'learning#export_note'

    # -------------
    # classroom
    # -------------

    # 同步教學教師功能
    get    'classroom/:groupUqid/behaviors' => 'join#list_behavior'
    post   'classroom/:groupUqid/teach' => 'classroom#start_classroom'
    put    'classroom/:groupUqid/teach' => 'classroom#set_classroom_status'
    get    'classroom/:groupUqid/teach' => 'classroom#get_classroom_status'
    get    'classroom/:groupUqid/teach/student' => 'classroom#get_student'
    put    'classroom/:groupUqid/teach/teacherStatus' => 'classroom#response_teacher'
    get    'classroom/:groupUqid/teach/studyResult' => 'classroom#get_study_result'
    put    'classroom/:groupUqid/teach/lockScreen' => 'classroom#lock_screen'
    post   'classroom/:groupUqid/teach/dispatchUrl' => 'classroom#dispatch_url'
    post   'classroom/:groupUqid/teach/memberBehaviors' => 'classroom#add_teach_member_behavior'

    # 同步教學學生功能
    get    'classroom/:groupUqid/study' => 'classroom#get_study_status'
    put    'classroom/:groupUqid/study/studyResult' => 'classroom#update_study_result'

    # -------------
    # group
    # -------------

    # 系統中所有群組
    get    'join/all' => 'join#list_all_group'

    # 群組中個人資訊
    get    'join/:groupUqid/selfBehaviors' => 'join#list_self_behavior'
    get    'join/:groupUqid/selfKnowledges' => 'join#self_knowledge'

    # 成員行為表現
    get    'join/:groupUqid/memberBehaviors/:itemUqid' => 'join#list_member_behavior'
    post   'join/:groupUqid/memberBehaviors' => 'join#add_member_behavior'
    delete 'join/:groupUqid/memberBehaviors/:itemUqid' => 'join#delete_member_behavior'

    # 群組中的行為表現項目
    get    'join/:groupUqid/behaviors' => 'join#list_behavior'
    post   'join/:groupUqid/behaviors' => 'join#add_behavior'
    put    'join/:groupUqid/behaviors/:itemUqid' => 'join#update_behavior'
    delete 'join/:groupUqid/behaviors/:itemUqid' => 'join#delete_behavior'

    # 群組中的訊息
    get    'join/:groupUqid/messages' => 'join#list_message'
    post   'join/:groupUqid/messages' => 'join#add_message'
    delete 'join/:groupUqid/messages/:messageUqid' => 'join#delete_message'
    post   'join/:groupUqid/messages/:messageUqid/like' => 'join#like_message'
    put    'join/:groupUqid/messages/:messageUqid/top' => 'join#top_message'

    # 群組中的知識
    get    'join/:groupUqid/knowledges' => 'join#list_knowledge'
    post   'join/:groupUqid/knowledges' => 'join#add_knowledge'
    put    'join/:groupUqid/knowledges/:itemUqid' => 'join#update_knowledge'
    delete 'join/:groupUqid/knowledges/:itemUqid' => 'join#remove_knowledge'
    post   'join/:groupUqid/knowledges/import' => 'join#import_knowledge'
    get    'join/:groupUqid/knowledges/:itemUqid/units' => 'join#list_knowledge_unit'

    # 群組中的活動
    get    'join/:groupUqid/activities' => 'join#list_activity'
    post   'join/:groupUqid/activities' => 'join#add_activity'
    put    'join/:groupUqid/activities/:itemUqid' => 'join#update_activity'
    delete 'join/:groupUqid/activities/:itemUqid' => 'join#delete_activity'
    post   'join/:groupUqid/activities/import' => 'join#import_activity'

    # 群組中的檔案
    get    'join/:groupUqid/files' => 'join#list_file'
    put    'join/:groupUqid/files' => 'join#update_file'

    # 群組中的連結
    get    'join/:groupUqid/links' => 'join#list_link'
    put    'join/:groupUqid/links' => 'join#update_link'

    # 群組中的成員
    get    'join/:groupUqid/members' => 'join#list_member'
    post   'join/:groupUqid/members' => 'join#add_member'
    put    'join/:groupUqid/members/:itemUqid' => 'join#update_member'
    delete 'join/:groupUqid/members/:itemUqid' => 'join#remove_member'
    post   'join/:groupUqid/members/import' => 'join#import_member'
    get    'join/:groupUqid/members/export' => 'join#export_member'

    # 群組中單元回饋
    post   'join/:groupUqid/members/:memberUqid/feedback' => 'join#add_member_unit_feedback'
    put    'join/:groupUqid/members/:memberUqid/feedback/:itemUqid' => 'join#update_member_unit_feedback'
    delete 'join/:groupUqid/members/:memberUqid/feedback/:itemUqid' => 'join#delete_member_unit_feedback'

    # 群組中的活動
    get    'join/:groupUqid/activities/:itemUqid/statistics' => 'join#get_activity_statistics'
    get    'join/:groupUqid/activities/:activityUqid/unit/:itemUqid' => 'join#get_activity_unit_result'
    get    'join/:groupUqid/activities/:activityUqid/unit/:itemUqid/export' => 'join#get_activity_unit_result_export'
    get    'join/:groupUqid/activities/:activityUqid/unit/:itemUqid/note' => 'join#get_activity_unit_member_note'
    get    'join/:groupUqid/activities/:activityUqid/unit/:itemUqid/hsitory' => 'join#get_activity_unit_member_history'
    get    'join/:groupUqid/activities/:activityUqid/unit/:itemUqid/member/:memberUqid' => 'join#get_activity_unit_member_result'

    # 群組功能
    get    'join' => 'join#list_group'
    post   'join' => 'join#create_group'
    get    'join/:groupUqid' => 'join#list_group'
    put    'join/:groupUqid' => 'join#update_group'
    delete 'join/:groupUqid' => 'join#delete_group'
    put    'join/:groupUqid/resetCode' => 'join#reset_group_code'
    post   'join/:groupUqid/requestToJoin' => 'join#request_to_join'
    post   'join/:groupCode/joinGroup' => 'join#join_group'
    post   'join/:groupUqid/leaveGroup' => 'join#leave_group'

    # -------------
    # creation
    # -------------

    # 知識
    get    'creation/knowledges' => 'creation#list_knowledge'
    post   'creation/knowledges' => 'creation#create_knowledge'
    get    'creation/knowledges/:itemUqid' => 'creation#list_knowledge'
    put    'creation/knowledges/:itemUqid' => 'creation#update_knowledge'
    delete 'creation/knowledges/:itemUqid' => 'creation#delete_knowledge'
    put    'creation/knowledges/:itemUqid/resetCode' => 'creation#reset_knowledge_code'
    post   'creation/knowledges/:itemUqid/publish' => 'creation#publish_knowledge'
    get    'creation/knowledges/:knowUqid/editors' => 'creation#list_knowledge_editor'
    get    'creation/knowledges/:knowUqid/chapters' => 'creation#list_chapter'
    get    'creation/knowledges/:knowUqid/units' => 'creation#list_unit'

    # 知識 - 編輯者
    post   'creation/knowledges/:knowUqid/editors' => 'creation#add_knowledge_editor'
    get    'creation/knowledges/:knowUqid/editors/:itemUqid' => 'creation#list_knowledge_editor'
    put    'creation/knowledges/:knowUqid/editors/:itemUqid' => 'creation#update_knowledge_editor'
    delete 'creation/knowledges/:knowUqid/editors/:itemUqid' => 'creation#remove_knowledge_editor'

    # 知識 - 章節
    post   'creation/knowledges/:knowUqid/chapters' => 'creation#create_chapter'
    get    'creation/knowledges/:knowUqid/chapters/:itemUqid' => 'creation#list_chapter'
    put    'creation/knowledges/:knowUqid/chapters/:itemUqid' => 'creation#update_chapter'
    delete 'creation/knowledges/:knowUqid/chapters/:itemUqid' => 'creation#delete_chapter'
    post   'creation/knowledges/:knowUqid/chapters/:itemUqid/cloneUnits' => 'creation#clone_unit'
    post   'creation/knowledges/:knowUqid/chapters/:itemUqid/removeUnits' => 'creation#remove_unit'

    # 知識 - 單元
    post   'creation/knowledges/:knowUqid/chapters/:chapterUqid/units' => 'creation#create_unit'
    get    'creation/knowledges/:knowUqid/chapters/:chapterUqid/units' => 'creation#list_unit'
    get    'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:itemUqid' => 'creation#list_unit'
    put    'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:itemUqid' => 'creation#update_unit'
    delete 'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:itemUqid' => 'creation#delete_unit'

    # 知識 - 測驗
    post   'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:unitUqid/quizzes' => 'creation#create_quiz'
    get    'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:unitUqid/quizzes' => 'creation#list_quiz'
    get    'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:unitUqid/quizzes/:itemUqid' => 'creation#list_quiz'
    put    'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:unitUqid/quizzes/:itemUqid' => 'creation#update_quiz'
    delete 'creation/knowledges/:knowUqid/chapters/:chapterUqid/units/:unitUqid/quizzes/:itemUqid' => 'creation#delete_quiz'

    # 頻道
    get    'creation/channels' => 'creation#list_channel'
    post   'creation/channels' => 'creation#create_channel'
    get    'creation/channels/:itemUqid' => 'creation#list_channel'
    put    'creation/channels/:itemUqid' => 'creation#update_channel'
    delete 'creation/channels/:itemUqid' => 'creation#delete_channel'

    # 頻道 - 成員
    get    'creation/channels/:channelUqid/members' => 'creation#list_channel_member'
    post   'creation/channels/:channelUqid/members' => 'creation#add_channel_member'
    get    'creation/channels/:channelUqid/members/:itemUqid' => 'creation#list_channel_member'
    put    'creation/channels/:channelUqid/members/:itemUqid' => 'creation#update_channel_member'
    delete 'creation/channels/:channelUqid/members/:itemUqid' => 'creation#remove_channel_member'

    # 頻道 - 類別
    post   'creation/channels/:channelUqid/categories' => 'creation#create_category'
    get    'creation/channels/:channelUqid/categories/:itemUqid' => 'creation#list_category'
    put    'creation/channels/:channelUqid/categories/:itemUqid' => 'creation#update_category'
    delete 'creation/channels/:channelUqid/categories/:itemUqid' => 'creation#delete_category'

    # 頻道 - 知識
    post   'creation/channels/:channelUqid/categories/:categoryUqid/knowledges' => 'creation#add_category_knowledge'
    put    'creation/channels/:channelUqid/categories/:categoryUqid/knowledges/:itemUqid' => 'creation#update_category_knowledge'
    delete 'creation/channels/:channelUqid/categories/:categoryUqid/knowledges/:itemUqid' => 'creation#remove_category_knowledge'


    # -------------
    # Super 管理者
    # -------------

    # 啟動碼
    get    'super/changeCode' => 'superadmin#change_code'

    # 管理者
    get    'super/accounts' => 'superadmin#get_accounts'
    post   'super/account' => 'superadmin#create_account'
    put    'super/account/:id' => 'superadmin#set_account'
    delete 'super/account/:id' => 'superadmin#destroy_accounts'

    # 系統配置
    get    'super/sysConfig' => 'superadmin#get_sys_config'
    post   'super/sysConfig' => 'superadmin#set_sys_config'

    # -------------
    # Sys 管理者
    # -------------

    # 使用許可
    get    'sys/permission/permissions' => 'sysadmin#list_permissions'
    get    'sys/permission/changeCode' => 'sysadmin#list_permission_changecode'
    get    'sys/permission/export/:pname' => 'sysadmin#view_permission'
    post   'sys/permission/upload_permission' => 'sysadmin#upload_permission'
    post   'sys/permission/create_code' => 'sysadmin#create_permission_code'
    post   'sys/permission/search_code' => 'sysadmin#search_permission_code'
    post   'sys/permission/reset/:id' => 'sysadmin#reset_permission_code'


    # 系統配置
    get    'sys/sysConfig' => 'sysadmin#get_sys_config'
    post   'sys/sysConfig' => 'sysadmin#set_sys_config'

    # -------------
    # Qiniu 測試
    # -------------
    # Qiniu
    get    'qiniu/uptoken/:type/:bucket/:filename' => 'qiniu#get_uptoken'
    post   'qiniu/notify' => 'qiniu#notify'
    get    'qiniu/management/:type/:bucket/:marker' => 'qiniu#management'
    get    'qiniu/buckets' => 'qiniu#buckets'
  end
end
