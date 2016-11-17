require "net/http"
require "net/https"
require "nokogiri"
require "mail"

class Private::UtilityController  < ApplicationController
	before_filter :check_session
	
	def parse_url
		begin
			url = params[:url]
			uri = URI(url)

			response = Net::HTTP.get_response(uri)
			doc = Nokogiri::HTML(response.body)

			if doc.css("title").size == 0 and uri.scheme == 'https'
				url = params[:url].sub(/https:/, "http:")
				uri = URI(url)

				response = Net::HTTP.get_response(uri)
				doc = Nokogiri::HTML(response.body)
			end

			result = {
				url: params[:url],
				host: uri.host,
				title: doc.css("title").size > 0 ? doc.css("title")[0].content : url
			}
		rescue Exception => e
			puts e
			result = { error: e.to_s }	
		end

		render :json => result
	end

	def cache_image
		if session[:userinfo] != nil and session[:userinfo][:userid] == 'marx.zeng@ischool.com.tw'
			if (['all', 'channel'].include?(params[:type]))
				Thread.new do
					if params[:uqid] == nil
						items = Channel.select('uqid, logo').load
					else
						items = Channel.select('uqid, logo').where(uqid: params[:uqid]).load
					end

					items.each {|item|
						if item.logo != nil and item.logo != '' and item.logo.split('base64,').size == 2
							logo = Base64.decode64(item.logo.split('base64,')[1])
						else
							logo = Base64.decode64(DEFAULT_LOGO.split('base64,')[1])
						end

						File.open("public/images/channel/#{item.uqid}.png", 'wb') {|file| file.write(logo)}
					}
				end
			end

			if (['all', 'group'].include?(params[:type]))
				Thread.new do
					if params[:uqid] == nil
						items = Group.select('uqid, logo').load
					else
						items = Group.select('uqid, logo').where(uqid: params[:uqid]).load
					end

					items.each {|item|
						if item.logo != nil and item.logo != '' and item.logo.split('base64,').size == 2
							logo = Base64.decode64(item.logo.split('base64,')[1])
						else
							logo = Base64.decode64(DEFAULT_LOGO.split('base64,')[1])
						end

						File.open("public/images/group/#{item.uqid}.png", 'wb') {|file| file.write(logo)}
					}
				end
			end

			if (['all', 'knowledge'].include?(params[:type]))
				Thread.new do
					if params[:uqid] == nil
						items = DraftKnowledge.select('uqid, logo').load
					else
						items = DraftKnowledge.select('uqid, logo').where(uqid: params[:uqid]).load
					end

					items.each {|item|
						if item.logo != nil and item.logo != '' and item.logo.split('base64,').size == 2
							logo = Base64.decode64(item.logo.split('base64,')[1])
						else
							logo = Base64.decode64(DEFAULT_LOGO.split('base64,')[1])
						end

						File.open("public/images/knowledge/#{item.uqid}.png", 'wb') {|file| file.write(logo)}
					}
				end
			end

			if (['all', 'user'].include?(params[:type]))
				Thread.new do
					if params[:uqid] == nil
						items = User.select('uqid, photo, banner').where(nouser: false).order('last_login_time desc').load
					else
						items = User.select('uqid, photo, banner').where(nouser: false, uqid: params[:uqid]).order('last_login_time desc').load
					end
					
					items.each {|item|
						if item.banner != nil and item.banner != '' and item.banner.split('base64,').size == 2
							banner = Base64.decode64(item.banner.split('base64,')[1])
						else
							banner = Base64.decode64(DEFAULT_USER_BANNER.split('base64,')[1])
						end

						if item.photo != nil and item.photo != '' and item.photo.split('base64,').size == 2
							photo = Base64.decode64(item.photo.split('base64,')[1])
						else
							photo = Base64.decode64(DEFAULT_USER_PHOTO.split('base64,')[1])
						end

						File.open("public/images/user/#{item.uqid}_banner.png", 'wb') {|file| file.write(banner)}
						File.open("public/images/user/#{item.uqid}_photo.png", 'wb') {|file| file.write(photo)}
					}
				end
			end
		end

		render :json => { success: "Well done!" }
	end

	def send_mail
		sender = User.find(session[:userinfo][:id])
		sender_full_name = parse_full_name(sender.first_name, sender.last_name, sender.userid, sender.nouser)
		receiver = params[:email]

		if params[:type] == 'group'
			target = Group.where(uqid: params[:uqid]).first
			logo = get_image('group', { uqid: target.uqid })
			title = "<div style='margin:15px 0 0 72px'>#{sender_full_name} 在 <a href='#{params[:url]}' target='_blank'>1know</a> 与您分享了一个群组</div>"
			subject = "#{sender_full_name} 在 1know 与您分享了一个群组：「#{target.name}」"
		elsif params[:type] == 'channel'
			target = Channel.where(uqid: params[:uqid]).first
			logo = get_image('channel', { uqid: target.uqid })
			title = "<div style='margin:15px 0 0 72px'>#{sender_full_name} 在 <a href='#{params[:url]}' target='_blank'>1know</a> 与您分享了一个频道</div>"
			subject = "#{sender_full_name} 在 1know 与您分享了一个频道：「#{target.name}」"
		elsif params[:type] == 'knowledge'
			target = Knowledge.where(uqid: params[:uqid]).first
			logo = get_image('knowledge', { uqid: target.uqid })
			title = "<div style='margin:15px 0 0 72px'>#{sender_full_name} 在 <a href='#{params[:url]}' target='_blank'>1know</a> 与您分享了一个知识</div>"
			subject = "#{sender_full_name} 在 1know 与您分享了一个知识：「#{target.name}」"
		end

		if sender != nil and receiver!= nil and target != nil
			Thread.new do
				content =
					"<div style='width:640px;border:1px solid #ddd'>
						<div style='height:56px;padding:15px;font-size:18px'>
							<img style='width:56px;height:56px;float:left' src='#{get_image('user', { uqid: sender.uqid, nouser: sender.nouser, type: 'photo'})}'/>
							#{title}
						</div>
						#{
						if params[:memo] != nil and params[:memo] != ''
						"<div style='padding:15px'>
							#{params[:memo]}
						</div>"
						end
						}
						<div style='border-top:1px solid #ddd'></div>
						<div style='min-height:88px;padding:20px'>
							<img style='float:left;width:88px;height:88px' src='#{logo}'/>
							<div style='margin-left:104px'>
								<a href='#{params[:url]}' target='_blank'><h2>#{target.name}</h2></a>
								<div>#{target.description}</div>
							</div>
						</div>
					</div>"

				mail = Mail.deliver do
					charset = "UTF-8"

					subject subject
					from    "#{sender_full_name} (1Know)<notify@1know.net>"
					to      "#{receiver}<#{receiver}>"

					text_part do
						body content
					end

					html_part do
						content_type 'text/html; charset=UTF-8'
						body content
					end
				end
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end
end