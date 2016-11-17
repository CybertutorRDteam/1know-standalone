class GroupMessage < ActiveRecord::Base
    self.table_name = 'group_message'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id 
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id
    belongs_to :unit, :class_name => 'Unit', :foreign_key => :ref_unit_id
    belongs_to :parent_message, :class_name => 'GroupMessage', :foreign_key => :ref_message_id

    has_many :messages, :class_name => 'GroupMessage', :foreign_key => :ref_message_id

	# content string (0)
	# is_top boolean
	# note_time decimal
	# publish_time datetime
	# ref_group_id integer (8)
	# ref_message_id integer (8)
	# ref_unit_id integer (8)
	# ref_user_id integer (8)
	# uqid string (32)
end
