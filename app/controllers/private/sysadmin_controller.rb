class Private::SysadminController  < ApplicationController
	before_filter :require_login_adminaccount

	def require_login_adminaccount
		if (session['role'] != "superadmin" && session['role'] != "sysadmin" )
			render :json => { error: "We're sorry, but something went wrong. [role]" }
		end
	end

	def list_permissions
		#show upload permission ui.
		#1. get permissions from db
		#2. open permission file
		#3. get permission content
		#4. join permission content and db content

		permissions = get_permissions_used_count()
		permissions.each do |item|
			filename = item.permission_name + '.cbp'
			begin
				file_content = File.read("public/permissions/#{filename}")
				#以特定分隔符號取得合約內容及簽章
				string_pattern = "[[[---]]]"
				index = file_content.index(string_pattern)
				puts index
				if (index.nil?)
					item.error_msg = '使用許可內容無法解析'
				else
					content = file_content.slice(0, index)
					#puts content

					if (content.nil?)
						item.error_msg = '使用許可內容不正確，解析失敗'
					else
						data = JSON.parse content
						contract_no = data["contract_no"]
						for elt in data["content"]
							case elt["role"]
								when "tea"
									item.teacher_count = elt["amount"]
									item.teacher_duration = elt["duration"]
								when "stu"
									item.student_count = elt["amount"]
									item.student_duration = elt["duration"]
							end
						end
						# puts item
					end
				end
			rescue
				nil
			end
		end
		render :json => permissions
	end

	def list_import_permission
		require 'csv'
		permission_name = params[:pname] || ''

		importUsers = User
			.where('NOT EXISTS (SELECT NULL FROM activation_codes WHERE "user".id = activation_codes.ref_user_id)')
			.order('expired_date DESC', 'id')

		render :json => importUsers
	end

	def update_import_permission
		ids = params[:id]
		set = params[:setTo]
		days = params[:days]
		user = User.where(:id => ids)
		if !user.nil?
			user.each do |u|
				if set
					u.expired_date = (u.expired_date.nil??  days.days.from_now : u.expired_date + days.days)
				else
					u.expired_date = -1.days.from_now
				end
				u.save
			end
		end
		render :json => { success: "Well done!" }
	end

	def view_permission
		require 'csv'
		permission_name = params[:pname] || ''

		account_codes = ActivationCode
			.joins('LEFT JOIN "user" ON "user".id = activation_codes.ref_user_id')
			.where( :permission_name => params[:pname] )
			.select('code, role, "user".userid, activation_time at time zone \'UTC\' as activation_time, duration')
			.order("ref_user_id DESC", "code")

		# send_data account_codes.to_csv(col_sep: "\t")
		respond_to do |format|
			format.json { render :json => account_codes }
			format.csv { send_data account_codes.to_csv }
			# format.csv { send_data account_codes.to_csv, :filename => "#{permission_name}.csv" }
			format.xls {
				@account_codes = account_codes
				stream = render_to_string( :template => "permission/view" )
				send_data stream
			}
		end
	end

	def upload_permission
		require 'openssl'
		require 'json'
		require 'securerandom'
		#1. save to disk
		#2. read and parse permission content
		#3. check if the permission is valid (ever used ?)
		#4. show permission content

		#save to disk
		uploaded_io = params[:inputFile]
		begin
			filename = uploaded_io.original_filename
			File.open(Rails.root.join('public', 'permissions', filename), 'wb') do |file|
				file.write(uploaded_io.read)
			end
		rescue
			render :json => { error: "無法讀取檔案" } and return
		end

		#read and parse permission content
		file_content = File.read("public/permissions/#{filename}")
		# puts file_content

		#以特定分隔符號取得合約內容及簽章
		string_pattern = "[[[---]]]"
		index = file_content.index(string_pattern)
		#puts index
		if (index.nil?)
			render :json => { error: "使用許可內容無法解析" } and return
		else
			content = file_content.slice(0, index)
			#puts content

			if (content.nil?)
				render :json => { error: "使用許可內容不正確，解析失敗" } and return
			else
				data = JSON.parse content
				never_used = is_permission_valid(File.basename(filename, ".cbp"))
				if (!never_used)
					# puts 'permission already exists'
					render :json => { error: "使用許可已匯入，不可重複匯入" } and return
				else
					#show permission content
					# {
					#	 "contract_no": "00011",
					#	 "content": [{
					#		 "role": "tea",
					#		 "amount": "100",
					#		 "duration": "30"
					#	 }, {
					#		 "role": "stu",
					#		 "amount": "500",
					#		 "duration": "30"
					#	 }]
					# }
					contract_no = data["contract_no"]
					for elt in data["content"]
						case elt["role"]
						when "tea"
							teacher_count = elt["amount"]
							teaacher_duration = elt["duration"]
						when "stu"
							student_count = elt["amount"]
							student_duration = elt["duration"]
						end
					end
				end
			end
		end
		render :json => {
			filename: filename,
			never_used: never_used,
			contract_no: contract_no,
			teacher_count: teacher_count,
			teaacher_duration: teaacher_duration,
			student_count: student_count,
			student_duration: student_duration
		}
	end

	def create_permission_code
		#1. read and parse permission content
		#2. read public key
		#3. validate the signature
		#4. create codes

		#read and parse permission content
		# filename = 'fsjh_00011.cbp';
		filename = params[:filename]
		file_content = File.read("public/permissions/#{filename}")
		# puts file_content

		#以特定分隔符號取得合約內容及簽章
		string_pattern = "[[[---]]]"
		index = file_content.index(string_pattern)
		#puts index
		if (index.nil?)
			render :json => { error: "使用許可內容無法解析" } and return
		else
			content = file_content.slice(0, index)
			#puts content
			signature_start_index = index + string_pattern.size
			signature = file_content.slice( signature_start_index ,  file_content.size - signature_start_index)
			#puts signature

			if (content.nil? || signature.nil?)
				render :json => { error: "使用許可內容不正確，解析失敗" } and return
			else
				data = JSON.parse content

				#load public, key.private? # => false
				key = OpenSSL::PKey::RSA.new File.read 'public/ca/cybertutor_public_key.pem'
				if (key.private?)
					render :json => { error: "公鑰錯誤" } and return
				else
					# validate signature
					digest = OpenSSL::Digest::SHA256.new
					if key.verify digest, signature, content
						# puts 'Valid signature'
						#check if the permission is valid (ever used ?)
						permission_name = File.basename(filename, ".cbp")
						if (!is_permission_valid(permission_name))
							render :json => { error: "使用許可已建立，不能重複建立" } and return
						else
							create_permission_codes(permission_name, data)
							render :json => { success: "Well done!", pname: permission_name }
						end
					else
						render :json => { error: "使用許可驗證失敗" } and return
					end
				end
			end
		end
	end

	def import_permission
		require 'openssl'
		require 'json'
		require 'securerandom'
		require 'csv'
		#1. save to disk
		#2. read and parse permission content
		#3. check if the permission is valid (ever used ?)
		#4. show permission content

		#save to disk
		uploaded_io = params[:importFile]
		def_duration = 365 # 1 year
		begin
			filename = uploaded_io.original_filename
			File.open(Rails.root.join('public', 'permissions', filename), 'wb') do |file|
				file.write(uploaded_io.read)
			end
		rescue
			render :json => { error: "無法讀取檔案" } and return
		end

		#read and parse permission content
		file_content = File.read("public/permissions/#{filename}")
		# puts file_content

		sys = Sysconfig.where({ :target => 'system', :name => 'default_login_max' }).first
		sys.nil?? max = 10 : max = sys.content.to_i
		users = User.count('userid')

		csv = CSV.parse(file_content)
		isOverload = (users + csv.size) > max
		importData = []
		denyData = []
		#puts index
		if(isOverload)
			render :json => {view: importData, deny: denyData, filename: filename, :over => isOverload} and return
		end
		if (csv.nil?)
			render :json => { error: "使用許可內容無法解析" } and return
		else
			csv.each do |row|
				if row[0] != '#' && 
					user = {acc: row[1], pwd: row[2], first_name: row[3], last_name: row[4], duration: row[5].to_i.nil?? def_duration : row[5]}
					item = User.where(['lower(userid) = ?', row[1].downcase + '@dr-cloud.net']).first
					item.nil?? importData.push(user) : denyData.push(user)
				end
			end
		end

		render :json => {view: importData, deny: denyData, filename: filename}
	end

	def create_permission_import
		require 'csv'
		#1. read and parse permission content
		#2. read public key
		#3. validate the signature
		#4. create codes

		#read and parse permission content
		# filename = 'fsjh_00011.cbp';
		filename = params[:filename]
		file_content = File.read("public/permissions/#{filename}")
		# puts file_content

		sysLang = Sysconfig.where({ :target => "system", :name => "default_language" }).first
		case sysLang.content
		when "en-us"
			lang = '{"title":"简体中文","type":"zh-cn"}'
		when "zh-cn"
			lang = '{"title":"简体中文","type":"zh-cn"}'
		when "zh-tw"
			lang = '{"title":"繁體中文","type":"zh-tw"}'
		else
			lang = '{"title":"简体中文","type":"zh-cn"}'
		end
		
		csv = CSV.parse(file_content)
		#puts index
		if (csv.nil?)
			render :json => { error: "使用許可內容無法解析" } and return
		else
			csv.each do |row|
				item = User.where(['lower(userid) = ?', row[1].downcase + '@dr-cloud.net']).first
				if row[0] != '#' and item.nil?
					item = User.new
					item.password = Digest::SHA2.hexdigest(row[2])
					item.uqid = UUID.new.generate[0..7]
					item.userid = (row[1].downcase + '@dr-cloud.net')
					item.first_name = row[3]
					item.last_name = row[4]
					item.banner = DEFAULT_USER_BANNER
					item.photo = DEFAULT_USER_PHOTO
					item.create_time = Time.now()
					item.account_type = 'plus'
					item.nouser = false
					item.language = lang
					item.expired_date = row[5].to_i.days.from_now
					item.save()
					set_image('user', { uqid: item.uqid, banner: item.banner, photo: item.photo })
				end
			end
		end

		render :json => { success: "Well done!", pname: filename }
	end

	def search_permission_code
		keyword = params[:code] || ""

		if (keyword == "") then
			account_codes = []
		else
			account_codes = ActivationCode
			.joins('LEFT JOIN "user" ON "user".id = activation_codes.ref_user_id')
			.where( ["code LIKE ?", "%#{keyword}%"] )
			.select('"user".userid, activation_codes.id, code, permission_name, role, activation_time at time zone \'UTC\' as activation_time, duration')
			.order('"user".userid desc', 'permission_name')
		end
		render :json => account_codes
	end

	def reset_permission_code
		# require 'csv'
		id = params[:id]
		if (is_unused_cancel_code(id))
			activationCode = ActivationCode.where( [ "id = ?", id ]).take
			if (!activationCode.nil?)
				old_code = activationCode["code"]
				new_code = ""
				ii = 0
				loop do
					ii += 1
					new_code = new_permission_code()
					activationCode.code = new_code
					activationCode.save! if activationCode.valid?
					break if !activationCode.errors[:code].any? or ii == 100
				end
				# activationCode.save
				# save to csv
				# CSV.open("public/cancel_code_log.csv", "a+") do |csv|
				#   csv << [old_code, new_code, activationCode.permission_name, activationCode.role, DateTime.now]
				# end
				# save to db
				CancelCodeLog.create({
					:old_code => old_code,
					:new_code => new_code,
					:permission_name => activationCode.permission_name,
					:role => activationCode.role,
				})
				render :json => { old_code: old_code, new_code: new_code }
			else
				render :json => { error: '編號不正確，不可註銷' }
			end
		else
			render :json => { error: '代碼已使用，不可註銷' }
		end
	end

	# 啟動碼異動清單
	def list_permission_changecode
		item = CancelCodeLog.order("updated_at DESC").all
		render :json => item
	end

	# 取得系統設置值
	def get_sys_config
		item = Sysconfig.where({ target: ["subsystem"] }).select("name, content")
		render :json => item
	end

	# 設定系統設置值
	def set_sys_config
		content = params[:content] || {}
		# 刪除舊資料
		sysconfig = Sysconfig.where({ target: ["subsystem"] })
		sysconfig.destroy_all

		# 重新建立
		# key = web_name, logo, copyright, service_email
		content.each do |key, value|
			sysconfig = Sysconfig.new({
				:target => 'subsystem',
				:name => key,
				:content => value.to_s,
				:ref_admin_accounts_id => session['admin_id']
			})
			sysconfig.save! if sysconfig.valid?
			case key
			when 'logo'
				set_image('config', { logo: value })
				APP_CONFIG['logo'] = (value != nil and value != '') ? "/images/logo.png" : ""
			else
				APP_CONFIG[key] = value
			end
		end
		render :json => { success: "Well done!" }
	end

	# 取得首頁設置值
	def get_frontpage_config
		item = Sysconfig.where({ target: ["frontpage", "frontpageObj"] }).select("name, content")
		render :json => item
	end

	# 設定首頁設置值
	def set_frontpage_config
		content = params[:content] || {}
		# 刪除舊資料
		sysconfig = Sysconfig.where({ :target => "frontpage" })
		sysconfig.destroy_all

		# 重新建立
		content.each do |key, value|
			sysconfig = Sysconfig.new({
				:target => 'frontpage',
				:name => key,
				:content => value.to_s,
				:ref_admin_accounts_id => session['admin_id']
			})
			sysconfig.save! if sysconfig.valid?
			case key
			when 'front_slider_activate','front_twobanner_activate','front_tagfunction_activate'
				APP_CONFIG[key] = (value.to_s == 'true')
			when 'front_tag_seq'
				FrontObject.update_all bTag: false
				begin
					obj = FrontObject.find(JSON.parse(value))
				rescue ActiveRecord::RecordNotFound => e
					obj = []
				end
				obj.each do |o|
					o.bTag = 1
					o.save
				end
				APP_CONFIG[key] = value
			else
				APP_CONFIG[key] = value
			end
		end
		render :json => { success: "Well done!" }
	end

	# 取得課程簡易資料
	def get_frontpage_knowledge
		echo = {}
		if(!params[:key].blank?)
			items = Knowledge.find_by_sql(
			"select k.id, k.uqid, k.name, k.logo 
			from knowledge k 
			where k.is_public = true and k.uqid = '#{params[:key]}' or k.name like '%#{params[:key]}%'")
		end
		echo[:data] = items.nil?? [] : items
		render :json => echo
	end

	# 取得集合資料
	def get_frontpage_objects
		objects = FrontObject.all.to_ary
		objects.each do |o|
			a = o.knowledges.split(',')
			o.knowledges = Knowledge.select('id,uqid,name,logo').where(:uqid => a).all.to_ary
		end
		render :json => objects
	end

	# 設定集合資料
	def set_frontpage_objects
		obj = params[:content]
		hex = SecureRandom.hex(16)
		if(obj[:id].nil?)
			item = FrontObject.new
		else
			item = FrontObject.where( :id => obj[:id] ).first
		end
		item.name = obj[:name]
		item.description = obj[:description].gsub('/<(.|script)*?>/', '') if not obj[:description].nil?
		ks = obj[:knowledges]
		item.knowledges = ks.nil?? [] : ks
		if (not obj[:bImg].nil?) && obj[:bImg].at(0..9) == 'data:image'
			if not item.bImg.blank?
				path = File.join(APP_CONFIG['upload_icons_url'], "/frontobject/", item.bImg)
				File.delete(path) if File.exist?(path) and not item.bImg.empty?
			end
			item.bImg = store_frontobject_pic(obj[:bImg], "bImg_" + hex)	
		end
		if (not obj[:sImg].nil?) && obj[:sImg].at(0..9) == 'data:image'
			if not item.sImg.blank?
				path = File.join(APP_CONFIG['upload_icons_url'], "/frontobject/", item.sImg)
				File.delete(path) if File.exist?(path) and not item.sImg.empty?
			end
			item.sImg = store_frontobject_pic(obj[:sImg], "sImg_" + hex)
		end
		item.bTag = obj[:useForTag]? 1:0
		item.save! if item.valid?
		render :json => item
	end

	private
	def new_permission_code()
		return SecureRandom.uuid[0, 8]
	end

	def is_permission_valid(permission_name)
		#檢查此使用許可未曾建置過，true: 可建立，false: 已建立
		rs = ActivationCode.where( :permission_name => permission_name ).take
		return (rs.nil?)
	end

	def create_permission_codes(permission_name, data)
		# contract_no = data["contract_no"]
		if (!data["content"].nil?)
			for h in data["content"]
				# 產生新的啟動碼，並於驗證code沒有重複，permission_name、role、duration不為空值時新增
				h["amount"].to_i.times do
					ii = 0
					loop do
						ii += 1
						activationCode = ActivationCode.new({
							:code => new_permission_code(),
							:permission_name => permission_name,
							:role => h["role"],
							:duration => h["duration"]
						})
						activationCode.save! if activationCode.valid?
						break if !activationCode.errors[:code].any? or ii == 100
					end
				end

				# 測試用
				# 1.to_i.times do
				#   ii = 0
				#   loop do
				#	 ii += 1
				#	 activationCode = ActivationCode.new({
				#	   :code => new_permission_code(),
				#	   :permission_name => permission_name,
				#	   :role => h["role"],
				#	   :duration => h["duration"]
				#	 })
				#	 activationCode.save! if activationCode.valid?
				#	 break if !activationCode.errors[:code].any? or ii == 100
				#   end
				# end
			end
		end
	end

	def get_permissions_used_count()
		return ActivationCode.find_by_sql(
			"select
				tb1.permission_name,
				case when tb2.used_count is null then 0 else tb2.used_count end,
				0 as teacher_count,
				0 as teacher_duration,
				0 as student_count,
				0 as student_duration
			from (
				select permission_name from activation_codes group by permission_name
			) tb1
			left join (
				select permission_name, count(*) as used_count
				from activation_codes
				where ref_user_id is not null
				group by permission_name
			)   tb2 on tb2.permission_name = tb1.permission_name
			order by tb1.permission_name desc"
		)
	end

	def is_unused_cancel_code(id)
		#檢查此啟動碼可否未使用，可以被註銷，true: 未使用，false：已使用
		rs = ActivationCode.where( :id => id, :ref_user_id => nil ).take
		return (!rs.nil?)
	end

	def store_frontobject_pic(base64Code, fname)
		upload_url = APP_CONFIG['upload_icons_url']
		if base64Code != nil and base64Code != '' and base64Code.split(';base64,').size == 2
			tmp = base64Code.split(';base64,')
			ext = tmp[0].split('/')[1]
			f_name = "#{fname}.#{ext}"
			Thread.new do
				mImg = Base64.decode64(tmp[1])
				realpath = File.join(upload_url, "/frontobject/", f_name)
				dirname = File.dirname(realpath)
				unless File.directory?(dirname)
					FileUtils.mkdir_p(dirname)
				end
				File.open(realpath, 'wb') {|file| file.write(mImg)} if not mImg.nil?
			end
			return f_name
		else
			return ''
		end
	end
end