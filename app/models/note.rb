class Note < ActiveRecord::Base
    self.table_name = 'bookmark'


    belongs_to :unit, :class_name => 'Unit', :foreign_key => :ref_unit_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

    # content string (0)
    # content_color string (0)
    # content_type string (0)
    # is_public boolean
    # ref_unit_id integer (8)
    # ref_user_id integer (8)
    # update_time datetime
    # uqid string (32)
    # video_time decimal
end
