class ReaderSubscriber < ActiveRecord::Base
    self.table_name = 'reader_subscriber'


    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id
    belongs_to :reader, :class_name => 'Reader', :foreign_key => :ref_reader_id
    belongs_to :subscriber, :class_name => 'User', :foreign_key => :ref_subscriber_id

	# ref_reader_id integer (8)
	# ref_subscriber_id integer (8)
	# ref_user_id integer (8)
	# uqid string (32)
end