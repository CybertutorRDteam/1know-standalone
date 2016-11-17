class User < ActiveRecord::Base
    self.table_name = 'user'


    has_many :readers, :class_name => 'Reader', :foreign_key => :ref_user_id

	# account_type string (0)
	# banner string (0)
	# create_time datetime
	# description string (0)
	# expired_date datetime
	# facebook string (0)
	# first_name string (0)
	# language string (0)
	# last_geolocation string (0)
	# last_login_ip string (0)
	# last_login_time datetime
	# last_name string (0)
	# nouser boolean
	# password string (0)
	# photo string (0)
	# twitter string (0)
	# uqid string (32)
	# userid string (0)
	# website string (0)
end
