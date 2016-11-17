class UnitFeedback < ActiveRecord::Base
    self.table_name = 'unit_feedback'


    belongs_to :unit, :class_name => 'Unit', :foreign_key => :ref_unit_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id
    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id

	# comment string (0)
	# ref_group_id integer (8)
	# ref_unit_id integer (8)
	# ref_user_id integer (8)
	# score decimal
	# uqid string (32)
end
