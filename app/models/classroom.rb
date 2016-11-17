class Classroom < ActiveRecord::Base
    self.table_name = 'classroom'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id
    
    has_many :members, :class_name => 'ClassroomMember', :foreign_key => :ref_classroom_id

    # create_time datetime dispatch_url string (0)
    # hangouts_url string (0)
    # last_update datetime
    # lock_screen boolean
    # ref_group_id integer (8)
    # ref_know_id integer (8)
    # ref_target_id integer (8)
    # ref_target_type string (0)
    # ref_unit_id integer (8)
    # teacher_offline boolean
end