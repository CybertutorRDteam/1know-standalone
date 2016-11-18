require 'libreconv'
require 'net/http'
require 'base64'

#add by Aaron@2014/10/7 , modified by kevin@2015/05/15
class ChooserController < ApplicationController
	after_filter :set_access_control_headers

	@@realdirectory = APP_CONFIG['upload_path'].first
	@@konzesys = APP_CONFIG['konzesys']
	#should match config/route.rb
	@@publicdirectory = { 'video' => "/video" ,
	 					  'doc' => '/library/ViewerJS#/doc',
	 					  'image' => '/image' }

	def set_access_control_headers
		headers['Access-Control-Allow-Origin'] = '*'
		headers['Access-Control-Allow-Method'] = '*'

		response.headers.delete "X-Frame-Options"
	end

	def set_konzesys_account
		ka = KonzesysAccount.where(:ref_user_id => session[:userinfo][:id]).first
		if ka.nil?
			ka = KonzesysAccount.new
			ka.ref_user_id = session[:userinfo][:id]
		end
		ka.account = ''
		if not params[:account].nil?
			ka.account = params[:account]
		end
		ka.password = ''
		if not params[:password].nil?
			ka.password = params[:password]
		end
		ka.save
		render :json => { success: "Well done!" , data: ka , req: params }
	end

	def index
		@params = params
		@unit = DraftUnit.where(:uqid => params[:unit_uqid]).first
		@konzesys_account = KonzesysAccount.where(:ref_user_id => session[:userinfo][:id]).first
		if @konzesys_account.nil?
			@konzesys_account = KonzesysAccount.new
		end
		@APP_CONFIG = APP_CONFIG
		@konzesys = @@konzesys
		# @qiniu = qiniu.where(:ref_user_id => session[:userinfo][:id]).first
		#access_key = 'bEA9JzrIBDkfXR5HPz6t1GnaEdNWw9erAip83Jwl'
		#secret_key = '5X39U2Kp12UQ9QB89UjVPEZBwTALwMxC4NV5uFf3'
		#domain = 'http://7xm74c.com1.z0.glb.clouddn.com/'
		@qiniu = {
			'activate' => APP_CONFIG['qiniu']['activate'],
			'access_key' => APP_CONFIG['qiniu']['access_key'],
			'secret_key' => APP_CONFIG['qiniu']['secret_key'],
			'domain' => APP_CONFIG['qiniu']['domain']
		}
	end

	def parse_video
		@target = params["video"]
		@target = Base64.decode64(@target)
		url = URI.parse(@target)
		http = Net::HTTP.new(url.host, url.port)
		req = Net::HTTP::Get.new(url.request_uri)
		resp = http.request(req)

		#res = Net::HTTP.start(url.host, url.port) {|http|
		#  http.request(req)
		#}

		render :text=> resp["Location"]
	end

	def upload_file
		file      = params[:File]
		file_name = file.original_filename
		unit_uqid = params[:unit_uqid]
		file_type = params[:type]
		user_id = session[:userinfo][:id]
        file_ext  = File.extname(file_name).downcase

        #權限判斷
        item = DraftUnit.find_by_sql(
			"select u.*
			from draft_unit u
				left join draft_chapter c on c.id = u.ref_chapter_id
				left join draft_knowledge k on k.id = c.ref_know_id
			where u.uqid = '#{unit_uqid}'
				and #{user_id} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item == nil
			render :json => { :url => "" }
			return
		end
		#document file add by Aaron@2014/11/6
		if file_type == 'doc' and %w{ .doc .docx .xls .xlsx .ppt .pptx .pdf}.include? file_ext
			directory = File.join(@@realdirectory[file_type])
		#video file
		elsif file_type == 'video' and %w{ .mp4 }.include? file_ext
			directory = File.join(@@realdirectory[file_type])
		#image file
		elsif file_type == 'image' and %w{ .jpg .png }.include? file_ext
			directory = File.join(@@realdirectory[file_type])
		else
			render :json => { :url => "" }
			#render status: 400,:text=> "The file format is not supported."
			return
		end

		FileUtils.mkdir_p directory
		f = UploadFile.where(:ref_user_id => user_id,:uqid=>unit_uqid,:file_type=>file_type).first
		if f.nil?
			#uqid become unit_uqid not file_uqid
			f = UploadFile.new
			f.uqid = unit_uqid
			f.file_type = file_type
		end
		#just infomation
		f.ref_user_id = user_id

		f.file_name = file_name
		f.file_size = file.size()
		f.file_ext = file_ext
		f.save

		realpath = File.join(directory,"#{f.uqid}#{f.file_ext}")

		File.open(realpath, "wb") {|f| f.write(file.read)}
		if  %w{ .doc .docx .xls .xlsx .ppt .pptx }.include? f.file_ext
			Libreconv.convert(realpath, File.join(directory,"#{f.uqid}.pdf"))
		end
		render :json => {
			key: f.uqid,
			url: get_publicpath_by_uqid(f.file_type,f.uqid),
			title: f.file_name,
			file_size: f.file_size,
			file_ext: f.file_ext,
			updated_at: f.updated_at,
			icon: '',
			value: ''
		}
	end
	# def get_realpath_by_uqid(type,uqid)
	# 	f = UploadFile.where(:file_type=>type,:uqid => uqid).first
	# 	if  %w{ .doc .docx .xls .xlsx .ppt .pptx }.include? f.file_ext
	# 		f.file_ext = ".pdf"
	# 	end
	# 	return File.join(@@realdirectory[f.file_type],"#{f.uqid}#{f.file_ext}")
	# end
	def get_realpath_by_uqid(type,uqid)
		f = UploadFile.where(:file_type=>type,:uqid => uqid).first
		extext = ""
		if  %w{ .doc .docx .xls .xlsx .ppt .pptx }.include? f.file_ext
			extext = ".pdf"
		end
		if f.uqid.length == 8
			u = User.find(f.ref_user_id)
			return File.join(@@realdirectory[f.file_type],u.uqid,"#{f.uqid}#{f.file_ext}#{extext}")
		else
			if (extext == ".pdf")
				return File.join(@@realdirectory[f.file_type],"#{f.uqid}#{extext}")
			else
				return File.join(@@realdirectory[f.file_type],"#{f.uqid}#{f.file_ext}")
			end
		end
	end
	def get_publicpath_by_uqid(type,uqid)
		f = UploadFile.where(:file_type=>type,:uqid => uqid).first
		if f.file_type == 'video'
			return File.join(@@publicdirectory[f.file_type],"#{f.uqid}#{f.file_ext}")
		else
			return File.join(@@publicdirectory[f.file_type],f.uqid)
		end
	end
	# def get_file
	# 	realpath = get_realpath_by_uqid(params[:type],params[:uqid])
	# 	f = UploadFile.where(:file_type=>params[:type],:uqid => params[:uqid]).first
	# 	if  %w{ .doc .docx .xls .xlsx .ppt .pptx }.include? f.file_ext
	# 		extext = ".pdf"
	# 	end

	# 	send_file realpath,:filename => "#{f.file_name}#{extext}"
	# end


	def get_file
		realpath = get_realpath_by_uqid(params[:type],params[:uqid])
		f = UploadFile.where(:file_type=>params[:type],:uqid => params[:uqid]).first
		if  %w{ .doc .docx .xls .xlsx .ppt .pptx }.include? f.file_ext
			extext = ".pdf"
		end
		the_file = File.open(realpath)
		file_begin = 0
		file_size = the_file.size
		file_end = file_size - 1
		if f.file_ext == ".mp4"
		  fresh_when(etag: f)
		  match = request.headers['range'].match(/bytes=(\d+)-(\d*)/)

		  if match
		    file_begin = match[1]
		    #file_end = match[1]  if match[2] and not match[2].empty?
		  end
		  response.header["Content-Length"] = (file_end.to_i - file_begin.to_i + 1).to_s
		  response.header["Pragma"] = "no-cache"
  		  #response.header["Accept-Ranges"]=  "bytes"
  		  response.header["Cache-Control"] = "no-cache"
		  response.headers['Content-Range'] = "bytes #{file_begin}-#{file_end.to_i + (match[2] == '1' ? 1 : 0)}/#{file_size}"
		  send_file realpath,
			  :filename => "#{f.file_name}#{extext}",
			  :status => "206 Partial Content",
			  :type => 'video/mp4'
			  #:disposition => "inline",
              #:stream =>  'true',
              #:buffer_size  =>  4096
              #:xsendfile => true
		else
		  send_file realpath,:filename => "#{f.file_name}#{extext}"
		end
		#, :type => 'image/jpeg'#, :disposition => 'inline'
		#output << "This is going to the output file"
		#output.close
	end

	def account
		if session[:userinfo] == nil
			render :json => { error: 'NotLogin' }
			return
		end

		item = User.find(session[:userinfo][:id])

		if item.language != nil
			begin
				lang = JSON.parse(item.language)
				session[:userinfo][:language] = {title: lang['title'], type: lang['type']}
			rescue => e
				session[:userinfo][:language] = {title: 'English', type: 'en-us'}
			end
		else
			session[:userinfo][:language] = {title: 'English', type: 'en-us'}
		end

		content = {
			email: item.userid,
			full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
			language: item.language != nil ? JSON.parse(item.language) : nil,
		}

		render :json => content
	end
end
