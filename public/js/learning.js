_1know.controller('LearningCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
	var self = this;

	self.toggleCategory = function(category) {
		self.category_filter = category;
		self.loadKnowledge(0, category);
	}

	self.showCategoryModal = function(type) {
		self.category_type = type;

		if (type === 'update') {
			angular.forEach(self.categories, function(item) {
				if (item.uqid === self.category_filter) {
					self.category = item;
					self.categoryName = item.name;
				}
			});
		}
		else
			self.toggleCategory('all');

		$('#categoryModal').modal('show');
		$('#categoryModal').on('hidden.bs.modal', function() {
			delete self.errMsg;
			delete self.categoryName;
		});
	}

	self.listKnowledgeSize = function() {
		$http.get([$utility.SERVICE_URL, '/learning/knowledges'].join(''))
		.success(function(response, status) {
			self.knowledgeSize = response;
		});
	}

	self.listCategory = function() {
		$http.get([$utility.SERVICE_URL, '/learning/categories'].join(''))
		.success(function(response, status) {
			self.categories = response;
		});

		self.listKnowledgeSize();
	}

	self.saveCategory = function() {
		if (self.categoryName !== undefined && self.categoryName !== '') {
			if (self.category_type === 'create') {
				$http.post([$utility.SERVICE_URL, '/learning/categories'].join(''), {name: self.categoryName})
				.success(function(response, status) {
					if (!response.error) {
						self.listCategory();
						self.toggleCategory(self.category_filter);
						$('#categoryModal').modal('hide');
					}
					else
						self.errMsg = response.error;
				});
			}
			else if (self.category_type === 'update') {
				$http.put([$utility.SERVICE_URL, '/learning/categories/', self.category.uqid].join(''), {name: self.categoryName})
				.success(function(response, status) {
					if (!response.error) {
						self.listCategory();
						self.toggleCategory(self.category_filter);
						$('#categoryModal').modal('hide');
					}
					else
						self.errMsg = response.error;
				});
			}
		}
	}

	self.deleteCategory = function() {
		$http.delete([$utility.SERVICE_URL, '/learning/categories/', self.category.uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.listCategory();
				self.toggleCategory('all');
				$('#categoryModal').modal('hide');
			}
			else
				self.errMsg = response.error;
		});
	}

	self.setCategory = function(knowledge, category) {
		if ((category !== null && knowledge.category_name === category.name)
			|| (category === null && knowledge.category_name === '*****')) return;

		$http.put([$utility.SERVICE_URL, '/learning/', knowledge.uqid, '/category'].join(''), {itemUqid: category === null ? '' : category.uqid})
		.success(function(response, status) {
			if (!response.error) {
				self.listCategory();

				if (!response.success)
					knowledge.category_name = response.name;

				if (self.category_filter !== 'all')
					self.loadKnowledge(0, self.category_filter);
			}
		});
	}

	self.loadKnowledge = function(start_index, category) {
		delete self.knowledgeKeyWord;
		self.start_index = start_index;

		var service = "";
		if (category === 'all')
			service = [$utility.SERVICE_URL, '/learning?start-index=', start_index * 16, '&max-results=16&category=all'].join('');
		else {
			if (category !== 'last_7_day' && category !== 'new_order' && category !== 'unclassified')
				category = ['category_', category].join('');

			service = [$utility.SERVICE_URL, '/learning?max-results=999&category=', category].join('');
		}

		$http.get(service)
		.success(function(response, status) {
			if (category === 'all') {
				if (self.start_index === 0)
					self.knowledges = response;
				else
					self.knowledges = self.knowledges.concat(response);

				if (response.length < 16)
					self.start_index = -1;
			}
			else
				self.knowledges = response;

			angular.forEach(response, function(item, index) {
				item.last_view_time_desc = $utility.timeToDesc(item.last_view_time);
			});
		});
	}

	self.searchKnowledges = function(event) {
		if (event.keyCode !== 13) return;

		if (self.knowledgeKeyWord !== undefined && self.knowledgeKeyWord !== '') {
			$http.get([$utility.SERVICE_URL, '/learning?max-results=999&keyword=', self.knowledgeKeyWord].join(''))
			.success(function(response, status) {
				self.knowledges = response;

				angular.forEach(response, function(item, index) {
					item.last_view_time_desc = $utility.timeToDesc(item.last_view_time);
				});
			});
		}
		else {
			self.toggleCategory('last_7_day');
			delete self.knowledgeKeyWord;
		}
	}

	self.showSubscribeModal = function() {
		$('#subscribeModal').modal('show');
		$('#subscribeModal').on('hidden.bs.modal', function() {
			delete self.errMsg;
			if (self.knowledgeCode !== undefined) {
				$scope.$apply(function(){$location.path('/learn/knowledge/' + self.knowledgeCode.uqid)});
				delete self.knowledgeCode;
			}
		});
	}

	self.subscribe = function() {
		if (self.onSubscribe === undefined && self.knowledgeCode !== undefined && self.knowledgeCode !== '') {
			self.onSubscribe = true;

			$http.post([$utility.SERVICE_URL, '/learning/', self.knowledgeCode, '/subscribe'].join(''))
			.success(function(response, status) {
				if (!response.error) {
					self.knowledgeCode = response;
					$('#subscribeModal').modal('hide');
				}
				else
					self.errMsg = response.error;

				delete self.onSubscribe;
			});
		}
	}

	self.loadNoteKnowledge = function(fn) {
		$http.get([$utility.SERVICE_URL, '/learning?notes=true'].join(''))
		.success(function(response, status) {
			self.knowledges = response;
			if (fn !== undefined) fn();
		});
	}

	self.loadNotes = function(target) {
		delete self.noteKeyWord;
		delete self.notes;

		self.currentKnowledge = target;

		$http.get([$utility.SERVICE_URL, '/learning/', target.uqid, '/notes?type=all'].join(''))
		.success(function(response, status) {
			var unit = null, units = [], time = null;
			angular.forEach(response, function(item) {
				if (unit === null || item.unit.uqid !== unit.uqid) {
					time = {
						time: item.time,
						timeDesc: $utility.timeToFormat(item.time),
						content_url: item.unit.content_url,
						notes: [{
							author: item.author,
							color: item.color,
							content: item.content,
							privacy: item.privacy,
							type: item.type,
							uqid: item.uqid
						}]
					};

					unit = {
						k_uqid: item.know.uqid,
						uqid: item.unit.uqid,
						name: item.unit.name,
						unit_type: item.unit.unit_type,
						content_url: item.unit.content_url,
						times: []
					};

					unit.times.push(time);
					units.push(unit);
				}
				else {
					if (time.time !== item.time) {
						time = {
							time: item.time,
							timeDesc: $utility.timeToFormat(item.time),
							content_url: item.unit.content_url,
							notes: [{
								author: item.author,
								color: item.color,
								content: item.content,
								privacy: item.privacy,
								type: item.type,
								uqid: item.uqid
							}]
						};

						unit.times.push(time);
					}
					else {
						time.notes.push({
							author: item.author,
							color: item.color,
							content: item.content,
							privacy: item.privacy,
							type: item.type,
							uqid: item.uqid
						});
					}
				}
			});

			self.currentKnowledge.units = units;
		});
	}

	self.searchNotes = function(event) {
		if (event.keyCode !== 13) return;

		if (self.noteKeyWord !== undefined && self.noteKeyWord !== '') {
			$http.get([$utility.SERVICE_URL, '/learning/notes?type=all&keyword=', self.noteKeyWord].join(''))
			.success(function(response, status) {
				var unit = null, units = [], time = null;
				angular.forEach(response, function(item) {
					if (unit === null || item.unit.uqid !== unit.uqid) {
						time = {
							time: item.time,
							timeDesc: $utility.timeToFormat(item.time),
							content_url: item.unit.content_url,
							notes: [{
								author: item.author,
								color: item.color,
								content: item.content,
								privacy: item.privacy,
								type: item.type,
								uqid: item.uqid
							}]
						};

						unit = {
							k_uqid: item.know.uqid,
							k_name: item.know.name,
							uqid: item.unit.uqid,
							name: item.unit.name,
							unit_type: item.unit.unit_type,
							content_url: item.unit.content_url,
							times: []
						};

						unit.times.push(time);
						units.push(unit);
					}
					else {
						if (time.time !== item.time) {
							time = {
								time: item.time,
								timeDesc: $utility.timeToFormat(item.time),
								content_url: item.unit.content_url,
								notes: [{
									author: item.author,
									color: item.color,
									content: item.content,
									privacy: item.privacy,
									type: item.type,
									uqid: item.uqid
								}]
							};

							unit.times.push(time);
						}
						else {
							time.notes.push({
								author: item.author,
								color: item.color,
								content: item.content,
								privacy: item.privacy,
								type: item.type,
								uqid: item.uqid
							});
						}
					}
				});

				self.notes = units;
			});
		}
		else {
			delete self.noteKeyWord;
			delete self.notes;
		}
	}

	self.showDeleteNoteModal = function(item) {
		self.currentNote = item;
		$('#deleteNoteModal').modal('show');
	}

	self.deleteNote = function() {
		$http.delete([$utility.SERVICE_URL, '/learning/notes/', self.currentNote.uqid].join(''))
		.success(function(response, status) {
			self.loadNotes(self.currentKnowledge);
			delete self.currentNote;
			$('#deleteNoteModal').modal('hide');
		});
	}

	self.changeNotePrivacy = function(item) {
		$http.put([$utility.SERVICE_URL, '/learning/notes/', item.uqid].join(''), { privacy: !item.privacy })
		.success(function(response, status) {
			if (response.error) {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
			else {
				item.privacy = response.privacy
			}
		});
	}

	self.changeNoteColor = function(item) {
		$http.put([$utility.SERVICE_URL, '/learning/notes/', item.uqid].join(''), { color: item.color })
		.success(function(response, status) {});
	}

	self.exportNotes = function() {
		window.open([$utility.SERVICE_URL, '/learning/', self.currentKnowledge.uqid, '/exportNotes'].join(''), '_blank');
	}

	self.importNotes = function() {
		if (!self.initImportEvent)
			self.setImportEvent();

		$('#import_notes').click();
	}

	self.setImportEvent = function() {
		self.initImportEvent = true;

		var inputFile = document.getElementById('import_notes');
		inputFile.addEventListener('click', function() {this.value = null;}, false);
		inputFile.addEventListener('change', readData, false);

		function readData(evt) {
			evt.stopPropagation();
			evt.preventDefault();
			var file = evt.dataTransfer !== undefined ? evt.dataTransfer.files[0] : evt.target.files[0];
			var reader = new FileReader();
			reader.onload = function(e) {
				var notes = e.target.result.split("\n");
				var count = 0;
				angular.forEach(notes, function(item) {
					var temp = item.split("||");
					if (temp.length >= 5) {
						var data = {
							time: temp[3] || 0,
							content: temp[4] || '',
							type: temp[2] || 'text'
						};

						$http.post([$utility.SERVICE_URL, '/learning/units/', temp[1], '/notes'].join(''), data)
						.success(function(response, status) {
							count += 1;

							if (count === notes.length) {
								self.loadNoteKnowledge(function() {
									angular.forEach(self.knowledges, function(item) {
										if (item.uqid === temp[0])
											self.loadNotes(item);
									});
								});
							}
						})
						.error(function(response, status) {
							count += 1;

							if (count === notes.length) {
								self.loadNoteKnowledge(function() {
									angular.forEach(self.knowledges, function(item) {
										if (item.uqid === temp[0])
											self.loadNotes(item);
									});
								});
							}
						});
					}
				});
			}
			reader.readAsText(file);
		}
	}

	self.openNodeVideo = function(target) {
		var videoPath = target.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
		var content = '';
		if (videoPath !== null && videoPath.length === 6) {
			if (videoPath[2] === 'youtube') {
				var startTime = ['&start=', target.time].join('');
				content = ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '?autoplay=1&autohide=1&rel=0&showinfo=0&theme=light', startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
				self.currentKnowledge.video_content = content;
			}
			else if (videoPath[2] === 'vimeo') {
				var startTime = ['#t=', target.time].join('');
				content = ['<iframe src="https://player.vimeo.com/video/', videoPath[3], startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
				self.currentKnowledge.video_content = content;
			}
			else if (videoPath[2] === 'youku') {
				// by elvira chen at 2015/9/7
				// content = ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
				content = '<div id="noteVideoPlayer" style="width:100%;height:100%"></div>';
				self.currentKnowledge.video_content = content;
				$timeout(function() {
					var player = new YKU.Player('noteVideoPlayer',{
	                    client_id: 'c865b5756563acee',
	                    vid: videoPath[4],
	                    width: '100%',
	                    height: '100%',
	                    autoplay: true,
	                    events:{
	                        onPlayStart: function() {
	                            player.seekTo(target.time);
	                        }
	                    }
	                });
	            }, 1000);
			}
		}
		else {
			var videoId = Date.now();
			self.currentKnowledge.video_content =
				['<video id="video-', videoId,'"',
					' src="', target.content_url, (target.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
					' width="100%" height="100%"',
					' class="video-js vjs-default-skin vjs-big-play-centered">',
				'</video>'].join('');

			$timeout(function() {
				videojs(['video-', videoId].join(''), {controls: true, preload: 'auto'}, function() {
					this.currentTime(target.time);
				});
			},100);
		}

		$('#noteVideoModal').modal('show');
		$('#noteVideoModal').on('hidden.bs.modal', function (e) {
			$scope.$apply(function() {
				delete self.currentKnowledge.video_content;
			});
		});
	}

	self.openKnowledge = function(target) {
		$location.path('/learn/knowledge/' + target.uqid);
	}

	self.init = function() {
		if ($routeParams.t !== undefined) {
			self.target = $routeParams.t;

			if ($routeParams.t === 'knowledge') {
				self.listCategory();
				//self.toggleCategory('last_7_day');
				self.toggleCategory('all');
			}
			else if ($routeParams.t === 'notebook') {
				self.loadNoteKnowledge(function() {
					if (self.knowledges.length > 0)
						self.loadNotes(self.knowledges[0]);
				});
			}
			else
				$location.path('/learn/knowledge');
		}
		else
			$location.path('/learn/knowledge');
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})
