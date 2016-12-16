class MainController < ApplicationController
	#after_filter :set_access_control_headers

	def set_access_control_headers
		headers['Access-Control-Allow-Origin'] = '*'
		headers['Access-Control-Allow-Method'] = '*'

		response.headers.delete "X-Frame-Options"
	end

	def index
		@APP_CONFIG = APP_CONFIG
		if session[:userinfo] == nil or session[:userinfo][:id] == nil
			@content = { role: 'NotLogin', host: request.host }
			return
		end

		item = User.find(session[:userinfo][:id])

		if (@APP_CONFIG['need_activation'] == true && (item.expired_date.nil? || (item.expired_date < DateTime.now.to_date)))
			@content = {
				uqid: item.uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				role: 'NeedActivation'
			}
		else
			@content = {
				uqid: item.uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				domain: item.userid.split('@')[1],
				protocol: request.protocol,
				host: request.host,
				host_with_port: request.host_with_port,
				role: '1know'
			}
		end
	end

	def callback
		if params[:target]
			target = params[:target].split(':')
			if target[0] == 'knowledge'
				@target = "/#!/learn/knowledge/#{target[1]}"
			elsif target[0] == 'channel'
				@target = "/#!/discover/channel/#{target[1]}"
			elsif target[0] == 'group'
				@target = "/#!/join/group/#{target[1]}"
			end
		else
			@target = nil
		end
	end

	def watch
		@APP_CONFIG = APP_CONFIG
		respond_to do |format|
			format.html {
				response.headers.except! 'X-Frame-Options'
				know = Knowledge.find_by_sql(
					"select k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed
					from knowledge k
						left join reader r on r.ref_know_id = k.id
					where k.uqid = '#{params[:k]}'").first

				if know != nil and !know.is_destroyed
					@content = {
						uqid: know.uqid,
						name: know.name,
						description: know.description,
						logo: get_image('knowledge', { uqid: know.uqid }),
						page: "#{request.protocol}#{request.host_with_port}/watch",
						k: params[:k],
						u: params[:u],
						n: params[:n]
					}
				else
					redirect_to '/404.html'
				end
			}

			format.json {
				know = Knowledge.find_by_sql(
					"select k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed
					from knowledge k
						left join reader r on r.ref_know_id = k.id
					where k.uqid = '#{params[:k]}'").first
				user = User.select('id, uqid, first_name, last_name').where(uqid: params[:n]).first

				if know != nil and !know.is_destroyed
					units = []
					know.chapters.each {|c|
						if c.is_destroyed == nil
							units.push({
								uqid: c.uqid,
								name: c.name,
								priority: c.priority,
								unit_type: 'chapter'
							})

							c.units.each {|u|
								if u.is_destroyed == nil
									quizzes = []
									if ['video', 'quiz'].include?(u.unit_type)
										u.questions.each {|item|
											if item.is_destroyed == nil
												begin
													options = JSON.parse(item.options)
												rescue => e
													options = []
												end

												quizzes.push({
													uqid: item.uqid,
													quiz_no: item.q_no.to_i,
													quiz_type: item.q_type,
													content: item.content,
													options: options,
													answer: item.answer,
													solution: item.solution,
													video_time: item.video_time,
													explain: item.explain,
													explain_url: item.explain_url
												})
											end
										}
									end

									notes = []
									if not user.nil?
										items = Note.select('uqid, video_time, content, content_type, content_color')
											.where(is_public: true, ref_user_id: user.id, ref_unit_id: u.id)
											.order('video_time asc')

										items.each{|item|
											notes.push({
												uqid: item.uqid,
												content: item.content_type == 'text' || item.content_type == nil ? item.content : JSON.parse(item.content),
												time: item.video_time == nil ? 0 : item.video_time.to_f,
												type: item.content_type == nil ? 'text' : item.content_type,
												color: item.content_color == nil ? '#fff' : item.content_color
											})
										}
									end
									units.push({
										uqid: u.uqid,
										name: u.name,
										priority: u.priority,
										unit_type: u.unit_type,
										content_url: u.content_url,
										content_time: u.content_time,
										description: u.supplementary_description,
										content: u.content != nil ? ((u.unit_type == 'poll' or u.unit_type == 'draw') ? JSON.parse(u.content) : u.content) : nil,
										quizzes: quizzes,
										notes: notes
									})
								end
							}
						end
					}

					render :json => units
				else
					render :json => { error: "We're sorry, but something went wrong." }
				end
			}
		end
	end
end