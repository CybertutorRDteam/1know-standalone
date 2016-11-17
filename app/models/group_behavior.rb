class GroupBehavior < ActiveRecord::Base
    self.table_name = 'group_behavior'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id

	# icon integer
	# name string (0)
	# points integer
	# ref_group_id integer (8)
	# uqid string (0)
end