_1know.controller('ClassroomCtrl', function($scope, $http, $location, $timeout, $routeParams, $compile, $utility, $interval) {
	var self = this;

	self.chooseDropboxFile = function(target) {
		if (target === 'files') {
			var options = {
				linkType: "preview",
				multiselect: true,
				success: function(files) {
					var content = [];
					files.forEach(function(item) {
						content.push({
							key: 'xxxxxxxx'.replace(/[xy]/g, function(c) { var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8); return v.toString(16); }),
							title: item.name,
							icon: item.icon,
							url: item.link,
							value: ['<a href="', item.link, '" target="_blank"><img style="height:20px" src="', item.icon, '"/><span style="margin-left:4px">', item.name, '</span></a>'].join('')
						});
					});

					$timeout(function() {
						self.target.file = self.target.file.concat(content);
						self.saveFile();
					},100);
				},
				cancel: function() {}
			};

			Dropbox.choose(options);
		}
		else if (target === 'message') {
			var options = {
				linkType: "preview",
				multiselect: false,
				success: function(files) {
					$timeout(function() {
						self.wallBoard.postContent = {
							url: files[0].link,
							title: files[0].name,
							host: 'www.dropbox.com'
						};

						if (files[0].thumbnails['640x480'] !== undefined)
							self.wallBoard.postContent.content = ['<img src="', files[0].thumbnails['640x480'], '" style="max-width:320px"/>'].join('');
					},100);
				},
				cancel: function() {}
			};

			Dropbox.choose(options);
		}
	}

	self.chooseGoogleFile = function(target) {
		if ($utility.GOOGLE_OAUTH_TOKEN === null) {
			gapi.auth.authorize({
				'client_id': $utility.GOOGLE_CLIEND_ID,
				'scope': $utility.GOOGLE_OAUTH_SCOPE,
				'immediate': false
			}, function(token) {
				if (token && !token.error) {
					$utility.GOOGLE_OAUTH_TOKEN = token.access_token;
					self.chooseGoogleFile(target);
				}
			});
		}
		else {
			if (target === 'files') {
				var picker = new google.picker.PickerBuilder()
					.addView(google.picker.ViewId.DOCS)
					.addView(new google.picker.DocsUploadView())
					.enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
					.setOAuthToken($utility.GOOGLE_OAUTH_TOKEN)
					.setDeveloperKey($utility.GOOGLE_DEVELOPER_KEY)
					.setCallback(function(data) {
						if (data.action == google.picker.Action.PICKED) {
							var content = [];
							data.docs.forEach(function(item) {
								content.push({
									key: 'xxxxxxxx'.replace(/[xy]/g, function(c) { var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8); return v.toString(16); }),
									title: item.name,
									icon: item.iconUrl,
									url: item.url,
									value: ['<a href="', item.url, '" target="_blank"><img style="height:20px" src="', item.iconUrl, '"/><span style="margin-left:4px">', item.name, '</span></a>'].join('')
								});
							});

							$timeout(function() {
								self.target.file = self.target.file.concat(content);
								self.saveFile();
							},100);
						}
					}).build();
				picker.setVisible(true);
			}
			else if (target === 'message') {
				var picker = new google.picker.PickerBuilder()
					.addView(google.picker.ViewId.DOCS)
					.addView(new google.picker.DocsUploadView())
					.setOAuthToken($utility.GOOGLE_OAUTH_TOKEN)
					.setDeveloperKey($utility.GOOGLE_DEVELOPER_KEY)
					.setCallback(function(data) {
						if (data.action == google.picker.Action.PICKED) {
							var embedUrl = '';
							if (data.docs[0].embedUrl !== undefined)
								embedUrl = data.docs[0].embedUrl;
							else
								embedUrl = ['https://docs.google.com/file/d/', data.docs[0].id, '/preview'].join('');

							$timeout(function() {
								self.wallBoard.postContent = {
									url: embedUrl,
									title: data.docs[0].name,
									host: 'docs.google.com'
								};

								if (data.docs[0].type === 'photo')
									self.wallBoard.postContent.content = ['<img src="https://drive.google.com/uc?export=view&id=', data.docs[0].id, '" style="max-width:320px"/>'].join('');
							},100);
						}
					}).build();
				picker.setVisible(true);
			}
		}
	}

	self.changeLayout = function(target) {
		self.layout = {};

		if (target === 'content') {
			self.layout.main = 'content';
			self.layout.sub = 'message';

			$timeout(function() {
				delete self.wallBoard.whatsMessage;
				delete self.wallBoard.postContent;

				self.drawBehaviorChart();
				$('[note-tooltip]').tooltip();
				$('#post-message').autosize();
			},100);
		}
		else if (target === 'knowledge') {
			self.layout.main = 'content';
			self.layout.sub = 'knowledge';
		}
		else if (target === 'activity') {
			self.layout.main = 'content';
			self.layout.sub = 'activity';
		}
		else if (target === 'file') {
			self.layout.main = 'content';
			self.layout.sub = 'file';
		}
		else if (target === 'link') {
			self.layout.main = 'content';
			self.layout.sub = 'link';

			delete self.linkUrl;
		}
		else if (target === 'profile') {
			self.layout.main = 'content';
			self.layout.sub = 'profile';
		}
		else if (target === 'picture') {
			self.layout.main = 'content';
			self.layout.sub = 'picture';
		}
		else if (target === 'behavior') {
			self.layout.main = 'content';
			self.layout.sub = 'behavior';
		}
		else if (target === 'self-behavior') {
			self.layout.main = 'content';
			self.layout.sub = 'self-behavior';

			self.showSelfBehavior();
		}
		else if (target === 'member') {
			self.layout.main = 'member';
			self.layout.sub = 'list-member';
		}
		else if (target === 'show-member-result') {
			self.layout.main = 'activity';
			self.layout.sub = 'show-member-result';
		}
		else if (target === 'show-unit-result') {
			self.layout.main = 'activity';
			self.layout.sub = 'show-unit-result';
		}
		else if (target === 'show-activity-summary') {
			self.layout.main = 'activity';
			self.layout.sub = 'show-activity-summary';
		}
		else
			self.layout.main = target;

		self.target.sortableKnowledge = false;
		self.target.sortableActivity = false;
		self.target.sortableActivityGoal = false;
		self.target.sortableFile = false;
		self.target.sortableLink = false;
		self.target.sortableMember = false;

		window.scrollTo(0, 0);
	}

	self.sortableKnowledge = function() {
		if (!self.target.sortableKnowledge) {
			self.target.sortableKnowledge = true;

			$('[knowledge-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.knowledges.splice(end, 0,
					self.knowledges.splice(start, 1)[0]);

					$scope.$apply();
					var item = self.knowledges[end];
					item.edit_priority = end + 1;
					self.updateKnowledge(item);
				}
			});
			$('[knowledge-list]').sortable('option', 'disabled', false);
			$('[knowledge-list]').disableSelection();
		}
		else {
			self.target.sortableKnowledge = false;
			$('[knowledge-list]').sortable('disable');
		}
	}

	self.sortableActivity = function() {
		if (!self.target.sortableActivity) {
			self.target.sortableActivity = true;

			$('[activity-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.activities.splice(end, 0,self.activities.splice(start, 1)[0]);

					$scope.$apply();
					var item = self.activities[end];
					item.edit_priority = end + 1;
					self.updateActivity(item);
				}
			});
			$('[activity-list]').sortable('option', 'disabled', false);
			$('[activity-list]').disableSelection();
		}
		else {
			self.target.sortableActivity = false;
			$('[activity-list]').sortable('disable');
		}
	}

	self.sortableActivityGoal = function() {
		if (!self.target.sortableActivityGoal) {
			self.target.sortableActivityGoal = true;

			$('[goal-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.currentActivity.edit_goal.splice(end, 0,
					self.currentActivity.edit_goal.splice(start, 1)[0]);
					$scope.$apply();
				}
			});
			$('[goal-list]').sortable('option', 'disabled', false);
			$('[goal-list]').disableSelection();
		}
		else {
			self.target.sortableActivityGoal = false;
			$('[goal-list]').sortable('disable');
		}
	}

	self.sortableFile = function() {
		if (!self.target.sortableFile) {
			self.target.sortableFile = true;

			$('[file-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.target.file.splice(end, 0,
					self.target.file.splice(start, 1)[0]);

					$scope.$apply();
					self.saveFile();
				}
			});
			$('[file-list]').sortable('option', 'disabled', false);
			$('[file-list]').disableSelection();
		}
		else {
			self.target.sortableFile = false;
			$('[file-list]').sortable('disable');
		}
	}

	self.sortableLink = function() {
		if (!self.target.sortableLink) {
			self.target.sortableLink = true;

			$('[link-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.target.link.splice(end, 0,
					self.target.link.splice(start, 1)[0]);

					$scope.$apply();
					self.saveLink();
				}
			});
			$('[link-list]').sortable('option', 'disabled', false);
			$('[link-list]').disableSelection();
		}
		else {
			self.target.sortableLink = false;
			$('[link-list]').sortable('disable');
		}
	}

	self.sortableMember = function() {
		if (!self.target.sortableMember) {
			self.target.sortableMember = true;

			$('[member-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.editMembers.splice(end, 0,
					self.editMembers.splice(start, 1)[0]);

					$scope.$apply();
					var member = self.editMembers[end];

					$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', member.item_uqid].join(''), { order: end + 1 })
					.success(function(response, status) {});
				}
			});
			$('[member-list]').sortable('option', 'disabled', false);
			$('[member-list]').disableSelection();
		}
		else {
			self.target.sortableMember = false;
			$('[member-list]').sortable('disable');
		}
	}

	self.listMessage = function(start_index, top) {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/messages?start-index=', start_index * 20, (top !== undefined && top === true ? '&top=true' : '')].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				angular.forEach(item.message, function(msg) {
					msg.publish_time_desc = msg.publish_time !== null && msg.publish_time !== '' ? $utility.timeToDesc(msg.publish_time) : '';
					msg.showModify = (item.publisher.uqid == $utility.account.uqid || $.inArray(self.self.role, ['owner', 'admin']) > -1);
				});
				item.publish_time_desc = item.publish_time !== null && item.publish_time !== '' ? $utility.timeToDesc(item.publish_time) : '';
				item.showMessage = false;
				item.showModify = (item.publisher.uqid == $utility.account.uqid || $.inArray(self.self.role, ['owner', 'admin']) > -1);
				item.showTop = $.inArray(self.self.role, ['owner', 'admin']) > -1;

				if (item.note) {
					item.note.timeDesc = $utility.timeToFormat(item.note.time);
					item.note.popover = [item.note.k_name.replace(/"/ig, "'"), item.note.u_name.replace(/"/ig, "'")].join('<br/>');
				}
			})

			if (top)
				self.topMessages = response;
			else {
				self.message_start_index = start_index;

				if (self.message_start_index === 0)
					self.messages = response;
				else
					self.messages = self.messages.concat(response);

				if (response.length < 20)
					self.message_start_index = -1;
			}

			$timeout(function() {
				$('[note-tooltip]').tooltip();
			},100);
		});
	}

	self.parseWhatsMessage = function(event) {
		if (self.wallBoard.whatsMessage === '') self.wallBoard.parseMessage = '';
		if (!self.wallBoard.whatsMessage || self.wallBoard.whatsMessage === '') return;

		self.wallBoard.parseMessage = self.wallBoard.whatsMessage.replace(/\r\n|\r|\n/g, '<br/>');

		var urlString = self.wallBoard.whatsMessage.match("\\(?\\b(http://|https://|www[.])[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]");
		if (urlString) {
			self.wallBoard.parseMessage = self.wallBoard.whatsMessage.replace(urlString[0], ['<a href="', urlString[0], '" target="_blank">', urlString[0], '</a>'].join('')).replace(/\r\n|\r|\n/g, '<br/>');

			var url = urlString[0];
			var videoPath = url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
			var imagePath = url.match(/([a-z\-_0-9\/\:\.]*\.(jpg|jpeg|png|gif))/i);

			if (videoPath !== null && videoPath.length === 6) {
				if (videoPath[2] === 'youtube') {
					$.get(['http://gdata.youtube.com/feeds/api/videos/', videoPath[5], '?alt=json'].join(''), function(response) {
						$scope.$apply(function() {
							self.wallBoard.postContent = {
								title: response.entry.title.$t,
								url: videoPath[0],
								host: 'www.youtube.com',
								content: ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '" width="400px" height="225px" frameborder="0"></iframe>'].join('')
							}
						});
					});
				}
				else if (videoPath[2] === 'vimeo') {
					$.get(['http://vimeo.com/api/oembed.json?url=', videoPath[0]].join(''), function(response) {
						$scope.$apply(function() {
							self.wallBoard.postContent = {
								title: response.title,
								url: videoPath[0],
								host: 'vimeo.com',
								content: ['<iframe src="https://player.vimeo.com/video/', videoPath[3], '" width="400px" height="225px" frameborder="0"></iframe>'].join('')
							}
						});
					});
				}
				else if (videoPath[2] === 'youku') {
					$.get(['https://openapi.youku.com/v2/videos/show_basic.json?client_id=c865b5756563acee&video_id=', videoPath[4]].join(''), function(response) {
						$scope.$apply(function() {
							self.wallBoard.postContent = {
								title: response.title,
								url: videoPath[0],
								host: 'www.youku.com',
								content: ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="400px" height="225px" frameborder="0"></iframe>'].join('')
							}
						});
					});
				}
			}
			else if (imagePath !== null) {
				self.wallBoard.postContent = {
					title: '',
					url: '',
					host: '',
					content: ['<img src="', url, '" style="max-width:320px"/>'].join('')
				}
			}
			else {
				var data = { url: url };
				$http.post([$utility.SERVICE_URL, '/utility/parseURL'].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						if (response.image === null || response.image === '')
							response.image = "http://1know.net/favicon.ico";

						self.wallBoard.postContent = response;
					}
				});
			}
		}
	}

	self.removePostContent = function() {
		delete self.wallBoard.whatsMessage;
		delete self.wallBoard.parseMessage;
		delete self.wallBoard.postContent;
		delete self.wallBoard.onPostMessage;
	}

	self.postMessage = function() {
		if (self.wallBoard.onPostMessage === undefined && (self.wallBoard.parseMessage || self.wallBoard.postContent)) {
			self.wallBoard.onPostMessage = true;

			var data = {};
			if (self.wallBoard.parseMessage)
				data = { content: ['<div style="word-break:break-all;margin-bottom:10px">', self.wallBoard.parseMessage.replace(/\r\n|\r|\n/g, '<br/>'), '</div>'].join('') };
			if (self.wallBoard.postContent) {
				data.content =
					[data.content,
					'<div>',
						'<div>', self.wallBoard.postContent.content, '</div>',
						self.wallBoard.parseMessage||(self.wallBoard.postContent.content&&self.wallBoard.postContent.host) ?
						'<div style="margin-top:10px;padding-top:10px;border-top:1px solid #ddd"></div>' : '',
						self.wallBoard.postContent.host ?
						['<div>',
							'<a style="font-size:14px;font-weight:bold;word-break:break-all" href="', self.wallBoard.postContent.url, '" target="_blank">', self.wallBoard.postContent.title, '</a>',
							'<div class="text-muted" style="font-size:12px;line-height:14px;margin-top:4px">', self.wallBoard.postContent.host, '</div>',
						'</div>'].join('') : '',
					'</div>'].join('');
			}

			$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/messages'].join(''), data)
			.success(function(response, status) {
				self.listMessage(0);

				delete self.wallBoard.whatsMessage;
				delete self.wallBoard.parseMessage;
				delete self.wallBoard.postContent;
				delete self.wallBoard.onPostMessage;

				self.socket.send({
					poster: $utility.account.uqid,
					type: 'wall-message-changed'
				});
			});
		}
	}

	self.parseFollowMessage = function(event, target) {
		if (event.keyCode === 27) {
			target.reply = false;
			delete target.followMessage;
			delete target.parseMessage;
			delete target.postContent;
			return;
		}

		if (target.followMessage === '') target.parseMessage = '';
		if (!target.followMessage || target.followMessage === '') return;

		target.parseMessage = target.followMessage.replace(/\r\n|\r|\n/g, '<br/>');

		var urlString = target.followMessage.match("\\(?\\b(http://|https://|www[.])[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]");
		if (urlString) {
			target.parseMessage = target.followMessage.replace(urlString[0], ['<a href="', urlString[0], '" target="_blank">', urlString[0], '</a>'].join('')).replace(/\r\n|\r|\n/g, '<br/>');

			var url = urlString[0];
			var videoPath = url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
			var imagePath = url.match(/([a-z\-_0-9\/\:\.]*\.(jpg|jpeg|png|gif))/i);

			if (videoPath !== null && videoPath.length === 6) {
				if (videoPath[2] === 'youtube') {
					$.get(['http://gdata.youtube.com/feeds/api/videos/', videoPath[5], '?alt=json'].join(''), function(response) {
						$scope.$apply(function() {
							target.postContent = {
								title: response.entry.title.$t,
								url: videoPath[0],
								host: 'www.youtube.com',
								content: ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '" width="400px" height="225px" frameborder="0"></iframe>'].join('')
							}
						});
					});
				}
				else if (videoPath[2] === 'vimeo') {
					$.get(['http://vimeo.com/api/oembed.json?url=', videoPath[0]].join(''), function(response) {
						$scope.$apply(function() {
							target.postContent = {
								title: response.title,
								url: videoPath[0],
								host: 'vimeo.com',
								content: ['<iframe src="https://player.vimeo.com/video/', videoPath[3], '" width="400px" height="225px" frameborder="0"></iframe>'].join('')
							}
						});
					});
				}
				else if (videoPath[2] === 'youku') {
					$.get(['https://openapi.youku.com/v2/videos/show_basic.json?client_id=c865b5756563acee&video_id=', videoPath[4]].join(''), function(response) {
						$scope.$apply(function() {
							target.postContent = {
								title: response.title,
								url: videoPath[0],
								host: 'www.youku.com',
								content: ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="400px" height="225px" frameborder="0"></iframe>'].join('')
							}
						});
					});
				}
			}
			else if (imagePath !== null) {
				target.postContent = {
					title: '',
					url: '',
					host: '',
					content: ['<img src="', url, '" style="max-width:320px"/>'].join('')
				}
			}
			else {
				var data = { url: url };
				$http.post([$utility.SERVICE_URL, '/utility/parseURL'].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						if (response.image === null || response.image === '')
							response.image = "http://1know.net/favicon.ico";

						target.postContent = response;
					}
				});
			}
		}
	}

	self.followMessage = function(target) {
		if (target.onPostMessage === undefined && (target.parseMessage || target.postContent)) {
			target.onPostMessage = true;

			var data = {
				message_uqid: target.uqid,
				content: ['<div style="word-break:break-all;margin-bottom:10px">', target.parseMessage.replace(/\r\n|\r|\n/g, '<br/>'), '</div>'].join('')
			};

			if (target.postContent) {
				data.content =
					[data.content,
					'<div>',
						'<div>', target.postContent.content, '</div>',
						target.parseMessage||(target.postContent.content&&target.postContent.host) ?
						'<div style="margin-top:10px;padding-top:10px;border-top:1px solid #ddd"></div>' : '',
						target.postContent.host ?
						['<div>',
							'<a style="font-size:14px;font-weight:bold;word-break:break-all" href="', target.postContent.url, '" target="_blank">', target.postContent.title, '</a>',
							'<div class="text-muted" style="font-size:12px;line-height:14px;margin-top:4px">', target.postContent.host, '</div>',
						'</div>'].join('') : '',
					'</div>'].join('');
			}

			$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/messages'].join(''), data)
			.success(function(response, status) {
				self.listMessage(0);

				delete target.followMessage;
				delete target.parseMessage;
				delete target.postContent;
				delete target.onPostMessage;
			});
		}
	}

	self.removeMessage = function(target) {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/messages/', target.uqid].join(''))
		.success(function(response, status) {
			self.listMessage(0, true);
			self.listMessage(0);
		});
	}

	self.refreshMessage = function() {
		self.listMessage(0);
		delete self.wallMessageChanged;
	}

	self.replyMessage = function(item) {
		item.reply = true;
		$timeout(function() {
			$(['#reply-', item.uqid].join('')).autosize();
		},100);
	}

	self.likeMessage = function(item) {
		$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/messages/', item.uqid, '/like'].join(''))
		.success(function(response, status) {
			item.like = response.like;
		});
	}

	self.topMessage = function(item) {
		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/messages/', item.uqid, '/top'].join(''))
		.success(function(response, status) {
			self.listMessage(0, true);
			self.listMessage(0);
		});
	}

	self.showActivityStatistics = function(target) {
		self.layout.main = 'activity';
		self.layout.sub = 'show-activity-summary';

		self.currentActivity = target;
		self.currentActivity.loading = true;
		self.currentActivity.progress = {
			all: 0,
			complated: 0,
			uncomplated: 0,
			unstarted: 0
		}

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', target.uqid, '/statistics'].join(''))
		.success(function(response, status) {
			self.currentActivity.statistics = response;
			self.currentActivity.progress.all = response.length;

			angular.forEach(response, function(item) {
				item.units = [];
				item.finished_unit = 0;
				angular.forEach(self.currentActivity.goal, function(goal) {
					var temp = {
						uqid: goal.unit.uqid,
						name: goal.unit.name,
						unit_type: goal.unit.unit_type,
						content_url: goal.unit.content_url,
						total_time: Math.ceil(goal.unit.content_time),
						total_time_desc: $utility.timeToFormat(Math.ceil(goal.unit.content_time)),
						status: 0,
						gained_time: 0,
						total_time: 0,
						last_view_time: '',
						score: '',
						comment: '',
						note_size: 0,
						progress: 0,
						popover: [item.full_name.replace(/"/ig, "'"), goal.unit.name.replace(/"/ig, "'")].join('<br/>')
					};

					angular.forEach(item.status.unit_uqid, function(uqid, index) {
						if (uqid === temp.uqid) {
							temp.status = item.status.status[index];
							temp.gained_time = Math.ceil(item.status.gained_time[index]);
							temp.gained_time_desc = $utility.timeToFormat(Math.ceil(item.status.gained_time[index]));
							temp.last_view_time = item.status.last_view_time[index] !== null ? new Date(item.status.last_view_time[index]) : '';
							temp.progress = isNaN(item.status.gained_time[index]/goal.unit.content_time) ? 0 : ((item.status.gained_time[index]/goal.unit.content_time) > 1 ? 100 : Math.ceil((item.status.gained_time[index]/goal.unit.content_time) * 100));

							if (temp.status === 4) {
								item.finished_unit += 1;
								if (temp.gained_time + 5 < temp.total_time) {
									temp.style = {border: '2px solid #f00', 'margin-top': '-2px'};
									temp.uncomplated = true;
								}
							}

							item.progress = Math.ceil((item.finished_unit/ item.total_unit) * 100);

							var time = [$utility.timeToFormat(Math.ceil(temp.gained_time)), ' / ', $utility.timeToFormat(Math.ceil(temp.total_time))].join('');
							var last_learning = [temp.last_view_time.toLocaleString()].join('');
							temp.popover = temp.status ? [item.full_name.replace(/"/ig, "'"), goal.unit.name.replace(/"/ig, "'"), time, last_learning].join('<br/>') : '';
						}
					});

					angular.forEach(item.feedback.unit_uqid, function(uqid, index) {
						if (uqid === temp.uqid) {
							temp.feedback_uqid = item.feedback.feedback_uqid[index];
							temp.score = item.feedback.score[index];
							temp.comment = item.feedback.comment[index];
						}
					});

					angular.forEach(item.note.unit_uqid, function(uqid, index) {
						if (uqid === temp.uqid) {
							temp.note_size = item.note.note_size[index];
						}
					});

					item.units.push(temp);
				});

				if (item.progress === 100)
					self.currentActivity.progress.complated += 1;
				else if (!item.progress || item.progress === 0)
					self.currentActivity.progress.unstarted += 1;
				else
					self.currentActivity.progress.uncomplated += 1;
			});

			self.filterActivityStatistics('all');
		});
	}

	self.filterActivityStatistics = function(type) {
		self.currentActivity.loading = true;

		$timeout(function() {
			self.currentActivity.loading = false;

			var rhtml = [], rtr = [], lhtml = [];
			angular.forEach(self.currentActivity.statistics, function(item, index) {
				rtr = [];
				angular.forEach(item.units, function(unit) {
					rtr.push(
						['<td style="padding:2px">',
							'<a class="btn btn-xs btn-block ', unit.status===4 ? 'btn-success' : (unit.status===2 ? 'btn-warning' : 'btn-default'), '" \
								style="width:60px', (unit.uncomplated ? ';border:2px solid #f00;height:22px': ''), '" \
								data-html="true" data-title="', unit.popover, '" data-toggle="tooltip" member-tooltip member="', item.user_uqid, '" unit="', unit.uqid, '">', unit.note_size||'&nbsp;', '</a>',
						'</td>'].join(''));
				});
				rtr.push('<td style="padding:2px"><div style="width:40px;height:22px">&nbsp;</div></td>');

				if (type === 'all') {
					item.show = true;
					rhtml.push(['<tr>', rtr.join(''), '</tr>'].join(''));
				}
				else if (type === 'complated') {
					if (item.progress === 100) {
						item.show = true;
						rhtml.push(['<tr>', rtr.join(''), '</tr>'].join(''));
					}
					else
						item.show = false;
				}
				else if (type === 'uncomplated') {
					if (item.progress < 100 && item.progress > 0) {
						item.show = true;
						rhtml.push(['<tr>', rtr.join(''), '</tr>'].join(''));
					}
					else
						item.show = false;
				}
				else if (type === 'unstarted') {
					if (!item.progress || item.progress === 0) {
						item.show = true;
						rhtml.push(['<tr>', rtr.join(''), '</tr>'].join(''));
					}
					else
						item.show = false;
				}

				if (item.show) {
					lhtml.push(
						['<tr>',
							'<td style="padding:2px">',
								'<div class="progress" style="width:40px;margin:0" data-html="true" data-placement="right" data-title="', (item.progress || 0), '%" \
									data-toggle="tooltip" activity-member-progress-tooltip>',
									'<div class="progress-bar ', (item.progress === 100) ? 'progress-bar-success' : 'progress-bar-warning', '" role="progressbar" \
										aria-valuenow="', item.progress, '" aria-valuemin="0" aria-valuemax="100" style="width:', item.progress, '%"></div>',
								'</div>',
							'</td>',
							'<td style="padding:2px">',
								'<div style="width:40px">', (index + 1), '</div>',
							'</td>',
							'<td style="padding:2px 6px">',
								'<div class="activity-chart-member" member-study-result member="', item.user_uqid, '">', item.full_name, '</div>',
							'</td>',
						'</tr>'].join(''));
				}
			});

			$('#currentActivity_statistics [container] [left] tbody').html(lhtml);
			$('[member-study-result]').on('click', function() {
				var member_uqid = $(this).attr('member');

				angular.forEach(self.currentActivity.statistics, function(item) {
					if (member_uqid === item.user_uqid) {
						$scope.$apply(function(){self.showMemberStudyResult(item);});
					}
				});
			});

			$('#currentActivity_statistics [container] [right] tbody').html(rhtml);
			$('[member-tooltip]').tooltip();
			$('[member-tooltip]').on('click', function() {
				var member_uqid = $(this).attr('member'), unit_uqid = $(this).attr('unit');

				angular.forEach(self.currentActivity.statistics, function(item) {
					if (member_uqid === item.user_uqid) {
						angular.forEach(item.units, function(unit) {
							if (unit_uqid === unit.uqid) {
								$scope.$apply(function(){self.showMemberActivityUnitResult(item, unit);});
							}
						});
					}
				});
			});
			$('#currentActivity_statistics [container] [right]').on('scroll', function() {
				$('#currentActivity_statistics [header] [right] table').offset({
					left: $('#currentActivity_statistics [container] [right] table').offset().left
				});
			});

			$(window).on('scroll', function() {
				var top = window.document.body.scrollTop || window.document.documentElement.scrollTop;

				if (top > 104) {
					$('#currentActivity_statistics [header]').css({
						top: 0,
						position: 'fixed',
						'background-color': 'rgba(34,34,34,0.8)',
						color: 'rgba(255,255,255,0.8)'
					});
					$('#currentActivity_statistics [container]').css('padding-bottom', '104px')
				}
				else {
					$('#currentActivity_statistics [header]').css({
						top: 'auto',
						position: 'auto',
						'background-color': 'transparent',
						color: 'rgba(0,0,0,1)'
					});
					$('#currentActivity_statistics [container]').css('padding-bottom', 'auto')
				}
			});

			$timeout(function(){$('[activity-member-progress-tooltip]').tooltip();},100);
			self.currentActivity.loading = false;
		},100);

		window.scrollTo(0, 0);
	}

	self.showMemberStudyResult = function(target) {
		self.changeLayout('show-member-result');
		self.currentActivity.currentMember = target;
	}

	self.showMemberUnitStudyResult = function(unit) {
		self.layout.third = 'notes';
		self.currentActivity.currentMember.currntUnit = unit;

		angular.forEach(self.currentActivity.currentMember.units, function(item) {
			item.active = false;
		});
		unit.active = true;

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', self.currentActivity.uqid, '/unit/', unit.uqid, '/member/', self.currentActivity.currentMember.user_uqid, '?timezone=', -1 * (new Date()).getTimezoneOffset() / 60].join(''))
		.success(function(response, status) {
			unit.notes = response.notes;

			angular.forEach(unit.notes, function(item) {
				item.timeDesc = $utility.timeToFormat(item.time);
			});
		});

		window.scrollTo(0, 0);
	}

	self.hideMemberUnitStudyResult = function() {
		delete self.layout.third;
		angular.forEach(self.currentActivity.currentMember.units, function(item) {
			item.active = false;
		});
	}

	self.showUnitStudyResult = function(target) {
		self.changeLayout('show-unit-result');
		self.currentActivity.currentUnit = target;

		if ($.inArray(target.unit_type, ['video', 'web', 'embed']) !== -1)
			self.toggleUnitViewType('note');
		else if ($.inArray(target.unit_type, ['quiz', 'qa', 'poll', 'draw']) !== -1)
			self.toggleUnitViewType('statistics');
	}

	self.toggleUnitViewType = function(type) {
		if (self.currentActivity.currentUnit.viewType === type) return;

		if (type === 'note')
			self.loadUnitStudyNote();
		else if (type === 'statistics')
			self.loadUnitStudyResult();
		else if (type === 'content') {
			self.currentActivity.currentUnit.viewType = type;

			if (self.currentActivity.currentUnit.unit_type === 'video') {
				var videoPath = self.currentActivity.currentUnit.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);

				if (videoPath !== null && videoPath[2] === 'youtube')
					self.currentActivity.currentUnit.video_url = ['http://www.youtube.com/embed/', videoPath[5]].join('');
				else if (videoPath !== null && videoPath[2] === 'vimeo')
					self.currentActivity.currentUnit.video_url = ['https://player.vimeo.com/video/', videoPath[3]].join('');
				else
					self.currentActivity.currentUnit.video_url = self.currentActivity.currentUnit.content_url;
			}
		}
	}

	self.loadUnitStudyNote = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', self.currentActivity.uqid, '/unit/', self.currentActivity.currentUnit.uqid, '/note'].join(''))
		.success(function(response, status) {
			self.currentActivity.currentUnit = response.unit;
			self.currentActivity.students = response.user;
			self.currentActivity.currentUnit.noteOrderType = 'member';
			self.currentActivity.currentUnit.absUrl = [$utility.BASE_URL, '/watch?k=', self.currentActivity.currentUnit.knowledge.uqid, '&u=', self.currentActivity.currentUnit.uqid].join('');

			var series = [{name:'Time', data: []}];
			var times = {}, categories = [];

			angular.forEach(response.user, function(item) {
				angular.forEach(item.notes, function(note) {
					note.timeDesc = $utility.timeToFormat(note.time);
					note.visible = true;
					if (note.color === null) note.color = "#fff";

					if (!times[note.time]) {
						categories.push(note.time);
						times[note.time] = 1;
					}
					else
						times[note.time] += 1;
				})
			});

			angular.forEach(categories, function(item) {
				series[0].data.push({
					x: item,
					y: 1,
					z: times[item],
					timeDesc: $utility.timeToFormat(item),
					events: {
						click: function() {
							$timeout(function() {
								self.openNodeVideo(self.currentActivity.currentUnit, item);
							},100);
						}
					}
				});
			});

			self.currentActivity.currentUnit.viewType = 'note';

			if (self.currentActivity.currentUnit.unit_type === 'video') {
				$timeout(function() {
					$('#chart_timebox').highcharts({
						credits: { enabled: false },
						chart: {
							type: 'bubble',
							zoomType: 'xy'
						},
						title: { text: '' },
						xAxis: {
							title: '',
							labels: { enabled: false },
							min: 0,
							max: self.currentActivity.currentUnit.content_time
						},
						yAxis: {
							title: '',
							labels: { enabled: false }
						},
						legend: { enabled: false },
						tooltip: {
							formatter: function() {
								return ["<span>Time: ", this.point.timeDesc, "</span><br/>", "<span>Notes: ", this.point.z, "</span>"].join('');
							},
							useHTML: true
						},
						series: series
					});
				},100);
			}
		});
	}

	self.toggleUnitNodteOrderType = function(type) {
		self.currentActivity.currentUnit.noteOrderType = type;
		self.clearUnitNoteColorFilter();

		if (type === 'time' && !self.currentActivity.currentUnit.timeNotes) {
			var timeNotes = [], timeIndex = [];
			angular.forEach(self.currentActivity.students, function(user) {
				angular.forEach(user.notes, function(note) {
					if ($.inArray(note.time, timeIndex) === -1) {
						timeIndex.push(note.time);
						timeNotes.push({
							time: note.time,
							timeDesc: $utility.timeToFormat(note.time),
							notes: [{full_name: user.full_name, color: note.color, type: note.type, content: note.content, visible: true}]
						})
					}
					else {
						angular.forEach(timeNotes, function(item) {
							if (item.time === note.time) {
								item.notes.push({full_name: user.full_name, color: note.color, type: note.type, content: note.content, visible: true});
							}
						});
					}
				});
			});

			timeNotes.sort(function(i, j) {
				return (i.time - j.time);
			});

			self.currentActivity.currentUnit.timeNotes = timeNotes;
		}
	}

	self.toggleUnitNoteColorFilter = function(color) {
		self.currentActivity.currentUnit.noteColor = color;

		if (self.currentActivity.currentUnit.noteOrderType === 'member') {
			angular.forEach(self.currentActivity.students, function(item) {
				angular.forEach(item.notes, function(note) {
					if (note.color === color)
						note.visible = true;
					else
						note.visible = false;
				})
			});
		}
		else if (self.currentActivity.currentUnit.noteOrderType === 'time') {
			angular.forEach(self.currentActivity.currentUnit.timeNotes, function(item) {
				angular.forEach(item.notes, function(note) {
					if (note.color === color)
						note.visible = true;
					else
						note.visible = false;
				})
			});
		}
	}

	self.clearUnitNoteColorFilter = function() {
		delete self.currentActivity.currentUnit.noteColor;

		angular.forEach(self.currentActivity.students, function(item) {
			angular.forEach(item.notes, function(note) {
				note.visible = true;
			})
		});

		if (self.currentActivity.currentUnit.timeNotes) {
			angular.forEach(self.currentActivity.currentUnit.timeNotes, function(item) {
				angular.forEach(item.notes, function(note) {
					note.visible = true;
				})
			});
		}
	}

	self.loadUnitStudyResult = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', self.currentActivity.uqid, '/unit/', self.currentActivity.currentUnit.uqid].join(''))
		.success(function(response, status) {
			self.currentActivity.currentUnit = response.unit;
			self.currentActivity.students = response.user;
			self.currentActivity.currentUnit.statisticsType = 'full';
			self.currentActivity.currentUnit.absUrl = [$utility.BASE_URL, '/watch?k=', self.currentActivity.currentUnit.knowledge.uqid, '&u=', self.currentActivity.currentUnit.uqid].join('');

			self.targetItem = { unit: response.unit };

			angular.forEach(response.unit.quizzes, function(quiz) {
				quiz.full_content = function(quiz) {
					return [parseInt(quiz.quiz_no, 10) < 10 ? '0' + quiz.quiz_no : quiz.quiz_no, quiz.content.replace(/<(?:.|\n)*?>/gm, '')].join('. ');
				}
			});

			self.currentActivity.currentUnit.viewType = 'statistics';
			self.parseUnitStudyResult();
		});
	}

	self.toggleUnitStatisticsType = function(type) {
		self.currentActivity.currentUnit.statisticsType = type;

		var chart = $('#unit_study_chart').highcharts();
		var max = null;

		if (type === 'normal')
			max = self.currentActivity.currentUnit.content_time * 1.1;
		else
			max = self.currentActivity.currentUnit.yAxisMax * 1.1;

		chart.yAxis[0].update({max: max});
	}

	self.parseUnitStudyResult = function() {
		if (self.currentActivity.currentUnit.unit_type === 'video' ||
			self.currentActivity.currentUnit.unit_type === 'web' ||
			self.currentActivity.currentUnit.unit_type === 'embed') {

			$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', self.currentActivity.uqid, '/unit/', self.currentActivity.currentUnit.uqid, '/hsitory?timezone=', -1 * (new Date()).getTimezoneOffset() / 60].join(''))
			.success(function(response, status) {
				var series = [{name:'', data: []}, {name:'', data: []}, {name:'', data: []}], categories = [], yAxisMax = self.currentActivity.currentUnit.content_time;

				angular.forEach(self.currentActivity.students, function(item, index) {
					categories.push(item.full_name);
					series[0].data.push({y:0,label:'',tooltip:''});
					series[1].data.push({y:0,label:'',tooltip:''});

					angular.forEach(response, function(user) {
						if (user.uqid === item.uqid) {
							categories[index] = [categories[index], ' (', $utility.timeToFormat(user.seconds), ')'].join('');

							if (user.status === 4) {
								series[0].data[index] = {
									y: user.seconds,
									label: $utility.timeToFormat(user.seconds),
									tooltip: ['<span>', user.full_name, '</span><br/><span>', $utility.timeToFormat(user.seconds), '</span>'].join('')
								};
							}
							else if (user.status === 2) {
								series[1].data[index] = {
									y: user.seconds,
									label: $utility.timeToFormat(user.seconds),
									tooltip: ['<span>', user.full_name, '</span><br/><span>', $utility.timeToFormat(user.seconds), '</span>'].join('')
								};
							}

							if (user.seconds > yAxisMax) yAxisMax = user.seconds;
						}
					});
				});

				self.currentActivity.currentUnit.yAxisMax = yAxisMax;

				var height = self.currentActivity.students.length * 36;
				height = height < 120 ? 120 : height;
				$('#unit_study_chart').css('height', height);
				$('#unit_study_chart').highcharts({
					credits: { enabled: false },
					title: { text: '' },
					chart: { type: 'bar' },
					colors: ['#5cb85c', '#f0ad4e', '#fff'],
					xAxis: {
						categories: categories,
						labels: { enabled: true }
					},
					yAxis: {
						title: {
							text: '.',
							align: 'right',
							style: { color: '#fff' }
						},
						labels: { enabled: false },
						opposite: true,
						max: yAxisMax * 1.1,
						plotLines: [{
							value: self.currentActivity.currentUnit.content_time,
							color: 'red',
							dashStyle: 'shortdash',
							width: 2,
							label: {
								text: $utility.timeToFormat(self.currentActivity.currentUnit.content_time),
								rotation: 0,
								y: -10,
								style: {
									color: '#f00',
									fontSize: 14
								}
							}
						}]
					},
					plotOptions: {
						series: {
							stacking: 'normal'
						}
					},
					tooltip: {
						formatter: function() {
							return this.point.tooltip;
						},
						useHTML: true
					},
					legend: { enabled: false },
					series: series
				});
			});
		}
		else if (self.currentActivity.currentUnit.unit_type === 'quiz') {
			self.parseQuizResult();
			$timeout(function(){self.drawQuizChart()});
		}
		else if (self.currentActivity.currentUnit.unit_type === 'poll') {
			$timeout(function(){self.drawPollChart()});
		}
	}

	self.drawPollChart = function() {
		var data = [], count = 0;

		angular.forEach(self.currentActivity.currentUnit.content.options, function(option) {
			data.push({
				name: option.item,
				value: option.value,
				y: 0
			});
		});

		angular.forEach(self.currentActivity.students, function(item) {
			angular.forEach(item.result, function(result) {
				angular.forEach(data, function(key) {
					if (key.value === result) {
						key.y += 1;
						count += 1;
					}
				});
			});
		});

		if (count > 0) {
			$('#unit_study_chart').css('height', 360);
			$('#unit_study_chart').highcharts({
				credits: { enabled: false },
				title: {
					align: 'left',
					text: ['<h3>', self.currentActivity.currentUnit.content.content, '</h3>'].join(''),
					useHTML: true
				},
				chart: {
					plotBackgroundColor: null,
					plotBorderWidth: null,
					plotShadow: false
				},
				tooltip: { enabled: false },
				plotOptions: {
					pie: {
						allowPointSelect: true,
						cursor: 'pointer',
						dataLabels: {
							enabled: true,
							color: '#000000',
							connectorColor: '#000000',
							format: '<b>{point.name}</b>: {point.percentage:.1f} % ({point.y})',
							style: {
								fontWeight: 'bold',
								fontSize: 16
							}
						}
					}
				},
				series: [{
					type: 'pie',
					name: 'Poll',
					data: data
				}]
			});
		}
	}

	self.drawQuizChart = function() {
		var datas = [], categories = [];

		angular.forEach(self.currentActivity.currentUnit.quizzes, function(item, index) {
			categories.push(index+1);

			var tooltip = [];
			angular.forEach(item.options, function(option, j) {
				tooltip.push(['<tr><td style="padding:4px">(', (option.correct ? '<i class="fa fa-fw fa-circle-o text-success"></i>' : '<i class="fa fa-fw fa-times text-danger"></i>'), ') ', option.item, '</td><td style="padding:4px">:</td><td style="padding:4px">', option.result_count, '</td></tr>'].join(''));
			});
			tooltip = ['<table><thead><tr><td colspan="3">', item.content, '</td></tr></thead><tbody>', tooltip.join(''), '</tbody></table>'].join('');
			datas.push({ y: 0, tooltip: tooltip });
		});

		angular.forEach(self.currentActivity.students, function(item) {
			angular.forEach(item.quizzes, function(quiz, index) {
				if (quiz.correct) datas[index].y += 1;
			});
		});

		var height = self.currentActivity.currentUnit.quizzes.length * 36;
		height = height < 240 ? 240 : height;
		$('#unit_study_chart').css('height', height);
		$('#unit_study_chart').highcharts({
			credits: { enabled: false },
			title: { text: null },
			xAxis: {
				categories: categories,
				title: {
					text: translations[$utility.LANGUAGE.type]['J013'],//題目
				}
			},
			yAxis: {
				min: 0,
				max: self.currentActivity.students.length,
				tickInterval: 1,
				opposite: true,
				title: {
					text: [translations[$utility.LANGUAGE.type]['J014'], '(', self.currentActivity.students.length, ')'].join('')//答對人數 / 總人數
				},
				plotLines: [{
					value: 0,
					width: 1,
					color: '#808080'
				}]
			},
			tooltip: {
				formatter: function() {
					return this.point.tooltip;
				},
				useHTML: true
			},
			plotOptions: {
				series: {
					stacking: 'normal'
				}
			},
			legend: { enabled: false },
			series: [{
				type: 'bar',
				name: 'Correct',
				data: datas
			}]
		});
	}

	self.parseQuizResult = function() {
		angular.forEach(self.currentActivity.currentUnit.quizzes, function(item) {
			angular.forEach(item.options, function(option) {
				option.result_count = 0;
			});
		});

		angular.forEach(self.currentActivity.students, function(user) {
			user.score = {
				success: 0,
				total: self.currentActivity.currentUnit.quizzes.length
			};

			user.quizzes = [];
			angular.forEach(self.currentActivity.currentUnit.quizzes, function(item, index) {
				var options = [];
				angular.forEach(item.options, function(option) {
					options.push({
						answer: false,
						correct: option.correct,
						item: option.item,
						latex: option.latex,
						latex_url: option.latex_url,
						value: option.value
					});
				});
				var quiz = {
					correct: false,
					uqid: item.uqid,
					quiz_no: item.quiz_no,
					quiz_type: item.quiz_type,
					content: item.content,
					options: options,
					answer: item.answer
				};

				if (user.result) {
					angular.forEach(user.result.result, function(key) {
						if (key.uqid === quiz.uqid) {
							if (quiz.quiz_type === 'multi') {
								var correct = 0;
								angular.forEach(key.answer, function(key) {
									angular.forEach(item.options, function(option) {
										if (key === option.value)
											option.result_count += 1;
									});

									angular.forEach(quiz.options, function(option) {
										if (key === option.value) {
											option.answer = true;
											correct += option.value;
										}
									});
								});

								if (correct === parseInt(quiz.answer, 10)) {
									quiz.correct = true;
									user.score.success += 1;
								}
								else
									quiz.correct = false;
							}
							else {
								angular.forEach(item.options, function(option) {
									if (key.answer[0] === option.value)
										option.result_count += 1;
								});

								angular.forEach(quiz.options, function(option) {
									if (key.answer[0] === option.value)
										option.answer = true;
								});

								if (key.answer[0] === parseInt(quiz.answer, 10)) {
									quiz.correct = true;
									user.score.success += 1;
								}
								else
									quiz.correct = false;
							}
						}
					});
				}

				user.quizzes.push(quiz);
			});
		});
	}

	self.showTargetItemResult = function(target) {
		self.currentActivity.currentUnit.targetItem = target;

		$timeout(function() {
			$('#draw-board').html('<canvas></canvas>');
			$('#draw-board').literallycanvas({
				imageURLPrefix: '/library/literallycanvas/img',
				backgroundColor: 'rgba(0, 0, 0, 0)',
				primaryColor: '#f00'
			});

			$('#draw-board .custom-button').before(
				['<div id="draw-exit" class="btn btn-xs btn-primary" style="margin:-4px 4px 0">',
					'<span translate="J100"></span>',
				'</div>',
				'<div class="btn-group" style="margin:-4px 4px 0">',
					'<div id="draw-replay-high" class="btn btn-xs btn-primary">',
						'<span translate="J101"></span>',
					'</div>',
					'<div id="draw-replay-normal" class="btn btn-xs btn-primary">',
						'<span translate="J102"></span>',
					'</div>',
				'</div>'].join(''));

			var lc = $('#draw-board').literallyCanvasInstance();
			if (self.currentActivity.currentUnit.targetItem.result !== null)
				lc.addShapes(self.currentActivity.currentUnit.targetItem.result.result.strokes);

			$('#draw-exit').click(function() {
				$scope.$apply(function() {
					delete self.currentActivity.currentUnit.targetItem;
				});
			});

			$('#draw-replay-high').click(function() {
				lc.terminal = true;
				lc.playStrokes(100);
			});

			$('#draw-replay-normal').click(function() {
				lc.terminal = true;
				lc.playStrokes(1);
			});

			if (self.currentActivity.currentUnit.content.description !== '') {
				self.drawDescription = self.currentActivity.currentUnit.content.description;

				$('#draw-board .custom-button').before('<div id="draw-description" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="J103"></span></div>');
				$('#draw-description').click(function() {
					$('#drawDescriptionModal').on('hidden.bs.modal', function() {
						delete self.drawDescription;
					});
					$('#drawDescriptionModal').modal('show');
				});
			}

			if (self.currentActivity.currentUnit.content.background !== '') {
				$('#draw-board .custom-button').before('<div id="draw-background" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="J104"></span></div>');
				$('#draw-background').click(function() {
					$timeout(function() {
						if (self.currentActivity.currentUnit.backgroundImage === undefined)
							self.currentActivity.currentUnit.backgroundImage = ['background: url(', self.currentActivity.currentUnit.content.background, ') no-repeat'].join('');
						else
							delete self.currentActivity.currentUnit.backgroundImage;
					},100);
				});
			}

			$compile(document.getElementById('literally-toolbar'))($scope);
		},100);
	}

	self.showMemberActivityUnitResult = function(target, unit) {
		self.layout.main = 'activity';
		self.layout.sub = 'show-member-unit-result';
		self.targetItem = { unit: unit, member: target, type: 'note' };

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', self.currentActivity.uqid, '/unit/', unit.uqid, '/member/', target.user_uqid, '?timezone=', -1 * (new Date()).getTimezoneOffset() / 60].join(''))
		.success(function(response, status) {
			self.currentActivity.learnings = response;

			angular.forEach(self.currentActivity.learnings.notes, function(item) {
				item.timeDesc = $utility.timeToFormat(item.time);
			});

			if (response.unit.unit_type === 'quiz') {
				angular.forEach(response.unit.quizzes, function(quiz, index) {
					angular.forEach(response.study_result.result, function(key) {
						if (key.uqid === quiz.uqid) {
							if (quiz.quiz_type === 'multi') {
								var correct = 0;
								angular.forEach(quiz.options, function(option) {
									option.answer = false;
								});
								angular.forEach(key.answer, function(key) {
									angular.forEach(quiz.options, function(option) {
										if (key === option.value) {
											option.answer = true;
											correct += option.value;
										}
									});
								});

								if (correct === parseInt(quiz.answer, 10)) {
									quiz.correct = true;
								}
								else
									quiz.correct = false;
							}
							else {
								angular.forEach(quiz.options, function(option) {
									option.answer = false;
									if (key.answer[0] === option.value)
										option.answer = true;
								});

								if (key.answer[0] === parseInt(quiz.answer, 10)) {
									quiz.correct = true;
								}
								else
									quiz.correct = false;
							}
						}
					});
				});
			}
			else if (response.unit.unit_type === 'poll') {
				var answer = response.study_result.result;
				angular.forEach(response.unit.content.options, function(option) {
					option.answer = false;
					angular.forEach(answer, function(key) {
						if (key === option.value) option.answer = true;
					});
				});
			}
			else if (response.unit.unit_type === 'draw') {
				$timeout(function() {
					$('#draw-board').html('<canvas></canvas>');
					$('#draw-board').literallycanvas({
						imageURLPrefix: '/library/literallycanvas/img',
						backgroundColor: 'rgba(0, 0, 0, 0)',
						primaryColor: '#f00'
					});

					$('#draw-board .custom-button').before(
						['<div class="btn-group" style="margin:-4px 4px 0">',
							'<div id="draw-replay-high" class="btn btn-xs btn-primary">',
								'<span translate="J101"></span>',
							'</div>',
							'<div id="draw-replay-normal" class="btn btn-xs btn-primary">',
								'<span translate="J102"></span>',
							'</div>',
						'</div>'].join(''));

					var lc = $('#draw-board').literallyCanvasInstance();
					if (response.study_result !== null)
						lc.addShapes(response.study_result.result.strokes);

					$('#draw-replay-high').click(function() {
						lc.terminal = true;
						lc.playStrokes(100);
					});

					$('#draw-replay-normal').click(function() {
						lc.terminal = true;
						lc.playStrokes(1);
					});

					if (response.unit.content.description !== '') {
						self.drawDescription = response.unit.content.description;

						$('#draw-board .custom-button').before('<div id="draw-description" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="J103"></span></div>');
						$('#draw-description').click(function() {
							$('#drawDescriptionModal').on('hidden.bs.modal', function() {
								delete self.drawDescription;
							});
							$('#drawDescriptionModal').modal('show');
						});
					}

					if (response.unit.content.background !== '') {
						$('#draw-board .custom-button').before('<div id="draw-background" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="J104"></span></div>');
						$('#draw-background').click(function() {
							$timeout(function() {
								if (response.backgroundImage === undefined)
									response.backgroundImage = ['background: url(', response.unit.content.background, ') no-repeat'].join('');
								else
									delete response.backgroundImage;
							},100);
						});
					}

					$compile(document.getElementById('literally-toolbar'))($scope);
				},100);
			}

			var series = [];
			angular.forEach(response.vh, function(item) {
				series.push({
					name: item.date,
					data: [{y: item.seconds, v: $utility.timeToFormat(item.seconds), tooltip: ['<span>', item.date, '</span><br/><span>', $utility.timeToFormat(item.seconds), '</span>'].join('')}]
				});
			});

			$timeout(function() {
				if (series.length > 0) {
					$('#member_unit_study_chart').highcharts({
						credits: { enabled: false },
						title: { text: '' },
						chart: { type: 'bar' },
						xAxis: {
							labels: { enabled: false }
						},
						yAxis: {
							title: { text: '' },
							labels: { enabled: false },
							opposite: true
						},
						legend: { enabled: false },
						plotOptions: {
							series: {
								stacking: 'normal'
							}
						},
						tooltip: {
							formatter: function() {
								return this.point.tooltip;
							},
							useHTML: true
						},
						series: series.reverse()
					});
				}
			},100);
		});
	}

	self.openNodeVideo = function(videoUrl, startTime) {
		//fix videoUrl become a object
		//by Aaron at 2015/1/8
		if ( !(typeof videoUrl == 'string' || videoUrl instanceof String) )
			videoUrl = videoUrl.content_url;
		var videoPath = videoUrl.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
		var content = '';
		if (videoPath !== null && videoPath.length === 6) {
			if (videoPath[2] === 'youtube') {
				startTime = ['&start=', startTime].join('');
				content = ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '?autoplay=1&autohide=1&rel=0&showinfo=0&theme=light', startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
				self.noteVideoContent = content;
			}
			else if (videoPath[2] === 'vimeo') {
				startTime = ['#t=', startTime].join('');
				content = ['<iframe src="https://player.vimeo.com/video/', videoPath[3], startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
				self.noteVideoContent = content;
			}
			else if (videoPath[2] === 'youku') {
				// by elvira chen at 2015/9/7
				// content = ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
				content = '<div id="noteVideoPlayer" style="width:100%;height:100%"></div>';
				self.noteVideoContent = content;
				$timeout(function() {
					var player = new YKU.Player('noteVideoPlayer',{
	                    client_id: 'c865b5756563acee',
	                    vid: videoPath[4],
	                    width: '100%',
	                    height: '100%',
	                    autoplay: true,
	                    events:{
	                        onPlayStart: function() {
	                            player.seekTo(startTime);
	                        }
	                    }
	                });
	            }, 1000);
			}
		}
		else {
			var videoId = Date.now();
			self.noteVideoContent =
				['<video id="video-', videoId,'"',
					' src="', videoUrl, (videoUrl.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
					' width="100%" height="100%"',
					' class="video-js vjs-default-skin vjs-big-play-centered">',
				'</video>'].join('');

			$timeout(function() {
				videojs(['video-', videoId].join(''), {controls: true, preload: 'auto'}, function() {
					var player = this;
					player.on('loadeddata', function(target) {
						player.currentTime(startTime);
						player.play();
					});
				});
			},100);
		}

		$('#noteVideoModal').modal('show');
		$('#noteVideoModal').on('hidden.bs.modal', function (e) {
			$scope.$apply(function() {
				delete self.noteVideoContent;
			});
		});
	}

	self.editMember = function(start_index) {
		self.removeAllMember = false;

		delete self.currentMember;
		self.member_start_index = start_index;

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members?status=all&start-index=', start_index * 20].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.last_view_time_desc = item.last_view_time !== null && item.last_view_time !== '' ? $utility.timeToDesc(item.last_view_time) : '';
				if (item.unregistered)
					item.last_view_time_desc = translations[$utility.LANGUAGE.type]['J015']//尚未註冊
			});

			if (self.member_start_index === 0)
				self.editMembers = response;
			else
				self.editMembers = self.editMembers.concat(response);

			if (response.length < 20)
				self.member_start_index = -1;
		});

		self.layout.main = 'member';
		self.layout.sub = 'edit-member';
	}

	self.editMemberBehavior = function() {
		delete self.currentMember;

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members?role=member&start-index=0&max-results=999'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				if (item.behavior_points > 0)
					item.symbol = ['+', item.behavior_points].join('');
				else if (item.behavior_points < 0)
					item.symbol = item.behavior_points;
				else if (item.behavior_points === 0)
					item.symbol = '0';
			});

			self.behaviorMembers = response;
		});

		self.layout.main = 'member';
		self.layout.sub = 'edit-behavior';

		self.memberGroupHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 136;
	}

	self.showMemberBehavior = function(target) {
		self.currentMember = target;

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/memberBehaviors/', target.item_uqid].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.gained_time = new Date(item.gained_time);
			});

			self.currentMember.behaviors = response;
		});

		window.scrollTo(0, 0);
	}

	self.showMemberBehavior2 = function(target) {
		self.currentMember = target;

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/memberBehaviors/', target.item_uqid].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.gained_time = new Date(item.gained_time);
			});

			self.currentMember.behaviors = response;
			$('#memberBehaviorModal').modal('show');
		});
	}

	self.deleteMemberBehavior = function(target) {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/memberBehaviors/', target.uqid].join(''))
		.success(function(response, status) {
			self.currentMember.behavior_points -= target.points;
			delete self.currentMember.deleteAlert;
			self.showMemberBehavior(self.currentMember);
		});
	}

	self.showAllMember = function(start_index) {
		delete self.currentMember;
		self.member_start_index = start_index;

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members?start-index=', start_index * 18, '&max-results=18'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.last_view_time_desc = item.last_view_time !== null && item.last_view_time !== '' ? $utility.timeToDesc(item.last_view_time) : '';
				if (item.unregistered)
					item.last_view_time_desc = translations[$utility.LANGUAGE.type]['J015']//尚未註冊
			});

			if (self.member_start_index === 0)
				self.listMembers = response;
			else
				self.listMembers = self.listMembers.concat(response);

			if (response.length < 18)
				self.member_start_index = -1;
		});

		self.layout.main = 'member';
		self.layout.sub = 'list-member';
	}

	self.searchMember = function(event) {
		if (event.keyCode !== 13 || !self.memberSearchWord) return;

		if (self.memberSearchWord !== '') {
			var service = "";
			if (self.layout.sub === 'edit-member')
				service = [$utility.SERVICE_URL, '/join/', self.target.uqid, '/members?keyword=', self.memberSearchWord].join('');
			else if (self.layout.sub === 'list-member')
				service = [$utility.SERVICE_URL, '/join/', self.target.uqid, '/members?status=approved&keyword=', self.memberSearchWord].join('');
			else if (self.layout.sub === 'edit-behavior') {
				service = [$utility.SERVICE_URL, '/join/', self.target.uqid, '/members?role=member&status=approved&keyword=', self.memberSearchWord].join('');
				delete self.currentMember;
			}

			$http.get(service)
			.success(function(response, status) {
				angular.forEach(response, function(item) {
					item.last_view_time_desc = item.last_view_time !== null && item.last_view_time !== '' ? $utility.timeToDesc(item.last_view_time) : '';
				});

				self.listMembers = response;
			});
		}
		else {
			delete self.memberSearchWord;
			delete self.listMembers;

			if (self.layout.sub === 'edit-member')
				self.editMember(0);
			else if (self.layout.sub === 'list-member')
				self.showAllMember(0);
			else if (self.layout.sub === 'edit-behavior')
				self.editMemberBehavior();
		}
	}

	self.showImportMember = function() {
		self.import = {
			items: [],
			checkAll: false,
			selectImportItem: function() {
				angular.forEach(self.import.items, function(item) {
					item.check = self.import.checkAll;
				})
			},
		};
		$('#importMemberModal').modal('show');
	}

	self.loadMemberFile = function() {
		if (!self.initLoadFileEvent)
			self.setLoadFileEvent();

		$('#load_member_file').click();
	}

	self.setLoadFileEvent = function() {
		self.initLoadFileEvent = true;

		var inputFile = document.getElementById('load_member_file');
		inputFile.addEventListener('click', function() {this.value = null;}, false);
		inputFile.addEventListener('change', readData, false);

		function readData(evt) {
			evt.stopPropagation();
			evt.preventDefault();
			var file = evt.dataTransfer !== undefined ? evt.dataTransfer.files[0] : evt.target.files[0];
			var reader = new FileReader();
			reader.onload = function(e) {
				var items = e.target.result.split("\n");
				var members = [];
				angular.forEach(items, function(item) {
					var member = item.split(',');

					if (member.length >= 3)
						members.push({ check: false, email: member[0], first_name: member[1] || '', last_name: member[2] || '' });
				});

				$scope.$apply(function(){
					self.import.items = members;
				});
			}
			reader.readAsText(file);
		}
	}

	self.importMember = function() {
		var members = [];
		angular.forEach(self.import.items, function(item) {
			if (item.check) members.push(item);
		});

		if (members.length > 0) {
			$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/import'].join(''), { members: members })
			.success(function(response, status) {
				if (!response.error) {
					self.editMember(0);
					delete self.import.memberInput;
					$('#importMemberModal').modal('hide');
				}
			});
		}
	}

	self.exportMember = function() {
		window.open([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/export'].join(''), '_blank');
	}

	self.addMember = function(event) {
		if (event.keyCode !== 13 || !self.memberAddEmail) return;

		if (self.memberAddEmail !== '') {
			$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members'].join(''), { email: self.memberAddEmail })
			.success(function(response, status) {
				if (!response.error) {
					self.editMember(0);
					delete self.memberAddEmail;
				}
			});
		}
	}

	self.updateMember = function(target) {
		var data = {
			role: target.edit_role,
			status: target.edit_status
		};

		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', target.item_uqid].join(''), data)
		.success(function(response, status) {
			angular.forEach(self.editMembers, function(item){
				if (item.item_uqid === target.item_uqid) {
					item.role = response.role;
					item.status = response.status;
				}
			});
		});
	}

	self.removeMember = function(target) {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', target.item_uqid].join(''))
		.success(function(response, status) {
			self.editMember(0);
		});
	}

	self.countRemoveMember = function() {
		var count = 0;
		angular.forEach(self.editMembers, function(item) {
			count += (item.removeCheck ? 1 : 0);
		});

		self.removeSelectedMemberCount = count;
	}

	self.checkRemoveMember = function() {
		angular.forEach(self.editMembers, function(item) {
			item.removeCheck = self.removeAllMember;
		});

		if (self.removeAllMember)
			self.removeSelectedMemberCount = self.editMembers.length;
		else
			self.removeSelectedMemberCount = 0;
	}

	self.removeCheckMember = function() {
		var items = [];
		angular.forEach(self.editMembers, function(item) {
			if (item.removeCheck)
				items.push(item.item_uqid);
		});

		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', items.join(',')].join(''))
		.success(function(response, status) {
			self.editMember(0);
			self.removeSelectedMemberAlert = false;
		});
	}

	self.editProfile = function() {
		self.changeLayout('profile');

		self.target.edit_name = self.target.name;
		self.target.edit_description = self.target.description;
		self.target.edit_privacy = self.target.privacy;
	}

	self.saveProfile = function() {
		var data = {
			name: self.target.edit_name,
			description: self.target.edit_description,
			privacy: self.target.edit_privacy
		};

		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid].join(''), data)
		.success(function(response, status) {
			self.target.name = response.name;
			self.target.description = response.description;
			self.target.privacy = response.privacy;

			self.changeLayout('content');
		});
	}

	self.editPicture = function() {
		self.changeLayout('picture');
		$timeout(function() {self.initPictureEvent()},100);
	}

	self.savePicture = function() {
		var data = {
			logo: self.target.edit_logo
		};

		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid].join(''), data)
		.success(function(response, status) {
			self.target.logo = response.logo;
			$('#pictureModal').modal('hide');
		});
	}

	self.listGroup = function() {
		$http.get([$utility.SERVICE_URL, '/join'].join(''))
		.success(function(response, status) {
			var groups = [];
			angular.forEach(response, function(item) {
				if (item.me.role === 'owner' && item.uqid !== self.target.uqid) {
					item.type = 'group';
					groups.push(item);
				}
			});

			self.selfGroups = groups;
		});
	}

	self.showImportActivity = function(item) {
		self.layout.third = 'import';
		delete self.layout.fourth;

		self.importActivity = {
			checkAll: false,
			target: item,
			selectAll: function() {
				angular.forEach(self.importActivity.items, function(item) {
					item.check = self.importActivity.checkAll;
				})
			},
			add: function() {
				var activities = [];
				angular.forEach(self.importActivity.items, function(item) {
					if (item.check) {
						var goal = [];
						angular.forEach(item.goal, function(goalItem) {
							goal.push({
								key: goalItem.key,
								know: { name: goalItem.know.name, uqid: goalItem.know.know_uqid },
								unit: { name: goalItem.unit.name, uqid: goalItem.unit.uqid }
							});
						});

						var data = {
							name: item.name,
							description: item.description,
							goal: JSON.stringify(goal)
						}

						activities.push(data);
					}
				});

				if (activities.length > 0) {
					$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/import'].join(''), { activities: activities })
					.success(function(response, status) {
						if (!response.error) {
							self.listActivity();

							self.socket.send({
								poster: $utility.account.uqid,
								type: 'activity-changed'
							});
						}
					});
				}

				self.importActivity.checkAll = false;
				self.importActivity.selectAll('all');

				delete self.layout.third;
				window.scrollTo(0, 0);
			}
		}

		$http.get([$utility.SERVICE_URL, '/join/', item.uqid, '/activities'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.check = false;
			})

			self.importActivity.items = response;
		});
	}

	self.showImportActivityKnowledgeUnit = function(item) {
		self.layout.fourth = 'import-unit';

		self.importActivityKnowledgeUnit = {
			checkAll: false,
			target: item,
			selectAll: function(type, target) {
				if (type === 'all') {
					angular.forEach(self.importActivityKnowledgeUnit.items, function(item) {
						item.check = self.importActivityKnowledgeUnit.checkAll;
						angular.forEach(item.units, function(unit) {
							unit.check = self.importActivityKnowledgeUnit.checkAll;
						});
					})
				}
				else if (type === 'chapter') {
					angular.forEach(self.importActivityKnowledgeUnit.items, function(item) {
						if (item.uqid === target.uqid) {
							angular.forEach(item.units, function(unit) {
								unit.check = item.check;
							});
						}
					})
				}
			},
			add: function() {
				var activity = self.currentActivity;

				angular.forEach(self.importActivityKnowledgeUnit.items, function(item) {
					angular.forEach(item.units, function(item) {
						if (item.check) {
							activity.edit_goal.push({
								key: 'xxxxxxxx'.replace(/[xy]/g, function(c) { var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8); return v.toString(16); }),
								know: { uqid: self.importActivityKnowledgeUnit.target.know_uqid, name: self.importActivityKnowledgeUnit.target.name },
								unit: item,
								included: true
							});
						}
					});
				});

				self.importActivityKnowledgeUnit.checkAll = false;
				self.importActivityKnowledgeUnit.selectAll('all');

				delete self.layout.fourth;
				window.scrollTo(0, 0);
			}
		}

		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/knowledges/', item.know_uqid, '/units'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.check = false;
				angular.forEach(item.units, function(unit) {
					unit.check = false;
				})
			})

			self.importActivityKnowledgeUnit.items = response;
		});
	}

	self.listActivity = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities'].join(''))
		.success(function(response, status) {
			var items = [], tag_name = '';

			angular.forEach(response, function(item) {
				if (item.tag === tag_name) {
					items.push({
						uqid: item.uqid,
						name: item.name,
						description: item.description,
						is_show: item.is_show,
						priority: item.priority,
						goal: item.goal,
						progress: item.progress,
						tag: item.tag,
						type: 'activity',
						show: tag_name === '' ? true : false
					});
				}
				else {
					items.push({
						name: item.tag,
						type: 'tag',
						show: false
					});

					items.push({
						uqid: item.uqid,
						name: item.name,
						description: item.description,
						is_show: item.is_show,
						priority: item.priority,
						goal: item.goal,
						progress: item.progress,
						tag: item.tag,
						type: 'activity',
						show: false
					});

					tag_name = item.tag;
				}
			});

			self.activities_right = items;
			self.activities = response.sort(function(a, b){return a.priority - b.priority});
		});
	}

	self.toggleActivityTag = function(tag) {
		tag.show = !tag.show;

		angular.forEach(self.activities_right, function(item) {
			if (item.tag === tag.name)
				item.show = !item.show;
		});
	}

	self.addActivity = function() {
		self.currentActivity = {
			edit_name: '',
			edit_description: '',
			edit_goal: [],
			edit_tag: '',
			edit_type: 'create'
		}

		self.layout.third = 'create';
		delete self.importActivity;
	}

	self.editActivity = function(item) {
		self.currentActivity = {
			uqid: item.uqid,
			name: item.name,
			description: item.description,
			goal: item.goal,
			edit_name: item.name,
			edit_description: item.description,
			edit_goal: item.goal.slice(0),
			edit_tag: item.tag,
			edit_type: 'update'
		}

		angular.forEach(self.currentActivity.edit_goal, function(goal) {
			goal.included = false;
			angular.forEach(self.knowledges, function(item) {
				if (goal.know.uqid === item.know_uqid) {
					goal.included = true;
					goal.know.know_uqid = goal.know.uqid;
				}
			});
		});

		self.layout.third = 'modify';
		delete self.importActivity;
	}

	self.removeActivityGoal = function(target) {
		var activity = self.currentActivity;
		var goal = [];
		angular.forEach(activity.edit_goal, function(item) {
			if (item.key !== target.key)
				goal.push(item);
		});
		activity.edit_goal = goal;
	}

	self.saveActivity = function() {
		if (self.currentActivity.edit_name !== undefined && self.currentActivity.edit_name !== '') {
			var goal = [];
			angular.forEach(self.currentActivity.edit_goal, function(item) {
				goal.push({
					key: item.key,
					know: { name: item.know.name, uqid: item.know.uqid },
					unit: { name: item.unit.name, uqid: item.unit.uqid }
				});
			});

			var data = {
				name: self.currentActivity.edit_name,
				description: self.currentActivity.edit_description,
				goal: JSON.stringify(goal),
				tag: self.currentActivity.edit_tag
			}

			if (self.currentActivity.edit_type === 'create') {
				$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities'].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.listActivity();
						self.changeLayout('activity');
					}
				});
			}
			else if (self.currentActivity.edit_type === 'update') {
				$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', self.currentActivity.uqid].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.listActivity();
						self.changeLayout('activity');
					}
				});
			}
		}
	}

	self.updateActivity = function(target, show) {
		var data = {
			priority: target.edit_priority,
			is_show: show
		};

		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', target.uqid].join(''), data)
		.success(function(response, status) {
			self.listActivity();

			self.socket.send({
				poster: $utility.account.uqid,
				type: 'activity-changed'
			});
		});
	}

	self.deleteActivity = function(target) {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/activities/', target.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.listActivity();

				self.socket.send({
					poster: $utility.account.uqid,
					type: 'activity-changed'
				});
			}
			else {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
		});
	}

	self.showImportKnowledge = function(item) {
		self.layout.third = 'import';

		var service = '';
		if (item.type === 'group') service = [$utility.SERVICE_URL, '/join/', item.uqid, '/knowledges'].join('');
		if (item.type === 'knowledge') service = [$utility.SERVICE_URL, '/join/', self.target.uqid, '/selfKnowledges'].join('');

		self.importKnowledge = {
			checkAll: false,
			target: item,
			selectAll: function() {
				angular.forEach(self.importKnowledge.items, function(item) {
					item.check = self.importKnowledge.checkAll;
				})
			},
			add: function() {
				var knowledges = [];
				if (self.importKnowledge.target.type === 'group') {
					angular.forEach(self.importKnowledge.items, function(item) {
						if (item.check) knowledges.push(item.know_uqid);
					});
				}
				else if (self.importKnowledge.target.type === 'knowledge') {
					angular.forEach(self.importKnowledge.items, function(item) {
						if (item.check) knowledges.push(item.uqid);
					});
				}

				if (knowledges.length > 0) {
					$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/knowledges/import'].join(''), { knowledges: knowledges })
					.success(function(response, status) {
						if (!response.error) {
							self.listKnowledge();

							self.socket.send({
								poster: $utility.account.uqid,
								type: 'knowledge-changed'
							});
						}
					});
				}

				self.importKnowledge.checkAll = false;
				self.importKnowledge.selectAll('all');

				delete self.layout.third;
				window.scrollTo(0, 0);
			}
		}

		$http.get(service)
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.check = false;
			})

			self.importKnowledge.items = response;
		});
	}

	self.listKnowledge = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/knowledges'].join(''))
		.success(function(response, status) {
			self.knowledges = response;
		});
	}

	self.addKnowledge = function(event) {
		if (event.keyCode !== 13 || !self.knowledgeCode) return;

		if (self.knowledgeCode !== '') {
			$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/knowledges'].join(''), { knowCode: self.knowledgeCode })
			.success(function(response, status) {
				if (!response.error) {
					self.knowledges = response;
					delete self.knowledgeCode;

					self.socket.send({
						poster: $utility.account.uqid,
						type: 'knowledge-changed'
					});
				}
			});

			delete self.layout.third;
		}
	}

	self.updateKnowledge = function(target, show) {
		var data = {
			priority: target.edit_priority,
			is_show: show
		};

		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/knowledges/', target.uqid].join(''), data)
		.success(function(response, status) {
			self.knowledges = response;

			self.socket.send({
				poster: $utility.account.uqid,
				type: 'knowledge-changed'
			});
		});
	}

	self.removeKnowledge = function(target) {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/knowledges/', target.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.knowledges = response;

				self.socket.send({
					poster: $utility.account.uqid,
					type: 'knowledge-changed'
				});
			}
			else {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
		});
	}

	self.showImportFile = function(item) {
		self.layout.third = 'import';

		self.importFile = {
			checkAll: false,
			target: item,
			selectAll: function() {
				angular.forEach(self.importFile.items, function(item) {
					item.check = self.importFile.checkAll;
				})
			},
			add: function() {
				var content = [];
				angular.forEach(self.target.file, function(item) {
					content.push({
						key: item.key,
						value: item.value
					});
				});
				angular.forEach(self.importFile.items, function(item) {
					if (item.check) {
						content.push({
							key: 'xxxxxxxx'.replace(/[xy]/g, function(c) { var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8); return v.toString(16); }),
							value: item.value
						});
					}
				});

				$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/files'].join(''), { file: JSON.stringify(content) })
				.success(function(response, status) {
					self.target.file = response;

					self.socket.send({
						poster: $utility.account.uqid,
						type: 'file-changed'
					});
				});

				self.importFile.checkAll = false;
				self.importFile.selectAll('all');

				delete self.layout.third;
				window.scrollTo(0, 0);
			}
		}

		$http.get([$utility.SERVICE_URL, '/join/', item.uqid, '/files'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.check = false;
			})

			self.importFile.items = response;
		});
	}

	self.listFile = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/files'].join(''))
		.success(function(response, status) {
			self.target.file = response;
		});
	}

	self.editFile = function(target) {
		target.edit_title = target.title;
		self.layout.third = 'modify';
		self.modifyFile = target;
	}

	self.changeFile = function() {
		if (event.keyCode !== 13 || !self.modifyFile.edit_title) return;

		self.modifyFile.title = self.modifyFile.edit_title;
		self.saveFile();

		delete self.modifyFile;
		delete self.layout.third;
	}

	self.removeFile = function(target) {
		var content = [];
		angular.forEach(self.target.file, function(item) {
			if (item.key !== target.key)
				content.push(item);
		});
		self.target.file = content;
		self.saveFile();
	}

	self.saveFile = function() {
		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/files'].join(''), { file: JSON.stringify(self.target.file) })
		.success(function(response, status) {
			self.target.file = response;

			self.socket.send({
				poster: $utility.account.uqid,
				type: 'file-changed'
			});
		});
	}

	self.showImportLink = function(item) {
		self.layout.third = 'import';

		self.importLink = {
			checkAll: false,
			target: item,
			selectAll: function() {
				angular.forEach(self.importLink.items, function(item) {
					item.check = self.importLink.checkAll;
				})
			},
			add: function() {
				var content = [];
				angular.forEach(self.target.link, function(item) {
					content.push({
						key: item.key,
						value: item.value
					});
				});
				angular.forEach(self.importLink.items, function(item) {
					if (item.check) {
						content.push({
							key: 'xxxxxxxx'.replace(/[xy]/g, function(c) { var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8); return v.toString(16); }),
							value: item.value
						});
					}
				});

				$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/links'].join(''), { link: JSON.stringify(content) })
				.success(function(response, status) {
					self.target.link = response;

					self.socket.send({
						poster: $utility.account.uqid,
						type: 'link-changed'
					});
				});

				self.importLink.checkAll = false;
				self.importLink.selectAll('all');

				delete self.layout.third;
				window.scrollTo(0, 0);
			}
		}

		$http.get([$utility.SERVICE_URL, '/join/', item.uqid, '/links'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.check = false;
			})

			self.importLink.items = response;
		});
	}

	self.listLink = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/links'].join(''))
		.success(function(response, status) {
			self.target.link = response;
		});
	}

	self.addLink = function(event) {
		if (event.keyCode !== 13 || !self.linkUrl) return;

		if (self.linkUrl !== '') {
			var data = { url: self.linkUrl };
			$http.post([$utility.SERVICE_URL, '/utility/parseURL'].join(''), data)
			.success(function(response, status) {
				if (!response.error) {
					var link = []
					angular.forEach(self.target.link, function(item) {
						link.push({
							key: item.key,
							title: item.title,
							url: item.url,
							value: item.value
						});
					});
					link.push({
						key: 'xxxxxxxx'.replace(/[xy]/g, function(c) { var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8); return v.toString(16); }),
						title: response.title,
						url: response.url,
						value: ['<a href="', response.url, '" target="_blank"><span style="margin-left:4px">', response.title, '</span></a>'].join('')
					});

					self.target.link = link;
					self.saveLink();

					delete self.linkUrl;
				}
			});

			delete self.layout.third;
		}
	}

	self.editLink = function(target) {
		target.edit_title = target.title;
		self.layout.third = 'modify';
		self.modifyLink = target;
	}

	self.changeLink = function() {
		if (event.keyCode !== 13 || !self.modifyLink.edit_title) return;

		self.modifyLink.title = self.modifyLink.edit_title;
		self.saveLink();

		delete self.modifyLink;
		delete self.layout.third;
	}

	self.removeLink = function(target) {
		var link = [];
		angular.forEach(self.target.link, function(item) {
			if (item.key !== target.key)
				link.push(item);
		});
		self.target.link = link;
		self.saveLink();
	}

	self.saveLink = function() {
		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/links'].join(''), { link: JSON.stringify(self.target.link) })
		.success(function(response, status) {
			self.target.link = response;

			self.socket.send({
				poster: $utility.account.uqid,
				type: 'link-changed'
			});
		});
	}

	self.showImportBehavior = function(item) {
		self.layout.third = 'import';

		self.importBehavior = {
			checkAll: false,
			target: item,
			selectAll: function() {
				angular.forEach(self.importBehavior.items, function(item) {
					item.check = self.importBehavior.checkAll;
				})
			},
			add: function() {
				var import_count = 0, finished_count = 0;
				angular.forEach(self.importBehavior.items, function(item) {
					if (item.check) {
						import_count += 1;

						var data = {
							name: item.name,
							icon: item.icon,
							points: item.points
						};

						$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/behaviors'].join(''), data)
						.success(function(response, status) {
							if (!response.error) {
								finished_count += 1;
								if (import_count === finished_count)
									self.listBehavior();
							}
						});
					}
				});

				self.importBehavior.checkAll = false;
				self.importBehavior.selectAll('all');

				delete self.layout.third;
				window.scrollTo(0, 0);
			}
		}

		$http.get([$utility.SERVICE_URL, '/join/', item.uqid, '/behaviors'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.check = false;
				item.symbol = item.points > 0 ? '+1' : '-1';
			})

			self.importBehavior.items = response;
		});
	}

	self.listBehavior = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/behaviors'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.symbol = item.points > 0 ? '+1' : '-1';
			});

			self.behaviors = response;
		});
	}

	self.addBehavior = function() {
		self.currentBehavior = {
			edit_name: '',
			edit_type: 'create',
			icon_index: 1
		};

		$("#behaviorModal").modal('show');
		$("#behaviorModal").on('hidden.bs.modal', function() {
			delete self.currentBehavior;
		});
	}

	self.editBehavior = function(target) {
		if (target === 'add') {
			self.addBehavior();
			return;
		}

		self.currentBehavior = {
			uqid: target.uqid,
			points: target.points,
			edit_name: target.name,
			edit_type: 'update',
			icon_index: target.icon
		};

		$("#behaviorModal").modal('show');
		$("#behaviorModal").on('hidden.bs.modal', function() {
			delete self.currentBehavior;
		});
	}

	self.saveBehavior = function(points) {
		if (self.currentBehavior.edit_name !== undefined && self.currentBehavior.edit_name !== '') {
			if (self.currentBehavior.edit_type === 'create') {
				var data = {
					name: self.currentBehavior.edit_name,
					icon: self.currentBehavior.icon_index,
					points: points
				};

				$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/behaviors'].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.listBehavior();
						$("#behaviorModal").modal('hide');
					}
				});
			}
			else if (self.currentBehavior.edit_type === 'update') {
				var data = {
					name: self.currentBehavior.edit_name,
					icon: self.currentBehavior.icon_index
				}

				$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/behaviors/', self.currentBehavior.uqid].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.listBehavior();
						$("#behaviorModal").modal('hide');
					}
				});
			}
		}
	}

	self.deleteBehavior = function() {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/behaviors/', self.currentBehavior.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.listBehavior();
				$("#behaviorModal").modal('hide');
			}
		});
	}

	self.showAddMemberBehavior = function(target) {
		self.currentMember = target;
		$("#addMemberBehaviorModal").modal('show');
	}

	self.addMemberBehavior = function(target) {
		if (self.currentMember.role !== 'member') return;

		var data = {
			memberUqid: [self.currentMember.item_uqid],
			behaviorUqid: target.uqid
		};

		$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/memberBehaviors'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				self.currentMember.behavior_points = response[0].behavior_points;
				delete self.currentMember;
				$("#addMemberBehaviorModal").modal('hide');
			}
		});
	}

	self.showAddMultiMemberBehavior = function() {
		$("#addMultiMemberBehaviorModal").modal('show');
	}

	self.addMultiMemberBehavior = function(target) {
		var data = {
			memberUqid: [],
			behaviorUqid: target.uqid
		};

		angular.forEach(self.currentActivity.statistics, function(item) {
			if (item.selected) data.memberUqid.push(item.item_uqid);
			delete item.selected;
		});

		$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/memberBehaviors'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				angular.forEach(response, function(a) {
					angular.forEach(self.currentActivity.statistics, function(b) {
						if (a.user_uqid === b.user_uqid)
							b.behavior_points = a.behavior_points;
					})
				});
				$("#addMultiMemberBehaviorModal").modal('hide');
			}
		});
	}

	self.showUnitFeedbackModal = function(item) {
		$('#unitFeedbackModal').modal('show');
		self.currentActivity.currentMember.feedbackUnit = item;
		self.currentActivity.currentMember.feedbackUnit.edit_score = self.currentActivity.currentMember.feedbackUnit.score;
		self.currentActivity.currentMember.feedbackUnit.edit_comment = self.currentActivity.currentMember.feedbackUnit.comment;
	}

	self.saveUnitFeedback = function() {
		var flag = true;
		if (self.currentActivity.currentMember.feedbackUnit.edit_score) {
			if (isNaN(Math.ceil(self.currentActivity.currentMember.feedbackUnit.edit_score)))
				flag = false;
		}

		if (flag) {
			var data = {
				unitUqid: self.currentActivity.currentMember.feedbackUnit.uqid,
				score: self.currentActivity.currentMember.feedbackUnit.edit_score,
				comment: self.currentActivity.currentMember.feedbackUnit.edit_comment
			};

			if (self.currentActivity.currentMember.feedbackUnit.feedback_uqid) {
				$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', self.currentActivity.currentMember.item_uqid, '/feedback/', self.currentActivity.currentMember.feedbackUnit.feedback_uqid].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.currentActivity.currentMember.feedbackUnit.score = response.score;
						self.currentActivity.currentMember.feedbackUnit.comment = response.comment;

						$('#unitFeedbackModal').modal('hide');
					}
				});
			}
			else {
				$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', self.currentActivity.currentMember.item_uqid, '/feedback'].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.currentActivity.currentMember.feedbackUnit.feedback_uqid = response.uqid
						self.currentActivity.currentMember.feedbackUnit.score = response.score;
						self.currentActivity.currentMember.feedbackUnit.comment = response.comment;

						$('#unitFeedbackModal').modal('hide');
					}
				});
			}
		}
	}

	self.deleteUnitFeedback = function() {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', self.currentActivity.currentMember.item_uqid, '/feedback/', self.currentActivity.currentMember.feedbackUnit.feedback_uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				delete self.currentActivity.currentMember.feedbackUnit.deleteAlert;
				delete self.currentActivity.currentMember.feedbackUnit.feedback_uqid;
				self.currentActivity.currentMember.feedbackUnit.score = '';
				self.currentActivity.currentMember.feedbackUnit.comment = '';

				$('#unitFeedbackModal').modal('hide');
			}
		});
	}

	self.showSelfBehavior = function() {
		$http.get([$utility.SERVICE_URL, '/join/', self.target.uqid, '/selfBehaviors'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.gained_time = new Date(item.gained_time);
			});

			self.selfBehaviors = response;
		});
	}

	self.resetCode = function() {
		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/resetCode'].join(''))
		.success(function(response, status) {
			self.target.code = response.code;
			delete self.target.resetCodeAlert;
		});
	}

	self.deleteGroup = function() {
		$http.delete([$utility.SERVICE_URL, '/join/', self.target.uqid].join(''))
		.success(function(response, status) {
			if (!response.error)
				$location.path('/join/group');
			else {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
		});
	}

	self.leaveGroup = function() {
		$http.post([$utility.SERVICE_URL, '/join/', self.target.uqid, '/leaveGroup'].join(''))
		.success(function(response, status) {
			$location.path('/join/group');
		});
	}

	self.updateNotification = function(flag) {
		$http.put([$utility.SERVICE_URL, '/join/', self.target.uqid, '/members/', self.self.uqid].join(''), { notification: flag })
		.success(function(response, status) {
			if (!response.error) {
				$timeout(function() {self.self.notification = response.notification}, 100);
			}
		});
	}

	self.teach = function(target, type) {
		if (target === null) {
			$('#classroomModal').modal('show');
			$('#classroomModal').on('hidden.bs.modal', function() {
				delete self.errMsg;
				if (self.teachTarget !== undefined) {
					delete self.teachTarget;
					$scope.$apply(function() {
						$location.path(['/join/group/', self.target.uqid, '/teach'].join(''));
					});
				}
			});
		}
		else {
			self.teachTarget = target;

			var data = {};
			if (type === 'knowledge')
				data = { targetUqid: target.know_uqid, type: type };
			else
				data = { targetUqid: target.uqid, type: type };

			$http.post([$utility.SERVICE_URL, '/classroom/', self.target.uqid, '/teach'].join(''), data)
			.success(function(response, status) {
				if (!response.error) {
					$('#classroomModal').modal('hide');
				}
				else
					self.errMsg = response.error;
			});
		}
	}

	self.study = function(target) {
		$location.path(['/join/group/', self.target.uqid, '/study'].join(''));
	}

	self.initPictureEvent = function() {
		$('#input_group_logo').on('change', readData);

		function readData(evt) {
			evt.stopPropagation();
			evt.preventDefault();
			var file = evt.dataTransfer !== undefined ? evt.dataTransfer.files[0] : evt.target.files[0];
			var reader = new FileReader();
			reader.onload = (function(theFile) {
				return function(e) {
					var image = new Image();
					image.src = e.target.result;
					image.onload = function() {
						var canvas = document.createElement('canvas');
						canvas.width = 400;
						canvas.height = image.height * (400 / image.width);
						var ctx = canvas.getContext('2d');
						ctx.drawImage(image, 0, 0, canvas.width, canvas.height);

						$('#picture_content').html(['<img src="', canvas.toDataURL(), '"/>'].join(''));

						var img = $('#picture_content img')[0];
						var canvas = document.createElement('canvas');

						$(img).Jcrop({
							bgColor: 'black',
							bgOpacity: .6,
							setSelect: [0, 0, 200, 200],
							aspectRatio: 1,
							onSelect: imgSelect,
							onChange: imgSelect
						});

						function imgSelect(selection) {
							canvas.width = canvas.height = 200;

							var ctx = canvas.getContext('2d');
							ctx.drawImage(img, selection.x, selection.y, selection.w, selection.h, 0, 0, canvas.width, canvas.height);

							self.target.edit_logo = canvas.toDataURL();
						}
					}
				}
			})(file);
			reader.readAsDataURL(file);
		}
	}

	self.drawBehaviorChart = function() {
		$('#behaviorChart').highcharts({
			credits: { enabled: false },
			chart: {
				type: 'pie'
			},
			title: {
				text: ''
			},
			tooltip: {
				enabled: false
			},
			plotOptions: {
				pie: {
					animation: false,
					shadow: true,
					center: ['50%', '50%'],
					innerSize: '60%',
					dataLabels: {
						enabled: false
					}
				}
			},
			series: [{
				data: [{
					name: 'Positive',
					y: self.self.behavior.positive === null ? 0 : self.self.behavior.positive,
					color: '#468847'
				},{
					name: 'Negative',
					y: self.self.behavior.negative === null ? 0 : self.self.behavior.negative,
					color: '#b94a48'
				}]
			}]
		});
	}

	self.init = function() {
		self.account = $utility.account;

		if ($routeParams.t !== undefined) {
			if ($routeParams.c === 'group') {
				$http.get([$utility.SERVICE_URL, '/join/', $routeParams.t].join(''))
				.success(function(response, status) {
					if (!response.error) {
						response.encodePage = encodeURIComponent(response.page);

						angular.forEach(response.file, function(item) {
							delete item.$$hashKey;
						});

						self.target = response;
						self.self = response.me;
						self.wallBoard = {};
						self.behaviorIcons = [
							'fa-thumbs-o-up', 'fa-leaf', 'fa-flask', 'fa-coffee', 'fa-group', 'fa-microphone',
							'fa-globe', 'fa-picture-o', 'fa-plane', 'fa-trophy', 'fa-comments-o', 'fa-clock-o',
							'fa-smile-o', 'fa-lightbulb-o', 'fa-check', 'fa-lemon-o', 'fa-puzzle-piece', 'fa-refresh',
							'fa-search', 'fa-bell', 'fa-bullhorn', 'fa-frown-o', 'fa-gavel', 'fa-music',
							'fa-heart-o', 'fa-cloud', 'fa-trash-o', 'fa-tint', 'fa-bolt', 'fa-thumbs-o-down'];

						self.listMessage(0, true);
						self.listMessage(0);
						self.listKnowledge();
						self.listActivity();
						self.listBehavior();
						self.listGroup();
						self.changeLayout('content');

						if (response.me.role === 'member') {
							$timeout(function(){self.drawBehaviorChart()},500);
						}

						self.initWebSocket();
					}
				});
			}
			else {
				self.target = $routeParams.t;
				self.contentType = $routeParams.c;
			}
		}
		else
			$location.path('/join/group');
	}

	self.initWebSocket = function() {
		self.presenceUsers = [];
		self.chatroomMessages = [];

		self.socket = new WebSocketRails(window.location.host + "/websocket");
		self.socket.channel = self.socket.subscribe(['1know-group-', self.target.uqid].join(''));
		self.socket.channel.bind('new_message', function(msg) {
			$scope.$apply(function(){
				if (msg.poster !== $utility.account.uqid) {
					if (msg.type === 'wall-message-changed') {
						self.wallMessageChanged = true;
					}
					else if (msg.type === 'knowledge-changed') {
						self.listKnowledge();
					}
					else if (msg.type === 'activity-changed') {
						self.listActivity();
					}
					else if (msg.type === 'file-changed') {
						self.listFile();
					}
					else if (msg.type === 'link-changed') {
						self.listLink();
					}
				}

				if (msg.type === 'member-changed') {
					var index = -1;
					angular.forEach(self.presenceUsers, function(item, i) {
						if (item.uqid === msg.poster) index = i;
					});

					if (msg.action === 'join' && index == -1) {
						self.presenceUsers.push(msg.user);

						if (msg.poster !== $utility.account.uqid) {
							self.socket.send( {
								poster: $utility.account.uqid,
								type: 'member-changed',
								action: 'stay',
								user: {
									uqid: $utility.account.uqid,
									email: $utility.account.email,
									first_name: $utility.account.first_name,
									last_name: $utility.account.last_name,
									full_name: $utility.account.full_name
								}
							});
						}
					}
					else if (msg.action === 'leave')
						self.presenceUsers.splice(index, 1);
					else if (msg.action === 'stay' && index == -1)
						self.presenceUsers.push(msg.user);
				}
				else if (msg.type === 'chat-message') {
					self.chatroomMessages.push(msg.message);
				}
			});
		});
		self.socket.send = function(data) {
			self.socket.channel.trigger('new_message', data);
		};
		self.socket.on_error = function(data) {
			console.log('websocket connect error - ' + data.toString());
			return self.socket.reconnect();
		};
		self.socket.on_close = function(data) {
			console.log('websocket connect close - ' + data.toString());
			return self.socket.reconnect();
		};

		$timeout(function() {
			self.socket.send( {
				poster: $utility.account.uqid,
				type: 'member-changed',
				action: 'join',
				user: {
					uqid: $utility.account.uqid,
					email: $utility.account.email,
					first_name: $utility.account.first_name,
					last_name: $utility.account.last_name,
					full_name: $utility.account.full_name
				}
			});
		},1000);

		$interval(function(){
			console.log(self.socket.state);
			if (self.socket.state == 'disconnected') self.socket.on_close('');
		}, 1000);

		self.sendChatMessage = function(event) {
			if (event.keyCode !== 13 || !self.chatroomMessage) return;

			var message = {uqid: $utility.account.uqid, message: self.chatroomMessage, time: Date.now()};

			self.socket.send({
				poster: $utility.account.uqid,
				type: 'chat-message',
				message: message
			});

			delete self.chatroomMessage;
		}
	}

	window.onbeforeunload = function() {
		self.socket.send( {
			poster: $utility.account.uqid,
			type: 'member-changed',
			action: 'leave'
		});
	}

	$scope.$location = $location;
	$scope.$watch('$location.path()', function() {
		if ($location.path() !== ['/join/group/', $routeParams.t].join('')) {
			self.socket.send( {
				poster: $utility.account.uqid,
				type: 'member-changed',
				action: 'leave'
			});
		}
	});

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})