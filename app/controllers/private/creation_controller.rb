require "uuid"

class Private::CreationController < ApplicationController
	before_filter :check_session

	# knowledge

	def list_knowledge
		condition = "where #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = dk.id)"
		condition = "#{condition} and dk.uqid = '#{params[:itemUqid]}'" if params[:itemUqid] != nil

		items = DraftKnowledge.find_by_sql(
			"select k.id, dk.code, dk.is_public, dk.uqid, dk.name, dk.description, dk.total_time, dk.last_update, dk.release_time,  r.reader_size, r.total_rate, r.rate_count, r.average_rate
			from draft_knowledge dk
				left join knowledge k on k.uqid = dk.uqid
				left join (select r.ref_know_id, count(r.id) reader_size,
						sum(case when r.rating is null then 0 else r.rating end) total_rate,
						sum(case when r.rating is null then 0 else 1 end) rate_count,
						case when sum(case when r.rating is null then 0 else 1 end) <> 0
							then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
							else 0 end average_rate
					from reader r
					group by r.ref_know_id) as r on r.ref_know_id = k.id
			#{condition}
			order by dk.last_update desc")

		if params[:itemUqid] == nil
			content = []
			items.each {|item|
				item.id = 0 if item.id == nil

				content.push({
					uqid: item.uqid,
					name: item.name,
					description: item.description,
					total_time: item.total_time.to_f,
					last_update: item.last_update,
					release_time: item.release_time != nil ? item.release_time.to_datetime : nil,
					release: item.release_time != nil ? true : false,
					privacy: item.is_public,
					code: item.code,
					readers: item.reader_size || 0,
					rate_count: item.rate_count || 0,
					total_rate: item.total_rate || 0,
					average_rate: item.average_rate ||0,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
					share_page: "#{request.protocol}#{request.host_with_port}/watch?k=#{item.uqid}"
				})
			}

			render :json => content
		elsif params[:itemUqid] != nil and items.size == 1
			item = items[0]
			item.id = 0 if item.id == nil

			groups = Group.find_by_sql(
				"select g.uqid, g.name, gm.role, gk.id joined
				from \"group\" g
					join group_member gm on gm.ref_group_id = g.id and gm.ref_user_id = #{session[:userinfo][:id]}
					left join group_knowledge gk on gk.ref_group_id = g.id and gk.ref_know_id = #{item.id}
				where gm.role in ('owner', 'admin') and g.is_destroyed = false
				order by g.name")

			channels = Channel.find_by_sql(
				"select cl.uqid, cl.name, cm.role, ck.id joined
				from channel cl
					join channel_member cm on cm.ref_channel_id = cl.id and cm.ref_user_id = #{session[:userinfo][:id]}
					left join category_knowledge ck on ck.ref_channel_id = cl.id and ck.ref_know_id = #{item.id}
				where cm.role in ('owner', 'admin', 'editor')
				order by cl.name")

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				total_time: item.total_time.to_f,
				last_update: item.last_update,
				release_time: item.release_time != nil ? item.release_time.to_datetime : nil,
				release: item.release_time != nil ? true : false,
				groups: item.release_time != nil ? groups : [],
				channels: item.release_time != nil ? channels : [],
				privacy: item.is_public,
				code: item.code,
				readers: item.reader_size,
				rate_count: item.rate_count,
				total_rate: item.total_rate,
				average_rate: item.average_rate,
				logo: get_image('knowledge', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
				share_page: "#{request.protocol}#{request.host_with_port}/watch?k=#{item.uqid}"
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def create_knowledge
		params[:name] = "New Knowledge" if params[:name] == nil or params[:name] == ''

		item = DraftKnowledge.new
		item.uqid = UUID.new.generate.split('-')[0..1].join('')
		item.total_time = 0
		item.name = params[:name]
		item.description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
		item.logo = params[:logo] != nil ? params[:logo] : DEFAULT_LOGO
		item.is_public = false
		item.last_update = Time.now
		item.save()

		set_image('knowledge', { uqid: item.uqid, logo: item.logo })

		ke = DraftKnowledgeEditor.new
		ke.ref_know_id = item.id
		ke.ref_user_id = session[:userinfo][:id]
		ke.uqid = UUID.new.generate.split('-')[0..1].join('')
		ke.order = 1
		ke.is_show = true
		ke.role = 'owner'
		ke.save()

		content = {
			uqid: item.uqid,
			name: item.name,
			description: item.description,
			logo: item.logo,
			last_update: item.last_update
		}

		render :json => content
	end

	def update_knowledge
		item = DraftKnowledge.find_by_sql(
			"select dk.*
			from draft_knowledge dk
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dk.uqid = '#{params[:itemUqid]}'
				and dke.ref_user_id = #{session[:userinfo][:id]}").first

		if item != nil
			item.name = params[:name] if params[:name] != nil and params[:name] != ''
			item.description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
			item.logo = params[:logo] if params[:logo]
			item.is_public = (params[:privacy] == true ? true : false) if params[:privacy] != nil
			item.last_update = Time.now
			item.save()

			set_image('knowledge', { uqid: item.uqid, logo: item.logo })

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				last_update: item.last_update,
				privacy: item.is_public,
				code: item.code,
				logo: item.logo
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_knowledge
		item = DraftKnowledge.find_by_sql(
			"select dk.*
			from draft_knowledge dk
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dk.uqid = '#{params[:itemUqid]}'
				and dke.ref_user_id = #{session[:userinfo][:id]}").first

		if item != nil
			know = Knowledge.where(['uqid = ?', item.uqid]).first

			if know != nil
				if know.readers.size > 0
					know.code = nil
					know.is_public = false
					know.is_destroyed = true
					know.save()

					ActiveRecord::Base.connection.execute("delete from category_knowledge where ref_know_id = #{know.id}")
					ActiveRecord::Base.connection.execute("delete from group_knowledge where ref_know_id = #{know.id}")
				else
					know.destroy
				end
			end
			units = DraftUnit.find_by_sql(
				"select u.* from draft_unit u
					left join draft_chapter c on c.id = u.ref_chapter_id
					left join draft_knowledge k on k.id = c.ref_know_id
				where k.uqid = '#{params[:itemUqid]}' and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)")

			units.each{|unit|
				if Unit.where(:uqid=>unit.uqid).first.nil?
					chooser_delete_file(unit)
				end
				unit.destroy
			}
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def reset_knowledge_code
		item = DraftKnowledge.find_by_sql(
			"select dk.*
			from draft_knowledge dk
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dk.uqid = '#{params[:itemUqid]}'
				and dke.ref_user_id = #{session[:userinfo][:id]}").first

		if item != nil
			item.code = UUID.new.generate[0..5].upcase
			item.last_update = Time.now
			item.save()

			know = Knowledge.where(uqid: item.uqid).first
			if know != nil
				know.code = item.code
				know.last_update = item.last_update
				know.save()
			end

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				last_update: item.last_update,
				privacy: item.is_public,
				code: item.code,
				logo: item.logo
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def publish_knowledge
		dk = DraftKnowledge.find_by_sql(
			"select dk.*
			from draft_knowledge dk
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dk.uqid = '#{params[:itemUqid]}'
				and dke.ref_user_id = #{session[:userinfo][:id]}").first

		if dk != nil
			user = User.where(id: session[:userinfo][:id]).first
			knowledge = Knowledge.find_by_sql(
				"select k.id
				from knowledge k
					join draft_knowledge dk on dk.uqid = k.uqid
					join draft_knowledge_editor ke on ke.ref_know_id = dk.id
				where ke.role = 'owner' and k.is_public = false and dk.id = #{dk.id}")

			if user.account_type == 'free' and !dk.is_public
				render :json => { error: 'Free 帐号只能发布公开的知识，如需发布非公开知识，建议升级至 Plus or Pro 帐号!' }
			elsif user.account_type == 'plus' and knowledge.size >= 20 and dk.release_time == nil
				render :json => { error: 'Plus 帐号只能发布20个非公开知识，如需发布更多非公开知识，建议升级至 Pro 帐号!' }
			else
				ActiveRecord::Base.transaction do
					existItems = {
						chapters: {},
						units: {},
						quizs: {}
					}

					pk = Knowledge.where(uqid: dk.uqid).first

					if pk == nil
						pk = Knowledge.new
						pk.uqid = dk.uqid
						pk.name = dk.name
						pk.description = dk.description
						pk.total_time = dk.total_time
						pk.logo = dk.logo
						pk.code = dk.code
						pk.is_public = dk.is_public
						pk.is_destroyed = false
						pk.last_update = dk.last_update
					else
						pk.name = dk.name
						pk.description = dk.description
						pk.total_time = dk.total_time
						pk.logo = dk.logo
						pk.code = dk.code
						pk.is_public = dk.is_public
						pk.is_destroyed = false
						pk.last_update = dk.last_update

						pk.chapters.each {|c|
							existItems[:chapters][c.uqid] = c
							c.units.each {|u|
								existItems[:units][u.uqid] = u
								u.questions.each {|q|
									existItems[:quizs][q.uqid] = q
								}
							}
						}
					end

					pk.last_update = Time.now
					pk.save()

					dk.chapters.each {|dc|
						if existItems[:chapters][dc.uqid] == nil
							pc = Chapter.new
							pc.uqid = dc.uqid
							pc.ref_know_id = pk.id
							pc.name = dc.name
							pc.priority = dc.priority
							pc.last_update = dc.last_update
							pc.save()
						else
							pc = existItems[:chapters][dc.uqid]
							pc.name = dc.name
							pc.priority = dc.priority
							pc.last_update = dc.last_update
							pc.save()
						end

						dc.units.each {|du|
							if existItems[:units][du.uqid] == nil
								pu = Unit.new
								pu.uqid = du.uqid
								pu.ref_chapter_id = pc.id
								pu.ref_know_id = pk.id
								pu.name = du.name
								pu.priority = du.priority
								pu.unit_type = du.unit_type
								pu.content_url = du.content_url
								pu.content_time = du.content_time
								pu.supplementary_description = du.supplementary_description
								pu.content = du.content
								pu.is_preview = du.is_preview
								pu.last_update = du.last_update
								pu.save()
							else
								pu = existItems[:units][du.uqid]
								pu.ref_chapter_id = pc.id
								pu.ref_know_id = pk.id
								pu.name = du.name
								pu.priority = du.priority
								pu.unit_type = du.unit_type
								pu.content_url = du.content_url
								pu.content_time = du.content_time
								pu.supplementary_description = du.supplementary_description
								pu.content = du.content
								pu.is_preview = du.is_preview
								pu.last_update = du.last_update
								pu.save()
							end

							du.questions.each {|dq|
								if existItems[:quizs][dq.uqid] == nil
									pq = Question.new
									pq.uqid = dq.uqid
									pq.ref_unit_id = pu.id
									pq.q_no = dq.q_no
									pq.q_type = dq.q_type
									pq.content = dq.content
									pq.options = dq.options
									pq.answer = dq.answer
									pq.explain = dq.explain
									pq.explain_url = dq.explain_url
									pq.solution = dq.solution
									pq.video_time = dq.video_time
									pq.save()
								else
									pq = existItems[:quizs][dq.uqid]
									pq.ref_unit_id = pu.id
									pq.q_no = dq.q_no
									pq.q_type = dq.q_type
									pq.content = dq.content
									pq.options = dq.options
									pq.answer = dq.answer
									pq.explain = dq.explain
									pq.explain_url = dq.explain_url
									pq.solution = dq.solution
									pq.video_time = dq.video_time
									pq.save()
								end

								dq.release_time = Time.now
								dq.save()
							}

							du.release_time = Time.now
							du.save()
						}

						dc.release_time = Time.now
						dc.save()
					}

					dk.release_time = Time.now
					dk.save()

					existItems = {
						chapters: {},
						units: {},
						quizs: {}
					}

					dk.chapters.each {|c|
						existItems[:chapters][c.uqid] = c
						c.units.each {|u|
							existItems[:units][u.uqid] = u
							u.questions.each {|q|
								existItems[:quizs][q.uqid] = q
							}
						}
					}

					pk.chapters.each {|c|
						if existItems[:chapters][c.uqid] == nil
							c.is_destroyed = true
							c.save()
						end

						c.units.each {|u|
							if existItems[:units][u.uqid] == nil
								u.is_destroyed = true
								chooser_delete_file(u)
								u.save()
							end

							u.questions.each {|q|
								if existItems[:quizs][q.uqid] == nil
									q.is_destroyed = true
									q.save()
								end
							}
						}
					}

					render :text => "done!"
				end
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_knowledge_editor
		condition = "where k.uqid = '#{params[:knowUqid]}'"
		condition = "#{condition} and ke.uqid = '#{params[:itemUqid]}'" if params[:itemUqid] != nil

		items = DraftKnowledgeEditor.find_by_sql(
			"select ke.uqid, ke.order, ke.is_show, ke.role, u.uqid user_uqid, u.userid, u.first_name, u.last_name, u.nouser, u.photo
			from draft_knowledge_editor ke
				join draft_knowledge k on k.id = ke.ref_know_id
				join \"user\" u on u.id = ke.ref_user_id
			#{condition} and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)
			order by ke.order, u.last_name, u.first_name")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				user_uqid: item.user_uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
				order: item.order,
				show: item.is_show,
				role: item.role,
				photo: get_image('user', { uqid: item.user_uqid, nouser: item.nouser, type: 'photo' }),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.user_uqid}",
				nouser: item.nouser
			})
		}

		render :json => content
	end

	def add_knowledge_editor
		dk = DraftKnowledge.find_by_sql(
			"select dk.*
			from draft_knowledge dk
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dk.uqid = '#{params[:knowUqid]}'
				and dke.ref_user_id = #{session[:userinfo][:id]}").first

		item = DraftKnowledgeEditor.find_by_sql(
			"select ke.*
			from draft_knowledge_editor ke
				join draft_knowledge k on k.id = ke.ref_know_id
				join \"user\" u on u.id = ke.ref_user_id
			where k.uqid = '#{params[:knowUqid]}' and u.userid = '#{params[:email].downcase}'").first

		if item == nil and dk != nil
			know = DraftKnowledge.where(uqid: params[:knowUqid]).first
			user = User.where(userid: params[:email].downcase).first

			order = DraftKnowledgeEditor.where(ref_know_id: know.id).maximum('order')

			item = DraftKnowledgeEditor.new
			item.ref_know_id = know.id
			item.ref_user_id = user.id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.order = (order == nil ? 1 : order + 1)
			item.is_show = true
			item.role = 'editor'
			item.save()

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_knowledge_editor
		item = DraftKnowledgeEditor.find_by_sql(
			"select ke.*
			from draft_knowledge_editor ke
				join draft_knowledge k on k.id = ke.ref_know_id
				join \"user\" u on u.id = ke.ref_user_id
			where k.uqid = '#{params[:knowUqid]}' and ke.uqid = '#{params[:itemUqid]}' and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			item.is_show = params[:show] == true ? true : false
			item.save()

			if params[:order] != nil
				order = params[:order].to_i

				if order > item.order
					ActiveRecord::Base.connection.execute(
						"update draft_knowledge_editor set \"order\" = \"order\" - 1
						where \"order\" > #{item.order} and \"order\" <= #{order} and ref_know_id = #{item.ref_know_id}")
				else
					ActiveRecord::Base.connection.execute(
						"update draft_knowledge_editor set \"order\" = \"order\" + 1
						where \"order\" < #{item.order} and \"order\" >= #{order} and ref_know_id = #{item.ref_know_id}")
				end

				item.order = order
				item.save()
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def remove_knowledge_editor
		item = DraftKnowledgeEditor.find_by_sql(
			"select ke.*
			from draft_knowledge_editor ke
				join draft_knowledge k on k.id = ke.ref_know_id
				join \"user\" u on u.id = ke.ref_user_id
			where k.uqid = '#{params[:knowUqid]}' and ke.uqid = '#{params[:itemUqid]}' and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			ActiveRecord::Base.connection.execute(
				"update draft_knowledge_editor set \"order\" = \"order\" - 1
				where \"order\" > #{item.order} and ref_know_id = #{item.ref_know_id}")

			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_chapter
		condition = "where k.uqid = '#{params[:knowUqid]}'"
		condition = "#{condition} and c.uqid = '#{params[:itemUqid]}'" if params[:itemUqid] != nil

		items = DraftChapter.find_by_sql(
			"select k.uqid k_uqid, k.name k_name, c.uqid, c.name, c.priority, c.release_time
			from draft_chapter c
				join draft_knowledge k on k.id = c.ref_know_id
			#{condition} and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)
			order by c.priority")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				release_time: item.release_time != nil ? item.release_time.to_datetime : nil,
				release: item.release_time == nil ? false : true,
				knowledge: {
					uqid: item.k_uqid,
					name: item.k_name
				}
			})
		}

		render :json => content
	end

	def create_chapter
		dk = DraftKnowledge.find_by_sql(
			"select dk.*
			from draft_knowledge dk
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dk.uqid = '#{params[:knowUqid]}'
				and dke.ref_user_id = #{session[:userinfo][:id]}").first

		if dk != nil
			params[:name] = "New Chapter" if params[:name] == nil or params[:name] == ''
			priority = DraftChapter.where(ref_know_id: dk.id).maximum('priority')

			item = DraftChapter.new
			item.ref_know_id = dk.id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name]
			item.priority = (priority == nil ? 1 : priority + 1)
			item.last_update = Time.now
			item.save()

			if params[:priority] != nil
				priority = params[:priority].to_i

				if priority > item.priority
					ActiveRecord::Base.connection.execute(
						"update draft_chapter set priority = priority - 1
						where priority > #{item.priority} and priority <= #{priority} and ref_know_id = #{item.knowledge.id}")
				else
					ActiveRecord::Base.connection.execute(
						"update draft_chapter set priority = priority + 1
						where priority < #{item.priority} and priority >= #{priority} and ref_know_id = #{item.knowledge.id}")
				end

				item.priority = priority
				item.save()
			end

			content = {
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				last_update: item.last_update,
				knowledge: {
					uqid: item.knowledge.uqid,
					name: item.knowledge.name
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_chapter
		item = DraftChapter.find_by_sql(
			"select c.*
			from draft_chapter c
				join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			if params[:priority] != nil
				priority = params[:priority].to_i

				if priority > item.priority
					ActiveRecord::Base.connection.execute(
						"update draft_chapter set priority = priority - 1
						where priority > #{item.priority} and priority <= #{priority} and ref_know_id = #{item.knowledge.id}")
				else
					ActiveRecord::Base.connection.execute(
						"update draft_chapter set priority = priority + 1
						where priority < #{item.priority} and priority >= #{priority} and ref_know_id = #{item.knowledge.id}")
				end

				item.priority = priority
			end

			item.name = params[:name] if params[:name] != nil and params[:name] != ''
			item.last_update = Time.now
			item.save()

			content = {
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				last_update: item.last_update,
				knowledge: {
					uqid: item.knowledge.uqid,
					name: item.knowledge.name
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_chapter
		item = DraftChapter.find_by_sql(
			"select c.*
			from draft_chapter c
				join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			ActiveRecord::Base.connection.execute(
				"update draft_chapter set priority = priority - 1
				where priority > #{item.priority} and ref_know_id = #{item.knowledge.id}")

			units = DraftUnit.find_by_sql(
				"select u.* from draft_unit u
					left join draft_chapter c on c.id = u.ref_chapter_id
					left join draft_knowledge k on k.id = c.ref_know_id
				where c.uqid = '#{params[:itemUqid]}' and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)")

			units.each{|unit|
				if Unit.where(:uqid=>unit.uqid).first.nil?
					chooser_delete_file(unit)
				end
				unit.destroy
			}
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_unit
		condition = "where #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)"
		condition = "#{condition} and k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil
		condition = "#{condition} and c.uqid = '#{params[:chapterUqid]}'" if params[:chapterUqid] != nil
		condition = "#{condition} and u.uqid = '#{params[:unitUqid]}'" if params[:unitUqid] != nil

		items = DraftUnit.find_by_sql(
			"select k.uqid k_uqid, k.name k_name, c.uqid ch_uqid, c.name ch_name, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time,
				u.supplementary_description, u.content, u.is_preview, u.release_time, count(q.id) quizzes, du.max_priority
			from draft_knowledge k
				join draft_chapter c on c.ref_know_id = k.id
				join draft_unit u on u.ref_chapter_id = c.id
				left outer join draft_question q on q.ref_unit_id = u.id
				left outer join (select ref_chapter_id, max(priority) max_priority from draft_unit group by ref_chapter_id) du on du.ref_chapter_id = c.id
			#{condition}
			group by k.uqid, k.name, c.uqid, c.name, c.priority, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time, u.supplementary_description, u.content, u.is_preview, u.release_time, du.max_priority
			order by c.priority, u.priority")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				unit_type: item.unit_type,
				content_url: item.content_url,
				content_time: item.content_time != nil ? item.content_time.to_f : nil,
				description: item.supplementary_description,
				content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
				preview: item.is_preview != nil ? item.is_preview : false,
				release_time: item.release_time != nil ? item.release_time.to_datetime : nil,
				release: item.release_time == nil ? false : true,
				max_priority: item.max_priority.to_i,
				chapter: {
					uqid: item.ch_uqid,
					name: item.ch_name
				},
				knowledge: {
					uqid: item.k_uqid,
					name: item.k_name
				}
			})
		}

		render :json => content
	end

	def create_unit
		params[:name] = "New Unit" if params[:name] == nil or params[:name] == ''

		chapter = DraftChapter.find_by_sql(
			"select c.*
			from draft_chapter c
				join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:chapterUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if chapter != nil
			priority = DraftUnit.where(ref_chapter_id: chapter.id).maximum('priority')

			item = DraftUnit.new
			item.ref_chapter_id = chapter.id
			item.ref_know_id = chapter.ref_know_id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name]
			item.priority = (priority == nil ? 1 : priority + 1)
			item.unit_type = ['video', 'web', 'embed', 'quiz', 'poll', 'qa', 'draw'].include?(params[:unit_type]) ? params[:unit_type] : 'web'
			item.content_url = params[:content_url] if params[:content_url] != nil
			item.content_time = params[:content_time] if params[:content_time] != nil
			item.supplementary_description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
			item.content = params[:content] if params[:content] != nil
			item.is_preview = params[:preview] == true ? true : false
			item.last_update = Time.now
			item.save()

			if params[:priority] != nil
				priority = params[:priority]
				if priority > item.priority
					ActiveRecord::Base.connection.execute(
						"update draft_unit set priority = priority - 1
						where priority > #{item.priority} and priority <= #{priority} and ref_chapter_id = #{item.chapter.id}")
				else
					ActiveRecord::Base.connection.execute(
						"update draft_unit set priority = priority + 1
						where priority < #{item.priority} and priority >= #{priority} and ref_chapter_id = #{item.chapter.id}")
				end

				item.priority = params[:priority]
				item.save()
			end

			update_know(item)

			content = {
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				unit_type: item.unit_type,
				content_url: item.content_url,
				content_time: item.content_time != nil ? item.content_time.to_f : nil,
				description: item.supplementary_description,
				content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
				preview: item.is_preview,
				chapter: {
					uqid: item.chapter.uqid,
					name: item.chapter.name
				},
				knowledge: {
					uqid: item.chapter.knowledge.uqid,
					name: item.chapter.knowledge.name
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_unit
		item = DraftUnit.find_by_sql(
			"select u.*
			from draft_unit u
				left join draft_chapter c on c.id = u.ref_chapter_id
				left join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:chapterUqid]}'
				and u.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			chapter = DraftChapter.find_by_sql(
				"select c.*
				from draft_chapter c
					join draft_knowledge k on k.id = c.ref_know_id
				where c.uqid = '#{params[:ch_uqid]}' and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

			if chapter != nil
				if item.ref_chapter_id == chapter.id
					if params[:priority] != nil
						priority = params[:priority]

						if priority > item.priority
							ActiveRecord::Base.connection.execute(
								"update draft_unit set priority = priority - 1
								where priority > #{item.priority} and priority <= #{priority} and ref_chapter_id = #{item.chapter.id}")
						else
							ActiveRecord::Base.connection.execute(
								"update draft_unit set priority = priority + 1
								where priority < #{item.priority} and priority >= #{priority} and ref_chapter_id = #{item.chapter.id}")
						end

						item.priority = params[:priority]
					end
				else
					ActiveRecord::Base.connection.execute(
						"update draft_unit set priority = priority - 1
						where priority > #{item.priority} and ref_chapter_id = #{item.chapter.id}")

					priority = DraftUnit.where(ref_chapter_id: chapter.id).maximum('priority')
					item.priority = (priority == nil ? 1 : priority + 1)
					item.ref_chapter_id = chapter.id
				end
			end

			item.name = params[:name] if params[:name] != nil
			item.unit_type = (['video', 'web', 'embed', 'quiz', 'poll', 'qa', 'draw'].include?(params[:unit_type]) ? params[:unit_type] : 'web') if params[:unit_type] != nil
			item.content_url = params[:content_url] if params[:content_url] != nil
			item.content_time = params[:content_time] if params[:content_time] != nil
			item.supplementary_description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
			item.is_preview = (params[:preview] == true ? true : false) if params[:preview] != nil
			item.content = params[:content] if params[:content] != nil
			item.last_update = Time.now
			item.save()

			update_know(item)

			content = {
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				unit_type: item.unit_type,
				content_url: item.content_url,
				content_time: item.content_time != nil ? item.content_time.to_f : nil,
				description: item.supplementary_description,
				content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
				preview: item.is_preview,
				chapter: {
					uqid: item.chapter.uqid,
					name: item.chapter.name
				},
				knowledge: {
					uqid: item.chapter.knowledge.uqid,
					name: item.chapter.knowledge.name
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_unit
		item = DraftUnit.find_by_sql(
			"select u.*
			from draft_unit u
				left join draft_chapter c on c.id = u.ref_chapter_id
				left join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:chapterUqid]}'
				and u.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			update_know(item)

			ActiveRecord::Base.connection.execute(
				"update draft_unit set priority = priority - 1
				where priority > #{item.priority} and ref_chapter_id = #{item.chapter.id}")

			if Unit.where(:uqid=>item.uqid).first.nil?
				chooser_delete_file(item)
			end
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def clone_unit
		chapter = DraftChapter.find_by_sql(
			"select c.*
			from draft_chapter c
				join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if chapter != nil
			units = DraftUnit.find_by_sql(
				"select u.* from draft_unit u
					left join draft_chapter c on c.id = u.ref_chapter_id
					left join draft_knowledge k on k.id = c.ref_know_id
				where u.uqid in ('#{params[:units].split(',').join("','")}') and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)")

			units.each{|unit|
				priority = DraftUnit.where(ref_chapter_id: chapter.id).maximum('priority')

				item = DraftUnit.new
				item.ref_chapter_id = chapter.id
				item.ref_know_id = chapter.ref_know_id
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.name = unit.name
				item.priority = (priority == nil ? 1 : priority + 1)
				item.unit_type = unit.unit_type
				item.content_url = unit.content_url
				item.content_time = unit.content_time
				item.supplementary_description = unit.supplementary_description
				item.content = unit.content
				item.is_preview = false
				item.last_update = Time.now
				item.save()

				chooser_copy_file(unit,item)
				update_know(item)
			}

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def remove_unit
		chapter = DraftChapter.find_by_sql(
			"select c.*
			from draft_chapter c
				join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if chapter != nil
			units = DraftUnit.find_by_sql(
				"select u.* from draft_unit u
					left join draft_chapter c on c.id = u.ref_chapter_id
					left join draft_knowledge k on k.id = c.ref_know_id
				where u.uqid in ('#{params[:units].split(',').join("','")}') and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)")


			units.each{|unit|
				if Unit.where(:uqid=>unit.uqid).first.nil?
					chooser_delete_file(unit)
				end
				unit.destroy
			}

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_quiz
		condition = "where #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)"
		condition = "#{condition} and k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil
		condition = "#{condition} and c.uqid = '#{params[:chapterUqid]}'" if params[:chapterUqid] != nil
		condition = "#{condition} and u.uqid = '#{params[:unitUqid]}'" if params[:unitUqid] != nil
		condition = "#{condition} and q.uqid = '#{params[:quizUqid]}'" if params[:quizUqid] != nil

		items = DraftQuestion.find_by_sql(
			"select q.*
			from draft_question q
				join draft_unit u on u.id = q.ref_unit_id
				join draft_chapter c on c.id = u.ref_chapter_id
				join draft_knowledge k on k.id = c.ref_know_id
			#{condition}
			order by c.priority, u.priority, q.q_no")

		content = []
		items.each {|item|
			begin
				options = JSON.parse(item.options)
			rescue => e
				options = []
			end

			content.push({
				uqid: item.uqid,
				quiz_no: item.q_no.to_i,
				quiz_type: item.q_type,
				content: item.content,
				options: options,
				answer: item.answer,
				solution: item.solution,
				explain: item.explain,
				explain_url: item.explain_url,
				solution: item.solution,
				video_time: item.video_time.to_i,
				unit: {
					uqid: item.unit.uqid,
					name: item.unit.name
				},
				chapter: {
					uqid: item.unit.chapter.uqid,
					name: item.unit.chapter.name
				},
				knowledge: {
					uqid: item.unit.chapter.knowledge.uqid,
					name: item.unit.chapter.knowledge.name
				}
			})
		}

		render :json => content
	end

	def create_quiz
		unit = DraftUnit.find_by_sql(
			"select u.*
			from draft_unit u
				left join draft_chapter c on c.id = u.ref_chapter_id
				left join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:chapterUqid]}'
				and u.uqid = '#{params[:unitUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if unit != nil
			params[:content] = "quiz content ..." if params[:content] == nil or params[:content] == ''
			q_no = DraftQuestion.where(ref_unit_id: unit.id).maximum('q_no')

			item = DraftQuestion.new
			item.ref_unit_id = unit.id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.q_no = (q_no == nil ? 1 : q_no + 1)
			item.q_type = params[:quiz_type] if params[:quiz_type] != nil
			item.content = params[:content] if params[:content] != nil
			item.options = params[:options] if params[:options] != nil
			item.answer = params[:answer] if params[:answer] != nil
			item.explain = params[:explain] if params[:explain] != nil
			item.explain_url = params[:explain_url] if params[:explain_url] != nil
			item.solution = params[:solution] if params[:solution] != nil
			item.video_time = params[:video_time] if params[:video_time] != nil
			item.save()

			begin
				options = JSON.parse(item.options)
			rescue => e
				options = []
			end

			content = {
				uqid: item.uqid,
				quiz_no: item.q_no.to_i,
				quiz_type: item.q_type,
				content: item.content,
				options: options,
				answer: item.answer,
				solution: item.solution,
				explain: item.explain,
				explain_url: item.explain_url,
				solution: item.solution,
				video_time: item.video_time.to_i,
				unit: {
					uqid: item.unit.uqid,
					name: item.unit.name
				},
				chapter: {
					uqid: item.unit.chapter.uqid,
					name: item.unit.chapter.name
				},
				knowledge: {
					uqid: item.unit.chapter.knowledge.uqid,
					name: item.unit.chapter.knowledge.name
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_quiz
		item = DraftQuestion.find_by_sql(
			"select q.*
			from draft_question q
				left join draft_unit u on u.id = q.ref_unit_id
				left join draft_chapter c on c.id = u.ref_chapter_id
				left join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:chapterUqid]}'
				and u.uqid = '#{params[:unitUqid]}'
				and q.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			if params[:priority] != nil
				priority = params[:priority]

				if priority > item.q_no
					ActiveRecord::Base.connection.execute(
						"update draft_question set q_no = q_no - 1
						where q_no > #{item.q_no} and q_no <= #{priority} and ref_unit_id = #{item.unit.id}")
				else
					ActiveRecord::Base.connection.execute(
						"update draft_question set q_no = q_no + 1
						where q_no < #{item.q_no} and q_no >= #{priority} and ref_unit_id = #{item.unit.id}")
				end

				item.q_no = params[:priority]
			end

			item.q_type = params[:quiz_type] if params[:quiz_type] != nil
			item.content = params[:content] if params[:content] != nil
			item.options = params[:options] if params[:options] != nil
			item.answer = params[:answer] if params[:answer] != nil
			item.explain = params[:explain] if params[:explain] != nil
			item.explain_url = params[:explain_url] if params[:explain_url] != nil
			item.solution = params[:solution] if params[:solution] != nil
			item.video_time = params[:video_time] if params[:video_time] != nil
			item.save()

			begin
				options = JSON.parse(item.options)
			rescue => e
				options = []
			end

			content = {
				uqid: item.uqid,
				quiz_no: item.q_no.to_i,
				quiz_type: item.q_type,
				content: item.content,
				options: options,
				answer: item.answer,
				solution: item.solution,
				explain: item.explain,
				explain_url: item.explain_url,
				solution: item.solution,
				video_time: item.video_time.to_i,
				unit: {
					uqid: item.unit.uqid,
					name: item.unit.name
				},
				chapter: {
					uqid: item.unit.chapter.uqid,
					name: item.unit.chapter.name
				},
				knowledge: {
					uqid: item.unit.chapter.knowledge.uqid,
					name: item.unit.chapter.knowledge.name
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_quiz
		item = DraftQuestion.find_by_sql(
			"select q.*
			from draft_question q
				left join draft_unit u on u.id = q.ref_unit_id
				left join draft_chapter c on c.id = u.ref_chapter_id
				left join draft_knowledge k on k.id = c.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'
				and c.uqid = '#{params[:chapterUqid]}'
				and u.uqid = '#{params[:unitUqid]}'
				and q.uqid = '#{params[:itemUqid]}'
				and #{session[:userinfo][:id]} in (select ref_user_id from draft_knowledge_editor where ref_know_id = k.id)").first

		if item != nil
			ActiveRecord::Base.connection.execute(
				"update draft_question set q_no = q_no - 1
				where q_no > #{item.q_no} and ref_unit_id = #{item.ref_unit_id}")

			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	# channel

	def list_channel
		condition = "and cl.uqid = '#{params[:itemUqid]}'" if params[:itemUqid] != nil

		items = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role != 'member'
				and cm.ref_user_id = #{session[:userinfo][:id]}
			#{condition}
			order by cl.last_update desc")

		if params[:itemUqid] == nil
			content = []
			items.each {|item|
				reader = ChannelMember.where(ref_channel_id: item.id, role: 'member').size

				content.push({
					uqid: item.uqid,
					name: item.name,
					description: item.description,
					last_update: item.last_update,
					reader: reader,
					logo: get_image('channel', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/channel/#{item.uqid}"
				})
			}

			render :json => content
		elsif params[:itemUqid] != nil and items.size == 1
			channel = items[0]
			cm = ChannelMember.where(ref_channel_id: channel.id, ref_user_id: session[:userinfo][:id]).first

			categories = []
			channel.categories.each {|c|
				if c.ref_category_id == nil
					sub_categories = []
					c.categories.each {|sub|
						sub_categories.push({
							uqid: sub.uqid,
							name: sub.name,
							priority: sub.priority,
							logo: sub.logo ? get_image('channel_category', { uqid: sub.uqid }) : nil,
							category_size: sub.categories.size,
							knowledge_size: sub.knowledges.size
						})
					}

					items = CategoryKnowledge.find_by_sql(
						"select k.id, k.uqid, k.name, ck.priority, k.last_update, k.is_public, r.id reader_id, u.uqid u_uqid, u.first_name, u.last_name, u.userid, u.nouser
						from category_knowledge ck
							join category ca on ca.id = ck.ref_category_id
							join knowledge k on k.id = ck.ref_know_id
							join draft_knowledge dk on dk.uqid = k.uqid
							left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
							left join \"user\" u on u.id = dke.ref_user_id
							left join reader r on r.ref_know_id = k.id and r.ref_user_id = #{session[:userinfo][:id]} and r.is_archived != true
						where ca.id = #{c.id}
						order by ck.priority")

					sub_knowledges = []
					items.each {|item|
						sub_knowledges.push({
							uqid: item.uqid,
							name: item.name,
							priority: item.priority,
							is_public: item.is_public,
							last_update: item.last_update,
							subscribed: session[:userinfo] == nil ? false : (item.reader_id != nil ? true : false),
							logo: get_image('knowledge', { uqid: item.uqid }),
							page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
							editor: {
								first_name: item.first_name,
								last_name: item.last_name,
								full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
								page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
							}
						})
					}

					categories.push({
						uqid: c.uqid,
						name: c.name,
						priority: c.priority,
						logo: c.logo ? get_image('channel_category', { uqid: c.uqid }) : nil,
						categories: sub_categories,
						knowledges: sub_knowledges,
						category_size: sub_categories.size,
						knowledge_size: sub_knowledges.size
					})
				end
			}

			content = {
				uqid: channel.uqid,
				name: channel.name,
				description: channel.description,
				logo: get_image('channel', { uqid: channel.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/channel/#{channel.uqid}",
				categories: categories,
				editable: (cm.role == 'owner' or cm.role == 'admin') ? true : false,
				max_category_priority: Category.where(ref_channel_id: channel.id, ref_category_id: nil).maximum('priority')
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def create_channel
		user = User.where(id: session[:userinfo][:id]).first

		if !['pro', 'vip'].include?(user.account_type)
			render :json => { error: '建立頻道功能只限 Pro 或 Vip 帳號使用，請升級至 Pro 或 VIP 帳號!' }
		else
			params[:name] = "New Channel" if params[:name] == nil or params[:name] == ''

			item = Channel.new
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name]
			item.description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
			item.logo = params[:logo] != nil ? params[:logo] : DEFAULT_LOGO
			item.last_update = Time.now
			item.save()

			set_image('channel', { uqid: item.uqid, logo: item.logo })

			cm = ChannelMember.new
			cm.ref_channel_id = item.id
			cm.ref_user_id = session[:userinfo][:id]
			cm.uqid = UUID.new.generate.split('-')[0..1].join('')
			cm.order = 1
			cm.role = 'owner'
			cm.status = 'approved'
			cm.save()

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				last_update: item.last_update,
				logo: get_image('channel', { uqid: item.uqid })
			}

			render :json => content
		end
	end

	def update_channel
		item = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			item.name = params[:name] if params[:name] and params[:name] != ''
			item.description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
			item.logo = params[:logo] if params[:logo] != nil
			item.last_update = Time.now
			item.save()

			set_image('channel', { uqid: item.uqid, logo: item.logo })

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				last_update: item.last_update,
				logo: item.logo
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_channel
		item = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_category
		category = Category.find_by_sql(
			"select ca.*, cm.role
			from category ca
				join channel cl on cl.id = ca.ref_channel_id
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role != 'member'
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'
				and ca.uqid = '#{params[:itemUqid]}'").first

		if category != nil
			sub_categories = []
			category.categories.each {|sub|
				sub_categories.push({
					uqid: sub.uqid,
					name: sub.name,
					priority: sub.priority,
					logo: sub.logo ? get_image('channel_category', { uqid: sub.uqid }) : nil,
					category_size: sub.categories.size,
					knowledge_size: sub.knowledges.size
				})
			}

			items = Knowledge.find_by_sql(
				"select k.id, k.uqid k_uqid, k.name, ck.uqid, ck.priority, ck.url, k.last_update, k.is_public, k.total_time, u.uqid u_uqid, u.first_name, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
				from category_knowledge ck
					join category ca on ca.id = ck.ref_category_id
					join knowledge k on k.id = ck.ref_know_id
					join draft_knowledge dk on dk.uqid = k.uqid
					left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
					left join \"user\" u on u.id = dke.ref_user_id
					left join (select r.ref_know_id, count(r.id) reader_size,
							sum(case when r.rating is null then 0 else r.rating end) total_rate,
							sum(case when r.rating is null then 0 else 1 end) rate_count,
							case when sum(case when r.rating is null then 0 else 1 end) <> 0
								then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
								else 0 end average_rate
						from reader r
						group by r.ref_know_id) as r on r.ref_know_id = k.id
				where ca.id = #{category.id}
				order by ck.priority")

			sub_knowledges = []
			items.each {|item|
				reader = Reader.find_by_sql(
					"select count(r.id) reader_size,
						sum(case when r.rating is null then 0 else r.rating end) total_rate,
						sum(case when r.rating is null then 0 else 1 end) rate_count
					from reader r
					where r.ref_know_id = #{item.id}").first

				sub_knowledges.push({
					uqid: item.uqid,
					name: item.name,
					last_update: item.last_update,
					priority: item.priority,
					is_public: item.is_public,
					total_time: item.total_time.to_i,
					readers: item.reader_size || 0,
					rate_count: item.rate_count || 0,
					total_rate: item.total_rate || 0,
					average_rate: item.average_rate || 0,
					url: item.url,
					logo: get_image('knowledge', { uqid: item.k_uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
					editor: {
						first_name: item.first_name,
						last_name: item.last_name,
						full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
						page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
					}
				})
			}

			content = {
				uqid: category.uqid,
				name: category.name,
				categories: sub_categories,
				knowledges: sub_knowledges,
				logo: category.logo ? get_image('channel_category', { uqid: category.uqid }) : nil,
				max_category_priority: Category.where(ref_channel_id: category.ref_channel_id, ref_category_id: category.id).maximum('priority'),
				max_knowledge_priority: CategoryKnowledge.where(ref_channel_id: category.ref_channel_id, ref_category_id: category.id).maximum('priority')
			}

			render :json => content
		else
			render :json => []
		end
	end

	def create_category
		channel = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'").first

		if channel != nil
			params[:name] = "New Category" if params[:name] == nil or params[:name] == ''
			parent = Category.select('id, uqid').where(['uqid = ? and ref_channel_id = ?', params[:parent_uqid], channel.id]).first

			if parent == nil
				priority = Category.where(ref_channel_id: channel.id, ref_category_id: nil).maximum('priority')
			else
				priority = Category.where(ref_channel_id: channel.id, ref_category_id: parent.id).maximum('priority')
			end

			item = Category.new
			item.ref_channel_id = channel.id
			item.ref_category_id = parent.id if parent != nil
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name]
			item.priority = (priority == nil ? 1 : priority + 1)
			item.logo = params[:logo] != nil ? params[:logo] : DEFAULT_LOGO
			item.save()

			channel.last_update = Time.now
			channel.save()

			set_image('channel_category', { uqid: item.uqid, logo: item.logo })

			content = {
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				logo: get_image('channel_category', { uqid: item.uqid }),
				category_size: item.categories.size,
				knowledge_size: item.knowledges.size
			}

			render :json => content
		else
			render :json => { eroor: 'Error!' }
		end
	end

	def update_category
		item = Category.find_by_sql(
			"select ca.*, cm.role
			from category ca
				join channel cl on cl.id = ca.ref_channel_id
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'
				and ca.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			if params[:priority] != nil
				priority = params[:priority].to_i
				if priority > item.priority
					if item.ref_category_id == nil
						ActiveRecord::Base.connection.execute(
							"update category set priority = priority - 1
							where priority > #{item.priority} and priority <= #{priority} and ref_channel_id = #{item.ref_channel_id}")
					else
						ActiveRecord::Base.connection.execute(
							"update category set priority = priority - 1
							where priority > #{item.priority} and priority <= #{priority} and ref_category_id = #{item.ref_category_id}")
					end
				else
					if item.ref_category_id == nil
						ActiveRecord::Base.connection.execute(
							"update category set priority = priority + 1
							where priority < #{item.priority} and priority >= #{priority} and ref_channel_id = #{item.ref_channel_id}")
					else
						ActiveRecord::Base.connection.execute(
							"update category set priority = priority + 1
							where priority < #{item.priority} and priority >= #{priority} and ref_category_id = #{item.ref_category_id}")
					end
				end

				item.priority = priority
			end

			item.name = params[:name] if params[:name] != nil and params[:name] != ''
			item.logo = params[:logo] if params[:logo] != nil and params[:logo] != ''
			item.save()

			set_image('channel_category', { uqid: item.uqid, logo: item.logo })

			channel = item.channel
			channel.last_update = Time.now
			channel.save()

			content = {
				uqid: item.uqid,
				name: item.name,
				priority: item.priority,
				logo: get_image('channel_category', { uqid: item.uqid }),
				category_size: item.categories.size,
				knowledge_size: item.knowledges.size
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_category
		item = Category.find_by_sql(
			"select ca.*, cm.role
			from category ca
				join channel cl on cl.id = ca.ref_channel_id
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'
				and ca.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			if item.ref_category_id == nil
				ActiveRecord::Base.connection.execute(
					"update category set priority = priority - 1
					where priority > #{item.priority} and ref_channel_id = #{item.ref_channel_id}")
			else
				ActiveRecord::Base.connection.execute(
					"update category set priority = priority - 1
					where priority > #{item.priority} and ref_category_id = #{item.ref_category_id}")
			end

			channel = item.channel
			channel.last_update = Time.now
			channel.save()

			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def add_category_knowledge
		category = Category.find_by_sql(
			"select ca.*, cm.role
			from category ca
				join channel cl on cl.id = ca.ref_channel_id
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role != 'member'
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'
				and ca.uqid = '#{params[:categoryUqid]}'").first

		uqid = params[:url].split('/knowledge/')[1]
		uqid = uqid ? uqid.split('?')[0]: 'not found'
		know = Knowledge.where(['code =? or uqid = ?', params[:url], uqid]).first

		if category != nil and know != nil
			priority = CategoryKnowledge.where(ref_category_id: category.id).maximum('priority')

			item = CategoryKnowledge.new
			item.ref_category_id = category.id
			item.ref_know_id = know.id
			item.ref_channel_id = category.ref_channel_id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.url = params[:url]
			item.priority = (priority == nil ? 1 : priority + 1)
			item.save()

			channel = item.channel
			channel.last_update = Time.now
			channel.save()

			item = Knowledge.find_by_sql(
				"select k.id, k.uqid k_uqid, k.name, ck.uqid, ck.priority, ck.url, k.last_update, k.is_public, k.total_time, u.uqid u_uqid, u.first_name, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
				from category_knowledge ck
					join category ca on ca.id = ck.ref_category_id
					join knowledge k on k.id = ck.ref_know_id
					join draft_knowledge dk on dk.uqid = k.uqid
					left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
					left join \"user\" u on u.id = dke.ref_user_id
					left join (select r.ref_know_id, count(r.id) reader_size,
							sum(case when r.rating is null then 0 else r.rating end) total_rate,
							sum(case when r.rating is null then 0 else 1 end) rate_count,
							case when sum(case when r.rating is null then 0 else 1 end) <> 0
								then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
								else 0 end average_rate
						from reader r
						group by r.ref_know_id) as r on r.ref_know_id = k.id
				where k.id = #{know.id}").first

			content = {
				uqid: item.uqid,
				name: item.name,
				last_update: item.last_update,
				priority: item.priority,
				is_public: item.is_public,
				total_time: item.total_time.to_i,
				readers: item.reader_size || 0,
				rate_count: item.rate_count || 0,
				total_rate: item.total_rate || 0,
				average_rate: item.average_rate || 0,
				url: item.url,
				logo: get_image('knowledge', { uqid: item.k_uqid }),
				page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
				editor: {
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
				}
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_category_knowledge
		item = CategoryKnowledge.find_by_sql(
			"select ck.*
			from category_knowledge ck
				join category ca on ca.id = ck.ref_category_id
				join channel cl on cl.id = ca.ref_channel_id
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role != 'member'
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'
				and ca.uqid = '#{params[:categoryUqid]}'
				and ck.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			know = Knowledge.find_by_sql("select id, uqid, name from knowledge where uqid = '#{params[:url].split('/knowledge/')[1].split('?')[0]}'").first

			if know != nil
				if params[:priority] != nil
					priority = params[:priority].to_i
					if priority > item.priority
						ActiveRecord::Base.connection.execute(
							"update category_knowledge set priority = priority - 1
							where priority > #{item.priority} and priority <= #{priority} and ref_category_id = #{item.ref_category_id}")
					else
						ActiveRecord::Base.connection.execute(
							"update category_knowledge set priority = priority + 1
							where priority < #{item.priority} and priority >= #{priority} and ref_category_id = #{item.ref_category_id}")
					end

					item.priority = priority
				end

				item.ref_know_id = know.id if know != nil
				item.url = params[:url] if params[:url] != nil
				item.save()

				channel = item.channel
				channel.last_update = Time.now
				channel.save()

				content = {
					uqid: item.uqid,
					name: know.name,
					url: item.url,
					priority: item.priority,
					category: {
						uqid: item.category.uqid,
						name: item.category.name
					},
					knowledge: {
						uqid: know.uqid,
						name: know.name
					}
				}

				render :json => content
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def remove_category_knowledge
		category = CategoryKnowledge.find_by_sql(
			"select ck.*
			from category_knowledge ck
				join category ca on ca.id = ck.ref_category_id
				join channel cl on cl.id = ca.ref_channel_id
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role != 'member'
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'
				and ca.uqid = '#{params[:categoryUqid]}'
				and ck.uqid = '#{params[:itemUqid]}'").first

		if category != nil
			if item.ref_category_id == nil
				ActiveRecord::Base.connection.execute(
					"update category_knowledge set priority = priority - 1
					where priority > #{item.priority} and ref_category_id = #{item.ref_category_id}")
			else
				ActiveRecord::Base.connection.execute(
					"update category_knowledge set priority = priority - 1
					where priority > #{item.priority} and ref_category_id = #{item.ref_category_id}")
			end

			channel = item.channel
			channel.last_update = Time.now
			channel.save()

			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_channel_member
		keyword = params[:keyword] != nil ? "and (lower(u.first_name) like lower('%#{params[:keyword]}%') or lower(u.last_name) like lower('%#{params[:keyword]}%') or lower(u.userid) like lower('%#{params[:keyword]}%'))" : ""

		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20

		status = params[:status] != nil ? params[:status] : ""
		status = '' if status == 'all'
		status = "and cm.status = 'approved'" if status == 'approved'
		status = "and cm.status = 'rejection'" if status == 'rejection'

		role = params[:role] != nil ? params[:role] : ""
		role = '' if role == 'all'
		role = "and cm.role = 'admin'" if role == 'admin'
		role = "and cm.role = 'editor'" if role == 'editor'
		role = "and cm.role = 'member'" if role == 'member'

		offset = "offset #{start_index} limit #{max_results}"
		offset = '' if keyword != ''

		condition = "where cl.uqid = '#{params[:channelUqid]}'"
		condition = "#{condition} and cm.uqid = '#{params[:itemUqid]}'" if params[:itemUqid] != nil

		items = ChannelMember.find_by_sql(
			"select cm.*, u.uqid user_uqid, u.userid, u.first_name, u.last_name, u.nouser, u.photo
			from channel_member cm
				join channel cl on cl.id = cm.ref_channel_id
				join \"user\" u on u.id = cm.ref_user_id
			#{condition} #{status} #{role} #{keyword}
			order by cm.order
			#{offset}")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				user_uqid: item.user_uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
				order: item.order,
				role: item.role,
				status: item.status,
				photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.user_uqid}",
				nouser: item.nouser
			})
		}

		render :json => content
	end

	def add_channel_member
		cm = ChannelMember.find_by_sql(
			"select cm.*
			from channel_member cm
				join channel cl on cl.id = cm.ref_channel_id
				join \"user\" u on u.id = cm.ref_user_id
			where cl.uqid = '#{params[:channelUqid]}' and u.userid = '#{params[:email].downcase}'").first

		channel = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.uqid = '#{params[:channelUqid]}'").first

		if cm == nil and channel != nil
			user = User.where(userid: params[:email].downcase).first

			order = ChannelMember.where(ref_channel_id: channel.id).maximum('order')

			item = ChannelMember.new
			item.ref_channel_id = channel.id
			item.ref_user_id = user.id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.order = (order == nil ? 1 : order + 1)
			item.role = 'admin'
			item.status = 'approved'
			item.save()

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_channel_member
		cm = ChannelMember.find_by_sql(
			"select cm.*
			from channel_member cm
				join channel cl on cl.id = cm.ref_channel_id
			where cl.uqid = '#{params[:channelUqid]}' and cm.uqid = '#{params[:itemUqid]}'").first

		channel = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.id = '#{cm.ref_channel_id}'").first

		if cm != nil
			if cm.ref_user_id != session[:userinfo][:id]
				if channel != nil and cm.role != 'owner'
					if params[:order]
						order = params[:order].to_i

						if order > cm.order
							ActiveRecord::Base.connection.execute(
								"update channel_member set \"order\" = \"order\" - 1
								where \"order\" > #{cm.order} and \"order\" <= #{order} and ref_channel_id = #{channel.id}")
						else
							ActiveRecord::Base.connection.execute(
								"update channel_member set \"order\" = \"order\" + 1
								where \"order\" < #{cm.order} and \"order\" >= #{order} and ref_channel_id = #{channel.id}")
						end

						cm.order = order
						cm.save()
					end

					if params[:role] == 'admin' or params[:role] == 'editor' or params[:role] == 'member'
						cm.role = params[:role]
						cm.save()
					end

					if params[:status] == 'approved'
						cm.status = params[:status]
						cm.save()
					end

					if params[:status] == 'rejection'
						ActiveRecord::Base.connection.execute(
							"update channel_member set \"order\" = \"order\" - 1
							where \"order\" > #{cm.order} and ref_channel_id = #{channel.id}")

						cm.destroy
					end
				end
			end
		end

		item = ChannelMember.find_by_sql(
			"select cm.uqid, cm.order, cm.role, cm.status, u.uqid user_uqid, u.userid, u.first_name, u.last_name, u.nouser, u.photo
			from channel_member cm
				join channel cl on cl.id = cm.ref_channel_id
				join \"user\" u on u.id = cm.ref_user_id
			where cm.id = #{cm.id}
			order by cm.order").first

		if item != nil
			content = {
				uqid: item.uqid,
				user_uqid: item.user_uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
				order: item.order,
				role: item.role,
				status: item.status,
				photo: get_image('user', { uqid: item.user_uqid, nouser: item.nouser, type: 'photo' }),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.user_uqid}",
				nouser: item.nouser
			}
		else
			content = nil
		end

		render :json => content
	end

	def remove_channel_member
		cm = ChannelMember.find_by_sql(
			"select cm.*
			from channel_member cm
				join channel cl on cl.id = cm.ref_channel_id
			where cl.uqid = '#{params[:channelUqid]}' and cm.uqid = '#{params[:itemUqid]}'").first

		channel = Channel.find_by_sql(
			"select cl.*, cm.role
			from channel cl
				join channel_member cm on cm.ref_channel_id = cl.id
			where cm.status = 'approved'
				and cm.role in ('owner', 'admin')
				and cm.ref_user_id = #{session[:userinfo][:id]}
				and cl.id = '#{cm.ref_channel_id}'").first

		if cm != nil and channel != nil
			ActiveRecord::Base.connection.execute(
				"update channel_member set \"order\" = \"order\" - 1
				where \"order\" > #{cm.order} and ref_channel_id = #{cm.ref_channel_id}")

			cm.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	private

	def update_know(unit)
		dk = unit.chapter.knowledge
		du = DraftUnit.find_by_sql(
			"select sum(u.content_time) total_time
			from draft_unit u
				left join draft_chapter ch on ch.id = u.ref_chapter_id
			where ch.ref_know_id = #{dk.id}").first

		if du != nil
			dk.total_time = du.total_time
			dk.last_update = Time.now
			dk.save()
		end
	end
end