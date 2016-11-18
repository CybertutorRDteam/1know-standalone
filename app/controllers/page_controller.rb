require "open-uri"

class PageController < ApplicationController
    before_filter :get_app_config

    def get_app_config
        @APP_CONFIG = APP_CONFIG
    end

    def user
        item = User.where(uqid: params[:uqid]).first

        if item != nil
            knowledges = Knowledge.find_by_sql(
                "select k.uqid, k.name
                from knowledge k
                    join draft_knowledge dk on dk.uqid = k.uqid
                    join draft_knowledge_editor dke on dke.ref_know_id = dk.id
                where dke.ref_user_id = #{item.id} and dke.is_show = true and k.is_public = true
                group by k.uqid, k.name, k.last_update
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

            @content = {
                uqid: item.uqid,
                email: item.userid,
                first_name: item.first_name,
                last_name: item.last_name,
                full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                description: item.description,
                website: item.website,
                facebook: item.facebook,
                twitter: item.twitter,
                banner: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'banner' }),
                photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
                knowledge: knowledge,
                nouser: item.nouser
            }
        else
            redirect_to '/404.html'
        end
    end

    def knowledge
        know = Knowledge.find_by_sql(
            "select k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed,
                sum(case when r.rating = 5 then 1 else 0 end) rating5,
                sum(case when r.rating = 4 then 1 else 0 end) rating4,
                sum(case when r.rating = 3 then 1 else 0 end) rating3,
                sum(case when r.rating = 2 then 1 else 0 end) rating2,
                sum(case when r.rating = 1 then 1 else 0 end) rating1
            from knowledge k
                left join reader r on r.ref_know_id = k.id
            where k.uqid = '#{params[:uqid]}' and k.is_destroyed = false
            group by k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed").first

        if know != nil and !know.is_destroyed
            subscribed = false
            groups = []
            channels = []
            if session[:userinfo] != nil
                reader = Reader.where(ref_know_id: know.id, ref_user_id: session[:userinfo][:id], is_archived: false).first
                subscribed = true if reader != nil

                groups = Group.find_by_sql(
                    "select g.uqid, g.name, gm.role, gk.id joined
                    from \"group\" g
                        join group_member gm on gm.ref_group_id = g.id and gm.ref_user_id = #{session[:userinfo][:id]}
                        left join group_knowledge gk on gk.ref_group_id = g.id and gk.ref_know_id = #{know.id}
                    where gm.role in ('owner', 'admin') and g.is_destroyed = false
                    order by g.name")
            end

            chapters = []
            know.chapters.each {|c|
                if c.is_destroyed == nil
                    units = []
                    c.units.each {|u|
                        if u.is_destroyed == nil
                            quizzes = []
                            if u.unit_type == 'quiz'
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
                                            explain: item.explain,
                                            explain_url: item.explain_url
                                        })
                                    end
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
                                preview: know.is_public ? true : (u.is_preview == nil ? false : u.is_preview)
                            })
                        end
                    }

                    chapters.push({
                        name: c.name,
                        priority: c.priority,
                        units: units
                    })
                end
            }

            items = DraftKnowledgeEditor.find_by_sql(
                "select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
                from draft_knowledge_editor dke
                    join \"user\" u on u.id = dke.ref_user_id
                    join draft_knowledge dk on dk.id = dke.ref_know_id
                    join knowledge k on k.uqid = dk.uqid
                where k.id = #{know.id} and (dke.is_show = true or dke.role = 'owner')
                order by dke.order")

            editors = []
            items.each {|e|
                editors.push({
                    uqid: e.uqid,
                    email: e.userid,
                    first_name: e.first_name,
                    last_name: e.last_name,
                    full_name: parse_full_name(e.first_name, e.last_name, e.userid, e.nouser),
                    photo: get_image('user', { uqid: e.uqid, nouser: e.nouser, type: 'photo' }),
                    page: "#{request.protocol}#{request.host_with_port}/user/#{e.uqid}",
                    nouser: e.nouser
                })
            }

            total_rate = know.rating5 + know.rating4 + know.rating3 + know.rating2 + know.rating1
            average_rate = ((know.rating5 * 5.0) + (know.rating4 * 4.0) + (know.rating3 * 3.0) + (know.rating2 * 2.0) + know.rating1).to_f
            rating = [know.rating5, know.rating4, know.rating3, know.rating2, know.rating1]

            @content = {
                uqid: know.uqid,
                name: know.name,
                description: know.description,
                release: know.last_update,
                reader: know.readers.size,
                code: know.code,
                privacy: know.is_public ? true : false,
                editors: editors,
                chapters: chapters,
                subscribed: subscribed,
                rating: rating,
                total_rate: total_rate,
                average_rate: average_rate != 0 ? average_rate / total_rate : 0,
                logo: get_image('knowledge', { uqid: know.uqid }),
                page: "#{request.protocol}#{request.host_with_port}/knowledge/#{know.uqid}",
                share_page: "#{request.protocol}#{request.host_with_port}/watch?k=#{know.uqid}",
                groups: groups
            }

            if session[:userinfo] != nil
                item = User.find(session[:userinfo][:id])
                if item != nil
                    if item.language != nil
                        language = JSON.parse(item.language)
                        if language['type'] == 'zh-tw'
                            language = {title: '繁體中文', type: 'zh-tw'}
                        elsif language['type'] == 'zh-cn'
                            language = {title: '简体中文', type: 'zh-cn'}
                        else
                            language = {title: 'English', type: 'en-us'}
                        end
                    else
                        language = {title: 'English', type: 'en-us'}
                    end

                    account = {
                        uqid: item.uqid,
                        email: item.userid,
                        first_name: item.first_name,
                        last_name: item.last_name,
                        full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                        photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                        nouser: item.nouser,
                        language: language
                    }
                else
                    account = nil
                end
            else
                account = nil
            end

            @content['account'] = account

            respond_to do |format|
                format.html
                format.json { render :json => @content }
            end
        else
            respond_to do |format|
                format.html { redirect_to '/404.html' }
                format.json { render :json => { error: "We're sorry, but something went wrong." } }
            end
        end
    end

    def group
        group = Group.where(uqid: params[:uqid], is_destroyed: false).first

        if group != nil
            members = User.find_by_sql(
                "select u.userid, u.uqid, u.first_name, u.last_name, u.photo, u.nouser
                from \"user\" u
                    join group_member gm on gm.ref_user_id = u.id
                where gm.ref_group_id = #{group.id} and gm.status = 'approved'
                order by gm.last_view_time desc nulls last, gm.sign_time desc
                limit 24")

            member = []
            members.each {|item|
                member.push({
                    uqid: item.uqid,
                    email: item.userid,
                    first_name: item.first_name,
                    last_name: item.last_name,
                    full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                    nouser: item.nouser,
                    photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                    page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
                })
            }

            knowledges = Knowledge.find_by_sql(
                "select k.uqid, k.name
                from knowledge k
                    join group_knowledge gk on gk.ref_know_id = k.id
                where gk.ref_group_id = #{group.id} and k.is_public = true and gk.is_show = true
                order by gk.priority")

            knowledge = []
            knowledges.each {|item|
                knowledge.push({
                    uqid: item.uqid,
                    name: item.name,
                    logo: get_image('knowledge', { uqid: item.uqid }),
                    page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
                })
            }

            activities = GroupActivity.find_by_sql(
                "select ga.uqid, ga.name, ga.description, ga.goal
                from group_activity ga
                where ga.ref_group_id = #{group.id} and ga.is_show = true
                order by ga.priority")

            activity = []
            activities.each {|item|
                activity.push({
                    uqid: item.uqid,
                    name: item.name,
                    description: item.description,
                    goal: JSON.parse(item.goal)
                })
            }

            joined = false
            if session[:userinfo] != nil
                gm = GroupMember.where(ref_user_id: session[:userinfo][:id], ref_group_id: group.id, status: 'approved').first
                joined = gm == nil ? false : true
            end

            @content = {
                uqid: group.uqid,
                name: group.name,
                description: group.description,
                knowledge_size: knowledges.size,
                member_size: members.size,
                activity_size: activity.size,
                knowledge: knowledge,
                member: member,
                activity: activity,
                privacy: group.is_public,
                content: group.content == nil ? [] : JSON.parse(group.content),
                logo: get_image('group', { uqid: group.uqid }),
                page: "#{request.protocol}#{request.host_with_port}/group/#{group.uqid}",
                joined: joined
            }

            if session[:userinfo] != nil
                item = User.find(session[:userinfo][:id])
                if item != nil
                    if item.language != nil
                        language = JSON.parse(item.language)
                        if language['type'] == 'zh-tw'
                            language = {title: '繁體中文', type: 'zh-tw'}
                        elsif language['type'] == 'zh-cn'
                            language = {title: '简体中文', type: 'zh-cn'}
                        else
                            language = {title: 'English', type: 'en-us'}
                        end
                    else
                        language = {title: 'English', type: 'en-us'}
                    end

                    account = {
                        uqid: item.uqid,
                        email: item.userid,
                        first_name: item.first_name,
                        last_name: item.last_name,
                        full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                        photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                        nouser: item.nouser,
                        language: language
                    }
                else
                    account = nil
                end
            else
                account = nil
            end

            @content['account'] = account

            respond_to do |format|
                format.html
                format.json { render :json => @content }
            end
        else
            respond_to do |format|
                format.html { redirect_to '/404.html' }
                format.json { render :json => { error: "We're sorry, but something went wrong." } }
            end
        end
    end

    def channel
        channel = Channel.where(uqid: params[:uqid]).first

        subscribed = false
        if channel != nil
            if session[:userinfo] != nil
                item = ChannelMember.where(ref_user_id: session[:userinfo][:id], ref_channel_id: channel.id, status: 'approved').first
                subscribed = true if item != nil
            end

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

                    sub_knowledges = []
                    if session[:userinfo] != nil
                        knows = CategoryKnowledge.find_by_sql(
                            "select k.uqid, k.name, ck.priority, sum(case when r.rating is null then 0 else r.rating end) rating, sum(case when r.rating is null then 0 else 1 end) rate_count, count(r.id) reader, r2.id reader_id
                            from category_knowledge ck
                                join category ca on ca.id = ck.ref_category_id
                                join knowledge k on k.id = ck.ref_know_id
                                left join reader r on r.ref_know_id = k.id
                                left join reader r2 on r2.ref_know_id = k.id and r2.ref_user_id = #{session[:userinfo][:id]} and r2.is_archived != true
                            where ca.id = #{c.id}
                            group by k.uqid, k.name, ck.priority, r2.id
                            order by ck.priority")
                    else
                        knows = CategoryKnowledge.find_by_sql(
                            "select k.uqid, k.name, ck.priority, sum(case when r.rating is null then 0 else r.rating end) rating, sum(case when r.rating is null then 0 else 1 end) rate_count, count(r.id) reader
                            from category_knowledge ck
                                join category ca on ca.id = ck.ref_category_id
                                join knowledge k on k.id = ck.ref_know_id
                                left join reader r on r.ref_know_id = k.id
                            where ca.id = #{c.id}
                            group by k.uqid, k.name, ck.priority
                            order by ck.priority")
                    end

                    knows.each {|know|
                        sub_knowledges.push({
                            uqid: know.uqid,
                            name: know.name,
                            priority: know.priority,
                            rating: know.rating.to_f == 0 ? 0 : ((know.rating.to_f / know.rate_count.to_f) * 10).ceil / 10.0,
                            reader: know.reader.to_i,
                            subscribed: session[:userinfo] == nil ? false : (know.reader_id != nil ? true : false),
                            logo: get_image('knowledge', { uqid: know.uqid }),
                            page: "#{request.protocol}#{request.host_with_port}/knowledge/#{know.uqid}",
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

            @content = {
                uqid: channel.uqid,
                name: channel.name,
                description: channel.description,
                logo: get_image('channel', { uqid: channel.uqid }),
                page: "#{request.protocol}#{request.host_with_port}/channel/#{channel.uqid}",
                categories: categories,
                subscribed: subscribed
            }

            if session[:userinfo] != nil
                item = User.find(session[:userinfo][:id])
                if item != nil
                    if item.language != nil
                        language = JSON.parse(item.language)
                        if language['type'] == 'zh-tw'
                            language = {title: '繁體中文', type: 'zh-tw'}
                        elsif language['type'] == 'zh-cn'
                            language = {title: '简体中文', type: 'zh-cn'}
                        else
                            language = {title: 'English', type: 'en-us'}
                        end
                    else
                        language = {title: 'English', type: 'en-us'}
                    end

                    account = {
                        uqid: item.uqid,
                        email: item.userid,
                        first_name: item.first_name,
                        last_name: item.last_name,
                        full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                        photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                        nouser: item.nouser,
                        language: language
                    }
                else
                    account = nil
                end
            else
                account = nil
            end

            @content['account'] = account

            respond_to do |format|
                format.html
                format.json { render :json => @content }
            end
        else
            respond_to do |format|
                format.html { redirect_to '/404.html' }
                format.json { render :json => { error: "We're sorry, but something went wrong." } }
            end
        end
    end

    def package_knowledge
        know = Knowledge.find_by_sql(
            "select k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed,
                sum(case when r.rating = 5 then 1 else 0 end) rating5,
                sum(case when r.rating = 4 then 1 else 0 end) rating4,
                sum(case when r.rating = 3 then 1 else 0 end) rating3,
                sum(case when r.rating = 2 then 1 else 0 end) rating2,
                sum(case when r.rating = 1 then 1 else 0 end) rating1
            from knowledge k
                left join reader r on r.ref_know_id = k.id
            where k.uqid = '#{params[:uqid]}'
            group by k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed").first

        if know == nil
            render :json => { error: "We're sorry, but something went wrong." }
            return
        end

        owner = DraftKnowledgeEditor.find_by_sql(
            "select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
            from draft_knowledge_editor dke
                join \"user\" u on u.id = dke.ref_user_id
                join draft_knowledge dk on dk.id = dke.ref_know_id
                join knowledge k on k.uqid = dk.uqid
            where k.id = #{know.id} and dke.ref_user_id = #{session[:userinfo][:id]}
            order by dke.order").first

        if owner == nil
            render :json => { error: "We're sorry, but something went wrong." }
            return
        end

        chapters = []
        know.chapters.each {|c|
            if c.is_destroyed == nil
                units = []
                c.units.each {|u|
                    if u.is_destroyed == nil
                        quizzes = []
                        if u.unit_type == 'quiz'
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
                                        explain: item.explain,
                                        explain_url: item.explain_url
                                    })
                                end
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
                            preview: u.is_preview == nil ? false : u.is_preview
                        })
                    end
                }

                chapters.push({
                    name: c.name,
                    priority: c.priority,
                    units: units
                })
            end
        }

        items = DraftKnowledgeEditor.find_by_sql(
            "select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
            from draft_knowledge_editor dke
                join \"user\" u on u.id = dke.ref_user_id
                join draft_knowledge dk on dk.id = dke.ref_know_id
                join knowledge k on k.uqid = dk.uqid
            where k.id = #{know.id} and dke.is_show = true
            order by dke.order")

        editors = []
        items.each {|e|
            editors.push({
                uqid: e.uqid,
                email: e.userid,
                first_name: e.first_name,
                last_name: e.last_name,
                full_name: parse_full_name(e.first_name, e.last_name, e.userid, e.nouser),
                photo: get_image('user', { uqid: e.uqid, nouser: e.nouser, type: 'photo' }),
                page: "#{request.protocol}#{request.host_with_port}/user/#{e.uqid}",
                nouser: e.nouser
            })
        }

        total_rate = know.rating5 + know.rating4 + know.rating3 + know.rating2 + know.rating1
        rating = [know.rating5, know.rating4, know.rating3, know.rating2, know.rating1]
        rating.push((rating[0].to_f/total_rate.to_f*100).nan? ? 0 : (rating[0].to_f/total_rate.to_f*100).to_i)
        rating.push((rating[1].to_f/total_rate.to_f*100).nan? ? 0 : (rating[1].to_f/total_rate.to_f*100).to_i)
        rating.push((rating[2].to_f/total_rate.to_f*100).nan? ? 0 : (rating[2].to_f/total_rate.to_f*100).to_i)
        rating.push((rating[3].to_f/total_rate.to_f*100).nan? ? 0 : (rating[3].to_f/total_rate.to_f*100).to_i)
        rating.push((rating[4].to_f/total_rate.to_f*100).nan? ? 0 : (rating[4].to_f/total_rate.to_f*100).to_i)

        content = {
            uqid: know.uqid,
            name: know.name,
            description: know.description,
            reader: know.readers.size,
            code: know.code,
            privacy: know.is_public ? true : false,
            editors: editors,
            chapters: chapters,
            rating: rating,
            logo: get_image('knowledge', { uqid: know.uqid }),
            page: "#{request.protocol}#{request.host_with_port}/knowledge/#{know.uqid}",
            root_url: "#{request.protocol}#{request.host_with_port}"
        }

        item = User.find(session[:userinfo][:id])

        if item.language != nil
            language = JSON.parse(item.language)
            if language['type'] == 'zh-tw'
                language = {title: '繁體中文', type: 'zh-tw'}
            elsif language['type'] == 'zh-cn'
                language = {title: '简体中文', type: 'zh-cn'}
            else
                language = {title: 'English', type: 'en-us'}
            end
        else
            language = {title: 'English', type: 'en-us'}
        end

        account = {
            uqid: item.uqid,
            email: item.userid,
            first_name: item.first_name,
            last_name: item.last_name,
            nouser: item.nouser,
            language: language
        }

        editorHtml = []
        content[:editors].each{|e|
            editorHtml.push(
                "<a href='#{e[:page]}' target='_blank' style='text-decoration:none'>
                    <img src='#{e[:photo]}' style='width:24px;height:24px;margin:2px'/>
                </a>")
        }
        editorHtml = editorHtml.join('')

        contentHtml = []
        content[:chapters].each_with_index {|c,i|
            unitHtml = []
            c[:units].each_with_index {|u,j|
                unitHtml.push(
                    "<tr>
                        <td style='width:20px;border:0;border-bottom:1px solid #ddd'>
                            <span>
                            #{
                                if u[:unit_type] == 'video'
                                    '<i class="fa fa-fw fa-film"></i>'
                                elsif u[:unit_type] == 'web'
                                    '<i class="fa fa-fw fa-link"></i>'
                                elsif u[:unit_type] == 'embed'
                                    '<i class="fa fa-fw fa-code"></i>'
                                elsif u[:unit_type] == 'quiz'
                                    '<i class="fa fa-fw fa-pencil-square-o"></i>'
                                elsif u[:unit_type] == 'poll'
                                    '<i class="fa fa-fw fa-thumbs-o-up"></i>'
                                elsif u[:unit_type] == 'qa'
                                    '<i class="fa fa-fw fa-question"></i>'
                                elsif u[:unit_type] == 'draw'
                                    '<i class="fa fa-fw fa-picture-o"></i>'
                                end
                            }
                            </span>
                        </td>
                        <td style='border:0;border-bottom:1px solid #ddd'>
                            <a href='javascript:;' ng-click='preview(#{i}, #{j})'>
                                <div style='max-width:600px;text-align:left;text-overflow:ellipsis;white-space:nowrap;overflow:hidden'>#{u[:name]}</div>
                            </a>
                        </td>
                    </tr>"
                )
            }
            unitHtml = unitHtml.join('')

            contentHtml.push(
                "<div class='panel panel-primary'>
                    <div class='panel-heading'>
                        <h3 class='panel-title'>#{c[:name]}</h3>
                    </div>
                    <div class='panel-body'>
                        <table class='table table-hover table-condensed' style='margin:0'>
                            <tbody>#{unitHtml}</tbody>
                        </table>
                    </div>
                </div>"
            )
        }
        contentHtml = contentHtml.join('')

        html =
        "<!DOCTYPE html>
        <html lang='en' ng-app='1know'>
        <head>
            <title>#{content[:name]}</title>

            <meta charset='UTF-8'>

            <link rel='icon' href='#{content[:logo]}' />

            <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/bootstrap/3.1.0/css/bootstrap.min.css'>
            <link rel='stylesheet' href='https://vjs.zencdn.net/4.2/video-js.css'>
            <link rel='stylesheet' href='https://netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.css'>
            <link rel='stylesheet' href='#{content[:root_url]}/library/literallycanvas/literallycanvas.css'>
            <link rel='stylesheet' href='#{content[:root_url]}/css/default.css'>

            <script src='https://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js'></script>
            <script src='https://ajax.googleapis.com/ajax/libs/angularjs/1.2.11/angular.min.js'></script>
            <script src='https://netdna.bootstrapcdn.com/bootstrap/3.1.0/js/bootstrap.min.js'></script>
            <script src='https://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.5.2/underscore-min.js'></script>
            <script src='https://vjs.zencdn.net/4.2/video.js'></script>
            <script src='#{content[:root_url]}/library/literallycanvas/literallycanvas.js'></script>
            <script>
                var web_name = '#{@APP_CONFIG['web_name']}';
                var hide_account_type = '#{@APP_CONFIG['hide_account_type']}';
                var logo = '#{@APP_CONFIG['logo']}';
                var copyright = '#{@APP_CONFIG['copyright']}';
                var service_email = '#{@APP_CONFIG['service_email']}';
            </script>
        </head>

        <body ng-controller='MainCtrl'>
            <nav id='header' class='navbar navbar-static-top navbar-inverse' role='navigation'>
                <div class='container'>
                    <div class='navbar-header'>
                        <a class='navbar-brand logo' style='padding:9px 15px' href='/'>
                            <img ng-show='logo' ng-src='{{ logo }}'>
                            <span ng-show='!logo && web_name' class='logo-header'>{{ web_name }}</span>
                            <span ng-show='!logo && !web_name' class='logo-header'>
                        </a>
                    </div>
                </div>
            </nav>

            <div ng-switch='model.layout'>
                <div class='container' style='margin:20px auto' ng-switch-when='content'>
                    <div class='row'>
                        <div class='col-xs-3'>
                            <div class='panel panel-default'>
                                <div style='padding:10px'>
                                    <span class='pull-right'><i class='fa fa-fw fa-user'></i> #{content[:reader]}</span>
                                    #{
                                        if content[:privacy]
                                            "<span class='text-info'><span>公開</span></span>"
                                        else
                                            "<span class='text-error'><span>非公開</span></span>"
                                        end
                                    }
                                </div>
                                <div>
                                    <img src='#{content[:logo]}' style='width:100%'/>
                                </div>
                                <div style='padding:10px;border-top:1px solid #ddd'>
                                    <span class='text-muted'>
                                        #{
                                            if account[:language][:type] == 'zh-tw'
                                                "<span>知識代碼</span>"
                                            elsif account[:language][:type] == 'zh-cn'
                                                "<span>知识代码</span>"
                                            else
                                                "<span>Knowledge Code</span>"
                                            end
                                        }
                                    </span>
                                    <span class='pull-right'>#{content[:code]}</span>
                                </div>
                                <div style='border-top:1px solid #ddd'><img ng-src='https://chart.googleapis.com/chart?cht=qr&chs=140x140&chl=#{content[:page]}'/></div>
                                <div style='padding:10px;border-top:1px solid #ddd'>
                                    <div class='row'>
                                        <div class='col-xs-3'><i class='fa fa-star'></i> 5</div>
                                        <div class='col-xs-6'>
                                            <div class='progress' style='height:12px'>
                                                <div class='progress-bar' style='width:#{content[:rating][5]}%'></div>
                                            </div>
                                        </div>
                                        <div class='span3'>#{content[:rating][0]}</div>
                                    </div>
                                    <div class='row'>
                                        <div class='col-xs-3'><i class='fa fa-star'></i> 4</div>
                                        <div class='col-xs-6'>
                                            <div class='progress' style='height:12px'>
                                                <div class='progress-bar' style='width:#{content[:rating][6]}%'></div>
                                            </div>
                                        </div>
                                        <div class='span3'>#{content[:rating][1]}</div>
                                    </div>
                                    <div class='row'>
                                        <div class='col-xs-3'><i class='fa fa-star'></i> 3</div>
                                        <div class='col-xs-6'>
                                            <div class='progress' style='height:12px'>
                                                <div class='progress-bar' style='width:#{content[:rating][7]}%'></div>
                                            </div>
                                        </div>
                                        <div class='span3'>#{content[:rating][2]}</div>
                                    </div>
                                    <div class='row'>
                                        <div class='col-xs-3'><i class='fa fa-star'></i> 2</div>
                                        <div class='col-xs-6'>
                                            <div class='progress' style='height:12px'>
                                                <div class='progress-bar' style='width:#{content[:rating][8]}%'></div>
                                            </div>
                                        </div>
                                        <div class='span3'>#{content[:rating][3]}</div>
                                    </div>
                                    <div class='row'>
                                        <div class='col-xs-3'><i class='fa fa-star'></i> 1</div>
                                        <div class='col-xs-6'>
                                            <div class='progress' style='height:12px'>
                                                <div class='progress-bar' style='width:#{content[:rating][9]}%'></div>
                                            </div>
                                        </div>
                                        <div class='span3'>#{content[:rating][4]}</div>
                                    </div>
                                </div>
                                <div style='padding:10px;border-top:1px solid #ddd'>
                                    <span class='text-muted'>
                                        #{
                                            if account[:language][:type] == 'zh-tw'
                                                "<span>編輯者</span>"
                                            elsif account[:language][:type] == 'zh-cn'
                                                "<span>编辑者</span>"
                                            else
                                                "<span>Editor</span>"
                                            end
                                        }
                                    </span>
                                    <div style='margin-top:10px'>#{editorHtml}
                                    </div>
                                </div>
                                <div style='padding:10px;border-top:1px solid #ddd'>
                                    <div class='text-muted'>Download Time</div>
                                    <div class='text-info' style='margin-top:8px'>#{Time.now}</div>
                                </div>
                            </div>
                        </div>

                        <div class='col-xs-9'>
                            <div class='panel panel-default'>
                                <div class='panel-body'>
                                    <h2>#{content[:name]}</h2>
                                    <div style='padding:10px'>#{content[:description].html_safe if content[:description] != nil}</div>
                                </div>
                            </div>
                            <div style='margin-top:20px'>
                                #{contentHtml}
                            </div>
                        </div>
                    </div>
                </div>

                <div ng-switch-when='preview' style='min-width:970px'>
                    <div style='min-height:42px;padding:4px;background:#ffffff;border-bottom:1px solid #ddd'>
                        <a class='btn btn-default disabled' style='border:none'>{{model.currentUnit.name}}</a>
                        <div class='pull-right'>
                            <a class='btn btn-default' style='border:none' ng-click='toggleMaximum()'>
                                <i class='fa fa-fw' ng-class='{\"fa-compress\": model.maximum, \"fa-expand\": !model.maximum}'></i>
                            </a>
                            <a class='btn btn-default' style='border:none' ng-click='closePreview()'>
                                <i class='fa fa-fw fa-sign-out'></i>
                            </a>
                        </div>
                    </div>

                    <div>
                        <div style='display:table'>
                            <div style='display:table-cell;vertical-align:top'>
                                <div ng-style='{width:model.contentWidth+\"px\", height:model.contentHeight+\"px\"}' style='background:#fff' ng-switch='model.currentUnit.unit_type'>
                                    <div ng-switch-when='video' style='height:100%;padding:5px;background:#000' ng-bind-html='model.currentUnit.video_content' id='videoContainer'></div>
                                    <div ng-switch-when='web' style='height:100%;overflow:auto;-webkit-overflow-scrolling:touch'>
                                        <iframe ng-src='{{model.currentUnit.content_url}}' width='100%' height='99%' frameborder='0'></iframe>
                                    </div>
                                    <div ng-switch-when='embed' style='height:100%' ng-bind-html='model.currentUnit.content'></div>
                                    <div ng-switch-when='quiz' style='height:100%;overflow:auto'>
                                        <div style='padding:10px'>
                                            <div style='border:1px solid #ddd;margin-bottom:10px;padding:10px' ng-repeat='quiz in model.currentUnit.quizzes'>
                                                <span class='pull-left'>
                                                    <span ng-if='$index<9'>0</span>{{$index+1}}.</span>
                                                </span>
                                                <div ng-bind-html='quiz.content'></div>
                                                <div style='margin-top:20px'>
                                                    <div ng-repeat='option in quiz.options' ng-switch='quiz.quiz_type'>
                                                        <label class='checkbox' ng-switch-when='multi' style='font-size:16px'>
                                                            <input type='checkbox' name='{{quiz.uqid}}' ng-model='option.answer'/>
                                                            <span ng-hide='option.latex!=undefined&&option.latex'>{{option.item}}</span>
                                                            <img ng-src='{{option.latex_url}}' border='0' ng-show='option.latex!=undefined&&option.latex'/>
                                                        </label>
                                                        <label class='radio' ng-switch-when='single' style='font-size:16px'>
                                                            <input type='radio' name='{{quiz.uqid}}' value='{{option.value}}' ng-model='quiz.single'/>
                                                            <span ng-hide='option.latex!=undefined&&option.latex'>{{option.item}}</span>
                                                            <img ng-src='{{option.latex_url}}' border='0' ng-show='option.latex!=undefined&&option.latex'/>
                                                        </label>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div ng-switch-when='poll' style='height:100%;overflow:auto'>
                                        <div style='padding:10px'>
                                            <h3 style='padding:30px'>
                                                <div ng-bind-html='model.currentUnit.content.content'></div>
                                                <div style='margin-top:20px'>
                                                    <label class='checkbox' style='cursor:pointer' ng-repeat='option in model.currentUnit.content.options'>
                                                        <input type='checkbox' name='{{model.currentUnit.uqid}}' ng-model='option.answer'/>
                                                        <span ng-switch='option.latex!=undefined&&option.latex'>
                                                            <span ng-switch-when='true'><img ng-src='{{option.latex_url}}' border='0'/></span>
                                                            <span ng-switch-when='false'>{{option.item}}</span>
                                                        </span>
                                                    </label>
                                                </div>
                                            </h3>
                                        </div>
                                    </div>
                                    <div ng-switch-when='qa' style='height:100%;overflow:auto'>
                                        <div style='padding:10px'>
                                            <h3><div ng-bind-html='model.currentUnit.content'></div></h3>
                                            <div style='margin-top:20px'>
                                                <div id='qa-result' style='height:200px'></div>
                                            </div>
                                        </div>
                                    </div>
                                    <div ng-switch-when='draw'>
                                        <div id='draw-board' ng-style='{width:model.contentWidth+\"px\", height:model.contentHeight+\"px\", background:model.currentUnit.backgroundImage}' style='background:rgba(0,0,0,0);bottom:0'>
                                            <canvas></canvas>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div style='width:320px;display:table-cell;vertical-align:top' ng-show='!model.maximum'>
                                <div ng-style='{height:model.contentHeight+\"px\"}' style='overflow:auto;padding:10px;word-break:break-all;background:#fff;border-left:1px solid #ddd;' ng-bind-html='model.currentUnit.description'></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div id='footer' class='container' style='text-align:center;margin-top:20px'>
                <span>{{copyright}}</span>
                <a class='btn btn-link' style='color:#333;text-decoration:none' target='_blank' href='mailto:{{service_email}}'><i class='fa fa-fw fa-envelope'></i> Contact</a>
            </div>

            <script>
                angular.module('1know', [])
                .config(function($sceProvider) {
                    $sceProvider.enabled(false);
                })
                .controller('MainCtrl', function($scope, $http, $timeout, $window) {
                    $scope.web_name = $window.web_name;
                    $scope.logo = $window.logo;
                    $scope.copyright = $window.copyright;
                    $scope.service_email = $window.service_email;

                    $scope.preview = function(i, j) {
                        delete $scope.model.currentUnit;

                        $scope.model.currentUnit = $scope.model.knowledge.chapters[i].units[j];
                        if ($scope.model.currentUnit === undefined) return;

                        $scope.model.layout = 'preview';

                        if ($scope.model.currentUnit.unit_type === 'video') {
                            var videoPath = $scope.model.currentUnit.content_url.match(/^(?:([A-Za-z]+):)?\\/\\/(?:.*?)\\.?(youtube|vimeo|youku)\\.(?:.*?)\\/([0-9]+|[^#]*v=([0-9a-zA-Z\\-\\_]+)|v_show\\/id_([0-9a-zA-Z]+))?/);
                            if (videoPath !== null && videoPath.length === 6) {
                                var content = '';
                                if (videoPath[2] === 'youtube')
                                    content = ['<iframe src=\"http://www.youtube.com/embed/', videoPath[4], '?autohide=1&rel=0&showinfo=0\" width=\"100%\" height=\"100%\" frameborder=\"0\"></iframe>'].join('');
                                else if (videoPath[2] === 'vimeo')
                                    content = ['<iframe src=\"https://player.vimeo.com/video/', videoPath[3], '\" width=\"100%\" height=\"100%\" frameborder=\"0\"></iframe>'].join('');
                                else if (videoPath[2] === 'youku')
                                    content = ['<iframe src=\"http://player.youku.com/embed/', videoPath[5], '\" width=\"100%\" height=\"100%\" frameborder=\"0\"></iframe>'].join('');

                                $scope.model.currentUnit.video_content = content;
                                $scope.changeSize();
                            }
                            else {
                                var videoId = Date.now();
                                $scope.model.currentUnit.video_content =
                                    ['<video id=\"video-', videoId,'\" class=\"video-js vjs-default-skin vjs-big-play-centered\" style=\"width:100%;height:100%\">',
                                        '<source src=\"', $scope.model.currentUnit.content_url, ($scope.model.currentUnit.content_url.indexOf(\"?\") != -1 ? '&' : '?'), videoId, '\" type=\"video/mp4\" />',
                                        '<source src=\"', $scope.model.currentUnit.content_url, ($scope.model.currentUnit.content_url.indexOf(\"?\") != -1 ? '&' : '?'), videoId, '\" type=\"video/flv\" />',
                                        '<source src=\"', $scope.model.currentUnit.content_url, ($scope.model.currentUnit.content_url.indexOf(\"?\") != -1 ? '&' : '?'), videoId, '\" type=\"audio/mp3\" />',
                                        '<source src=\"', $scope.model.currentUnit.content_url, ($scope.model.currentUnit.content_url.indexOf(\"?\") != -1 ? '&' : '?'), videoId, '\" type=\"audio/acc\" />',
                                    '</video>'].join('');

                                $timeout(function() {
                                    var option = {
                                        controls: 'true',
                                        preload: 'auto',
                                        width: '100%',
                                        height: '100%'
                                    }
                                    videojs(['video-', videoId].join(''), option, function() {
                                        $scope.changeSize();
                                    });
                                },100);
                            }
                        }
                        else if ($scope.model.currentUnit.unit_type === 'draw') {
                            $scope.changeSize();
                            $timeout(function() {
                                $('#draw-board').html('<canvas></canvas>');
                                $('#draw-board').literallycanvas({
                                    imageURLPrefix: '/library/literallycanvas/img',
                                    backgroundColor: 'rgba(0, 0, 0, 0)',
                                    primaryColor: '#f00'
                                });

                                if ($scope.model.currentUnit.content.background !== '') {
                                    $('#draw-board .custom-button').before('<div id=\"draw-background\" class=\"btn btn-xs btn-primary\" style=\"margin:-4px 4px 0 0;\">Background Image</div>');
                                    $('#draw-background').click(function() {
                                        $timeout(function() {
                                            if ($scope.model.currentUnit.backgroundImage === undefined)
                                                $scope.model.currentUnit.backgroundImage = ['url(', $scope.model.currentUnit.content.background, ') no-repeat'].join('');
                                            else
                                                delete $scope.model.currentUnit.backgroundImage;
                                        },100);
                                    });
                                }
                            },100);
                        }
                        else
                            $scope.changeSize();

                        window.scrollTo(0, 0);
                    }

                    $scope.closePreview = function() {
                        delete $scope.model.currentUnit;
                        $scope.model.layout = 'content';
                        if ($scope.model.maximum)
                            $scope.toggleMaximum();
                    }

                    $scope.toggleMaximum = function() {
                        $scope.model.maximum = !$scope.model.maximum;

                        if ($scope.model.maximum) {
                            $('#header').hide();
                            $('#footer').hide();
                        }
                        else {
                            $('#header').show();
                            $('#footer').show();
                        }

                        $scope.changeSize();
                    }

                    $scope.changeSize = function() {
                        if ($scope.model.maximum) {
                            $scope.model.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
                            $scope.model.contentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 42;
                        }
                        else {
                            $scope.model.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth) - 320;
                            $scope.model.contentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 118;
                        }

                        $scope.model.contentWidth = $scope.model.contentWidth < 650 ? 650 : $scope.model.contentWidth;

                        if ($scope.model.currentUnit) {
                            if ($scope.model.currentUnit.unit_type === 'draw') {
                                $('#draw-board canvas').attr({ 'width': $scope.model.contentWidth, 'height': $scope.model.contentHeight});
                                $('#draw-board canvas').css({ 'width': $scope.model.contentWidth, 'height': $scope.model.contentHeight});
                                if ($('#draw-board').literallyCanvasInstance() !== undefined)
                                    $('#draw-board').literallyCanvasInstance().repaint();
                            }
                        }
                    }

                    window.onresize = function() {
                        $scope.$apply(function() {
                            $scope.changeSize();
                        });
                    }

                    $scope.model = {
                        layout: 'content',
                        maximum: false,
                        knowledge: #{content.to_json}
                    };
                })
            </script>
        </body>
        </html>"

        send_data html, :filename => "#{content[:name]}.html"
    end
end