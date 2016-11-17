class StudyResult < ActiveRecord::Base
    self.table_name = 'study_result'


    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id
    belongs_to :unit, :class_name => 'Unit', :foreign_key => :ref_unit_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

    # content string (0)
    # learning_time datetime
    # ref_know_id integer (8)
    # ref_unit_id integer (8)
    # ref_user_id integer (8)
end
