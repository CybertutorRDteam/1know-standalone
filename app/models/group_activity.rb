class GroupActivity < ActiveRecord::Base
    self.table_name = 'group_activity'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id

	# description string (0)
	# goal string (0)
	# is_show boolean
	# maturity datetime
	# name string (0)
	# priority integer
	# ref_group_id integer (8)
	# tag string (0)
	# uqid string (32)
end
