var websnapr_hash = websnapr_hash || '';

_1know.controller('ModifyKnowledgeCtrl', function($scope, $http, $location, $timeout, $compile, $routeParams, $utility, $window) {
	var self = this;

	self.chooseDrawBackgroundImage = function() {
		Dropbox.choose({
			linkType: "direct",
			multiselect: false,
			extensions: ['.png', '.jpg', '.gif'],
			success: function(files) {
				$scope.$apply(function() {
					if (files.length === 1) {
						var item = files[0];
						self.modifyTarget.edit_content_draw.background = item.link;
					}
				});
			},
			cancel: function() {}
		});
	}

	self.initHtmlEditor = function(elementId, text, options) {
		$timeout(function() {
			if ($(elementId).redactor() !== undefined)
				$(elementId).redactor('destroy');

			$(elementId).html(text);

			if (options && options.toolbar === false)
				$(elementId).redactor({toolbar:false});
			else {
				RedactorPlugins = RedactorPlugins || {};
				RedactorPlugins.custom = {
					init: function () {
						var dropdown = {
								// 'point1': { title: 'Google Drive', callback: this.googledrive },
								// 'point2': { title: 'Dropbox', callback: this.dropbox }
							};

						this.buttonAdd('drive', 'Drive', false, dropdown);
						this.buttonAwesome('drive', 'fa-paperclip');

						if (elementId !== '#knowledge-description' && elementId !== '#unit-description') {
							this.buttonAdd('latex', 'LaTex', this.latex);
							this.buttonAwesome('latex', 'fa-superscript');
						}
					},
					googledrive: function(buttonName, buttonDOM, buttonObj, e) {
						$utility.chooseGoogleFile(elementId, function(data) {
							if (data.action == google.picker.Action.PICKED) {
								var content = [];
								data.docs.forEach(function(item) {
									content.push(['<a href="', item.url, '" target="_blank"><img style="height:20px" src="', item.iconUrl, '"/><span style="margin-left:4px">', item.name, '</span></a>'].join(''));
								});

								var html = $(elementId).redactor('get');
								html = html + content.join('<br/>');
								$(elementId).redactor('set', html);
							}
						});
					},
					dropbox: function(buttonName, buttonDOM, buttonObj, e) {
						$utility.chooseDropboxFile(elementId, function(files) {
							var content = [];
							files.forEach(function(item) {
								content.push(['<a href="', item.link, '" target="_blank"><img style="height:20px" src="', item.icon, '"/><span style="margin-left:4px">', item.name, '</span></a>'].join(''));
							});

							var html = $(elementId).redactor('get');
							html = html + content.join('<br/>');
							$(elementId).redactor('set', html);
						});
					},
					latex: function(buttonName, buttonDOM, buttonObj, e) {
						$('#latexModal').modal('show');
					}
				};

				$(elementId).redactor({
					visual: (!options || options.visual === undefined) ? true : options.visual,
					buttons: ['html', 'formatting',  'bold', 'italic', 'deleted', 'unorderedlist', 'orderedlist', 'image', 'video', 'link', 'alignment'],
					plugins: ['fontcolor', 'fontsize', 'custom']
				});
			}
		}, 100);
	}

	self.initPictureEvent = function(fn) {
		$('#input_knowledge_logo').on('change', readData);

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

	self.showEmbed = function() {
		$('#embedModal').modal('show');
	}

	self.showAllUnit = function() {
		self.showChapterUnit = !self.showChapterUnit;
		angular.forEach(self.chapters, function(chapter) {
			chapter.showUnit = self.showChapterUnit;
		});
	}

	self.joinGroup = function(item) {
		$http.post([$utility.SERVICE_URL, '/join/', item.uqid, '/knowledges'].join(''), { knowUqid: self.target.uqid })
		.success(function(response, status) {
			if (!response.error) {
				$location.path('/join/group/' + item.uqid);
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

	self.showEditorModal = function() {
		$('#editorModal').modal('show');
		$('#editorModal').on('hidden.bs.modal', function() {
			delete self.currentEditor;
		});
	}

	self.loadEditor = function() {
		$http.get([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/editors'].join(''))
		.success(function(response, status) {
			self.editors = response;
		});
	}

	self.sortableEditor = function() {
		if (!self.target.sortableEditor) {
			self.target.sortableEditor = true;

			$('[editor-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.editors.splice(end, 0,
					self.editors.splice(start, 1)[0]);

					$scope.$apply();

					var item = self.editors[end];
					self.updateEditor(item, end + 1, item.show);
				}
			});
			$('[editor-list]').sortable('option', 'disabled', false);
			$('[editor-list]').disableSelection();
		}
		else {
			self.target.sortableEditor = false;
			$('[editor-list]').sortable('disable');
		}
	}

	self.addEditor = function(event) {
		if (event.keyCode !== 13) return;

		if (self.editorEmail !== undefined && self.editorEmail !== '') {
			$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/editors'].join(''), { email: self.editorEmail })
			.success(function(response, status) {
				delete self.editorEmail;
				self.loadEditor();
			});
		}
	}

	self.updateEditor = function(item, order, show) {
		var data = { order: order, show: show };

		$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/editors/', item.uqid].join(''), data)
		.success(function(response, status) {
			self.loadEditor();
		});
	}

	self.removeEditor = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/editors/', self.currentEditor.uqid].join(''))
		.success(function(response, status) {
			self.loadEditor();
			self.currentEditor.deleteAlert = false;
		});
	}

	self.changeLayout = function(target, fn) {
		self.layout = target;

		self.target.sortableChapter = false;
		angular.forEach(self.chapters, function(c) {
			c.sortableUnit = false;
			angular.forEach(c.units, function(u) {
				u.sortableQuiz = false;
			})
		})

		if (target === 'knowledge')
			self.initHtmlEditor('#knowledge-description', self.target.edit_description);
		else if (target === 'unit')
			self.initHtmlEditor('#unit-description', self.modifyTarget.edit_description);
		else if (target === 'quiz') {
			self.initHtmlEditor('#quiz-content', self.modifyTarget.edit_content);
			self.initHtmlEditor('#quiz-solution', self.modifyTarget.edit_solution);
		}

		window.scrollTo(0,0);

		if (fn) fn();
	}

	self.editPicture = function() {
		self.changeLayout('picture');
		$timeout(function() {self.initPictureEvent()},100);
	}

	self.savePicture = function() {
		$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid].join(''), { logo: self.target.edit_logo })
		.success(function(response, status) {
			self.target.logo = response.logo;
			$('#pictureModal').modal('hide');
		});
	}

	self.editKnowledge = function() {
		self.target.edit_name = self.target.name;
		self.target.edit_description = self.target.description;
		self.target.edit_privacy = self.target.privacy;

		self.changeLayout('knowledge');
	}

	self.saveKnowledge = function() {
		if (self.target.edit_name === '')
			return;

		var data = {
			name: self.target.edit_name,
			description: $('#knowledge-description').redactor('get'),
			privacy: self.target.edit_privacy
		}

		$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				self.target.name = response.name;
				self.target.description = response.description;
				self.target.privacy = response.privacy;

				self.changeLayout('content');
			}
		});
	}

	self.editTag = function() {
		var q = $http.get([$utility.SERVICE_URL, '/creation/knowledges/get/tag'].join(''))
		.success(function(response, status){
			if(!response.error){
				self.tags = response;
				var uqid = self.target.uqid;
				var ary = [];
				angular.forEach(self.tags, function(item, key){
					if(item.knowledges.search(uqid) > -1)
						ary.push(item.name);
				});
				self.tagList = ary.join(',');
			}
		});
		q.then(function(){
			self.changeLayout('tag');
		});
	}

	self.saveTag = function() {
		var setInto = [];
		angular.forEach(self.tags, function(tag,key){
			if(self.tagList.search(tag.name) > -1)
				setInto.push(tag.id);
		});

		$http.post([$utility.SERVICE_URL, '/creation/knowledges/set/tag/', self.target.uqid].join(''), { setInto: setInto.join('')})
		.success(function(response){
			if(!response.error)
				self.changeLayout('content');
		});
	}

	self.changePrivacy = function(privacy) {
		$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid].join(''), { privacy: privacy })
		.success(function(response, status) {
			if (!response.error) {
				self.target.privacy = response.privacy;
				self.target.publishAlert = true;
			}
		});
	}

	self.resetCode = function() {
		$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/resetCode'].join(''))
		.success(function(response, status) {
			self.target.code = response.code;
			delete self.target.resetCodeAlert;
		});
	}

	self.deleteKnowledge = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				$location.path('/create/knowledge');
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

	self.publish = function() {
		self.target.publishAlert = false;

		if (self.onPublish === undefined) {
			self.onPublish = true;

			$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/publish'].join(''))
			.success(function(response, status) {
				if (!response.error)
					$location.path('/create/knowledge');
				else {
					self.errMessage = response.error;
					$('#errorMessageModal').modal('show');
					$('#errorMessageModal').on('hidden.bs.modal', function() {
						delete self.errMessage;
					});

					delete self.onPublish;
				}
			});
		}
	}

	self.loadChapter = function() {
		$http.get([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters'].join(''))
		.success(function(response, status) {
			self.chapters = [];

			var priorities = [];
			angular.forEach(response, function(item, index) {
				priorities.push(++index);
			});
			angular.forEach(response, function(item) {
				item.unit_type = 'chapter';
				item.priorities = priorities;
				item.showUnit = true;
			});

			self.chapters = response;
			self.loadUnit();
		});
	}

	self.sortableChapter = function() {
		if (!self.target.sortableChapter) {
			self.target.sortableChapter = true;

			$('[chapter-list]').sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index();

					self.chapters.splice(end, 0,
					self.chapters.splice(start, 1)[0]);

					$scope.$apply();

					self.modifyTarget = self.chapters[end];
					self.modifyTarget.priority = end + 1;

					var data = {
						priority: self.modifyTarget.priority
					}

					$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.uqid].join(''), data)
					.success(function(response, status) {
						if (response.error) {
							self.errMessage = response.error;
							$('#errorMessageModal').modal('show');
							$('#errorMessageModal').on('hidden.bs.modal', function() {
								delete self.errMessage;
							});
						}
					});
				}
			});
			$('[chapter-list]').sortable('option', 'disabled', false);
			$('[chapter-list]').disableSelection();
		}
		else {
			self.target.sortableChapter = false;
			$('[chapter-list]').sortable('disable');
		}
	}

	self.addChapter = function() {
		var chapter = {};
		chapter.edit_name = '';
		chapter.edit_type = 'create';
		chapter.priorities = [];
		if (self.chapters !== undefined) {
			for (var i = 1; i <= self.chapters.length + 1; i++)
				chapter.priorities.push(i);

			chapter.edit_priority = self.chapters.length + 1;
		}
		else
			chapter.edit_priority = 1;

		self.modifyTarget = chapter;
		self.changeLayout('chapter');
	}

	self.editChapter = function(chapter) {
		chapter.edit_name = chapter.name;
		chapter.edit_priority = Math.ceil(chapter.priority);
		chapter.edit_type = 'update';
		chapter.playlist = '';
		chapter.playlist_entry = [];
		chapter.check_all_entry = true;

		self.modifyTarget = chapter;
		self.changeLayout('chapter');
	}

	self.saveChapter = function() {
		if (self.modifyTarget.edit_name === '')
			return;

		var data = {
			name: self.modifyTarget.edit_name,
			priority: self.modifyTarget.edit_priority
		}

		if (self.modifyTarget.edit_type === 'create') {
			$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters'].join(''), data)
			.success(function(response, status) {
				self.loadChapter();
				delete self.modifyTarget;
				self.changeLayout('content');
			});
		}
		else if (self.modifyTarget.edit_type === 'update') {
			$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.uqid].join(''), data)
			.success(function(response, status) {
				self.loadChapter();
				delete self.modifyTarget;
				self.changeLayout('content');
			});
		}
	}

	self.deleteChapter = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.loadChapter();
				delete self.modifyTarget;
				self.changeLayout('content');
			}
			else
				self.modifyTarget.saveMsg = response.error;
		});
	}

	self.checkAllEntry = function() {
		if (self.modifyTarget !== undefined && self.modifyTarget.playlist_entry !== undefined) {
			angular.forEach(self.modifyTarget.playlist_entry, function(item) {
				item.create = self.modifyTarget.check_all_entry;
			});
		}
	}

	self.checkAllPreview = function() {
		if (self.modifyTarget !== undefined && self.modifyTarget.playlist_entry !== undefined) {
			angular.forEach(self.modifyTarget.playlist_entry, function(item) {
				item.preview = self.modifyTarget.check_all_preview;
			});
		}
	}

	self.showCloneModal = function(target, type) {
		self.modifyTarget = target;

		$('#cloneUnitModal').modal('show');
		$('#cloneUnitModal').on('shown.bs.modal', function() {
			self.clone = {
				type: type,
				items: [],
				checkAll: false,
				target: type === 'clone' ? { name: '- Select Knowledge -' } : target
			}

			if (type === 'clone') {
				$http.get([$utility.SERVICE_URL, '/creation/knowledges'].join(''))
				.success(function(response, status) {
					self.clone.knowledges = response;
				});
			}
			else if (type === 'remove') {
				$scope.$apply(function() {
					angular.forEach(target.units, function(item) {
						self.clone.items.push({
							uqid: item.uqid,
							name: item.name
						});
					});
				});
			}
		});
		$('#cloneUnitModal').on('hidden.bs.modal', function() {
			delete self.modifyTarget;
			delete self.clone;
			self.loadChapter();
		});
	}

	self.selectCloneItem = function(target) {
		if (!target) {
			angular.forEach(self.clone.items, function(item) {
				item.check = self.clone.checkAll;
			});
		}
		else {
			angular.forEach(self.clone.items, function(item) {
				if (item.unit_type !== 'chapter' && item.chapter.uqid === target.uqid)
					item.check = target.check;
			});
		}
	}

	self.selectCloneKnowledge = function(target) {
		self.clone.target = target;

		$http.get([$utility.SERVICE_URL, '/creation/knowledges/', target.uqid, '/units'].join(''))
		.success(function(response, status) {
			var items = [];
			angular.forEach(response, function(item, index) {
				if (index === 0){
					items.push({unit_type: 'chapter', name: item.chapter.name, uqid: item.chapter.uqid});
					items.push(item);
				}
				else if (item.chapter.uqid !== response[index-1].chapter.uqid){
					items.push({unit_type: 'chapter', name: item.chapter.name, uqid: item.chapter.uqid});
					items.push(item);
				}
				else
					items.push(item);
			});
			self.clone.items = items;
		});
	}

	self.cloneUnit = function() {
		var units = [];
		angular.forEach(self.clone.items, function(item) {
			if (item.check) {
				units.push(item.uqid);
			}
		});

		$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.uqid, '/cloneUnits'].join(''), { units: units.join(',') })
		.success(function(response, status) {
			if (!response.error)
				$('#cloneUnitModal').modal('hide');
		});
	}

	self.removeUnit = function(index) {
		var units = [];
		angular.forEach(self.clone.items, function(item) {
			if (item.check) {
				units.push(item.uqid);
			}
		});

		$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.uqid, '/removeUnits'].join(''), { units: units.join(',') })
		.success(function(response, status) {
			if (!response.error)
				$('#cloneUnitModal').modal('hide');
		});
	}

	self.showParsePlaylist = function(chapter) {
		self.modifyTarget = chapter;
		self.modifyTarget.edit_type = 'parsePlaylist';
		self.modifyTarget.check_all_entry = true;

		$('#youtubePlaylistModal').modal('show');
		$('#youtubePlaylistModal').on('hidden.bs.modal', function() {
			delete self.modifyTarget;
			self.loadChapter();
		});
	}

	self.parsePlaylist = function() {
		self.modifyTarget.playlist_entry = [];
		var url = self.modifyTarget.playlist.match(/^(http|https):\/\/www.youtube.com\/[^#]*list=([0-9a-zA-Z\-\_]+)?/);
		if (url !== null && url.length == 3) {
			self.loadPlaylist(url[2], 1);
			self.modifyTarget.loadPlaylist = true;
		}
	}

	self.loadPlaylist = function(url, start_index) {
		$.ajax({
			url: ['http://gdata.youtube.com/feeds/api/playlists/', url, '?alt=json&max-results=20&start-index=', start_index].join('')
		}).done(function(response) {
			$scope.$apply(function() {
				angular.forEach(response.feed.entry, function(item) {
					if (item.media$group.yt$duration !== undefined && item.media$group.media$player !== undefined) {
						self.modifyTarget.playlist_entry.push({
							name: item.media$group.media$title.$t,
							time_desc: $utility.timeToFormat(item.media$group.yt$duration.seconds),
							time: item.media$group.yt$duration.seconds,
							url: item.media$group.media$player[0].url,
							description: item.media$group.media$description.$t,
							create: true,
							preview: false
						});
					}
				});

				if (response.feed.entry === undefined || response.feed.entry.length < 20)
					self.modifyTarget.loadPlaylist = false;
				else
					self.loadPlaylist(url, 20+start_index);
			});
		}).fail(function() {
			self.modifyTarget.playlist_entry = [];
		});
	}

	self.savePlaylist = function(index) {
		self.modifyTarget.loadPlaylist = true;

		if (index < self.modifyTarget.playlist_entry.length) {
			var entry = self.modifyTarget.playlist_entry[index];
			if (entry.create) {
				var data = {
					name: entry.name,
					unit_type: 'video',
					content_url: entry.url,
					content_time: entry.time,
					description: entry.description,
					preview: entry.preview
				}

				$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.uqid, '/units'].join(''), data)
				.success(function(response, status) {
					self.modifyTarget.playlist_entry[index].upload = true;
					index += 1;
					self.savePlaylist(index);
				});
			}
			else {
				index += 1;
				self.savePlaylist(index);
			}
		}
		else
			$('#youtubePlaylistModal').modal('hide');
	}

	self.loadUnit = function() {
		$http.get([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/units'].join(''))
		.success(function(response, status) {
			angular.forEach(self.chapters, function(chapter) {
				chapter.units = [];

				angular.forEach(response, function(unit) {
					unit.format_time = $utility.timeToFormat(unit.content_time);
					unit.priorities = [];
					for(var i = 1; i <= unit.max_priority; i++)
						unit.priorities.push(i);

					if (unit.chapter.uqid === chapter.uqid)
						chapter.units.push(unit);
				});
			});
		});
	}

	self.sortableUnit = function(target) {
		if (!target.sortableUnit) {
			target.sortableUnit = true;

			$(['[unit-list=', target.uqid, ']'].join('')).sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'),
					end = ui.item.index(),
					chIndex = $(ui.item.context).attr('chapter-index');

					self.chapters[chIndex].units.splice(end, 0,
					self.chapters[chIndex].units.splice(start, 1)[0]);

					$scope.$apply();

					self.modifyTarget = self.chapters[chIndex].units[end];
					self.modifyTarget.priority = end + 1;

					var data = {
						ch_uqid: self.chapters[chIndex].uqid,
						priority: self.modifyTarget.priority,
						preview: self.modifyTarget.preview
					}

					$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.chapters[chIndex].uqid, '/units/', self.modifyTarget.uqid].join(''), data)
					.success(function(response, status) {
						if (response.error) {
							self.errMessage = response.error;
							$('#errorMessageModal').modal('show');
							$('#errorMessageModal').on('hidden.bs.modal', function() {
								delete self.errMessage;
							});
						}
					});
				}
			});
			$('[unit-list]').sortable('option', 'disabled', false);
			$('[unit-list]').disableSelection();
		}
		else {
			target.sortableUnit = false;
			$(['[unit-list=', target.uqid, ']'].join('')).sortable('disable');
		}
	}

	self.addUnit = function(chapter) {
		if (chapter === null) chapter = self.chapters[0];

		var unit = {};
		unit.edit_type = 'create';
		unit.chapter = chapter;
		unit.edit_name = '';
		unit.edit_ch_uqid = chapter.uqid;
		unit.edit_ch_name = chapter.name;
		unit.edit_unit_type = 'video';
		unit.edit_content_url = '';
		unit.edit_content_time = '0';
		unit.edit_content_time_desc = '';
		unit.edit_description = '';
		unit.edit_preview = false;
		unit.edit_content_embed = '';
		unit.edit_content_poll = {
			content: '',
			options: []
		};
		unit.edit_content_qa = '';
		unit.edit_content_draw = {
			description: '',
			background: ''
		};

		unit.priorities = [];
		if (chapter.units !== undefined) {
			for (var i = 1; i <= chapter.units.length + 1; i++)
				unit.priorities.push(i);
			unit.edit_priority = chapter.units.length + 1;
		}
		else
			unit.edit_priority = 1;

		self.modifyTarget = unit;
		self.modifyTarget.previewUnit = false;
		self.changeLayout('unit', function() {
			self.modifyTarget.video_tooltip =
			'<div style="width:400px;padding:10px">\
				<div class="row">\
					<label class="col-xs-3" style="text-align:right">Youku</label>\
					<div class="col-xs-9"><span>http://v.youku.com/v_show/id_XNzE0MTU3NjIw.html</span></div>\
				</div>\
				<!--<div class="row">\
					<label class="col-xs-3" style="text-align:right">Vimeo</label>\
					<div class="col-xs-9"><span>http://vimeo.com/62238077</span></div>\
				</div>-->\
				<div class="row">\
					<label class="col-xs-3" style="text-align:right">Video(mp4)</label>\
					<div class="col-xs-9"><span>http://vjs.zencdn.net/v/oceans.mp4</span></div>\
				</div>\
				<div class="row">\
					<label class="col-xs-3" style="text-align:right">Audio(mp3)</label>\
					<div class="col-xs-9"><span>http://www.w3schools.com/html/horse.mp3</span></div>\
				</div>\
			</div>';

			$timeout(function(){$('[video-tooltip]').tooltip();},100);
		});
	}

	self.editUnit = function(unit) {
		unit.edit_type = 'update';
		unit.edit_name = unit.name;
		unit.edit_priority = unit.priority;
		unit.edit_ch_uqid = unit.chapter.uqid;
		unit.edit_ch_name = unit.chapter.name;
		unit.edit_unit_type = unit.unit_type;
		unit.edit_content_url = (unit.content_url ? unit.content_url : unit.edit_content_url);
		unit.edit_content_time = (unit.content_time ? unit.content_time : unit.edit_content_time);
		unit.edit_content_time_desc = unit.unit_type === 'video' ? $utility.timeToFormat(unit.content_time) : '';
		unit.edit_description = unit.description === null ? '' : unit.description;
		unit.edit_preview = unit.preview;

		if (unit.unit_type === 'embed' && unit.content !== null) {
			unit.edit_content_embed = unit.content;
		}
		else {
			unit.edit_content_embed = '';
		}

		if (unit.unit_type === 'poll' && unit.content !== null) {
			unit.edit_content_poll = {
				content: unit.content.content,
				options: unit.content.options
			};
		}
		else {
			unit.edit_content_poll = {
				content: '',
				options: []
			};
		}

		if (unit.unit_type === 'qa' && unit.content !== null) {
			unit.edit_content_qa = unit.content;
		}
		else {
			unit.edit_content_qa = '';
		}

		if (unit.unit_type === 'draw' && unit.content !== null) {
			unit.edit_content_draw = {
				description: unit.content.description,
				background: unit.content.background
			};
		}
		else {
			unit.edit_content_draw = {
				description: '',
				background: ''
			};
		}

		self.modifyTarget = unit;

		self.modifyTarget.previewUnit = false;
		self.modifyTarget.previewQuiz = false;
		self.changeLayout('unit', function() {
			self.modifyTarget.video_tooltip =
			'<div style="width:400px;padding:10px">\
				<div class="row">\
					<label class="col-xs-3" style="text-align:right">Youku</label>\
					<div class="col-xs-9"><span>http://v.youku.com/v_show/id_XNzE0MTU3NjIw.html</span></div>\
				</div>\
				<!--<div class="row">\
					<label class="col-xs-3" style="text-align:right">Vimeo</label>\
					<div class="col-xs-9"><span>http://vimeo.com/62238077</span></div>\
				</div>-->\
				<div class="row">\
					<label class="col-xs-3" style="text-align:right">Video(mp4)</label>\
					<div class="col-xs-9"><span>http://vjs.zencdn.net/v/oceans.mp4</span></div>\
				</div>\
				<div class="row">\
					<label class="col-xs-3" style="text-align:right">Audio(mp3)</label>\
					<div class="col-xs-9"><span>http://www.w3schools.com/html/horse.mp3</span></div>\
				</div>\
			</div>';

			// $timeout(function(){$('[video-tooltip]').tooltip();},100);
		});

		if (self.modifyTarget.edit_unit_type === 'embed')
			self.initHtmlEditor('#embed-content', self.modifyTarget.edit_content_embed, {visual:false});
		else if (self.modifyTarget.edit_unit_type === 'poll')
			self.initHtmlEditor('#poll-content', self.modifyTarget.edit_content_poll.content);
		else if (self.modifyTarget.edit_unit_type === 'qa')
			self.initHtmlEditor('#qa-content', self.modifyTarget.edit_content_qa);
		else if (self.modifyTarget.edit_unit_type === 'draw')
			self.initHtmlEditor('#draw-description', unit.content.description);

		self.parseUnitContent();
	}
	self.uploadVideo = function(){
		if (self.modifyTarget.uqid === undefined) {
			self.saveUnit(self.uploadVideo);
			return;
		}
		OneKnow.choose({
			uploadType : 'video' ,
			unitUqid : self.modifyTarget.uqid ,
			success:function(data){
				$scope.$apply(function(){
					self.modifyTarget.edit_content_url = data.url;
					self.parseUnitContent();
				});
		}});
	};
	self.uploadDoc = function(){
		if (self.modifyTarget.uqid === undefined) {
			self.saveUnit(self.uploadDoc);
			return;
		}
		OneKnow.choose({
			uploadType : 'doc' ,
			unitUqid : self.modifyTarget.uqid ,
			success:function(data){
				$scope.$apply(function(){
					self.modifyTarget.edit_content_url = data.url;
					self.parseUnitContent();
				});
		}});
	};
	self.uploadImage = function(){
		if (self.modifyTarget.uqid === undefined) {
			self.saveUnit(self.uploadImage);
			return;
		}
		OneKnow.choose({
			uploadType : 'image' ,
			unitUqid : self.modifyTarget.uqid ,
			success:function(data){
				$scope.$apply(function(){
					if ( !self.modifyTarget.edit_content_draw )
						self.modifyTarget.edit_content_draw = {};
					self.modifyTarget.edit_content_draw.background = data.url + '?' + Date.now();
					self.parseUnitContent();
				});
		}});
	};
	self.changeChapter = function(chapter) {
		self.modifyTarget.priorities = [];
		for (var i = 1; i <= chapter.units.length + 1; i++)
			self.modifyTarget.priorities.push(i);

		if (self.modifyTarget.edit_type === 'create') {
			self.modifyTarget.edit_priority = chapter.units.length + 1;
		}
		else if (self.modifyTarget.edit_type === 'update') {
			if (self.modifyTarget.chapter.uqid === chapter.uqid)
				self.modifyTarget.edit_priority = self.modifyTarget.priority;
			else
				self.modifyTarget.edit_priority = chapter.units.length + 1;
		}

		self.modifyTarget.edit_ch_uqid = chapter.uqid;
		self.modifyTarget.edit_ch_name = chapter.name;
	}

	self.toggleUnitType = function(target) {
		self.modifyTarget.edit_unit_type = target;

		if (self.modifyTarget.edit_unit_type === 'embed')
			self.initHtmlEditor('#embed-content', self.modifyTarget.edit_content_embed, {visual:false});
		else if (self.modifyTarget.edit_unit_type === 'poll')
			self.initHtmlEditor('#poll-content', self.modifyTarget.edit_content_poll.content);
		else if (self.modifyTarget.edit_unit_type === 'qa')
			self.initHtmlEditor('#qa-content', self.modifyTarget.edit_content_qa);
		else if (self.modifyTarget.edit_unit_type === 'draw')
			self.initHtmlEditor('#draw-description', self.modifyTarget.edit_content_draw.description);

		self.parseUnitContent();
	}

	self.addLaTex = function() {
		if (self.modifyTarget.edit_unit_type === 'embed')
			self.addEmbedLaTex();
		else if (self.modifyTarget.edit_unit_type === 'poll')
			self.addPollLaTex();
		else if (self.modifyTarget.edit_unit_type === 'qa')
			self.addQALaTex();
		else if (self.modifyTarget.edit_unit_type === 'draw')
			self.addDrawLaTex();
		else if (self.modifyTarget.parentUnit)
			self.addQuizLaTex();
	}

	self.addEmbedLaTex = function() {
		// var source = ['<img src="http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(self.modifyTarget.input_content), '"/>'].join('');

		delete self.modifyTarget.input_content;
		$('#embed-content').redactor('set', [$('#embed-content').redactor('get'), $('#mathjax-output .MathJax').html()].join(''));
		self.modifyTarget.edit_content_embed = $('#embed-content').redactor('get');

		$('#latexModal').modal('hide');
	}

	self.addPollLaTex = function() {
		// var source = ['<img src="http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(self.modifyTarget.input_content), '"/>'].join('');

		delete self.modifyTarget.input_content;
		$('#poll-content').redactor('set', [$('#poll-content').redactor('get'), $('#mathjax-output .MathJax').html()].join(''));
		self.modifyTarget.edit_content_poll.content = $('#poll-content').redactor('get');

		$('#latexModal').modal('hide');
	}

	self.addQALaTex = function() {
		// var source = ['<img src="http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(self.modifyTarget.input_content), '"/>'].join('');

		delete self.modifyTarget.input_content;
		$('#qa-content').redactor('set', [$('#qa-content').redactor('get'), $('#mathjax-output .MathJax').html()].join(''));
		self.modifyTarget.edit_content_qa = $('#qa-content').redactor('get');

		$('#latexModal').modal('hide');
	}

	self.addDrawLaTex = function() {
		// var source = ['<img src="http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(self.modifyTarget.input_content), '"/>'].join('');

		delete self.modifyTarget.input_content;
		$('#draw-description').redactor('set', [$('#draw-description').redactor('get'), $('#mathjax-output .MathJax').html()].join(''));
		self.modifyTarget.edit_content_draw.description = $('#draw-description').redactor('get');

		$('#latexModal').modal('hide');
	}

	self.addQuizLaTex = function() {
		// var source = ['<img src="http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(self.modifyTarget.input_content), '"/>'].join('');

		delete self.modifyTarget.input_content;
		$('#quiz-content').redactor('set', [$('#quiz-content').redactor('get'), $('#mathjax-output .MathJax').html()].join(''));
		self.modifyTarget.edit_content = $('#quiz-content').redactor('get');

		$('#latexModal').modal('hide');
	}

	self.addPollOption = function() {
		var content = self.modifyTarget.edit_content_poll;
		content.options.push({
			item: '',
			value: Math.pow(2, self.modifyTarget.edit_content_poll.options.length)
		});
	}

	self.removePollOption = function(option) {
		var content = self.modifyTarget.edit_content_poll;
		var options = [];
		angular.forEach(content.options, function(item) {
			if (item.value !== option.value)
				options.push(item);
		});
		self.modifyTarget.edit_content_poll.options = options;
	}

	self.parseUnitContent = function() {
		var unit = self.modifyTarget;

		self.modifyTarget.edit_content_time = '';
		self.modifyTarget.edit_content_time_desc = '';

		if (unit.edit_unit_type === 'video') {
			$timeout(function(){$('[video-tooltip]').tooltip();},100);
			if (unit.edit_content_url !== '') {
				var videoPath = unit.edit_content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);

				if (videoPath !== null && videoPath.length === 6) {
					if (videoPath[2] === 'youtube') {
						$.get(['http://gdata.youtube.com/feeds/api/videos/', videoPath[5], '?alt=json'].join(''), function(response) {
							if (self.modifyTarget.edit_name === '')
								self.modifyTarget.edit_name = response.entry.title.$t;

							self.modifyTarget.edit_content_time = response.entry.media$group.yt$duration.seconds;
							self.modifyTarget.edit_content_time_desc = $utility.timeToFormat(response.entry.media$group.yt$duration.seconds);
							if (self.modifyTarget.edit_type !== 'update')
								self.modifyTarget.edit_description = response.entry.media$group.media$description.$t;

							self.initHtmlEditor('#unit-description', self.modifyTarget.edit_description);
						});
					}
					else if (videoPath[2] === 'vimeo') {
						$.get(['http://vimeo.com/api/oembed.json?url=', videoPath[0]].join(''), function(response) {
							if (self.modifyTarget.edit_name === '')
								self.modifyTarget.edit_name = response.title;

							self.modifyTarget.edit_content_time = response.duration;
							self.modifyTarget.edit_content_time_desc = $utility.timeToFormat(response.duration);
							if (self.modifyTarget.edit_type !== 'update')
								self.modifyTarget.edit_description = response.description;

							self.initHtmlEditor('#unit-description', self.modifyTarget.edit_description);
						});
					}
					else if (videoPath[2] === 'youku') {
						$.get(['https://openapi.youku.com/v2/videos/show_basic.json?client_id=c865b5756563acee&video_id=', videoPath[4]].join(''), function(response) {
							if (self.modifyTarget.edit_name === '')
								self.modifyTarget.edit_name = response.title;

							self.modifyTarget.edit_content_time = response.duration;
							self.modifyTarget.edit_content_time_desc = $utility.timeToFormat(response.duration);
							if (self.modifyTarget.edit_type !== 'update')
								self.modifyTarget.edit_description = response.description;

							self.initHtmlEditor('#unit-description', self.modifyTarget.edit_description);
						});
					}
					else {
						self.modifyTarget.edit_content_time = 0;
						self.modifyTarget.edit_content_time_desc = '';
					}
				}
				else {
					$timeout(function() {
						var videoId = Date.now();
						$('#html5-video-preload').html(
							['<video id="video-', videoId,'"',
								' src="', self.modifyTarget.edit_content_url, (self.modifyTarget.edit_content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
								' style="width:0;height:0;opacity:0">',
							'</video>'].join('')
						);

						$(['#video-', videoId].join('')).on('loadeddata', function(target) {
							$scope.$apply(function() {
								self.modifyTarget.edit_content_time = target.target.duration;
								self.modifyTarget.edit_content_time_desc = $utility.timeToFormat(Math.ceil(target.target.duration));
							});
						});
					},100);
				}
			}

			if (unit.quizzes === undefined)
				self.listQuiz(unit);
		}
		else if (unit.edit_unit_type === 'quiz') {
			if (unit.quizzes === undefined)
				self.listQuiz(unit);
		}

		if (self.modifyTarget.previewUnit&&self.layout=='unit') {
			self.previewUnit(true);
		}
	}

	self.previewUnit = function(flag) {
		if (flag !== undefined)
			self.modifyTarget.previewUnit = flag;
		else
			self.modifyTarget.previewUnit = !self.modifyTarget.previewUnit;

		if (self.modifyTarget.previewUnit) {
			if (self.modifyTarget.edit_unit_type === 'video') {
				var videoPath = self.modifyTarget.edit_content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
				var content = '';
				if (videoPath !== null && videoPath.length === 6) {
					if (videoPath[2] === 'youtube') {
						var startTime = self.modifyTarget.edit_content_url.match(/t=([0-9]+)/);
						if (startTime !== null && startTime.length === 2)
							startTime = ['&start=', startTime[1]].join('');
						else
							startTime = '';
						content = ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '?autohide=1&rel=0&showinfo=0&theme=light', startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
					}
					else if (videoPath[2] === 'vimeo') {
						var startTime = self.modifyTarget.edit_content_url.match(/t=([0-9]+)/);
						if (startTime !== null && startTime.length === 2)
							startTime = ['#t=', startTime[1]].join('');
						else
							startTime = '';
						content = ['<iframe src="https://player.vimeo.com/video/', videoPath[3], startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
					}
					else if (videoPath[2] === 'youku')
						content = ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="100%" height="100%" frameborder="0"></iframe>'].join('');

					self.modifyTarget.edit_video_content = content;
				}
				else {
					var videoId = Date.now();
					self.modifyTarget.edit_video_content =
						['<video id="video-', videoId,'"',
							' src="', self.modifyTarget.edit_content_url, (self.modifyTarget.edit_content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
							' width="100%" height="100%"',
							' class="video-js vjs-default-skin vjs-big-play-centered">',
						'</video>'].join('');

					$timeout(function() {
						videojs(['video-', videoId].join(''), {controls: true, preload: 'auto'}, function() {});
					},100);
				}
			}
			else if (self.modifyTarget.edit_unit_type === 'embed') {
				self.modifyTarget.edit_content_embed = $('#embed-content').redactor('get');
			}
			else if (self.modifyTarget.edit_unit_type === 'poll') {
				self.modifyTarget.edit_content_poll.content = $('#poll-content').redactor('get');
			}
			else if (self.modifyTarget.edit_unit_type === 'qa') {
				self.modifyTarget.edit_content_qa = $('#qa-content').redactor('get');
			}
			else if (self.modifyTarget.edit_unit_type === 'draw') {
				$timeout(function() {
					$('#draw-board').html('<canvas></canvas>');
					$('#draw-board').literallycanvas({
						imageURLPrefix: '/library/literallycanvas/img',
						backgroundColor: 'rgba(0, 0, 0, 0)',
						primaryColor: '#f00'
					});
					$('#draw-board .clear-button').detach();
				},100);
			}
		}
	}

	self.saveUnit = function(flag) {
		//flag - false : addQuiz
		//       ...
		//       else  : changeLayout content
		if (self.modifyTarget.edit_name === '') {
			$('#modifyTarget_edit_name').focus();
			return;
		}

		if (self.modifyTarget.edit_unit_type === 'video' &&
			self.modifyTarget.edit_content_url !== '' &&
			self.modifyTarget.edit_content_time === 0)
			return;

		if (self.modifyTarget.edit_unit_type !== 'video')
			self.modifyTarget.edit_content_time = 1;

		var content;
		if (self.modifyTarget.edit_unit_type === 'poll') {
			angular.forEach(self.modifyTarget.edit_content_poll.options, function(option) {
				if (option.latex)
					option.latex_url = ['http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(option.item)].join('');

				delete option.$$hashKey;
			});

			content = {
				content: $('#poll-content').redactor('get'),
				options: self.modifyTarget.edit_content_poll.options
			};

			content = JSON.stringify(content);
		}
		else if (self.modifyTarget.edit_unit_type === 'qa') {
			content = $('#qa-content').redactor('get');
		}
		else if (self.modifyTarget.edit_unit_type === 'embed') {
			content = $('#embed-content').redactor('get');
		}
		else if (self.modifyTarget.edit_unit_type === 'draw') {
			content = JSON.stringify({
				background: self.modifyTarget.edit_content_draw.background,
				description: $('#draw-description').redactor('get')
			});
		}

		var data = {
			ch_uqid: self.modifyTarget.edit_ch_uqid,
			name: self.modifyTarget.edit_name,
			priority: self.modifyTarget.edit_priority,
			description: $('#unit-description').redactor('get'),
			unit_type: self.modifyTarget.edit_unit_type,
			content_url: self.modifyTarget.edit_content_url,
			content_time: self.modifyTarget.edit_content_time,
			preview: self.modifyTarget.edit_preview,
			content: content
		}

		if (self.modifyTarget.edit_type === 'create') {
			$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.chapter.uqid, '/units'].join(''), data)
			.success(function(response, status) {
				self.loadUnit();
				//self.modifyTarget = response;
				//self.modifyTarget.edit_unit_type = self.modifyTarget.unit_type;
				for (var prop in response) {
				    if( response.hasOwnProperty( prop ) ) {
				      self.modifyTarget[prop] = response[prop];
				    }
				  }
				self.modifyTarget.edit_type = "update";
				if (flag !== undefined && flag === false)
					self.addQuiz(self.modifyTarget);
				else if ( angular.isFunction(flag))
					flag()
				// else if (flag !== undefined && flag === 'showVideoUpload')
				// 	self.uploadVideo();
				// else if (flag !== undefined && flag === 'showDocUpload')
				// 	self.uploadDoc();
				// else if (flag !== undefined && flag === 'showImageUpload')
				// 	self.uploadImage();
				else
					self.changeLayout('content');
			});
		}
		else if (self.modifyTarget.edit_type === 'update') {
			$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.chapter.uqid, '/units/', self.modifyTarget.uqid].join(''), data)
			.success(function(response, status) {
				self.loadUnit();
				self.modifyTarget = response;
				if (flag !== undefined && flag === false)
					self.addQuiz(self.modifyTarget);
				else
					self.changeLayout('content');
			});
		}

		window.scrollTo(0, 0);
	}

	self.changeUnitPreview = function(target) {
		var data = { preview: !target.preview };

		$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', target.chapter.uqid, '/units/', target.uqid].join(''), data)
		.success(function(response, status) {
			target.preview = response.preview;
		});
	}

	self.deleteUnit = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.chapter.uqid, '/units/', self.modifyTarget.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.loadUnit();
				delete self.modifyTarget;
				self.changeLayout('content');
			}
			else
				self.modifyTarget.saveMsg = response.error;
		});
	}

	self.listQuiz = function(unit) {
		if (unit.uqid) {
			$http.get([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', unit.chapter.uqid, '/units/', unit.uqid, '/quizzes'].join(''))
			.success(function(response, status) {
				angular.forEach(response, function(quiz) {
					quiz.full_content = function(quiz) {
						return [parseInt(quiz.quiz_no, 10) < 10 ? '0' + quiz.quiz_no : quiz.quiz_no, quiz.content.replace(/<(?:.|\n)*?>/gm, '')].join('. ');
					}

					quiz.video_time_desc = $utility.timeToFormat(quiz.video_time);
					quiz.parentUnit = unit;
				});
				unit.quizzes = response;
			});
		}
	}

	self.sortableQuiz = function(target) {
		if (!target.sortableQuiz) {
			target.sortableQuiz = true;

			$(['[quiz-list=', target.uqid ,']'].join('')).sortable({
				start: function(e, ui) {
					ui.item.data('start', ui.item.index());
				},
				update: function(e, ui) {
					var start = ui.item.data('start'), end = ui.item.index();

					self.modifyTarget.quizzes.splice(end, 0, self.modifyTarget.quizzes.splice(start, 1)[0]);
					$scope.$apply();

					var quiz = self.modifyTarget.quizzes[end];
					var data = { priority: end + 1 };

					$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.chapter.uqid, '/units/', self.modifyTarget.uqid, '/quizzes/', quiz.uqid].join(''), data)
					.success(function(response, status) {
						self.listQuiz(self.modifyTarget);
					});
				}
			});
			$('[quiz-list]').sortable('option', 'disabled', false);
			$('[quiz-list]').disableSelection();
		}
		else {
			target.sortableQuiz = false;
			$(['[quiz-list=', target.uqid ,']'].join('')).sortable('disable');
		}
	}

	self.addQuiz = function(unit) {
		if (self.modifyTarget.uqid === undefined) {
			self.saveUnit(false);
			return;
		}

		var quiz = {
			parentUnit: unit,
			edit_content: '',
			edit_solution: '',
			edit_video_time: '0',
			edit_options: [],
			preview: false,
			priorities: [],
			edit_type: 'create'
		}

		self.modifyTarget = quiz;
		self.changeLayout('quiz');

		self.changeQuizVideoTime();
	}

	self.editQuiz = function(quiz) {
		quiz.edit_content = quiz.content;
		quiz.edit_solution = quiz.solution;
		quiz.edit_video_time = quiz.video_time;
		quiz.edit_options = quiz.options.slice(0);
		quiz.edit_priority = quiz.quiz_no;
		quiz.priorities = [];
		quiz.edit_type = 'update';
		for (var i = 1; i <= quiz.parentUnit.quizzes.length; i++)
			quiz.priorities.push(i);

		self.modifyTarget = quiz;
		self.modifyTarget.previewQuiz = false;
		self.changeLayout('quiz');

		self.changeQuizVideoTime();
	}

	self.changeQuizVideoTime = function() {
		var time = Math.ceil(self.modifyTarget.edit_video_time);
		var format_time = [Math.floor(time / 3600), Math.floor((time % 3600) / 60), (time % 60)];

		self.modifyTarget.edit_video_time_h = format_time[0];
		self.modifyTarget.edit_video_time_m = format_time[1];
		self.modifyTarget.edit_video_time_s = format_time[2];

		self.modifyTarget.edit_video_time_desc = $utility.timeToFormat(self.modifyTarget.edit_video_time);
	}

	self.changeQuizVideoTime2 = function() {
		self.modifyTarget.edit_video_time =
			Math.ceil(self.modifyTarget.edit_video_time_h * 3600) +
			Math.ceil(self.modifyTarget.edit_video_time_m * 60) +
			Math.ceil(self.modifyTarget.edit_video_time_s);

		self.modifyTarget.edit_video_time_desc = $utility.timeToFormat(self.modifyTarget.edit_video_time);
	}

	self.previewQuizContent = function() {
		self.modifyTarget.previewQuiz = !self.modifyTarget.previewQuiz;

		var quiz_type = 0, answer = 0;
		angular.forEach(self.modifyTarget.edit_options, function(option) {
			if (option.correct) {
				quiz_type += 1;
				answer += Math.ceil(option.value);
			}
			if (option.latex)
				option.latex_url = ['http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(option.item)].join('');
		});
		quiz_type = quiz_type <= 1 ? 'single' : 'multi';

		self.modifyTarget.quiz_type = quiz_type;
		self.modifyTarget.edit_content = $('#quiz-content').redactor('get');
		self.modifyTarget.edit_solution = $('#quiz-solution').redactor('get');
	}

	self.addQuizOption = function() {
		var quiz = self.modifyTarget;
		quiz.edit_options.push({
			correct: false,
			item: '',
			value: Math.pow(2, self.modifyTarget.edit_options.length)
		});
	}

	self.removeQuizOption = function(option) {
		var quiz = self.modifyTarget;
		var options = [];
		angular.forEach(quiz.edit_options, function(item) {
			if (item.value !== option.value)
				options.push(item);
		});
		self.modifyTarget.edit_options = options;
	}

	self.saveQuiz = function() {
		var quiz_type = 0, answer = 0, options = '';
		angular.forEach(self.modifyTarget.edit_options, function(option) {
			if (option.correct) {
				quiz_type += 1;
				answer += Math.ceil(option.value);
			}
			if (option.latex)
				option.latex_url = ['http://chart.apis.google.com/chart?cht=tx&chl=', encodeURIComponent(option.item)].join('');

			delete option.$$hashKey;
		});
		quiz_type = quiz_type <= 1 ? 'single' : 'multi';
		options = JSON.stringify(self.modifyTarget.edit_options);

		var data = {
			quiz_type: quiz_type,
			answer: answer,
			options: options,
			content: $('#quiz-content').redactor('get'),
			priority: self.modifyTarget.edit_priority,
			solution: $('#quiz-solution').redactor('get')
		}

		if (self.modifyTarget.parentUnit.unit_type === 'video')
			data['video_time'] = self.modifyTarget.edit_video_time;

		if (self.modifyTarget.edit_type === 'create') {
			$http.post([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.parentUnit.chapter.uqid, '/units/', self.modifyTarget.parentUnit.uqid, '/quizzes'].join(''), data)
			.success(function(response, status) {
				self.listQuiz(self.modifyTarget.parentUnit);
				self.editUnit(self.modifyTarget.parentUnit);
			});
		}
		else if (self.modifyTarget.edit_type === 'update') {
			$http.put([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.parentUnit.chapter.uqid, '/units/', self.modifyTarget.parentUnit.uqid, '/quizzes/', self.modifyTarget.uqid].join(''), data)
			.success(function(response, status) {
				self.listQuiz(self.modifyTarget.parentUnit);
				self.editUnit(self.modifyTarget.parentUnit);
			});
		}
	}

	self.deleteQuiz = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/knowledges/', self.target.uqid, '/chapters/', self.modifyTarget.parentUnit.chapter.uqid, '/units/', self.modifyTarget.parentUnit.uqid, '/quizzes/', self.modifyTarget.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.listQuiz(self.modifyTarget.parentUnit);
				self.editUnit(self.modifyTarget.parentUnit);
			}
			else
				self.modifyTarget.saveMsg = response.error;
		});
	}

	self.togglePreview = function() {
		self.preview = !self.preview;

		if (!self.preview) {
			self.layout = 'content';
		}
		else {
			self.viewType = 'list';
			angular.forEach(self.chapters, function(chapter) {
				angular.forEach(chapter.units, function(item) {
					if (item.unit_type === 'video') {
						var videoPath = item.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
						if (videoPath !== null && videoPath.length === 6) {
							if (videoPath[2] === 'youtube') {
								item.thumbnail_image = ['http://i1.ytimg.com/vi/', videoPath[5], '/0.jpg'].join('');
							}
							else if (videoPath[2] === 'vimeo') {
								$.get(['http://vimeo.com/api/oembed.json?url=', videoPath[0]].join(''), function(response) {
									$scope.$apply(function() {
										item.thumbnail_image = response.thumbnail_url;
									});
								});
							}
							else if (videoPath[2] === 'youku') {
								$.get(['https://openapi.youku.com/v2/videos/show_basic.json?client_id=c865b5756563acee&video_id=', videoPath[4]].join(''), function(response) {
									$scope.$apply(function() {
										item.thumbnail_image = response.thumbnail_v2;
									});
								});
							}
						}
						else
							item.content_url2 = '/icon.png'; //['http://images.websnapr.com/?url=', item.content_url, '&key=727h5b1Hm40w&hash=' + encodeURIComponent(websnapr_hash)].join('');
					}
					// else if (item.unit_type === 'web')
					// 	item.content_url2 = ['http://images.websnapr.com/?url=', item.content_url, '&key=727h5b1Hm40w&hash=' + encodeURIComponent(websnapr_hash)].join('');
				});
			});
		}

		window.scrollTo(0, 0);
	}

	self.openPreviewTarget = function(target) {
		self.previewTarget = target;

		$timeout(function() {
			if (self.previewTarget.unit_type === 'video') {
				var videoPath = self.previewTarget.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
				var content = '';
				if (videoPath !== null && videoPath.length === 6) {
					if (videoPath[2] === 'youtube') {
						var startTime = self.previewTarget.content_url.match(/t=([0-9]+)/);
						if (startTime !== null && startTime.length === 2)
							startTime = ['&start=', startTime[1]].join('');
						else
							startTime = '';
						content = ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '?autohide=1&rel=0&showinfo=0&theme=light', startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
					}
					else if (videoPath[2] === 'vimeo') {
						var startTime = self.previewTarget.content_url.match(/t=([0-9]+)/);
						if (startTime !== null && startTime.length === 2)
							startTime = ['#t=', startTime[1]].join('');
						else
							startTime = '';
						content = ['<iframe src="https://player.vimeo.com/video/', videoPath[3], startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
					}
					else if (videoPath[2] === 'youku')
						content = ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="100%" height="100%" frameborder="0"></iframe>'].join('');

					$('#previewUnitVideoContainer').html(content);
				}
				else {
					var mp3 = self.previewTarget.content_url.match(/([a-z\-_0-9\/\:\.]*\.mp3)/i);
					var videoId = Date.now();

					if (mp3 === null) {
						$('#previewUnitVideoContainer').html(
							['<video id="video-', videoId,'"',
								' src="', self.previewTarget.content_url, (self.previewTarget.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
								' width="100%" height="100%"',
								' class="video-js vjs-default-skin vjs-big-play-centered">',
							'</video>'].join('')
						);
					}
					else {
						self.previewTarget.sub_type = 'audio';

						if (self.previewTarget.description === '')
							self.previewTarget.description = ['<div style="font-size:16px;padding:10px">', translations[$utility.LANGUAGE.type]['G011'], '</div>'].join('');//-- 補充教材 --

						$('#previewUnitVideoContainer').html(
							['<video id="video-', videoId,'"',
								' src="', self.previewTarget.content_url, (self.previewTarget.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
								' width="100%" height="90px"',
								' class="video-js vjs-default-skin vjs-big-play-centered">',
							'</video>'].join('')
						);
					}

					$timeout(function() {
						videojs(['video-', videoId].join(''), {controls: true, preload: 'auto'}, function() {});
					},100);
				}
			}
			else if (self.previewTarget.unit_type === 'quiz') {
				if (self.previewTarget.quizzes === undefined)
					self.listQuiz(self.previewTarget);
			}
			else if (self.previewTarget.unit_type === 'draw') {
				$timeout(function() {
					$('#draw-board').html('<canvas></canvas>');
					$('#draw-board').literallycanvas({
						imageURLPrefix: '/library/literallycanvas/img',
						backgroundColor: 'rgba(0, 0, 0, 0)',
						primaryColor: '#f00'
					});

					if (self.previewTarget.content.description !== '') {
						$('#draw-board .custom-button').before('<div id="draw-description" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="G050"></span></div>');
						$('#draw-description').click(function() {
							$('#drawDescriptionModal').modal('show');
						});
					}

					if (self.previewTarget.content.background !== '') {
						$('#draw-board .custom-button').before('<div id="draw-background" class="btn btn-xs btn-primary" style="margin:-4px 0 0"><span translate="G068"></span></div>');
						$('#draw-background').click(function() {
							$scope.$apply(function() {
								if (self.previewTarget.backgroundImage === undefined)
									self.previewTarget.backgroundImage = ['url(', self.previewTarget.content.background, ') no-repeat'].join('');
								else
									delete self.previewTarget.backgroundImage;
							});
						});
					}

					$('#draw-board canvas').attr({'width': $('#draw-board').css('width'), 'height': $('#draw-board').css('height')});
					$('#draw-board canvas').css({'width': $('#draw-board').css('width'), 'height': $('#draw-board').css('height')});

					$compile(document.getElementById('literally-toolbar'))($scope);
				},100);
			}
			else if (self.previewTarget.unit_type === 'embed') {
				if ($(self.previewTarget.content).find('embed').length > 0)
					self.previewTarget.content = $(self.previewTarget.content).find('embed').css('width', '100%').css('height', '100%')[0].outerHTML;
				else if ($(self.previewTarget.content).find('iframe').length > 0)
					self.previewTarget.content = $(self.previewTarget.content).find('iframe').css('width', '100%').css('height', '100%')[0].outerHTML;
				else if ($(self.previewTarget.content)[0].nodeName === 'EMBED')
					self.previewTarget.content = $(self.previewTarget.content).css('width', '100%').css('height', '100%')[0].outerHTML;
				else if ($(self.previewTarget.content)[0].nodeName === 'IFRAME')
					self.previewTarget.content = $(self.previewTarget.content).css('width', '100%').css('height', '100%')[0].outerHTML;
			}

			$('#previewModal').on('hidden.bs.modal', function (e) {
				$scope.$apply(function() {
					delete self.previewTarget;
				});
			});
			$('#previewModal').modal('show');
		},100);
	}

	self.init = function() {
		$http.get([$utility.SERVICE_URL, '/creation/knowledges/', $routeParams.t].join(''))
		.success(function(response, status) {
			if (!response.error) {
				response.encodePage = encodeURIComponent(response.page);

				self.target = response;
				self.layout = 'content';
				self.preview = false;
				self.maximum = false;
				self.showChapterUnit = true;
				self.loadChapter();
				self.loadEditor();
			}
			else
				$location.path('/create/knowledge');
		});
		self.isActiveTag = $window.frontCfg.tagfunctionActivate;
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
}).directive('tagInput', function() {
	return {
		restrict: 'E',
		scope: {
			inputTags: '=taglist',
			autocomplete: '=autocomplete'
		},
		link: function($scope, element, attrs) {
			$scope.defaultWidth = 200;
			$scope.tagText = '';
			$scope.placeholder = attrs.placeholder;
			if ($scope.autocomplete) {
				$scope.autocompleteFocus = function(event, ui) {
					$(element).find('input').val(ui.item.value);
					return false;
				};
				$scope.autocompleteSelect = function(event, ui) {
					$scope.$apply('tagText="' + ui.item.value + '"');
					$scope.$apply('addTag()');
					return false;
				};
				$(element).find('input').autocomplete({
					minLength: 0,
					source: function(request, response) {
						var item;
						return response(function() {
							var i, len, ref, results, check;
							ref = $scope.autocomplete;
							results = [];
							for (i = 0, len = ref.length; i < len; i++) {
								item = ref[i];
								check = item.name.toLowerCase().indexOf(request.term.toLowerCase()) !== -1;
								check = check && $scope.tagArray().indexOf(item.name) === -1;
								if (check) {
									results.push(item.name);
								}
							}
							return results;
						}());
					},
					focus: function(_this) {
						return function(event, ui) {
							return $scope.autocompleteFocus(event, ui);
						};
					}(this),
					select: function(_this) {
						return function(event, ui) {
							return $scope.autocompleteSelect(event, ui);
						};
					}(this)
				});
			}
			$scope.tagArray = function() {
				if ($scope.inputTags === undefined) {
					return [];
				}
				return $scope.inputTags.split(',').filter(function(tag) {
					return tag !== ''  ;
				});
			};
			$scope.addTag = function() {
				var tagArray;
				if ($scope.tagText.length === 0) {
					return;
				}
				tagArray = $scope.tagArray();
				if(tagArray.indexOf($scope.tagText) == -1)
					tagArray.push($scope.tagText);
				$scope.inputTags = tagArray.join(',');
				return $scope.tagText = '';
			};
			$scope.deleteTag = function(key) {
				var tagArray;
				tagArray = $scope.tagArray();
				if (tagArray.length > 0 && $scope.tagText.length === 0 && key === undefined) {
					tagArray.pop();
				} else {
					if (key !== undefined) {
						tagArray.splice(key, 1);
					}
				}
				return $scope.inputTags = tagArray.join(',');
			};
			$scope.$watch('tagText', function(newVal, oldVal) {
				var tempEl;
				if (!(newVal === oldVal && newVal === undefined)) {
					tempEl = $('<span>' + newVal + '</span>').appendTo('body');
					$scope.inputWidth = tempEl.width() + 5;
					if ($scope.inputWidth < $scope.defaultWidth) {
						$scope.inputWidth = $scope.defaultWidth;
					}
					return tempEl.remove();
				}
			});
			element.bind('keydown', function(e) {
				var key;
				key = e.which;
				if (key === 9 || key === 13) {
					e.preventDefault();
				}
				if (key === 8) {
					return $scope.$apply('deleteTag()');
				}
			});
			return element.bind('keyup', function(e) {
				var key;
				key = e.which;
				if (key === 9 || key === 13 || key === 188) {
					e.preventDefault();
					//return $scope.$apply('addTag()');
				}
			});
		},
		template: '<div class="tag-input-ctn"><div class="input-tag" data-ng-repeat="tag in tagArray()">{{tag}}<div class="delete-tag" data-ng-click="deleteTag($index)">&times;</div></div><input type="text" data-ng-style="{width: inputWidth}" data-ng-model="tagText" placeholder="{{placeholder}}"/></div>'
	};
});