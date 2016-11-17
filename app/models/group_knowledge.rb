class GroupKnowledge < ActiveRecord::Base
    self.table_name = 'group_knowledge'


    belongs_to :group, :class_name => 'Group', :foreign_key => :ref_group_id
    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id

    # approve_code string (0)
    # is_show boolean
    # last_update datetime
    # priority integer
    # ref_group_id integer (8)
    # ref_know_id integer (8)
    # uqid string (32)
end
