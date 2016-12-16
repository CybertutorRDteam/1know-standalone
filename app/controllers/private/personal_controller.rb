require "net/http"

class Private::PersonalController  < ApplicationController
	before_filter :check_session

	def get_profile
		item = User.find(session[:userinfo][:id])

		knowledges = Knowledge.find_by_sql(
			"select k.uqid, k.name
			from knowledge k
				join draft_knowledge dk on dk.uqid = k.uqid
				join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dke.ref_user_id = #{item.id}
			order by k.last_update desc")

		knowledge = []
		knowledges.each {|item|
			knowledge.push({
				uqid: item.uqid,
				name: item.name,
				logo: get_image('knowledge', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
			})
		}

		content = {
			uqid: item.uqid,
			email: item.userid,
			first_name: item.first_name,
			last_name: item.last_name,
			full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
			description: item.description,
			website: item.website,
			facebook: item.facebook,
			twitter: item.twitter,
			account_type: item.account_type,
			expired_date: item.expired_date,
			photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
			banner: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'banner' }),
			page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
			knowledges: knowledge
		}

		render :json => content
	end

	def set_profile
		item = User.find(session[:userinfo][:id])

		if item != nil
			item.first_name = params[:first_name] if params[:first_name] != nil
			item.last_name = params[:last_name] if params[:last_name] != nil
			item.description = params[:description] if params[:description] != nil
			item.website = params[:website] if params[:website] != nil
			item.twitter = params[:twitter] if params[:twitter] != nil
			item.facebook = params[:facebook] if params[:facebook] != nil
			item.photo = params[:photo] if params[:photo] != nil
			item.banner = params[:banner] if params[:banner] != nil
			item.language = params[:language] if params[:language] != nil
			item.save()

			set_image('user', { uqid: item.uqid, banner: item.banner, photo: item.photo })

			if item.language != nil
				lang = JSON.parse(item.language)
				session[:userinfo][:language] = {title: lang['title'], type: lang['type']}
			end

			content = {
				uqid: item.uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
				description: item.description,
				website: item.website,
				facebook: item.facebook,
				twitter: item.twitter,
				account_type: item.account_type,
				expired_date: item.expired_date,
				photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
				banner: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'banner' }),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def set_password
		uri = URI([APP_CONFIG['OAuth_server'], "/service/changepassword.php?account=#{session[:userinfo][:userid]}&password=#{params[:oldpassword]}&newpassword=#{params[:newpassword]}"].join(''))
		http = Net::HTTP.get_response(uri)
		result = JSON.parse(http.body)

		if result['statusCode'] == '00'
			render :json => result
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end
end