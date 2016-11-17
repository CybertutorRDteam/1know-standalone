_1know.controller('ModifyChannelCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
	var self = this;

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
		$('#input_target_logo').on('change', readData);

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
							self.modifyTarget.edit_logo = canvas.toDataURL();
						}
					}
				}
			})(file);
			reader.readAsDataURL(file);
		}
	}

	self.loadChannel = function() {
		$http.get([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				var priorities = [];
				for (var i=1;i<=response.max_category_priority;i++)
					priorities.push(i);

				angular.forEach(response.categories, function(item){
					item.priorities = priorities;
				});

				response.type = 'channel';
				self.target = response;
				self.filterRole = 'all';
				self.loadCategory(null, true);
			}
			else
				$location.path('/create/channel');
		});
	}

	self.changeLayout = function(target) {
		self.layout = target;
		
		if (self.target)
			self.target.sortableMember = false;

		window.scrollTo(0,0);
	}

	self.editPicture = function() {
		self.changeLayout('picture');
		$timeout(function() {self.initPictureEvent()},100);
	}

	self.savePicture = function() {
		$http.put([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid].join(''), { logo: self.target.edit_logo })
		.success(function(response, status) {
			self.target.logo = response.logo;
			$('#pictureModal').modal('hide');
		});
	}

	self.editChannel = function() {
		self.target.edit_name = self.target.name;
		self.target.edit_description = self.target.description;

		self.changeLayout('channel');
		self.initHtmlEditor('#channel-description', self.target.edit_description);

		window.scrollTo(0, 0);
	}

	self.saveChannel = function() {
		var errMsg = [];

		if (self.target.edit_name === '')
			errMsg.push(translations[$utility.LANGUAGE.type]['H022']);//頻道名稱不可為空白!

		if (errMsg.length > 0) {
			self.target.saveMsg = errMsg.join('');
			return;
		}

		var data = {
			name: self.target.edit_name,
			description: $('#channel-description').redactor('get')
		}

		$http.put([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid].join(''), data)
		.success(function(response, status) {
			self.target.name = response.name;
			self.target.description = response.description;

			self.changeLayout('content');
		});
	}

	self.deleteChannel = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				$location.path('/create/channel');
			}
			else
				self.target.saveMsg = response.error;
		});
	}

	self.loadCategory = function(category, lastItem) {
		if (category === null) {
			self.target.view = true;
			self.categoryPath = [];
			self.currentCategory = self.target;
			self.isRoot = true;
			return;
		}

		self.currentCategory = category;
		self.isRoot = false;

		if (lastItem) {
			category.view = true;
			self.target.view = false;
			self.categoryPath = [];
			self.categoryPath.push(category);
		}
		else {
			var path = [];
			for (var i=0;i<self.categoryPath.length;i++) {
				if (category.uqid !== self.categoryPath[i].uqid) {
					self.categoryPath[i].view = false;
					path.push(self.categoryPath[i]);
				}
				else
					i = self.categoryPath.length;
			}
			path.push(category);
			category.view = true;
			self.target.view = false;
			self.categoryPath = path;
		}

		$http.get([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories/', self.currentCategory.uqid].join(''))
		.success(function(response, status) {
			var priorities = [];
			for (var i=1;i<=response.max_category_priority;i++)
				priorities.push(i);

			angular.forEach(response.categories, function(item){
				item.priorities = priorities;
				item.parent = category;
				item.type = 'category';
			});

			priorities = [];
			for (var i=1;i<=response.max_knowledge_priority;i++)
				priorities.push(i);

			angular.forEach(response.knowledges, function(item){
				item.priorities = priorities;
			});

			self.currentCategory.categories = response.categories;
			self.currentCategory.knowledges = response.knowledges;
		});
	}

	self.addCategory = function() {
		var item = {};
		item.edit_name = '';
		item.edit_type = 'create';

		self.modifyTarget = item;
		self.changeLayout('category');
		$timeout(function() {self.initPictureEvent()},100);
	}

	self.editCategory = function(target) {
		if (!self.target.editable) return;
		
		var item = target;
		item.edit_name = item.name;
		item.edit_priority = Math.ceil(item.priority);
		item.edit_type = 'update';

		self.modifyTarget = item;
		self.changeLayout('category');
		$timeout(function() {self.initPictureEvent()},100);
	}

	self.saveCategory = function() {
		var errMsg = [];

		if (self.modifyTarget.edit_name === '')
			errMsg.push(translations[$utility.LANGUAGE.type]['H024']);//分類名稱不可為空白!

		if (errMsg.length > 0) {
			self.modifyTarget.saveMsg = errMsg.join('');
			return;
		}

		var data = {
			name: self.modifyTarget.edit_name,
			priority: self.modifyTarget.edit_priority,
			logo: self.modifyTarget.edit_logo,
			parent_uqid: self.currentCategory.uqid
		}

		if (self.modifyTarget.edit_type === 'create') {
			$http.post([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories'].join(''), data)
			.success(function(response, status) {
				if (!response.error) {
					if (self.currentCategory.type === 'channel')
						self.loadChannel();
					else
						self.loadCategory(self.currentCategory, false);

					self.changeLayout('content');
				}
				else
					self.modifyTarget.saveMsg = response.error;
			});
		}
		else if (self.modifyTarget.edit_type === 'update') {
			$http.put([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories/', self.modifyTarget.uqid].join(''), data)
			.success(function(response, status) {
				if (!response.error) {
					if (self.currentCategory.type === 'channel')
						self.loadChannel();
					else
						self.loadCategory(self.currentCategory, false);

					self.changeLayout('content');
				}
				else
					self.modifyTarget.saveMsg = response.error;
			});
		}
	}

	self.deleteCategory = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories/', self.modifyTarget.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				if (self.currentCategory.type === 'channel')
					self.loadChannel();
				else
					self.loadCategory(self.currentCategory, false);
				
				self.changeLayout('content');
			}
			else
				self.modifyTarget.saveMsg = response.error;
		});
	}

	self.addKnowledge = function() {
		var item = {};
		item.url = '';
		item.edit_type = 'create';

		self.modifyTarget = item;
		self.changeLayout('knowledge');
	}

	self.editKnowledge = function(item) {
		if (!self.target.editable) return;

		item.edit_url = item.url;
		item.edit_priority = Math.ceil(item.priority);
		item.edit_type = 'update';

		self.modifyTarget = item;
		self.changeLayout('knowledge');
	}

	self.saveKnowledge = function() {
		var errMsg = [];

		if (self.modifyTarget.edit_url === '')
			errMsg.push(translations[$utility.LANGUAGE.type]['H025']);//URL 連結不可為空白!

		if (errMsg.length > 0) {
			self.modifyTarget.saveMsg = errMsg.join('');
			return;
		}

		var data = {
			url: self.modifyTarget.edit_url,
			priority: self.modifyTarget.edit_priority
		}

		if (self.modifyTarget.edit_type === 'create') {
			$http.post([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories/', self.currentCategory.uqid, '/knowledges'].join(''), data)
			.success(function(response, status) {
				if (!response.error) {
					self.loadCategory(self.currentCategory, false);
					self.changeLayout('content');
				}
				else
					self.modifyTarget.saveMsg = response.error;
			});
		}
		else if (self.modifyTarget.edit_type === 'update') {
			$http.put([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories/', self.currentCategory.uqid, '/knowledges/', self.modifyTarget.uqid].join(''), data)
			.success(function(response, status) {
				if (!response.error) {
					self.loadCategory(self.currentCategory, false);
					self.changeLayout('content');
				}
				else
					self.modifyTarget.saveMsg = response.error;
			});
		}
	}

	self.deleteKnowledge = function() {
		$http.delete([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/categories/', self.currentCategory.uqid, '/knowledges/', self.modifyTarget.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.loadCategory(self.currentCategory, false);
				self.changeLayout('content');
			}
			else
				self.modifyTarget.saveMsg = response.error;
		});
	}

	self.loadMember = function(start_index) {
		self.member_start_index = start_index;
		self.filterRole = 'all';

		delete self.searchWord;

		$http.get([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/members?start-index=', start_index * 20].join(''))
		.success(function(response, status) {
			if (self.member_start_index === 0)
				self.members = response;
			else
				self.members = self.members.concat(response);

			if (response.length < 20)
				self.member_start_index = -1;
		});
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

					self.members.splice(end, 0, 
					self.members.splice(start, 1)[0]);

					$scope.$apply();
					
					var item = self.members[end];
					item.edit_order = end + 1;
					self.updateMember(item);
				}
			});
		}
		else {
			self.target.sortableMember = false;
			$('[member-list]').sortable('disable');
		}
	}

	self.editMember = function() {
		self.changeLayout('member');
		self.loadMember(0);
	}
	
	self.addMember = function(event) {
		if (event.keyCode !== 13) return;
		
		if (self.memberEmail !== undefined && self.memberEmail !== '') {
			$http.post([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/members'].join(''), { email: self.memberEmail })
			.success(function(response, status) {
				delete self.memberEmail;
				self.loadMember(0);
			});
		}
	}

	self.updateMember = function(target) {
		var data = {
			order: target.edit_order,
			role: target.edit_role,
			status: target.edit_status
		};

		$http.put([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/members/', target.uqid].join(''), data)
		.success(function(response, status) {
			angular.forEach(self.members, function(item) {
				if (item.uqid === target.uqid) {
					item.order = response.order;
					item.role = response.role;
					item.status = response.status;
				}
			});
		});
	}

	self.searchMember = function(event) {
		if (event.keyCode !== 13) return;

		self.filterRole = 'all';

		if (self.searchWord !== undefined && self.searchWord !== '') {
			$http.get([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/members?keyword=', self.searchWord].join(''))
			.success(function(response, status) {
				self.members = response;
			});
		}
		else
			self.clearMember();
	}

	self.filterMember = function(role, start_index) {
		self.member_start_index = start_index;
		self.filterRole = role;

		delete self.searchWord;

		if (role !== 'all') {
			$http.get([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/members?start-index=', start_index * 20, '&role=', role].join(''))
			.success(function(response, status) {
				if (self.member_start_index === 0)
					self.members = response;
				else
					self.members = self.members.concat(response);

				if (response.length < 20)
					self.member_start_index = -1;
			});
		}
		else
			self.loadMember(0);
	}

	self.clearMember = function() {
		delete self.searchWord;
		delete self.members;

		self.loadMember(0);
	}

	self.removeMember = function(target) {
		var data = { status: target.edit_status };

		$http.delete([$utility.SERVICE_URL, '/creation/channels/', self.target.uqid, '/members/', target.uqid].join(''))
		.success(function(response, status) {
			self.loadMember(0);
		});
	}

	self.init = function() {
		self.changeLayout('content');
		self.target = { uqid: $routeParams.t };
		self.loadChannel();
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})