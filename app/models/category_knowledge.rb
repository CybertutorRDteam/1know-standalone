class CategoryKnowledge < ActiveRecord::Base
    self.table_name = 'category_knowledge'


    belongs_to :channel, :class_name => 'Channel', :foreign_key => :ref_channel_id
    belongs_to :category, :class_name => 'Category', :foreign_key => :ref_category_id
    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id

    # priority integer
    # ref_category_id integer (8)
    # ref_channel_id integer (8)
    # ref_know_id integer (8)
    # uqid string (32)
	# url string (0)
end
