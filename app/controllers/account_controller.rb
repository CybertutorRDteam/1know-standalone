require "net/http"
require "uuid"

class AccountController < ApplicationController
	before_filter :check_session, :only => :user
	
	def setup
		reset_session
		if User.where(:uqid=>"stud01").first.nil?
			(1..15).each { |index|
				uqid = "stud#{"%02d" % index}"
				item = User.new
				item.uqid = uqid 
				item.userid = "#{uqid}@1know.net"
				item.first_name = ''
				item.last_name = ''
				item.last_login_ip = request.remote_ip
				item.last_login_time = Time.now()
				item.create_time = Time.now()
				item.account_type = 'plus'
				item.nouser = true
				item.save()
			}
			render :json => { success: "Well done!" }
		else
			render :json => { success: "Done!" }
		end
	end

	def user
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
			uqid: item.uqid,
			email: item.userid,
			first_name: item.first_name,
			last_name: item.last_name,
			full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
			language: item.language != nil ? JSON.parse(item.language) : nil,
			account_type: item.account_type,
			photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
			page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
			nouser: item.nouser,
			domain: item.userid.split('@')[1],
			guest_code: item.nouser ? item.userid.split('@')[0] : ''
		}
		
		item.last_login_ip = request.remote_ip
		item.last_login_time = Time.now()
		item.save()

		if session[:userinfo][:thirdParty] == '1know'
			content[:role] = '1know'
		elsif session[:userinfo][:thirdParty] == 'ischool'
			content[:role] = 'ischool'
		end

		render :json => content
	end

	def login
		reset_session
		
		uri = URI([APP_CONFIG['OAuth_server'], "/oauth/token.php"].join(''))
		response = Net::HTTP.post_form(uri,
			'grant_type' => 'password',
			'scope' => 'User.Mail,User.BasicInfo',
			'username' => params[:uid].downcase,
			'password' => params[:pwd].downcase,
			'client_id' => APP_CONFIG['client_id'],
			'client_secret' =>  APP_CONFIG['client_secret']
		)
		token = JSON.parse(response.body)
		
		if !token['error']
			uri = URI([APP_CONFIG['OAuth_server'], "/services/me.php?access_token=#{token['access_token']}&token_type=bearer"].join(''))
			result = Net::HTTP.get_response(uri)
			account = JSON.parse(result.body)

			item = User.where(['lower(userid) = ?', params[:uid].downcase]).first

			if item == nil
				item = User.new
				item.uqid = UUID.new.generate[0..7]
				item.userid = target['mail'].downcase
				item.first_name = target['firstName']
				item.last_name = target['lastName']
				item.banner = DEFAULT_USER_BANNER
				item.photo = DEFAULT_USER_PHOTO
				item.create_time = Time.now()
				item.account_type = 'plus'
				item.nouser = false
				item.save()

				set_image('user', { uqid: item.uqid, banner: item.banner, photo: item.photo })
			end

			session[:userinfo] = {
				id: item.id,
				uqid: item.uqid,
				userid: item.userid,
				accountType: item.account_type,
				nouser: item.nouser
			}

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
				uqid: item.uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
				language: item.language != nil ? JSON.parse(item.language) : nil,
				account_type: item.account_type,
				domain: item.userid.split('@')[1],
				photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
				nouser: item.nouser,
				guest_code: item.nouser ? item.userid.split('@')[0] : ''
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def logout
		reset_session
		render :json => { success: "Well done!" }
	end

	def switch
		reset_session

		item = User.where(nouser: true, userid: params[:email].downcase).first
		if item == nil
			item.last_login_ip = request.remote_ip
			item.last_login_time = Time.now()
			item.save()

			session[:userinfo] = {id: item.id, uqid: item.uqid, userid: item.userid, accountType: item.account_type, nouser: item.nouser}
			
			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def switch2
		acc = (params[:email]).downcase
		pwd = Digest::SHA2.hexdigest(params[:pwd])

		item = User.where( nouser: false, userid: acc, password: pwd ).first
		if item != nil
			reset_session
			if(item.expired_date > Time.now())
				item.last_login_ip = request.remote_ip
				item.last_login_time = Time.now()
				item.save()
				
				session[:userinfo] = {id: item.id, uqid: item.uqid, userid: item.userid, accountType: item.account_type, nouser: item.nouser, thirdParty: '1know'}
				
				render :json => { success: "Well done!" }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			if session[:regist_timer].nil? or session[:regist_timer] > 1.days.from_now
				
				item = User.new
				item.uqid = UUID.new.generate[0..7]
				item.userid = acc
				item.first_name = ''
				item.last_name = ''
				item.banner = DEFAULT_USER_BANNER
				item.photo = DEFAULT_USER_PHOTO
				item.create_time = Time.now()
				item.expired_date = nil
				item.account_type = 'plus'
				item.nouser = false
				item.save()
				
				session[:regist_timer] = Time.now()
				
				render :json => { success: "Well done!" }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		end
	end
	
	def guest
		reset_session
		
		uqid = UUID.new.generate.split('-')[0]
		item = User.new
		item.uqid = uqid
		item.userid = "#{uqid}@1know.net"
		item.first_name = ''
		item.last_name = ''
		item.last_login_ip = request.remote_ip
		item.last_login_time = Time.now()
		item.create_time = Time.now()
		item.account_type = 'free'
		item.nouser = true
		item.save()

		session[:userinfo] = {
			id: item.id,
			uqid: item.uqid,
			userid: item.userid,
			accountType: item.account_type,
			nouser: item.nouser,
			language: {title:'English', type:'en-us'}
		}

		render :json => { success: "Well done!" }
	end

	def setACode
		#1. Check if user has signed in (from session)
		if session[:userinfo].nil?
			render :json=> {"err" => "User must be signed in first."}
			return
		end

		#2. Check if the code is valid. (existed and never used.)
		code = params[:code]
		acodes = ActivationCode.where(["code=?", code])
		puts acodes

		if acodes.size <= 0
			render :json=> {"err"=> "此验证码无效."}
			return
		else
			acode = acodes[0]
			if (!acode.ref_user_id.nil?) #no one ever used.
				render :json=> {"err"=> "此验证码无效."}
				return
			else
				#3. modify this code which is used by the current user.
				acode.ref_user_id = session[:userinfo][:id]
				acode.activation_time = Time.new ;
				acode.save

				#4. update the expired date of  this user.
				user = User.find(session[:userinfo][:id])
				user.expired_date = acode.duration.days.from_now

				user.save
				render :json=> {"result"=> "OK.", "user" => user }
				return
			end
		end
		
	end
end
