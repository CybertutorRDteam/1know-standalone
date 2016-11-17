class GroupMemberBehavior < ActiveRecord::Base
    self.table_name = 'group_member_behavior'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id
    belongs_to :member, :class_name => 'GroupMember', :foreign_key => :ref_member_id
    belongs_to :behavior, :class_name => 'GroupBehavior', :foreign_key => :ref_behavior_id

    # gained_time datetime
    # points integer
    # ref_behavior_id integer (8)
    # ref_group_id integer (8)
    # ref_member_id integer (8)
    # ref_user_id integer (8)
    # uqid string (0)
end