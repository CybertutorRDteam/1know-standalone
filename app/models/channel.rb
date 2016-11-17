class Channel < ActiveRecord::Base
    self.table_name = 'channel'


    has_many :categories, -> { order "priority ASC" }, :class_name => 'Category', :foreign_key => :ref_channel_id
    has_many :knowledges, -> { order "priority ASC" }, :class_name => 'CategoryKnowledge', :foreign_key => :ref_channel_id

    # description string (0)
    # last_update datetime
    # logo string (0)
    # name string (0)
    # uqid string (32)
end