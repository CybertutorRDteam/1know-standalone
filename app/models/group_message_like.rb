class GroupMessageLike < ActiveRecord::Base
    self.table_name = 'group_message_like'


    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id
    belongs_to :message, :class_name => 'GroupMessage', :foreign_key => :ref_message_id

    # ref_message_id integer (8)
    # ref_user_id integer (8)
end