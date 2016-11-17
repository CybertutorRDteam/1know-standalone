class GroupMember < ActiveRecord::Base
    self.table_name = 'group_member'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id 
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

	# first_name string (0)
	# last_name string (0)
	# last_view_time datetime
	# notification boolean
	# order integer
	# ref_email string (0)
	# ref_group_id integer (8)
	# ref_user_id integer (8)
	# role string (0)
	# sign_time datetime
	# status string (0)
	# uqid string (32)
end
