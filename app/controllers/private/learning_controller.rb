require "uuid"

class Private::LearningController < ApplicationController
	before_filter :check_session

	def query_study_history
		render :json => { dates: [], rows: [] } if params[:type] == nil

		if params[:type] == 'knowledge'
			target = Knowledge.where(uqid: params[:itemUqid]).first
		elsif params[:type] == 'activity'
			target = GroupActivity.where(uqid: params[:itemUqid]).first

			if target != nil
				goal = JSON.parse(target.goal)
				units = []
				goal.each {|u| units.push(u['unit']['uqid']) }
			end
		end

		if target != nil
			days = params[:days].to_i
			
			if days != 0 and days != 1
				now = Time.now
				
				dates = []
				days.times {|day|
					dates.push((now - (60 * 60 * 24 * (days - day - 1))).to_s[0, 10])
				}
				columns = []
				dates.each {|date|
					columns.push("round(sum(case to_char(vh.time_watched::timestamp + interval '#{params[:timezone]} hours', 'YYYY-MM-DD') when '#{date}' then vh.seconds_watched / 60 else 0 end)) as \"#{date}\"")
				}

				if params[:type] == 'knowledge'
					rows = ViewHistory.find_by_sql(
						"select #{columns.join(', ')}
						from view_history vh
						where vh.ref_know_id = #{target.id} and vh.ref_user_id = #{session[:userinfo][:id]}")
				elsif params[:type] == 'activity'
					rows = ViewHistory.find_by_sql(
						"select #{columns.join(', ')}
						from view_history vh
							join unit u on vh.ref_unit_id = u.id
						where u.uqid in ('#{units.join("','")}') and vh.ref_user_id = #{session[:userinfo][:id]}")
				end

				dates.each {|date|
					rows.each {|row|
						row[date] = row[date].to_f
					}
				}

				render :json => { dates: dates, rows: rows }
			elsif days == 0 or days == 1
				if params[:days].to_i == 0
					now = Time.now
				elsif params[:days].to_i == 1
					now = (Time.now - (60 * 60 * 24)).to_s[0, 10]
				end

				dates = []
				24.times {|time|
					if time < 10
						dates.push("#{now.to_s[0, 10]} 0#{time}")
					else
						dates.push("#{now.to_s[0, 10]} #{time.to_s}")
					end
				}
				columns = []
				dates.each {|date|
					columns.push("round(sum(case to_char(vh.time_watched::timestamp + interval '#{params[:timezone]} hours', 'YYYY-MM-DD HH24') when '#{date}' then vh.seconds_watched / 60 else 0 end)) as \"#{date[11, 2]}\"")
				}

				if params[:type] == 'knowledge'
					rows = ViewHistory.find_by_sql(
						"select #{columns.join(', ')}
						from view_history vh
						where vh.ref_know_id = #{target.id} and vh.ref_user_id = #{session[:userinfo][:id]}")
				elsif params[:type] == 'activity'
					rows = ViewHistory.find_by_sql(
						"select #{columns.join(', ')}
						from view_history vh
							join unit u on vh.ref_unit_id = u.id
						where u.uqid in ('#{units.join("','")}') and vh.ref_user_id = #{session[:userinfo][:id]}")
				end

				times = []
				dates.each {|date|
					time = date[11, 2]
					times.push time
					rows.each {|row|
						row[time] = row[time].to_f
					}
				}

				render :json => { dates: times, rows: rows }
			end
		else
			render :json => { dates: [], rows: [] }
		end
	end

	def list_knowledge
		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20
		offset = "offset #{start_index} limit #{max_results}" if params['max-results'] != 'unlimit'
		offset = '' if params[:notes] == 'true'

		condition = "where r.ref_user_id = #{session[:userinfo][:id]} and r.is_archived != true"
		condition = "#{condition} and k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil
		condition = "#{condition} and lower(k.name) like lower('%#{params[:keyword]}%')" if params[:keyword] != nil
		condition = "#{condition} and c.name is null" if params[:category] == 'unclassified'
		condition = "#{condition} and current_timestamp + '-7 days' < us.last_view_time" if params[:category] == 'last_7_day'
		condition = "#{condition} and last_view_time is null" if params[:category] == 'new_order'
		condition = "#{condition} and category_uqid = '#{params[:category].split('_')[1]}'" if params[:category] != nil and params[:category].split('_')[0] == 'category'

		items = Reader.find_by_sql(
			"select k.id, k.uqid, k.name, k.is_public, k.is_destroyed, k.description, k.code, r.approve_code, r.rating, r.hashtag, k.total_time,
				us.last_view_time, k.last_update last_update_time, r.last_update reader_last_update, n.notes, c.name category_name
			from reader r
				join knowledge k on r.ref_know_id = k.id
				left join (select max(us.last_view_time) last_view_time, us.ref_know_id from unit_status us
							where us.ref_user_id = #{session[:userinfo][:id]}
							group by us.ref_know_id) as us on us.ref_know_id = k.id
				left join (select count(b.id) notes, u.ref_know_id from bookmark b
								join unit u on u.id = b.ref_unit_id
							where b.ref_user_id = #{session[:userinfo][:id]}
							group by u.ref_know_id) as n on n.ref_know_id = k.id
				left join user_reader_category c on c.uqid = r.category_uqid
			#{condition}
			order by last_view_time desc nulls first, reader_last_update desc nulls last, last_update_time desc
			#{offset}")

		if params[:knowUqid] == nil
			content = []
			items.each {|item|
				tmp = {
					uqid: item.uqid,
					name: item.name,
					code: item.code,
					approve_code: item.approve_code,
					description: item.description,
					privacy: item.is_public,
					destroyed: item.is_destroyed == nil ? false : item.is_destroyed,
					total_time: item.total_time.to_f,
					rating: item.rating == nil ? 0 : item.rating.to_i,
					note_size: item.notes,
					last_update_time: item.last_update_time != nil ? item.last_update_time.to_datetime : nil,
					last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
					category_name: item.category_name || '*****'
				}

				if params[:notes] == 'true'
					if item.notes != nil && item.notes > 0
						tmp[:note_size] = item.notes
						content.push(tmp) 
					end
				else
					content.push(tmp)
				end
			}

			render :json => content
		elsif params[:knowUqid] != nil and items.size == 1
			item = items[0]

			items = DraftKnowledgeEditor.find_by_sql(
				"select u.uqid, u.userid, u.first_name, u.last_name, u.nouser, u.photo
				from draft_knowledge_editor dke
					join \"user\" u on u.id = dke.ref_user_id
					join draft_knowledge dk on dk.id = dke.ref_know_id
					join knowledge k on k.uqid = dk.uqid
				where k.id = #{item.id} and (dke.is_show = true or dke.role = 'owner')
				order by dke.order")

			editors = []
			items.each {|e|
				editors.push({
					uqid: e.uqid,
					email: e.userid,
					first_name: e.first_name,
					last_name: e.last_name,
					full_name: parse_full_name(e.first_name, e.last_name, e.userid, e.nouser),
					nouser: e.nouser,
					photo: get_image('user', { uqid: e.uqid, nouser: e.nouser, type: 'photo' }),
					page: "#{request.protocol}#{request.host_with_port}/user/#{e.uqid}"
				})
			}

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
				code: item.code,
				approve_code: item.approve_code,
				description: item.description,
				privacy: item.is_public,
				destroyed: item.is_destroyed == nil ? false : item.is_destroyed,
				total_time: item.total_time.to_f,
				rating: item.rating == nil ? 0 : item.rating.to_i,
				note_size: item.notes,
				last_update_time: item.last_update_time != nil ? item.last_update_time.to_datetime : nil,
				last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
				logo: get_image('knowledge', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
				share_page: "#{request.protocol}#{request.host_with_port}/watch?k=#{item.uqid}",
				editors: editors,
				groups: groups,
				channels: channels
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_knowledge_size
		item = Reader.find_by_sql(
			"select count(k.id) total_size,
				count(k.id) - count(us1.ref_know_id) new_order_size,
				count(us2.ref_know_id) last_7day_size,
				sum(case when c.name is null then 1 else 0 end) unclassified_size
			from reader r
				join knowledge k on r.ref_know_id = k.id
				left join (select max(us.last_view_time) last_view_time, k.id ref_know_id from knowledge k
							left join unit_status us on us.ref_know_id = k.id
							where us.ref_user_id = #{session[:userinfo][:id]}
							group by k.id) as us1 on us1.ref_know_id = k.id
				left join (select max(us.last_view_time) last_view_time, us.ref_know_id from unit_status us
							where us.ref_user_id = #{session[:userinfo][:id]} and current_timestamp + '-7 days' < us.last_view_time
							group by us.ref_know_id) as us2 on us2.ref_know_id = k.id
				left join user_reader_category c on c.uqid = r.category_uqid
			where r.ref_user_id = #{session[:userinfo][:id]} and r.is_archived != true").first

		content = {
			total_size: item.total_size || 0,
			new_order_size: item.new_order_size || 0,
			last_7day_size: item.last_7day_size || 0,
			unclassified_size: item.unclassified_size || 0
		}

		render :json => content
	end

	def subscribe_knowledge
		know = Knowledge.where(['code = ? or uqid = ?', params[:knowUqid].upcase, params[:knowUqid].downcase]).first
		
		if know != nil and !know.is_destroyed
			item = Reader.where(['ref_user_id = ? and ref_know_id = ?', session[:userinfo][:id], know.id]).first
			
			if item != nil
				item.is_archived = false
				item.save()
			else
				item = Reader.new
				item.ref_user_id = session[:userinfo][:id]
				item.ref_know_id = know.id
				item.approve_code = know.code
				item.is_archived = false
				item.last_update = Time.now()
				item.save()
			end

			render :json => know, :only => ['uqid', 'code']
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def unsubscribe_knowledge
		know = Knowledge.where(['uqid = ?', params[:knowUqid]]).first

		if know != nil
			item = Reader.where(['ref_user_id = ? and ref_know_id = ?', session[:userinfo][:id], know.id]).first

			if item != nil
				item.is_archived = true
				item.save

				render :json => { success: "Well done!" }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def rate_knowledge
		know = Knowledge.where(['uqid = ?', params[:knowUqid]]).first

		if know != nil
			reader = Reader.where(['ref_know_id = ? and ref_user_id = ?', know.id, session[:userinfo][:id]]).first

			if reader != nil and params[:rating].to_i <= 5 and params[:rating].to_i > 0
				reader.rating = params[:rating]
				reader.save()

				render :json => { rating: reader.rating }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_category
		items = UserReaderCategory.find_by_sql(
			"select c.uqid, c.name, count(r.id) know_size
			from user_reader_category c
				left join reader r on r.category_uqid = c.uqid and r.is_archived != true
			where c.ref_user_id = #{session[:userinfo][:id]}
			group by c.uqid, c.name
			order by c.name")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				know_size: item.know_size
			})
		}

		render :json => content
	end

	def create_category
		params[:name] = "New Category" if params[:name] == nil or params[:name] == ''

		item = UserReaderCategory.new
		item.uqid = UUID.new.generate.split('-')[0..1].join('')
		item.name = params[:name]
		item.ref_user_id = session[:userinfo][:id]
		item.save

		content = {
			uqid: item.uqid,
			name: item.name
		}

		render :json => content
	end

	def update_category
		item = UserReaderCategory.find_by_sql(
			"select c.id, c.uqid, c.name
			from user_reader_category c
				left join reader r on r.category_uqid = c.uqid and r.is_archived != true
			where c.ref_user_id = #{session[:userinfo][:id]}
				and c.uqid = '#{params[:itemUqid]}'
			order by c.name").first

		if item != nil
			item.name = (params[:name] != nil and params[:name] != '') ? params[:name] : item.name
			item.save

			content = {
				uqid: item.uqid,
				name: item.name
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_category
		item = UserReaderCategory.find_by_sql(
			"select c.id, c.uqid, c.name
			from user_reader_category c
				left join reader r on r.category_uqid = c.uqid and r.is_archived != true
			where c.ref_user_id = #{session[:userinfo][:id]}
				and c.uqid = '#{params[:itemUqid]}'
			order by c.name").first

		item.destroy if item != nil

		render :json => { success: "Well done!" }
	end

	def set_category
		reader = Reader.find_by_sql(
			"select r.*
			from (select * from reader where ref_user_id = #{session[:userinfo][:id]}) r
				left join knowledge k on k.id = r.ref_know_id
			where k.uqid = '#{params[:knowUqid]}'").first

		category = UserReaderCategory.where({uqid: params[:itemUqid]}).first

		if reader != nil
			if category != nil
				reader.category_uqid = category.uqid
				reader.save()

				content = {
					uqid: category.uqid,
					name: category.name
				}

				render :json => content
			else
				reader.category_uqid = nil
				reader.save()

				render :json => { success: "Well done!" }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def add_study_history
		unit = Unit.where(['uqid = ?', params[:unitUqid]]).first

		if unit != nil and params[:last_second_watched] != nil and params[:seconds_watched] != nil
			vh = ViewHistory.new
			vh.ref_user_id = session[:userinfo][:id]
			vh.ref_unit_id = unit.id
			vh.ref_know_id = unit.ref_know_id
			vh.last_second_watched = params[:last_second_watched]
			vh.seconds_watched = params[:seconds_watched]
			vh.time_watched = Time.now
			vh.save()

			us = update_unit_status(unit, vh.seconds_watched)
			
			vh_out = {
				last_second_watched: vh.last_second_watched.to_f,
				seconds_watched: vh.seconds_watched.to_f,
				time_watched: vh.time_watched.to_datetime
			}

			us_out = {
				status: us.status.to_i,
				gained: us.gained.to_f,
				total: us.total.to_f,
				last_view_time: us.last_view_time.to_datetime
			}

			render :json => { vh: vh_out, us: us_out }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_study_result
		unit = Unit.where(['uqid = ?', params[:unitUqid]]).first

		if unit != nil and params[:content] != nil
			sr = StudyResult.where(ref_user_id: session[:userinfo][:id], ref_unit_id: unit.id).first

			if sr == nil
				sr = StudyResult.new
				sr.ref_user_id = session[:userinfo][:id]
				sr.ref_unit_id = unit.id
				sr.ref_know_id = unit.ref_know_id
				sr.content = params[:content]
				sr.learning_time = Time.now
				sr.save()
			else
				sr.content = params[:content]
				sr.learning_time = Time.now
				sr.save()
			end
			
			render :json => { content: JSON.parse(sr.content), learning_time: sr.learning_time }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def set_unit_status
		unit = Unit.where(['uqid = ?', params[:unitUqid]]).first
		status = params[:status].to_i if params[:status] != nil
		status = 0 if status != 2 and status != 4

		if unit != nil
			us = UnitStatus.where(['ref_user_id = ? and ref_unit_id = ?', session[:userinfo][:id], unit.id]).first

			if us == nil
				us = UnitStatus.new
				us.ref_user_id = session[:userinfo][:id]
				us.ref_unit_id = unit.id
				us.ref_know_id = unit.chapter.knowledge.id
				us.status = 2
				us.gained = 0
				us.total = 0
			end

			us.gained = 0 if us.gained == nil
			us.total = unit.content_time

			us.status = status 
			us.last_view_time = Time.now
			us.save()

			us.gained = us.gained.to_f
			us.total = us.total.to_f
			us.last_view_time = us.last_view_time.to_datetime

			render :json => { gained: us.gained, total: us.total, status: us.status }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_unit
		condition = "where r.ref_user_id = #{session[:userinfo][:id]} and u.is_destroyed is null"
		condition = "#{condition} and k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil
		condition = "#{condition} and u.uqid = '#{params[:unitUqid]}'" if params[:unitUqid] != nil

		items = Unit.find_by_sql(
			"select k.uqid k_uqid, k.name k_name, ch.uqid ch_uqid, ch.name ch_name, ch.priority ch_priority,
				u.id, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time, u.supplementary_description, u.content,
				us.status, us.last_view_time, us.gained gained_time, us.total total_time,
				array_agg(uf.group_uqid) group_uqid, array_agg(uf.group_name) group_name, array_agg(uf.score) score, array_agg(uf.comment) as comment
			from unit u
				left join chapter ch on ch.id = u.ref_chapter_id
				left join knowledge k on k.id = ch.ref_know_id
				left join reader r on r.ref_know_id = k.id
				left join unit_status us on us.ref_unit_id = u.id and us.ref_user_id = #{session[:userinfo][:id]}
				left join (select g.uqid group_uqid, g.name group_name, uf.score, uf.comment, uf.ref_unit_id
					from unit_feedback uf
					left join \"group\" g on uf.ref_group_id = g.id
					where uf.ref_user_id = #{session[:userinfo][:id]}) as uf on uf.ref_unit_id = u.id
			#{condition}
			group by k.uqid, k.name, ch.uqid, ch.name, ch.priority,
				u.id, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time, u.supplementary_description, u.content,
				us.status, us.last_view_time, us.gained, us.total
			order by ch.priority, u.priority")
		
		content = []
		items.each {|item|
			sr = StudyResult.where(ref_user_id: session[:userinfo][:id], ref_unit_id: item.id).first
			vh = ViewHistory.where(ref_user_id: session[:userinfo][:id], ref_unit_id: item.id).order('id desc').first

			content.push({
				uqid: item.uqid,
				name: item.name,
				unit_type: item.unit_type,
				content_url: item.content_url,
				content_time: item.content_time.to_f,
				priority: item.priority.to_i,
				description: item.supplementary_description,
				content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
				total_time: item.total_time.to_f,
				gained_time: item.gained_time.to_f,
				progress: (item.gained_time.to_f / item.total_time.to_f).nan? ? 0 : ((item.gained_time.to_f / item.total_time.to_f) > 1 ? 100 : (item.gained_time.to_f / item.total_time.to_f * 100).round(2)),
				status: item.status.to_i,
				last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
				last_second_watched: vh != nil ? vh.last_second_watched : 0,
				chapter: {
					uqid: item.ch_uqid,
					name: item.ch_name,
					priority: item.ch_priority
				},
				feedback: {
					uqid: item.group_uqid,
					name: item.group_name,
					score: item.score,
					comment: item.comment,
				},
				study_result: sr != nil ? JSON.parse(sr.content) : nil,
				learning_time: sr != nil ? sr.learning_time : nil
			})
		}

		render :json => content
	end

	def list_quiz
		condition = "where k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil
		condition = "where u.uqid = '#{params[:unitUqid]}'" if params[:unitUqid] != nil
		condition = "where q.uqid = '#{params[:quizUqid]}'" if params[:quizUqid] != nil

		items = Question.find_by_sql(
			"select q.*
			from question q
				join unit u on u.id = q.ref_unit_id
				join chapter c on c.id = u.ref_chapter_id
				join knowledge k on k.id = c.ref_know_id
			#{condition} and q.is_destroyed is null
			order by q.q_no")

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
				video_time: item.video_time.to_i,
				explain: item.explain,
				explain_url: item.explain_url
			})
		}

		render :json => content
	end

	def export_note
		condition = "where n.ref_user_id = #{session[:userinfo][:id]}"
		condition = "#{condition} and k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil

		items = Note.find_by_sql(
			"select n.uqid, n.video_time, n.content, n.content_type, k.uqid k_uqid, k.name k_name, u.uqid u_uqid, u.name u_name
			from bookmark n
				join unit u on u.id = n.ref_unit_id
				join chapter c on c.id = u.ref_chapter_id
				join knowledge k on k.id = c.ref_know_id
			#{condition}
			order by k.name, c.priority, u.priority, n.video_time")

		content = [];
		items.each{|item|
			content.push("#{item.k_uqid}||#{item.u_uqid}||#{item.content_type or 'text'}||#{item.video_time}||#{item.content.to_s}")
		}

		send_data content.join("\r\n"), :filename => "#{items[0].k_name}_notes.csv" if content.size > 0
	end

	def list_note
		subscriber = []
		if params[:knowUqid] != nil
			subscriber = ReaderSubscriber.find_by_sql(
				"select rs.*
				from reader_subscriber rs
					join reader r on r.id = rs.ref_reader_id
					join knowledge k on k.id = r.ref_know_id
				where rs.ref_user_id = #{session[:userinfo][:id]} and k.uqid = '#{params[:knowUqid]}'")
		elsif params[:unitUqid] != nil
			subscriber = ReaderSubscriber.find_by_sql(
				"select rs.*
				from reader_subscriber rs
					join reader r on r.id = rs.ref_reader_id
					join unit u on u.ref_know_id = r.ref_know_id
				where rs.ref_user_id = #{session[:userinfo][:id]} and u.uqid = '#{params[:unitUqid]}'")
		else
			subscriber = ReaderSubscriber.find_by_sql(
				"select rs.*
				from reader_subscriber rs
					join reader r on r.id = rs.ref_reader_id
				where rs.ref_user_id = #{session[:userinfo][:id]}")
		end

		users = [session[:userinfo][:id]]
		subscriber.each{|s| users.push(s.ref_subscriber_id)}
		condition = "where n.ref_user_id in (#{users.join(', ')}) and (n.is_public = true or n.ref_user_id = #{session[:userinfo][:id]})"
		condition = "#{condition} and lower(n.content) like lower('%#{params[:keyword]}%') and (n.content_type is null or n.content_type = 'text') and n.ref_user_id = #{session[:userinfo][:id]}" if params[:keyword] != nil
		condition = "#{condition} and k.uqid = '#{params[:knowUqid]}'" if params[:knowUqid] != nil
		condition = "#{condition} and u.uqid = '#{params[:unitUqid]}'" if params[:unitUqid] != nil
		condition = "#{condition} and n.uqid = '#{params[:itemUqid]}'" if params[:itemUqid] != nil
		
		if params[:type] == nil or params[:type] == 'text'
			condition = "#{condition} and (n.content_type is null or n.content_type = 'text')"
		elsif params[:type] != 'all'
			condition = "#{condition} and n.content_type = '#{params[:type]}'"
		end

		items = Note.find_by_sql(
			"select n.uqid, n.video_time, n.content, n.content_type, n.content_color, n.is_public,
				k.uqid k_uqid, k.name k_name, u.uqid u_uqid, u.name u_name, u.unit_type u_type, u.content_url u_url,
				us.first_name, us.last_name, us.userid, us.nouser, us.uqid us_uqid
			from bookmark n
				join unit u on u.id = n.ref_unit_id
				join chapter c on c.id = u.ref_chapter_id
				join knowledge k on k.id = c.ref_know_id
				join \"user\" us on us.id = n.ref_user_id
			#{condition}
			order by k.name, c.priority, u.priority, n.video_time, n.update_time")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				content: item.content_type == 'text' || item.content_type == nil ? item.content : JSON.parse(item.content),
				time: item.video_time == nil ? 0 : item.video_time.to_i,
				type: item.content_type == nil ? 'text' : item.content_type,
				color: item.content_color == nil ? '#fff' : item.content_color,
				privacy: item.is_public,
				unit: {
					uqid: item.u_uqid,
					name: item.u_name,
					unit_type: item.u_type,
					content_url: item.u_url
				},
				know: {
					uqid: item.k_uqid,
					name: item.k_name
				},
				author: {
					uqid: item.us_uqid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser)
				}
			})
		}

		render :json => content
	end

	def add_unit_note
		unit = Unit.where(uqid: params[:unitUqid]).first
		
		if unit != nil
			note = Note.where(
				ref_user_id: session[:userinfo][:id],
				ref_unit_id: unit.id,
				video_time: params[:time] || 0,
				content: params[:content] || '').first

			if note == nil
				item = Note.new
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.ref_user_id = session[:userinfo][:id]
				item.ref_unit_id = unit.id
				item.video_time = params[:time] || 0
				item.content = params[:content] || ''
				item.is_public = true
				item.update_time = Time.now
				if ['text', 'image', 'video', 'audio'].include?(params[:type])
					item.content_type = params[:type]
				else
					item.content_type = 'text'
				end
				item.save()

				update_unit_status(unit, 0)
				
				render :json => {
					uqid: item.uqid,
					time: item.video_time,
					content: item.content,
					type: item.content_type
				}
			else
				render :json => {
					uqid: note.uqid,
					time: note.video_time,
					content: note.content,
					type: note.content_type
				}
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_unit_note
		item = Note.where({ref_user_id: session[:userinfo][:id], uqid: params[:itemUqid]}).first

		if item != nil
			item.video_time = params[:time] != nil ? params[:time] : item.video_time
			item.content = params[:content] != nil ? params[:content] : item.content
			item.content_color = params[:color] != nil ? params[:color] : item.content_color
			item.is_public = params[:privacy] == false ? false : true
			item.update_time = Time.now
			item.save()

			render :json => {
				uqid: item.uqid,
				time: item.video_time,
				content: item.content,
				color: item.content_color,
				privacy: item.is_public
			}
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_unit_note
		item = Note.where({ref_user_id: session[:userinfo][:id], uqid: params[:itemUqid]}).first

		if item != nil
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_subscriber
		items = ReaderSubscriber.find_by_sql(
			"select rs.*, u.userid, u.first_name, u.last_name, u.nouser, u.uqid u_uqid
			from reader_subscriber rs
				join \"user\" u on u.id = rs.ref_subscriber_id
				join reader r on r.id = rs.ref_reader_id
				join knowledge k on k.id = r.ref_know_id
			where r.ref_user_id = #{session[:userinfo][:id]} and k.uqid = '#{params[:knowUqid]}'")

		content = []
		items.each{|item|
			content.push({
				uqid: item.uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
				photo: get_image('user', { uqid: item.u_uqid, nouser: item.nouser, type: 'photo' }),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}"
			})
		}

		render :json => content
	end

	def add_subscriber
		if params[:knowUqid] and params[:email] and (params[:email] != session[:userinfo][:userid])
			reader = Reader.find_by_sql(
				"select r.id
				from (select * from reader where ref_user_id = #{session[:userinfo][:id]}) r
					join knowledge k on k.id = r.ref_know_id
				where k.uqid = '#{params[:knowUqid]}'").first

			user = User.where(userid: params[:email]).first
			item = ReaderSubscriber.where({ref_reader_id: reader.id, ref_user_id: user.id}).first

			if item == nil
				item = ReaderSubscriber.new
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.ref_reader_id = reader.id
				item.ref_user_id = session[:userinfo][:id]
				item.ref_subscriber_id = user.id
				item.save()

				render :json => { success: "Well done!" }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def remove_subscriber
		item = ReaderSubscriber.where({uqid: params[:itemUqid], ref_user_id: session[:userinfo][:id]}).first

		if item != nil
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_activity
		condition = "and ga.uqid = '#{params[:activityUqid]}'" if params[:activityUqid] != nil

		items = GroupActivity.find_by_sql(
			"select ga.uqid, ga.maturity, ga.name, ga.description, ga.goal, g.uqid g_uqid
			from group_activity ga
				join \"group\" g on g.id = ga.ref_group_id
				join group_member gm on gm.ref_group_id = g.id
			where gm.ref_user_id = #{session[:userinfo][:id]} #{condition} and ga.is_show = true
			order by ga.maturity")

		if items.size > 1
			content = []
			items.each {|ga|
				goal = JSON.parse(ga.goal)
				units = []
				goal.each {|u| units.push(u['unit']['uqid']) }

				unit = Unit.find_by_sql(
					"select sum(case when us.status = 4 then 1 else 0 end) finish_count, count(u.id) unit_count, max(us.last_view_time) last_view_time
					from unit u
						left join unit_status us on us.ref_unit_id = u.id and us.ref_user_id = #{session[:userinfo][:id]}
					where u.uqid in ('#{units.join("','")}')").first

				content.push({
					group_uqid: ga.g_uqid,
					uqid: ga.uqid,
					name: ga.name,
					maturity: ga.maturity,
					description: ga.description,
					unit_count: unit.unit_count.to_i,
					finish_count: unit.finish_count.to_i,
					progress: (unit.finish_count.to_f / unit.unit_count.to_f).nan? ? 0 : ((unit.finish_count.to_f / unit.unit_count.to_f) > 1 ? 100 : (unit.finish_count.to_f / unit.unit_count.to_f * 100).round(1)),
					last_view_time: unit.last_view_time != nil ? unit.last_view_time.to_datetime : nil,
					logo: get_image('group', { uqid: ga.g_uqid }),
					page: "#{request.protocol}#{request.host_with_port}/join/group/#{ga.g_uqid}",
				})
			}

			render :json => content
		elsif items.size == 1
			ga = items[0]

			goal = JSON.parse(ga.goal)
			units = []
			goal.each {|u| units.push(u['unit']['uqid']) }

			unit = Unit.find_by_sql(
				"select sum(case when us.status = 4 then 1 else 0 end) finish_count, count(u.id) unit_count, max(us.last_view_time) last_view_time
				from unit u
					left join unit_status us on us.ref_unit_id = u.id and us.ref_user_id = #{session[:userinfo][:id]}
				where u.uqid in ('#{units.join("','")}')").first

			content = {
				group_uqid: ga.g_uqid,
				uqid: ga.uqid,
				name: ga.name,
				maturity: ga.maturity,
				description: ga.description,
				unit_count: unit.unit_count.to_i,
				finish_count: unit.finish_count.to_i,
				progress: (unit.finish_count.to_f / unit.unit_count.to_f).nan? ? 0 : ((unit.finish_count.to_f / unit.unit_count.to_f) > 1 ? 100 : (unit.finish_count.to_f / unit.unit_count.to_f * 100).round(1)),
				last_view_time: unit.last_view_time != nil ? unit.last_view_time.to_datetime : nil,
				logo: get_image('group', { uqid: ga.g_uqid }),
				page: "#{request.protocol}#{request.host_with_port}/join/group/#{ga.g_uqid}",
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_activity_unit
		condition = "and ga.uqid = '#{params[:activityUqid]}'" if params[:activityUqid] != nil

		gas = GroupActivity.find_by_sql(
			"select ga.uqid, ga.maturity, ga.description, ga.goal, g.name, g.uqid g_uqid
			from group_activity ga
				join \"group\" g on g.id = ga.ref_group_id
				join group_member gm on gm.ref_group_id = g.id
			where gm.ref_user_id = #{session[:userinfo][:id]} #{condition}")

		content = []
		gas.each {|ga|
			goal = JSON.parse(ga.goal)
			units = []
			goal.each {|u| units.push(u['unit']['uqid']) }

			items = Unit.find_by_sql(
				"select k.uqid k_uqid, k.name k_name, ch.uqid ch_uqid, ch.name ch_name, ch.priority ch_priority,
					u.id, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time, u.supplementary_description, u.content,
					us.status, us.last_view_time, us.gained gained_time, us.total total_time,
					array_agg(uf.group_uqid) group_uqid, array_agg(uf.group_name) group_name, array_agg(uf.score) score, array_agg(uf.comment) as comment
				from unit u
					join chapter ch on ch.id = u.ref_chapter_id
					join knowledge k on k.id = ch.ref_know_id
					left join unit_status us on us.ref_unit_id = u.id and us.ref_user_id = #{session[:userinfo][:id]}
					left join (select g.uqid group_uqid, g.name group_name, uf.score, uf.comment, uf.ref_unit_id
						from unit_feedback uf
						left join \"group\" g on uf.ref_group_id = g.id
						where uf.ref_user_id = #{session[:userinfo][:id]}) as uf on uf.ref_unit_id = u.id
				where u.uqid in ('#{units.join("','")}')
				group by k.uqid, k.name, ch.uqid, ch.name, ch.priority,
					u.id, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time, u.supplementary_description, u.content,
					us.status, us.last_view_time, us.gained, us.total")
		
			content = []
			units.each {|unit|
				items.each {|item|
					if unit == item.uqid
						sr = StudyResult.where(ref_user_id: session[:userinfo][:id], ref_unit_id: item.id).first

						content.push({
							uqid: item.uqid,
							name: item.name,
							unit_type: item.unit_type,
							content_url: item.content_url,
							content_time: item.content_time.to_f,
							priority: item.priority.to_i,
							description: item.supplementary_description,
							content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
							total_time: item.total_time.to_f,
							gained_time: item.gained_time.to_f,
							progress: (item.gained_time.to_f / item.total_time.to_f).nan? ? 0 : ((item.gained_time.to_f / item.total_time.to_f) > 1 ? 100 : (item.gained_time.to_f / item.total_time.to_f * 100).round(2)),
							status: item.status.to_i,
							last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
							chapter: {
								uqid: item.ch_uqid,
								name: item.ch_name,
								priority: item.ch_priority
							},
							feedback: {
								uqid: item.group_uqid,
								name: item.group_name,
								score: item.score,
								comment: item.comment,
							},
							study_result: sr != nil ? JSON.parse(sr.content) : nil,
							learning_time: sr != nil ? sr.learning_time : nil
						})
					end
				}
			}
		}

		render :json => content
	end

	def list_group
		items = Group.find_by_sql(
			"select g.uqid, g.name
			from \"group\" g
				left join group_member gm on gm.ref_group_id = g.id
			where gm.ref_user_id = #{session[:userinfo][:id]} and g.is_destroyed = false
			order by g.name")

		content = []
		items.each{|item|
			content.push({
				uqid: item.uqid,
				name: item.name
			})
		}

		render :json => content
	end

	private

	def update_unit_status(unit, gained)
		us = UnitStatus.where(['ref_user_id = ? and ref_unit_id = ?', session[:userinfo][:id], unit.id]).first

		if us == nil
			us = UnitStatus.new
			us.ref_user_id = session[:userinfo][:id]
			us.ref_unit_id = unit.id
			us.ref_know_id = unit.ref_know_id
			us.status = 2
			us.gained = 0
			us.total = 0
			us.save()
		end

		unit.content_time = 1 if unit.content_time == nil or unit.content_time == ''

		us.gained = 0 if us.gained == nil
		us.gained = us.gained + gained

		us.total = 0 if us.total == nil
		us.total = unit.content_time

		if unit.unit_type == 'video'
			if us.gained + 5 >= us.total
				us.status = 4
			end
		end 

		us.last_view_time = Time.now
		us.save()

		return us
	end
end