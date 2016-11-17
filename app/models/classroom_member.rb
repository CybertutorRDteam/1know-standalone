class ClassroomMember < ActiveRecord::Base
    self.table_name = 'classroom_member'

    belongs_to :classroom, :class_name => 'Classroom', :foreign_key => :ref_classroom_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

    # join_time datetime
    # ref_classroom_id integer (8)
    # ref_user_id integer (8)
end