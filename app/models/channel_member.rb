class ChannelMember < ActiveRecord::Base
    self.table_name = 'channel_member'


    belongs_to :channel, :class_name => 'Channel', :foreign_key => :ref_channel_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

	# order integer
	# ref_channel_id integer (8)
	# ref_user_id integer (8)
	# role string (0)
	# sign_time datetime
	# status string (0)
	# uqid string (0)
end