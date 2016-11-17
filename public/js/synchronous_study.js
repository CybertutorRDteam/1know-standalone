_1know.controller('SynchronousStudyCtrl', function($scope, $http, $location, $timeout, $compile, $routeParams, $utility, $interval) {
	var self = this;

	self.showUnitDescModal = function() {
		$('#unitDescModal').modal('show');
	}

	self.loadStatus = function() {
		$http.get([$utility.SERVICE_URL, '/classroom/', self.target, '/study'].join(''))
		.success(function(response, status) {
			if (!response.error) {
				if (response.study_result !== null)
					response.study_result.learning_time = new Date(response.study_result.learning_time);

				self.currentUnit = response;

				self.profile = response.profile;
				self.lockedScreen = response.lock_screen;
				self.dispatchModel = response.dispatch_url;
				self.teacherOffline = response.teacher_offline;

				$timeout(function(){self.parseContent();},100);

				if (response.teacher_offline)
					$('#teacherModal').modal('show');

				$('[quiz-submit]').parent().show();
				$('[poll-submit]').parent().show();
				$('[qa-submit]').parent().show();
				$('#draw-submit').show();
			}
			else {
				self.teacherOffline = true;
				$('#teacherModal').modal('show');
			}
		});
	}

	self.parseContent = function() {
		self.changeSize();

		if (self.currentUnit.unit_type === 'video') {
			var video_msg_html = ["<table width='", self.contentWidth , "px' height='", self.contentHeight , "'>",
						"<tr><td valign='middle' align='center' class='video_bg' style='font-size:2em;'>",
						"视频单元，请看老师画面</td></tr></table>"].join("");
			$('#videoContainer').html(video_msg_html);
			/*
			var videoPath = self.currentUnit.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
			if (videoPath !== null && videoPath.length === 6) {
				var content = '';
				if (videoPath[2] === 'youtube')
					content = ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '?autohide=1&rel=0&showinfo=0&theme=light" ng-style="{width:syncStudyCtrl.contentWidth+\'px\', height:syncStudyCtrl.contentHeight+\'px\'}" frameborder="0"></iframe>'].join('');
				else if (videoPath[2] === 'vimeo')
					content = ['<iframe src="https://player.vimeo.com/video/', videoPath[3], '" ng-style="{width:syncStudyCtrl.contentWidth+\'px\', height:syncStudyCtrl.contentHeight+\'px\'}" frameborder="0"></iframe>'].join('');
				else if (videoPath[2] === 'youku')
					content = ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" ng-style="{width:syncStudyCtrl.contentWidth+\'px\', height:syncStudyCtrl.contentHeight+\'px\'}" frameborder="0"></iframe>'].join('');

				$('#videoContainer').html(content);
				$compile(document.getElementById('videoContainer'))($scope);
			}
			else {
				var videoId = Date.now();

				$('#videoContainer').html(
					['<video id="video-', videoId,'"',
						' src="', self.currentUnit.content_url, (self.currentUnit.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
						' width="100%" height="100%"',
						' class="video-js vjs-default-skin vjs-big-play-centered">',
					'</video>'].join('')
				);

				videojs(['video-', videoId].join(''), {controls: true, preload: 'auto'}, function() {});
				$(['#video-', videoId].join('')).attr('ng-style', '{width:syncStudyCtrl.contentWidth+\'px\', height:syncStudyCtrl.contentHeight+\'px\'}');
				$compile(document.getElementById(['video-', videoId].join('')))($scope);
			}
			*/
		}
		else if (self.currentUnit.unit_type === 'quiz' && self.currentUnit.study_result !== null) {
			angular.forEach(self.currentUnit.quizzes, function(quiz, index) {
				angular.forEach(self.currentUnit.study_result.result, function(key) {
					if (key.uqid === quiz.uqid) {
						if (quiz.quiz_type === 'multi') {
							angular.forEach(key.answer, function(key) {
								angular.forEach(quiz.options, function(option) {
									if (key === option.value) option.answer = true;
								});
							});
						}
						else {
							quiz.single = key.answer[0];
						}
					}
				});
			});
		}
		else if (self.currentUnit.unit_type === 'poll' && self.currentUnit.study_result !== null) {
			var answer = self.currentUnit.study_result.result;
			angular.forEach(answer, function(key) {
				angular.forEach(self.currentUnit.content.options, function(option) {
					if (key === option.value) option.answer = true;
				});
			});
		}
		else if (self.currentUnit.unit_type === 'qa') {
			$timeout(function() {
				if ($('#qa-result').redactor() !== undefined)
					$('#qa-result').redactor('destroy');

				$('#qa-result').html(self.currentUnit.study_result == null ? '' : self.currentUnit.study_result.result);
				$('#qa-result').redactor({
					iframe: true,
					buttons: ['html', '|', 'formatting', '|', 'bold', 'italic', 'deleted', '|', 'unorderedlist', 'orderedlist', '|', 'image', 'video', 'link'],
					plugins: ['fontcolor', 'fontsize']
				});
			},100);
		}
		else if (self.currentUnit.unit_type === 'draw') {
			$timeout(function() {
				$('#draw-board').html('<canvas></canvas>');
				$('#draw-board').literallycanvas({
					imageURLPrefix: '/library/literallycanvas/img',
					backgroundColor: 'rgba(0, 0, 0, 0)',
					primaryColor: '#f00'
				});

				$('#draw-board .custom-button').before(
					['<div id="draw-submit" class="btn btn-xs btn-primary" style="margin:-4px 4px 0">',
						'<span translate="L003"></span>',
					'</div>',
					'<div class="btn-group" style="margin:-4px 4px 0">',
						'<div id="draw-replay-high" class="btn btn-xs btn-primary">',
							'<span translate="L004"></span>',
						'</div>',
						'<div id="draw-replay-normal" class="btn btn-xs btn-primary">',
							'<span translate="L005"></span>',
						'</div>',
					'</div>'].join(''));

				var lc = $('#draw-board').literallyCanvasInstance();
				if (self.currentUnit.study_result !== null)
					lc.addShapes(self.currentUnit.study_result.result.strokes);

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

				if (self.currentUnit.content.background !== '') {
					$('#draw-board .custom-button').before('<div id="draw-background" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="L006"></span></div>');
					$('#draw-background').click(function() {
						$timeout(function() {
							if (self.currentUnit.backgroundImage === undefined)
								self.currentUnit.backgroundImage = ['url(', self.currentUnit.content.background, ') no-repeat'].join('');
							else
								delete self.currentUnit.backgroundImage;
						},100);
					});
				}

				$compile(document.getElementById('literally-toolbar'))($scope);
			},100);
		}
	}

	self.sendQuizResult = function() {
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
					quiz.correct = 'YES';
					correct_count += 1;
				}
				else
					quiz.correct = 'NO';
			}
			else {
				answer.push(parseInt(quiz.single, 10));
				correct.push(parseInt(quiz.answer, 10));

				if (parseInt(quiz.answer, 10) === parseInt(quiz.single, 10)) {
					quiz.correct = 'YES';
					correct_count += 1;
				}
				else
					quiz.correct = 'NO';
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

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/study/studyResult'].join(''), { unitUqid: self.currentUnit.uqid, content: JSON.stringify(data) })
		.success(function(response, status) {
			self.currentUnit.study_result = response;
			self.setUnitStatus();

			$('[quiz-submit]').parent().hide();
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

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/study/studyResult'].join(''), { unitUqid: self.currentUnit.uqid, content: JSON.stringify(data) })
		.success(function(response, status) {
			self.currentUnit.study_result = response;
			self.setUnitStatus();

			$('[poll-submit]').parent().hide();
		});
	}

	self.sendQAResult = function() {
		var unit = self.currentUnit;

		var data = {
			unit_type: unit.unit_type,
			result: $("#qa-result").redactor('get')
		};

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/study/studyResult'].join(''), { unitUqid: self.currentUnit.uqid, content: JSON.stringify(data) })
		.success(function(response, status) {
			self.currentUnit.study_result = response;
			self.setUnitStatus();

			if (self.currentUnit.study_result === null || self.currentUnit.study_result === undefined) {
				self.currentUnit.study_result = {
					result: response.content.result
				}
			}
			else
				self.currentUnit.study_result.result = response.content.result;

			$('[qa-submit]').parent().hide();
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
				screenshot: screenshot
			}
		};

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/study/studyResult'].join(''), { unitUqid: self.currentUnit.uqid, content: JSON.stringify(data) })
		.success(function(response, status) {
			self.currentUnit.study_result = response;
			self.setUnitStatus();

			$('#draw-submit').hide();
		});
	}

	self.setUnitStatus = function() {
		var data = {
			uqid: self.currentUnit.uqid,
			status: 4
		};

		$http.put([$utility.SERVICE_URL, '/learning/units/', self.currentUnit.uqid, '/status'].join(''), data)
		.success(function(response, status) {});

		self.socket.send( {
			poster: $utility.account.uqid,
			type: 'unit-study-result',
			message: {
				user_uqid: $utility.account.uqid,
				unit_uqid: self.currentUnit.uqid
			}
		});
	}

	self.init = function() {
		self.target = $routeParams.t;
		self.behaviorIcons = [
			'fa-thumbs-o-up', 'fa-leaf', 'fa-flask', 'fa-coffee', 'fa-group', 'fa-microphone',
			'fa-globe', 'fa-picture-o', 'fa-plane', 'fa-trophy', 'fa-comments-o', 'fa-clock-o',
			'fa-smile-o', 'fa-lightbulb-o', 'fa-check', 'fa-lemon-o', 'fa-puzzle-piece', 'fa-refresh',
			'fa-search', 'fa-bell', 'fa-bullhorn', 'fa-frown-o', 'fa-gavel', 'fa-music',
			'fa-heart-o', 'fa-cloud', 'fa-trash-o', 'fa-tint', 'fa-bolt', 'fa-thumbs-o-down'
		];
		self.lockedScreen = false;
		self.loadStatus();

		$scope.mainCtrl.toggleVisible(false);
		self.initWebSocket();
	}

	self.initWebSocket = function() {
		self.socket = new WebSocketRails(window.location.host + "/websocket");
		self.socket.channel = self.socket.subscribe(['1know-classroom-', self.target].join(''));
		self.socket.channel.bind('new_message', function(msg) {
			$scope.$apply(function() {
				if (msg.type === 'teacher-status-changed') {
					if (msg.message === 'online') {
						self.teacherOffline = false;
						$('#teacherModal').modal('hide');
					}
					else {
						self.teacherOffline = true;
						$('#teacherModal').modal('show');
					}
				}
				else if (msg.type === 'student-status-changed') {
					if (msg.message === 'attendance') {
						self.socket.send( {
							poster: $utility.account.uqid,
							type: 'student-status-changed',
							message: {
								user_uqid: $utility.account.uqid,
								status: 'online'
							}
						});
					}
				}
				else if (msg.type === 'unit-changed') {
					self.loadStatus();
					delete self.dispatchModel;
					$('#unitDescModal').modal('hide');
				}
				else if (msg.type === 'lock-screen') {
					self.lockedScreen = msg.message;

					if (!msg.message && self.currentUnit.unit_type === 'qa') {
						$timeout(function() {
							if ($('#qa-result').redactor() !== undefined)
								$('#qa-result').redactor('destroy');

							$('#qa-result').html(self.currentUnit.study_result == null ? '' : self.currentUnit.study_result.result);
							$('#qa-result').redactor({
								iframe: true,
								buttons: ['html', '|', 'formatting', '|', 'bold', 'italic', 'deleted', '|', 'unorderedlist', 'orderedlist', '|', 'image', 'video', 'link'],
								plugins: ['fontcolor', 'fontsize']
							});
						},100);
					}
				}
				else if (msg.type === 'dispatch-url') {
					if (msg.message === 'close')
						delete self.dispatchModel;
					else {
						self.lockedScreen = false;
						self.dispatchModel = msg.message;

						var videoPath = self.dispatchModel.url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);
						var content = '';
						if (videoPath !== null && videoPath.length === 6) {
							if (videoPath[2] === 'youtube') {
								var startTime = self.dispatchModel.url.match(/t=([0-9]+)/);
								if (startTime !== null && startTime.length === 2)
									startTime = ['&start=', startTime[1]].join('');
								else
									startTime = '';
								content = ['<iframe src="http://www.youtube.com/embed/', videoPath[5], '?autohide=1&rel=0&showinfo=0&theme=light', startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
							}
							else if (videoPath[2] === 'vimeo') {
								var startTime = self.dispatchModel.url.match(/t=([0-9]+)/);
								if (startTime !== null && startTime.length === 2)
									startTime = ['#t=', startTime[1]].join('');
								else
									startTime = '';
								content = ['<iframe src="https://player.vimeo.com/video/', videoPath[3], startTime, '" width="100%" height="100%" frameborder="0"></iframe>'].join('');
							}
							else if (videoPath[2] === 'youku')
								content = ['<iframe src="http://player.youku.com/embed/', videoPath[4], '" width="100%" height="100%" frameborder="0"></iframe>'].join('');

							self.dispatchModel.content = content;
						}
						else
							self.dispatchModel.content = ['<iframe src="', self.dispatchModel.url, '" width="100%" height="100%" frameborder="0"></iframe>'].join('')
					}
				}
				else if (msg.type === 'student-behavior-points-changed') {
					if (msg.message.uqid === self.profile.item_uqid) {
						self.behavior = msg.message;

						if (self.behavior.points > 0) {
							self.profile.behavior.positive += 1;
							self.behavior.symbol = '+1';
						}
						else {
							self.profile.behavior.negative -= 1;
							self.behavior.symbol = '-1';
						}

						self.profile.behavior.total += self.behavior.points;

						$('#behaviorModal').modal('show');
						$timeout(function() {
							$('#behaviorModal').modal('hide');
							delete self.behavior;
						},2000);
					}
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
			self.socket.send({
				poster: $utility.account.uqid,
				type: 'student-status-changed',
				message: {
					user_uqid: $utility.account.uqid,
					status: 'online'
				}
			});
		},1000);

		$interval(function(){
			if (self.socket.connection_stale()) self.socket.on_close('');
		}, 1000);
	}

	self.reponseSelf = function() {
		self.socket.send( {
			poster: $utility.account.uqid,
			type: 'student-status-changed',
			message: {
				user_uqid: $utility.account.uqid,
				status: 'online'
			}
		});
	}

	self.leaveClassroom = function() {
		$location.path(['/join/group/', self.target].join(''));
	}

	self.changeSize = function() {
		self.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
		self.contentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;

		if ($('#draw-board canvas').length === 1) {
			$('#draw-board canvas').attr({ 'width': self.contentWidth, 'height': self.contentHeight });
			$('#draw-board canvas').css({ 'width': self.contentWidth, 'height': self.contentHeight });
			if ($('#draw-board').literallyCanvasInstance() !== undefined)
				$('#draw-board').literallyCanvasInstance().repaint();
		}
	}

	window.onresize = function() {
		$scope.$apply(function() {
			self.changeSize();
		});
	}

	window.onbeforeunload = function() {
		self.socket.send( {
			poster: $utility.account.uqid,
			type: 'student-status-changed',
			message: {
				user_uqid: $utility.account.uqid,
				status: 'offline'
			}
		});
	}

	$scope.$location = $location;
	$scope.$watch('$location.path()', function() {
		if ($location.path() !== ['/join/group/', $routeParams.t, '/study'].join('')) {
			self.socket.send( {
				poster: $utility.account.uqid,
				type: 'student-status-changed',
				message: {
					user_uqid: $utility.account.uqid,
					status: 'offline'
				}
			});
		}
	});

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})
