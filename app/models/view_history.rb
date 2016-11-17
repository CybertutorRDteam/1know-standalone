class ViewHistory < ActiveRecord::Base
    self.table_name = 'view_history'


    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id
    belongs_to :unit, :class_name => 'Unit', :foreign_key => :ref_unit_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

    # last_second_watched decimal
    # ref_know_id integer (8)
    # ref_unit_id integer (8)
    # ref_user_id integer (8)
    # seconds_watched decimal
    # time_watched datetime
end
