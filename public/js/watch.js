_1know.controller('WatchCtrl', function($scope, $http, $location, $timeout, $compile, $routeParams, $utility, $interval, $window) {
	var self = this;

	self.web_name = $window.web_name;
	self.logo = $window.logo;
	self.copyright = $window.copyright;
	self.service_email = $window.service_email;

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

	self.showGroupModal = function(item) {
		angular.forEach(self.groups, function(item) {
			item.share = false;
		});
		self.shareNote = item;
		self.shareNote.share_content = item.content;

		$('#groupModal').modal('show');
	}

	self.listGroup = function() {
		$http.get([$utility.SERVICE_URL, '/learning/groups'].join(''))
		.success(function(response, status) {
			self.groups = response;
		});
	}

	self.selectShareGroup = function() {
		angular.forEach(self.groups, function(item) {
			item.share = self.shareAll;
		});
	}

	self.shareNoteToGroup = function() {
		angular.forEach(self.groups, function(item) {
			if (item.share) {
				var data = {
					unitUqid: self.currentUnit.uqid,
					noteTime: self.shareNote.time,
					content: ['<div style="word-break:break-all;margin-bottom:10px">', self.shareNote.type === 'text' ? self.shareNote.share_content.replace(/\r\n|\r|\n/g, '<br/>') : (self.shareNote.type === 'image' ? ['<img src="', self.shareNote.content.screenshot, '" style="width:320px"/>'].join('') : ''), '</div>'].join('')
				};

				$http.post([$utility.SERVICE_URL, '/join/', item.uqid, '/messages'].join(''), data)
				.success(function(response, status) {
					var socket = new PUBNUB.ws([
						'wss://pubsub.pubnub.com',
						'/pub-c-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
						'/sub-c-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
						'/1know-group-', item.uqid].join(''));

					socket.onopen = function() {
						socket.send({
							poster: $utility.account.uqid,
							type: 'wall-message-changed'
						})
					}
				});
			}
		});

		$('#groupModal').modal('hide');
	}

	self.showSubscriberModal = function() {
		$('#subscriberModal').modal('show');
	}

	self.listSubscriber = function() {
		$http.get([$utility.SERVICE_URL, '/learning/', self.target.uqid, '/subscribers'].join(''))
		.success(function(response, status) {
			self.subscribers = response;
		});
	}

	self.addSubscriber = function() {
		if (event.keyCode !== 13) return;

		if (self.subscriberEmail !== undefined && self.subscriberEmail !== '') {
			$http.post([$utility.SERVICE_URL, '/learning/', self.target.uqid, '/subscribers'].join(''), { email: self.subscriberEmail })
			.success(function(response, status) {
				delete self.subscriberEmail;
				self.listSubscriber();
			});
		}
	}

	self.removeSubscriber = function() {
		$http.delete([$utility.SERVICE_URL, '/learning/', self.target.uqid, '/subscribers/', self.currentSubscriber.uqid].join(''))
		.success(function(response, status) {
			self.listSubscriber();
			self.currentSubscriber.deleteAlert = false;
		});
	}

	self.toggleNotePosition = function(position) {
		self.notePosition = position;

		if (self.notePosition === 'right') {
			self.leftContentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;

			if (self.showUnitDesc)
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 352;
			else
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 112;
		}
		else if (self.notePosition === 'bottom') {
			self.leftContentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 98;

			if (self.showUnitDesc)
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 278;
			else
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;
		}
	}

	self.toggleUnitDesc = function() {
		self.showUnitDesc = !self.showUnitDesc;

		if (self.notePosition === 'right') {
			if (self.showUnitDesc)
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 352;
			else
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 112;
		}
		else if (self.notePosition === 'bottom') {
			if (self.showUnitDesc)
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 278;
			else
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;
		}
	}

	self.toggleMaximum = function() {
		self.maximum = !self.maximum;
		self.changeSize();
	}

	self.changeLayout = function(target) {
		self.layout = target;

		if (target === 'knowledge') {
			self.queryStudyHistory(30);
			self.stopPromise();

			if (self.contentType === 'knowledge') {
				$http.get([$utility.SERVICE_URL, '/learning/', $routeParams.t, '/units'].join(''))
				.success(function(response, status) {
					self.parseUnits(response);
				});
			}
			else if (self.contentType === 'activity') {
				$http.get([$utility.SERVICE_URL, '/learning/activities/', $routeParams.t, '/units'].join(''))
				.success(function(response, status) {
					self.parseUnits(response);
				});
			}

			$scope.mainCtrl.toggleVisible(true);
		}
		else if (target === 'learning') {
			self.chooseUnit(self.currentUnit);

			$scope.mainCtrl.toggleVisible(false);
		}

		window.scrollTo(0, 0);
	};

	self.changeSize = function() {
		if (self.maximum) {
			self.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
			self.contentWidth = self.contentWidth < 880 ? 880 : self.contentWidth;
		}
		else {
			self.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth) - 280;
			self.contentWidth = self.contentWidth < 600 ? 600 : self.contentWidth;
		}

		if (self.notePosition === 'right')
			self.leftContentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;
		else if (self.notePosition === 'bottom')
			self.leftContentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 98;

		self.rightContentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;

		self.noteWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
		self.noteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;

		if (self.currentUnit.unit_type === 'draw') {
			$('#draw-board canvas').attr({ 'width': self.contentWidth, 'height': self.contentHeight});
			$('#draw-board canvas').css({ 'width': self.contentWidth, 'height': self.contentHeight});
			if ($('#draw-board').literallyCanvasInstance() !== undefined)
				$('#draw-board').literallyCanvasInstance().repaint();
		}

		if ($('#note-board canvas').length === 1) {
			$('#note-board canvas').attr({ 'width': self.noteWidth, 'height': self.noteHeight});
			$('#note-board canvas').css({ 'width': self.noteWidth, 'height': self.noteHeight});
			if ($('#note-board').literallyCanvasInstance() !== undefined)
				$('#note-board').literallyCanvasInstance().repaint();
		}

		if (self.notePosition === 'right') {
			if (self.showUnitDesc)
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 352;
			else
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 112;
		}
		else if (self.notePosition === 'bottom') {
			if (self.showUnitDesc)
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 278;
			else
				self.textNoteHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;
		}
	}

	window.onresize = function() {
		$scope.$apply(function() {
			self.changeSize();
		});
	}

	self.viewImageNote = function(item) {
		self.openNoteBoard(function() {
			$('#note-save').detach();

			self.noteBoard.type = 'update';
			self.currentNote = item;

			if (self.currentUnit.unit_type === 'video') {
				self.videoSeekTo(item);
				self.videoPause();
			}

			var lc = self.noteBoard.lc;
			lc.shapes = [];
			lc.addShapes(item.content.strokes);
		});
	}

	self.openNoteBoard = function(fn) {
		self.noteBoard.show = !self.noteBoard.show;

		if (self.noteBoard.show) {
			self.onDrawNoteBoard();

			$timeout(function() {
				$('#note-board').html('<canvas></canvas>');
				$('#note-board').literallycanvas({
					imageURLPrefix: '/library/literallycanvas/img',
					backgroundColor: 'rgba(0, 0, 0, 0.1)',
					primaryColor: '#f00'
				});

				$('.colorpicker.alpha').css('z-index', '1280');

				$('#note-board .custom-button').before(
					['<div class="btn-group" style="margin:-4px 4px 0">',
						'<div id="note-close" class="btn btn-xs btn-danger">',
							'<span translate="E043"></span>',
						'</div>',
						'<div id="note-save" class="btn btn-xs btn-primary">',
							'<span translate="E044"></span>',
						'</div>',
					'</div>',
					'<div class="btn-group" style="margin:-4px 4px 0">',
						'<div id="note-replay-high" class="btn btn-xs btn-primary">',
							'<span translate="E045"></span>',
						'</div>',
						'<div id="note-replay-normal" class="btn btn-xs btn-primary">',
							'<span translate="E046"></span>',
						'</div>',
					'</div>'].join(''));

				var lc = $('#note-board').literallyCanvasInstance();
				self.noteBoard.lc = lc;

				$('#note-close').click(function() {
					$timeout(function() {
						self.openNoteBoard();
					},100);
				});

				$('#note-save').click(function() {
					self.saveImageNote(function() {
						if (self.currentUnit.unit_type === 'video')
							self.videoPlay();
						self.noteBoard.show = false;

						$('#note-board').html('');
						self.loadNote();
					});
				});

				$('#note-replay-high').click(function() {
					lc.terminal = true;
					lc.playStrokes(100);
				});

				$('#note-replay-normal').click(function() {
					lc.terminal = true;
					lc.playStrokes(1);
				});

				$compile(document.getElementById('literally-toolbar'))($scope);

				if (fn) fn();
			},100);
		}
		else
			self.videoPlay();
	}

	self.onDrawNoteBoard = function() {
		self.noteBoard.type = 'new';

		if (self.currentUnit.unit_type === 'video') {
			if (self.currentUnit.currentTime === undefined) {
				if (self.videoPlayer.type === 'youku')
					self.currentUnit.currentTime = Math.ceil(self.videoPlayer.target.currentTime());
				else if (self.videoPlayer.type === 'videojs')
					self.currentUnit.currentTime = Math.ceil(self.videoPlayer.target.currentTime());
			}

			self.videoPause();
		}
	}

	self.unsubscribe = function() {
		$http.delete([$utility.SERVICE_URL, '/learning/', self.target.uqid, '/unsubscribe'].join(''))
		.success(function(response, status) {
			if (!response.error) {
				$location.path('/learn/knowledge');
			}
		});
	}

	self.rateKnowledge = function(rating) {
		$http.put([$utility.SERVICE_URL, '/learning/', self.target.uqid, '/rating'].join(''), { rating: rating })
		.success(function(response, status) {
			self.target.rating = response.rating;
		});
	}

	self.joinGroup = function(target) {
		$http.post([$utility.SERVICE_URL, '/join/', target.uqid, '/knowledges'].join(''), { knowUqid: self.target.uqid })
		.success(function(response, status) {
			if (!response.error) {
				$location.path('/join/group/' + target.uqid);
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

	self.queryStudyHistory = function(days) {
		self.target.days = days;

		$http.get([$utility.SERVICE_URL, '/learning/', self.contentType, '/', self.target.uqid, '/history?days=', days, '&timezone=', -1 * (new Date()).getTimezoneOffset() / 60].join(''))
		.success(function(response, status) {
			var series = [];
			angular.forEach(response.rows, function(row, i) {
				var datas = [];
				angular.forEach(response.dates, function(data, j) {
					datas.push(Math.ceil(row[data]));
				});

				series.push({
					name: self.target.name,
					data: datas
				});

				self.target.activity = response;
			});

			$timeout(function() {
				$(['#chart_', self.target.uqid].join('')).highcharts({
					credits: { enabled: false },
					title: { text: '' },
					chart: { type: 'line' },
					xAxis: {
						categories: response.dates,
						labels: { enabled: false }
					},
					yAxis: {
						min: 0,
						title: {
							text: translations[$utility.LANGUAGE.type]['E012']//花費時間 (分)
						},
						plotLines: [{
							value: 0,
							width: 1,
							color: '#808080'
						}]
					},
					legend: { enabled: false },
					series: series
				});
			},100);
		});
	}

	self.loadNote = function() {
		$http.get([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/notes?type=all'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.timeCeil = Math.ceil(item.time);
				item.timeDesc = $utility.timeToFormat(item.time);
				if (item.type === 'text')
					item.htmlContent = item.content.replace(/\r\n|\r|\n/g, '<br/>');
			});

			self.currentUnit.notes = response;
		});
	}

	self.editNote = function(item) {
		if (item.type === 'text') {
			self.editTextNote(item);
		}
		else if (item.type === 'image') {
			self.openNoteBoard(function() {
				self.editImageNote(item);
			});
		}
	}

	self.showDeleteNoteModal = function(item) {
		self.currentNote = item;
		$('#deleteNoteModal').modal('show');
	}

	self.deleteNote = function() {
		if (self.currentNote.type === 'text')
			self.deleteTextNote();
		else if (self.currentNote.type === 'image')
			self.deleteImageNote();
	}

	self.onAddTextNote = function(event) {
		if (self.currentUnit.currentTime === undefined) {
			if (self.currentUnit.unit_type === 'video') {
				if (self.videoPlayer.type === 'youku')
					self.currentUnit.currentTime = Math.ceil(self.videoPlayer.target.currentTime());
				else if (self.videoPlayer.type === 'videojs')
					self.currentUnit.currentTime = Math.ceil(self.videoPlayer.target.currentTime());
			}
		}

		if (event.keyCode === 13 && event.shiftKey === false) {
			self.addTextNote();
			if (self.currentUnit.unit_type === 'video') self.videoPlay();
		}
		else
			if (self.currentUnit.unit_type === 'video') self.videoPause();
	}

	self.addTextNote = function() {
		if (self.currentUnit.newNote !== undefined && self.currentUnit.newNote !== '') {

			var data = {
				time: self.currentUnit.currentTime,
				content: self.currentUnit.newNote,
				type: 'text'
			};

			$http.post([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/notes'].join(''), data)
			.success(function(response, status) {
				if (response.error) {
					self.errMessage = response.error;
					$('#errorMessageModal').modal('show');
					$('#errorMessageModal').on('hidden.bs.modal', function() {
						delete self.errMessage;
					});
				}
				else {
					delete self.currentUnit.newNote;
					delete self.currentUnit.currentTime;

					self.loadNote();
				}
			});
		}
	}

	self.editTextNote = function(item) {
		if (self.currentUnit.unit_type === 'video')
			self.videoPause();

		item.edit_time = item.time;
		item.edit_content = item.content;
		item.edit_time_desc = item.timeDesc;
		self.currentNote = item;

		$('#textNoteModal').modal('show');
		$('#textNoteModal').on('hidden.bs.modal', function() {
			if (self.currentUnit.unit_type === 'video')
				self.videoPlay();
		});
	}

	self.changeNoteVideoTime = function() {
		self.currentNote.edit_time_desc = $utility.timeToFormat(self.currentNote.edit_time);
	}

	self.updateTextNote = function() {
		var data = {
			content: self.currentNote.edit_content,
			time: self.currentNote.edit_time
		};

		$http.put([$utility.SERVICE_URL, '/learning/notes/', self.currentNote.uqid].join(''), data)
		.success(function(response, status) {
			if (response.error) {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
			else {
				// self.currentNote.content = response.content;
				// self.currentNote.htmlContent = response.content.replace(/\r\n|\r|\n/g, '<br/>');
				self.loadNote();
				$('#textNoteModal').modal('hide');
			}
		});
	}

	self.deleteTextNote = function() {
		$http.delete([$utility.SERVICE_URL, '/learning/notes/', self.currentNote.uqid].join(''))
		.success(function(response, status) {
			self.loadNote();
			delete self.currentNote;
			$('#deleteNoteModal').modal('hide');
		});
	}

	self.editImageNote = function(item) {
		self.noteBoard.type = 'update';
		self.currentNote = item;

		if (self.currentUnit.unit_type === 'video') {
			self.videoSeekTo(item);
			self.videoPause();
		}

		var lc = self.noteBoard.lc;
		lc.shapes = [];
		lc.addShapes(item.content.strokes);
	}

	self.saveImageNote = function(fn) {
		var shapes = $('#note-board').literallyCanvasInstance().shapes;
		var screenshot = $('#note-board').canvasForExport().toDataURL("image/png");
		var strokes = [];

		angular.forEach(shapes, function(shape) {
			var stroke = {};
			if (shape instanceof LC.EraseLinePathShape) {
				stroke.type = 'EraseLinePathShape';
				stroke.color = shape.points[0].color;
				stroke.size = shape.points[0].size;
				stroke.points = [];

				angular.forEach(shape.points, function(point){
					stroke.points.push({
						time: point.time,
						x: point.x,
						y: point.y
					});
				});
			}
			else if (shape instanceof LC.LinePathShape) {
				stroke.type = 'LinePathShape';
				stroke.color = shape.points[0].color;
				stroke.size = shape.points[0].size;
				stroke.points = [];

				angular.forEach(shape.points, function(point){
					stroke.points.push({
						time: point.time,
						x: point.x,
						y: point.y
					});
				});
			}
			else if (shape instanceof LC.Line) {
				stroke.type = 'Line';
				stroke.color = shape.color;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x1 = shape.x1;
				stroke.x2 = shape.x2;
				stroke.y1 = shape.y1;
				stroke.y2 = shape.y2;
			}
			else if (shape instanceof LC.Rectangle) {
				stroke.type = 'Rectangle';
				stroke.fillColor = shape.fillColor;
				stroke.strokeColor = shape.strokeColor;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x = shape.x;
				stroke.y = shape.x;
				stroke.width = shape.width;
				stroke.height = shape.height;
			}
			else if (shape instanceof LC.Circle) {
				stroke.type = 'Circle';
				stroke.fillColor = shape.fillColor;
				stroke.strokeColor = shape.strokeColor;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x = shape.x;
				stroke.y = shape.y;
				stroke.radius = shape.radius;
			}
			else if (shape instanceof LC.Oval) {
				stroke.type = 'Oval';
				stroke.fillColor = shape.fillColor;
				stroke.strokeColor = shape.strokeColor;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x = shape.x;
				stroke.y = shape.y;
				stroke.radiusX = shape.radiusX;
				stroke.radiusY = shape.radiusY;
			}

			strokes.push(stroke);
		});

		var data = {
			time: self.currentUnit.currentTime,
			content: JSON.stringify({
				strokes: strokes,
				screenshot: screenshot,
				screenSize: {
					width: (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth),
					height: (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight)
				}
			}),
			type: 'image'
		};

		if (self.noteBoard.type === 'new') {
			$http.post([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/notes'].join(''), data)
			.success(function(response, status) {
				if (response.error) {
					self.errMessage = response.error;
					$('#errorMessageModal').modal('show');
					$('#errorMessageModal').on('hidden.bs.modal', function() {
						delete self.errMessage;
					});
				}
				else
					fn();
			});
		}
		else if (self.noteBoard.type === 'update') {
			$http.put([$utility.SERVICE_URL, '/learning/notes/', self.currentNote.uqid].join(''), data)
			.success(function(response, status) {
				if (response.error) {
					self.errMessage = response.error;
					$('#errorMessageModal').modal('show');
					$('#errorMessageModal').on('hidden.bs.modal', function() {
						delete self.errMessage;
					});
				}
				else
					fn();
			});
		}
	}

	self.deleteImageNote = function() {
		$http.delete([$utility.SERVICE_URL, '/learning/notes/', self.currentNote.uqid].join(''))
		.success(function(response, status) {
			// self.noteBoard.lc.shapes = [];
			// self.noteBoard.lc.repaint();
			// self.noteBoard.type = 'new';
			self.loadNote();
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

	self.checkQuizSolution = function() {
		var quiz = self.currentUnit.currentQuiz;

		if (quiz.quiz_type === 'multi') {
			angular.forEach(quiz.options, function(option) {
				if (option.answer !== undefined && option.answer === true) {
					quiz.correct += parseInt(option.value, 10);
				}
			});

			if (parseInt(quiz.answer, 10) === parseInt(quiz.correct, 10)) {
				quiz.correct = true;
			}
			else
				quiz.correct = false;
		}
		else {
			if (parseInt(quiz.answer, 10) === parseInt(quiz.single, 10)) {
				quiz.correct = true;
			}
			else
				quiz.correct = false;
		}

		self.currentUnit.currentQuiz.isCheck = true;
	}

	self.continueLearning = function() {
		self.videoPlay();
		delete self.currentUnit.currentQuiz.isCheck;
		delete self.currentUnit.currentQuiz;
		$('#videoQuizModal').modal('hide');
	}

	self.showQuizSolution = function() {
		self.currentUnit.showQuizSolution = true;
	}

	self.sendQuizResult = function() {
		self.currentUnit.sendQuizResult = true;

		var quizzes = self.currentUnit.quizzes;
		var correct_count = 0, correct = [], answer = [], result = [];

		angular.forEach(quizzes, function(quiz) {
			quiz.correct = 0, correct = [], answer = [];
			if (quiz.quiz_type === 'multi') {
				angular.forEach(quiz.options, function(option) {
					if (option.answer !== undefined && option.answer === true) {
						quiz.correct += parseInt(option.value, 10);
						answer.push(parseInt(option.value, 10));
					}
					if (option.correct)
						correct.push(parseInt(option.value, 10));
				});

				if (parseInt(quiz.answer, 10) === parseInt(quiz.correct, 10)) {
					quiz.correct = true;
					correct_count += 1;
				}
				else
					quiz.correct = false;
			}
			else {
				answer.push(parseInt(quiz.single, 10));
				correct.push(parseInt(quiz.answer, 10));

				if (parseInt(quiz.answer, 10) === parseInt(quiz.single, 10)) {
					quiz.correct = true;
					correct_count += 1;
				}
				else
					quiz.correct = false;
			}

			result.push({
				uqid: quiz.uqid,
				correct: correct,
				answer: answer
			});
		});

		var data = {
			unit_type: 'quiz',
			result: result
		};

		$http.put([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/studyResult'].join(''), { content: JSON.stringify(data) })
		.success(function(response, status) {
			if (correct_count === quizzes.length) {
				self.currentUnit.completed = true;
				self.setUnitStatus();
			}
		});
	}

	self.sendPollResult = function() {
		var unit = self.currentUnit;
		var result = [];

		angular.forEach(unit.content.options, function(option) {
			if (option.answer !== undefined && option.answer === true) {
				result.push(parseInt(option.value, 10));
			}
		});

		var data = {
			unit_type: unit.unit_type,
			result: result
		};

		$http.put([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/studyResult'].join(''), { content: JSON.stringify(data) })
		.success(function(response, status) {
			self.currentUnit.completed = true;
			self.setUnitStatus();

			$('#poll-submit').html(translations[$utility.LANGUAGE.type]['E013']);//已儲存
		});
	}

	self.sendQAResult = function() {
		var unit = self.currentUnit;

		var data = {
			unit_type: unit.unit_type,
			result: $("#qa-result").redactor('get')
		};

		$http.put([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/studyResult'].join(''), { content: JSON.stringify(data) })
		.success(function(response, status) {
			if (self.currentUnit.study_result === null || self.currentUnit.study_result === undefined) {
				self.currentUnit.study_result = {
					result: response.content.result
				}
			}
			else
				self.currentUnit.study_result.result = response.content.result;

			self.currentUnit.completed = true;
			self.setUnitStatus();

			$('#qa-submit').html(translations[$utility.LANGUAGE.type]['E013']);//已儲存
		});
	}

	self.sendDrawResult = function() {
		var shapes = $('#draw-board').literallyCanvasInstance().shapes;
		var screenshot = $('#draw-board').canvasForExport().toDataURL("image/png");
		var strokes = [];

		angular.forEach(shapes, function(shape) {
			var stroke = {};
			if (shape instanceof LC.EraseLinePathShape) {
				stroke.type = 'EraseLinePathShape';
				stroke.color = shape.points[0].color;
				stroke.size = shape.points[0].size;
				stroke.points = [];

				angular.forEach(shape.points, function(point){
					stroke.points.push({
						time: point.time,
						x: point.x,
						y: point.y
					});
				});
			}
			else if (shape instanceof LC.LinePathShape) {
				stroke.type = 'LinePathShape';
				stroke.color = shape.points[0].color;
				stroke.size = shape.points[0].size;
				stroke.points = [];

				angular.forEach(shape.points, function(point){
					stroke.points.push({
						time: point.time,
						x: point.x,
						y: point.y
					});
				});
			}
			else if (shape instanceof LC.Line) {
				stroke.type = 'Line';
				stroke.color = shape.color;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x1 = shape.x1;
				stroke.x2 = shape.x2;
				stroke.y1 = shape.y1;
				stroke.y2 = shape.y2;
			}
			else if (shape instanceof LC.Rectangle) {
				stroke.type = 'Rectangle';
				stroke.fillColor = shape.fillColor;
				stroke.strokeColor = shape.strokeColor;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x = shape.x;
				stroke.y = shape.y;
				stroke.width = shape.width;
				stroke.height = shape.height;
			}
			else if (shape instanceof LC.Circle) {
				stroke.type = 'Circle';
				stroke.fillColor = shape.fillColor;
				stroke.strokeColor = shape.strokeColor;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x = shape.x;
				stroke.y = shape.y;
				stroke.radius = shape.radius;
			}
			else if (shape instanceof LC.Oval) {
				stroke.type = 'Oval';
				stroke.fillColor = shape.fillColor;
				stroke.strokeColor = shape.strokeColor;
				stroke.strokeWidth = shape.strokeWidth;
				stroke.x = shape.x;
				stroke.y = shape.y;
				stroke.radiusX = shape.radiusX;
				stroke.radiusY = shape.radiusY;
			}

			strokes.push(stroke);
		});

		var unit = self.currentUnit;
		var data = {
			unit_type: unit.unit_type,
			result: {
				strokes: strokes,
				screenshot: screenshot,
				screenSize: {
					width: (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth),
					height: (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight)
				}
			}
		};

		$http.put([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/studyResult'].join(''), { content: JSON.stringify(data) })
		.success(function(response, status) {
			self.currentUnit.study_result = response.content;
			self.currentUnit.learning_time = response.learning_time;

			self.currentUnit.completed = true;
			self.setUnitStatus();

			$('#draw-submit').html(translations[$utility.LANGUAGE.type]['E013']);//已儲存
		});
	}

	self.openNote = function(item) {
		if (item.type === 'text')
			self.videoSeekTo(item);
		else if (item.type === 'image')
			self.viewImageNote(item);
	}

	self.seekBack30Sec = function() {
		if (self.videoPlayer.type === 'youku') {
			var time = self.videoPlayer.target.currentTime() - 30;
			self.videoPlayer.target.seekTo(time);
			self.videoOnPause(self.videoPlayer);
		}
		else if (self.videoPlayer.type === 'videojs') {
			var time = self.videoPlayer.target.currentTime() - 30;
			self.videoPlayer.target.currentTime(time);
		}
	}

	self.videoSeekTo = function(item) {
		if (self.videoPlayer.type === 'youku') {
			if (self.youkuStart) {
				self.videoPlayer.target.seekTo(item.time);
				self.videoOnPause(self.videoPlayer);
			}
			else {
				var checkReady = $interval(function() {
					if (self.youkuReady) {
						$timeout(function() {
							self.videoPlayer.target.playVideo();
							$interval.cancel(checkReady);
						}, 500);
					}
				}, 500);
				var checkStart = $interval(function() {
					if (self.youkuStart) {
						self.videoPlayer.target.seekTo(item.time);
						self.currentUnit.currentTime = self.videoPlayer.target.currentTime();
						$interval.cancel(checkStart);
					}
				}, 100);
			}
		}
		else if (self.videoPlayer.type === 'videojs') {
			self.videoPlayer.target.currentTime(item.time);
		}
	}

	self.videoPlay = function() {
		if (self.videoPlayer.type === 'youku') {
			self.videoPlayer.target.playVideo();
		}
		else if (self.videoPlayer.type === 'videojs') {
			self.videoPlayer.target.play();
		}
	}

	self.videoOnPlaying = function() {
		self.currentUnit.onPause = false;
		self.currentUnit.seconds_started = Date.now();

		self.stopPromise();

		if (self.videoPlayer.startTime !== undefined) {
			if (self.videoPlayer.type === 'vimeo')
				self.videoPlayer.target.api('seekTo', self.videoPlayer.startTime);
			else if (self.videoPlayer.type === 'videojs')
				self.videoPlayer.target.currentTime(self.videoPlayer.startTime);

			delete self.videoPlayer.startTime;
		}

		self.showStudyProgress();
		self.sendStudyHistoryProgress();
	}

	self.videoPause = function() {
		if (self.videoPlayer.type === 'youku') {
			self.videoPlayer.target.pauseVideo();
			self.videoOnPause();
		}
		else if (self.videoPlayer.type === 'videojs') {
			self.videoPlayer.target.pause();
		}
	}

	self.videoOnPause = function() {
		if (!self.currentUnit.onPause) {
			self.currentUnit.onPause = true;

			if (self.videoPlayer.type === 'youku')
				self.currentUnit.currentTime = self.videoPlayer.target.currentTime();
			else if (self.videoPlayer.type === 'videojs')
				self.currentUnit.currentTime = self.videoPlayer.target.currentTime();

			self.sendStudyHistory();
		}
	}

	self.videoOnEnding = function() {
		self.currentUnit.completed = true;
		self.setUnitStatus(true);
	}

	self.sendStudyHistory = function() {
		var timeStamp = Date.now();
		var seconds_watched = (timeStamp - self.currentUnit.seconds_started) / 1000;
		var last_second_watched = (self.currentUnit.unit_type === 'video')
			? Math.round(self.currentUnit.currentTime * 1000) / 1000
			: self.currentUnit.gained_time;

		var data = {
			seconds_watched: seconds_watched || 0,
			last_second_watched: last_second_watched
		};

		$http.post([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/studyHistory'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				self.currentUnit.seconds_started = timeStamp;
				self.currentUnit.last_second_watched = response.vh.last_second_watched;
				self.currentUnit.status = response.us.status;

				self.online = true;
			}
			else
				self.online = false;
		})
		.error(function(response, status) {
			self.online = false;
		})
	}

	self.sendStudyHistoryProgress = function() {
		self.promise1 = $timeout(function() {
			if (!self.currentUnit.onPause && self.layout === 'learning' &&
				(($location.path() === ['/learn/knowledge/', self.target.uqid].join('')) ||
				($location.path() === ['/learn/activity/', self.target.uqid].join('')))) {

				if (self.currentUnit.unit_type === 'video') {
					if (self.videoPlayer.type === 'youku')
						self.currentUnit.currentTime = self.videoPlayer.target.currentTime();
					else if (self.videoPlayer.type === 'videojs')
						self.currentUnit.currentTime = self.videoPlayer.target.currentTime();
				}

				self.sendStudyHistory();
			}

			self.sendStudyHistoryProgress();
		}, 20000);
	}

	self.showStudyProgress = function() {
		self.promise2 = $timeout(function() {
			if (self.currentUnit.unit_type === 'video')
				self.currentUnit.playTime = [self.currentUnit.gained_time_desc, self.currentUnit.content_time_desc].join(' / ');
			else
				self.currentUnit.playTime = self.currentUnit.gained_time_desc;

			if (!self.currentUnit.onPause && self.layout === 'learning' &&
				(($location.path() === ['/learn/knowledge/', self.target.uqid].join('')) ||
				($location.path() === ['/learn/activity/', self.target.uqid].join('')))) {

				self.currentUnit.gained_time += 1;
				self.currentUnit.gained_time_desc = $utility.timeToFormat(self.currentUnit.gained_time);

				if (self.currentUnit.unit_type === 'video') {
					if (self.syncUnitNote) {
						var currentVideoTime = 0;
						if (self.videoPlayer.type === 'youku')
							currentVideoTime = Math.ceil(self.videoPlayer.target.currentTime());
						else if (self.videoPlayer.type === 'videojs')
							currentVideoTime = Math.ceil(self.videoPlayer.target.currentTime());

						if ($('#notes #time-' + currentVideoTime).length > 0) {
							var temp = $('#notes #time-' + currentVideoTime).offset().top - $('#notes').offset().top + $('#notes').scrollTop() - 5;
							$('#notes').scrollTop(temp);

							$('#notes > div').css({'border': 'none'});
							$('#notes > div').css({'border-bottom': '1px solid #ddd'});
							$('#notes #time-' + currentVideoTime).css({'border': '1px dashed #f00'});
						}
					}

					if (self.currentUnit.quizzes.length > 0) {
						var currentVideoTime = 0;
						if (self.videoPlayer.type === 'youku')
							currentVideoTime = Math.ceil(self.videoPlayer.target.currentTime());
						else if (self.videoPlayer.type === 'videojs')
							currentVideoTime = Math.ceil(self.videoPlayer.target.currentTime());

						angular.forEach(self.currentUnit.quizzes, function(item) {
							if (Math.ceil(item.video_time) === currentVideoTime) {
								self.videoPause();
								self.currentUnit.currentQuiz = item;
								$('#videoQuizModal').modal('show');
							}
						});
					}
				}
			}

			self.showStudyProgress();
		}, 1000);
	}

	self.setUnitStatus = function(next) {
		var data = {
			uqid: self.currentUnit.uqid,
			status: self.currentUnit.completed ? 4 : 2
		};

		self.currentUnit.saving = true;
		$http.put([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/status'].join(''), data)
		.success(function(response, status) {
			self.currentUnit.status = response.status;
			self.currentUnit.completed = response.status === 4;

			delete self.currentUnit.saving;

			if (next) {
				if (response.status === 4) {
					for (var i = self.currentUnit.playIndex + 1; i < self.units.length; i++) {
						var nextUnit = self.units[i];
						if (nextUnit.unit_type !== 'chapter') {
							$timeout(function() { self.chooseUnit(nextUnit); }, 100);
							i = self.units.length;
							return;
						}
					}
				}
			}
		});
	}

	self.setCompleted = function() {
		self.currentUnit.completed = !self.currentUnit.completed;
		self.setUnitStatus(true);
	}

	self.chooseUnit = function(unit) {
		delete self.currentUnit.showQuizSolution;

		self.currentUnit = unit;
		self.stopPromise();

		$timeout(function() {
			self.studyUnit(unit);
		}, 100);

		self.currentUnit.absUrl = [$utility.BASE_URL, '/watch?k=', self.target.uqid, '&u=', unit.uqid].join('');
	}

	self.preUnit = function() {
		for (var i = self.currentUnit.playIndex - 1; i >= 0; i--) {
			var preUnit = self.units[i];
			if (preUnit.unit_type !== 'chapter') {
				self.chooseUnit(preUnit);
				i = -1;
				return;
			}
		}
	}

	self.nextUnit = function() {
		for (var i = self.currentUnit.playIndex + 1; i < self.units.length; i++) {
			var nextUnit = self.units[i];
			if (nextUnit.unit_type !== 'chapter') {
				self.chooseUnit(nextUnit);
				i = self.units.length;
				return;
			}
		}
	}

	self.studyUnit = function(unit) {
		self.noteBoard = { show: false }
		self.loadNote();

		delete self.videoPlayer;
		$('#videoContainer').html('');

		if (unit.description === null || unit.description === '')
			self.showUnitDesc = false;
		else
			self.showUnitDesc = true;

		self.changeSize();

		if (unit.unit_type === 'video') {
			unit.playTime = [unit.gained_time_desc, unit.content_time_desc].join(' / ');

			var videoPath = unit.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
			var startTime = 0;

			if (videoPath !== null && videoPath.length === 6) {
				startTime = unit.content_url.match(/t=([0-9]+)/);
				if (startTime !== null && startTime.length === 2)
					startTime = Math.abs(startTime[1]);
				else
					startTime = 0;
				startTime = (unit.total_time - Math.abs(unit.last_second_watched)) <= 5 ? startTime : Math.floor(unit.last_second_watched);
				if (unit.seekToTime !== undefined) {
					startTime = Math.ceil(unit.seekToTime);
					self.unitAutoplay = true;
				}

				if (videoPath[2] === 'youku') {
					self.youkuReady = false;
					self.youkuStart = false;
					$('#videoContainer').html('<div id="videoPlayer" ng-style="{width:watchCtrl.contentWidth+\'px\', height:watchCtrl.leftContentHeight+\'px\'}"></div>');

					var player = new YKU.Player('videoPlayer',{
						client_id: 'c865b5756563acee',
						vid: videoPath[4],
						width: '100%',
						height: '100%',
						autoplay: self.unitAutoplay,
						events:{
							onPlayerReady: function() {
								self.youkuReady = true;
							},
							onPlayStart: function() {
								self.youkuStart = true;
								self.videoOnPlaying();
							},
							onPlayEnd: function() {
								self.videoOnEnding();
							}
						}
					});

					self.videoPlayer = {target: player, type: 'youku'};

					$compile(document.getElementById('videoPlayer'))($scope);
				}
				else {
					if (videoPath[2] === 'youtube')
						unit.content_url = unit.content_url.split('&list')[0];

					var videoId = Date.now();
					var option = {
						controls: true,
						preload: 'auto',
						forceSSL: true,
						forceHTML5: true,
						autoplay: self.unitAutoplay,
						techOrder: videoPath[2] === 'youtube' ? ['youtube'] : (videoPath[2] === 'vimeo' ? ['vimeo'] : []),
						src: unit.content_url,
						ytcontrols: true
					}

					$('#videoContainer').html(
						['<video id="video-', videoId,'"',
							' src="', unit.content_url, (unit.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
							' width="100%" height="100%"',
							' class="video-js vjs-default-skin vjs-big-play-centered">',
						'</video>'].join('')
					);

					videojs(['video-', videoId].join(''), option, function() {
						var player = this;

						player.on("ended", function() {
							self.videoOnEnding();
						});
						player.on("play", function() {
							self.videoOnPlaying();
						});
						player.on("pause", function() {
							self.videoOnPause();
						});

						self.videoPlayer = {target: player, type: 'videojs', startTime: startTime};
					});

					$(['#video-', videoId].join('')).attr('ng-style', '{width:watchCtrl.contentWidth+\'px\', height:watchCtrl.leftContentHeight+\'px\'}');
					$compile(document.getElementById(['video-', videoId].join('')))($scope);
				}
			}
			else {
				var mp3 = unit.content_url.match(/([a-z\-_0-9\/\:\.]*\.mp3)/i);

				startTime = (unit.total_time - Math.abs(unit.last_second_watched)) <= 5 ? 0 : Math.floor(unit.last_second_watched);
				if (unit.seekToTime !== undefined) {
					startTime = Math.ceil(unit.seekToTime);
					self.unitAutoplay = true;
				}

				var videoId = Date.now();
				var option = {
					controls: true,
					preload: 'auto',
					autoplay: self.unitAutoplay,
					plugins: {
						speed: [
							{ text: '0.5', rate: 0.5 },
							{ text: '0.75', rate: 0.75 },
							{ text: 'Normal', rate: 1, selected: true },
							{ text: '1.5', rate: 1.5 },
							{ text: '2', rate: 2 }
						]
					}
				};

				if (mp3 === null) {
					$('#videoContainer').html(
						['<video id="video-', videoId,'"',
							' src="', unit.content_url, (unit.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
							' width="100%" height="100%"',
							' class="video-js vjs-default-skin vjs-big-play-centered">',
						'</video>'].join('')
					);

					videojs(['video-', videoId].join(''), option, function() {
						var player = this;

						player.on("ended", function() {
							self.videoOnEnding();
						});
						player.on("play", function() {
							self.videoOnPlaying();
						});
						player.on("pause", function() {
							self.videoOnPause();
						});

						self.videoPlayer = {target: player, type: 'videojs', startTime: startTime};
					});

					$(['#video-', videoId].join('')).attr('ng-style', '{width:watchCtrl.contentWidth+\'px\', height:watchCtrl.leftContentHeight+\'px\'}');
					$compile(document.getElementById(['video-', videoId].join('')))($scope);
				}
				else {
					unit.sub_type = 'audio';
					self.showUnitDesc = false;

					$('#videoContainer').html(
						['<video id="video-', videoId,'"',
							' src="', unit.content_url, (unit.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
							' width="100%" height="90px"',
							' class="video-js vjs-default-skin vjs-big-play-centered">',
						'</video>'].join('')
					);

					videojs(['video-', videoId].join(''), option, function() {
						var player = this;

						player.on("ended", function() {
							self.videoOnEnding();
						});
						player.on("play", function() {
							self.videoOnPlaying();
						});
						player.on("pause", function() {
							self.videoOnPause();
						});

						self.videoPlayer = {target: player, type: 'videojs', startTime: startTime};
					});
				}
			}

			if (unit.quizzes === undefined) {
				$http.get([$utility.SERVICE_URL, '/learning/units/', unit.uqid, '/quizzes'].join(''))
				.success(function(response, status) {
					angular.forEach(response, function(quiz) {
						quiz.correct = null;
					});

					unit.quizzes = response;

					if (unit.study_result !== null) {
						angular.forEach(unit.quizzes, function(quiz, index) {
							var answer = unit.study_result.result[index].answer;

							if (quiz.quiz_type === 'multi') {
								angular.forEach(answer, function(key) {
									angular.forEach(quiz.options, function(option) {
										if (key === option.value) option.answer = true;
									});
								});
							}
							else {
								quiz.single = answer[0];
							}
						});
					}
				});
			}
		}
		else {
			if (unit.unit_type === 'quiz' && unit.quizzes === undefined) {
				$http.get([$utility.SERVICE_URL, '/learning/units/', unit.uqid, '/quizzes'].join(''))
				.success(function(response, status) {
					angular.forEach(response, function(quiz) {
						quiz.correct = null;
					});

					unit.quizzes = response;
				});
			}
			else if (unit.unit_type === 'poll' && unit.study_result !== null) {
				var answer = unit.study_result.result;
				angular.forEach(answer, function(key) {
					angular.forEach(unit.content.options, function(option) {
						if (key === option.value) option.answer = true;
					});
				});
			}
			else if (unit.unit_type === 'qa') {
				self.initHtmlEditor('#qa-result', unit.study_result == null ? '' : unit.study_result.result);
			}
			else if (unit.unit_type === 'draw') {
				$timeout(function() {
					$('#draw-board').html('<canvas></canvas>');
					$('#draw-board').literallycanvas({
						imageURLPrefix: '/library/literallycanvas/img',
						backgroundColor: 'rgba(0, 0, 0, 0)',
						primaryColor: '#f00'
					});

					$('#draw-board .custom-button').before(
						['<div id="draw-submit" class="btn btn-xs btn-primary" style="margin:-4px 4px 0">',
							'<span translate="E044"></span>',
						'</div>',
						'<div class="btn-group" style="margin:-4px 4px 0">',
							'<div id="draw-replay-high" class="btn btn-xs btn-primary">',
								'<span translate="E045"></span>',
							'</div>',
							'<div id="draw-replay-normal" class="btn btn-xs btn-primary">',
								'<span translate="E046"></span>',
							'</div>',
						'</div>'].join(''));

					var lc = $('#draw-board').literallyCanvasInstance();
					if (unit.study_result)
						lc.addShapes(unit.study_result.result.strokes);

					$('#draw-submit').click(function() {
						self.sendDrawResult();
					});

					$('#draw-replay-high').click(function() {
						lc.terminal = true;
						lc.playStrokes(100);
					});

					$('#draw-replay-normal').click(function() {
						lc.terminal = true;
						lc.playStrokes(1);
					});

					if (unit.content.description !== '') {
						$('#draw-board .custom-button').before('<div id="draw-description" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="E047"></span></div>');
						$('#draw-description').click(function() {
							$('#drawDescriptionModal').modal('show');
						});
					}

					if (unit.content.background !== '') {
						$('#draw-board .custom-button').before('<div id="draw-background" class="btn btn-xs btn-primary" style="margin:-4px 0 0"><span translate="E048"></span></div>');
						$('#draw-background').click(function() {
							$scope.$apply(function() {
								if (unit.backgroundImage === undefined)
									unit.backgroundImage = ['url(', unit.content.background, ') no-repeat'].join('');
								else
									delete unit.backgroundImage;
							});
						});
					}

					$compile(document.getElementById('literally-toolbar'))($scope);
				},100);
			}
			else if (unit.unit_type === 'embed') {
				if ($(unit.content).find('embed').length > 0)
					unit.content = $(unit.content).find('embed').css('width', '100%').css('height', '100%')[0].outerHTML;
				else if ($(unit.content).find('iframe').length > 0)
					unit.content = $(unit.content).find('iframe').css('width', '100%').css('height', '100%')[0].outerHTML;
				else if ($(unit.content)[0].nodeName === 'EMBED')
					unit.content = $(unit.content).css('width', '100%').css('height', '100%')[0].outerHTML;
				else if ($(unit.content)[0].nodeName === 'IFRAME')
					unit.content = $(unit.content).css('width', '100%').css('height', '100%')[0].outerHTML;
			}

			unit.seconds_started = Date.now();

			self.showStudyProgress();
			self.sendStudyHistoryProgress();
		}
	}

	self.loadKnowledge = function() {
		$http.get([$utility.SERVICE_URL, '/learning/', $routeParams.t].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.target = response;

				$http.get([$utility.SERVICE_URL, '/learning/', $routeParams.t, '/units'].join(''))
				.success(function(response, status) {
					self.parseUnits(response);
				});

				self.listSubscriber();
				self.changeLayout('knowledge');
			}
			else
				window.location.href = [location.origin, "/knowledge/", $routeParams.t].join('');
		});
	}

	self.loadActivity = function() {
		$http.get([$utility.SERVICE_URL, '/learning/activities/', $routeParams.t].join(''))
		.success(function(response, status) {
			if (!response.error) {
				self.target = response;

				$http.get([$utility.SERVICE_URL, '/learning/activities/', $routeParams.t, '/units'].join(''))
				.success(function(response, status) {
					self.parseUnits(response);
				});

				self.changeLayout('knowledge');
			}
			else
				$location.path('/learn/knowledge');
		});
	}

	self.parseUnits = function(response) {
		angular.forEach(response, function(item, index) {
			if (item.unit_type === 'video')
				item.spendTime = [$utility.timeToFormat(item.gained_time), ' / ', $utility.timeToFormat(item.content_time)].join('');
			else
				item.spendTime = $utility.timeToFormat(item.gained_time);
		});

		if (self.contentType === 'knowledge')
			self.chapters = [];

		var ch_uqid = '', targetChapter, lastUnit = null, targetUnit, items = [];
		angular.forEach(response, function(item, index) {
			if (!lastUnit) lastUnit = response[0];

			if (self.contentType === 'knowledge') {
				if (ch_uqid !== item.chapter.uqid) {
					ch_uqid = item.chapter.uqid;
					items.push({
						uqid: item.chapter.uqid,
						name: item.chapter.name,
						priority: item.chapter.priority,
						progress: 0,
						unit_type: 'chapter'
					});

					targetChapter = {
						uqid: item.chapter.uqid,
						name: item.chapter.name,
						units: []
					}

					self.chapters.push(targetChapter);
				}
			}

			if (item.uqid !== null && item.uqid !== '') {
				item.playIndex = items.length;
				item.completed = item.status === 4 ? true : false;
				items.push(item);

				if (self.contentType === 'knowledge')
					targetChapter.units.push(item);

				if (item.uqid === $routeParams.unit) {
					targetUnit = item;
					if ($routeParams.seconds !== undefined)
						targetUnit.seekToTime = $routeParams.seconds;
				}
			}

			if (item.content_time !== null && item.content_time !== '') {
				item.content_time = Math.ceil(item.content_time);
				item.format_time = $utility.timeToFormat(item.content_time);
				item.content_time_desc = $utility.timeToFormat(item.content_time);

				if (item.unit_type !== 'video') item.format_time = '';
			}
			else {
				item.format_time = '';
				item.content_time_desc = '';
			}

			if (item.gained_time !== null && item.gained_time !== '') {
				item.gained_time = Math.ceil(item.gained_time);
				item.gained_time_desc = $utility.timeToFormat(item.gained_time);
			}
			else
				item.gained_time_desc = '';

			item.total_time = Math.ceil(item.total_time);

			if (new Date(item.last_view_time) > new Date(lastUnit.last_view_time)) {
				lastUnit = item;
				item.lastStudyUnit = true;
			}
		});

		self.units = items;

		if ($routeParams.unit !== undefined && targetUnit !== undefined) {
			self.currentUnit = targetUnit;
			self.changeLayout('learning');
		}
		else {
			self.currentUnit = lastUnit;
		}
	}

	self.showFeedbackModal = function(item) {
		self.currentFeedbackUnit = item;
		$('#feedbackModal').modal('show');
	}

	self.init = function() {
		self.listGroup();

		self.online = true;
		self.layout = 'knowledge';
		self.contentType = 'knowledge';
		self.notePosition = 'right';
		self.maximum = false;
		self.unitAutoplay = false;
		self.syncUnitNote = false;
		self.showUnitDesc = true;
		self.noteBoard = {
			show: false,
			type: 'new'
		};

		if ($routeParams.t !== undefined) {
			if ($routeParams.c === 'knowledge') {
				self.contentType = 'knowledge';
				self.loadKnowledge();
			}
			else if ($routeParams.c === 'activity') {
				self.contentType = 'activity';
				self.loadActivity();
			}
		}
		else
			$location.path('/learn/knowledge');
	}

	self.stopPromise = function() {
		if(angular.isDefined(self.promise1))
			$timeout.cancel(self.promise1);
		if(angular.isDefined(self.promise2))
			$timeout.cancel(self.promise2);
	}

	$scope.$location = $location;
	$scope.$watch('$location.path()', function() {
		self.stopPromise();
	});

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})