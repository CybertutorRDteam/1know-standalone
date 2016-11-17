class UserReaderCategory < ActiveRecord::Base
    self.table_name = 'user_reader_category'


    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

    # name string (0)
    # ref_user_id integer (8)
    # uqid string (32)
end