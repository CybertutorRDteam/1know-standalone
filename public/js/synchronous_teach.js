_1know.controller('SynchronousTeachCtrl', function($scope, $http, $location, $timeout, $routeParams, $compile, $utility, $interval) {
	var self = this;

	self.changeLayout = function(target) {
		self.layout = target;

		if (target === 'attendance') {
			if (self.currentUnit.unit_type === 'video')
				self.videoPause();
		}

		if (self.whiteBoard.show)
			self.toggleWhiteBoard();
	}

	self.attendance = function() {
		self.socket.send( {
			poster: $utility.account.uqid,
			type: 'student-status-changed',
			message: 'attendance'
		});
	}

	self.showDispatchModal = function() {
		$('#dispatchModal').modal('show');
		$('#dispatchModal').on('hidden.bs.modal', function() {
			delete self.currentUnit.dispatchUrl;
			delete self.errMsg;
		});

		if (self.currentUnit.unit_type === 'video')
			self.videoPause();
	}

	self.dispatchUrl = function() {
		if (self.currentUnit.dispatchUrl === undefined || self.currentUnit.dispatchUrl === '') return;

		$http.post([$utility.SERVICE_URL, '/utility/parseURL'].join(''), { url: self.currentUnit.dispatchUrl })
		.success(function(response, status) {
			if (!response.error) {
				self.lockedScreen = false;
				self.dispatchModel = response;

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

				$http.post([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/dispatchUrl'].join(''), { content: JSON.stringify(response) })
				.success(function(response, status) {
					if (!response.error) {
						$('#dispatchModal').modal('hide');

						self.socket.send( {
							poster: $utility.account.uqid,
							type: 'dispatch-url',
							message: {
								title: self.dispatchModel.title,
								url: self.dispatchModel.url
							}
						});
					}
				});
			}
			else
				self.errMsg = translations[$utility.LANGUAGE.type]['K012'];//網址錯誤
		});
	}

	self.closeDispatch = function() {
		$http.post([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/dispatchUrl'].join(''), { content: '' })
		.success(function(response, status) {
			if (!response.error) {
				delete self.dispatchModel;

				self.socket.send( {
					poster: $utility.account.uqid,
					type: 'dispatch-url',
					message: 'close'
				});
			}
		});
	}

	self.toggleWhiteBoard = function() {
		self.whiteBoard.show = !self.whiteBoard.show;

		if (!self.whiteBoard.created) {
			self.whiteBoard.created = true;

			$timeout(function() {
				$('#teach-white-board').literallycanvas({
					imageURLPrefix: '/library/literallycanvas/img',
					backgroundColor: 'rgba(0, 0, 0, 0.3)',
					primaryColor: '#f00'
				});

				$('.colorpicker.alpha').css('z-index', '1280');
				$compile(document.getElementById('literally-toolbar'))($scope);
			},100);
		}

		if (self.currentUnit.unit_type === 'video') {
			if (self.whiteBoard.show)
				self.videoPause();
			else
				self.videoPlay();
		}
	}

	self.lockScreen = function() {
		self.lockedScreen = !self.lockedScreen;

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/lockScreen'].join(''), { status: self.lockedScreen })
		.success(function(response, status) {
			self.socket.send( {
				poster: $utility.account.uqid,
				type: 'lock-screen',
				message: self.lockedScreen
			});
		});
	}

	self.listBehavior = function() {
		$http.get([$utility.SERVICE_URL, '/classroom/', self.target, '/behaviors'].join(''))
		.success(function(response, status) {
			self.behaviors = response;
		});
	}

	self.loadStatus = function(fn) {
		$http.get([$utility.SERVICE_URL, '/classroom/', self.target, '/teach'].join(''))
		.success(function(response, status) {
			if (response.unit !== undefined && response.unit.length > 0) {
				var items = [], ch_uqid = '';
				angular.forEach(response.unit, function(item, index) {
					if (ch_uqid !== item.chapter.uqid) {
						ch_uqid = item.chapter.uqid;
						items.push({
							uqid: item.chapter.uqid,
							name: item.chapter.name,
							unit_type: 'chapter'
						});
					}

					item.playIndex = items.length;
					items.push(item);
				});

				self.units = items;
				self.lockedScreen = response.classroom.lock_screen;
				self.dispatchModel = response.classroom.dispatch_url;
				self.content = response.classroom.content;

				angular.forEach(response.unit, function(item, index) {
					if (item.current) self.currentUnit = item;
					item.index = index;

					if ($.inArray(item.unit_type, ['quiz', 'poll', 'qa', 'draw']) !== -1) {
						item.viewType = 'question';
					}

					item.result_count = 0;
				});

				if (self.currentUnit === undefined)
					self.chooseUnit(response.unit[0]);
				else
					self.chooseUnit(self.currentUnit);
			}

			fn();
		});
	}

	self.loadStudents = function(fn) {
		$http.get([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/student'].join(''))
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				item.status = 'offline';
				item.online = false;
				item.units = {};
				angular.forEach(self.units, function(unit) {
					item.units[unit.uqid] = { send_result: false };
				});
			});

			self.students = response;
			fn();
		});
	}

	self.chooseUnit = function(unit) {
		delete self.dispatchWeb;
		self.whiteBoard.show = false;
		self.changeLayout('content');

		angular.forEach(self.units, function(item) {
			if (item.uqid == unit.uqid) {
				item.current = true;
				self.currentUnit = unit;
				$timeout(function(){self.parseContent();},100);
			}
			else
				item.current = false;
		});

		if (self.currentUnit.unit_type === 'quiz')
			self.currentUnit.showAnswer = false;

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/teach'].join(''), { unitUqid: self.currentUnit.uqid })
		.success(function(response, status) {
			self.loadResult();

			self.socket.send( {
				poster: $utility.account.uqid,
				type: 'unit-changed',
				message: self.currentUnit.uqid
			});
		});
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

	self.parseContent = function() {
		$('#videoContainer').html('');

		self.changeSize();

		if (self.currentUnit.unit_type === 'video') {
			var videoPath = self.currentUnit.content_url.match(/^(?:([A-Za-z]+):)?\/\/(?:.*?)\.?(youtube|vimeo|youku)\.(?:.*?)\/([0-9]+|v_show\/id_([0-9a-zA-Z]+)|[^#]*v=([0-9a-zA-Z\-\_]+))?/);

			if (videoPath !== null && videoPath.length === 6) {
				if (videoPath[2] === 'youku') {
					$('#videoContainer').html('<div id="videoPlayer" ng-style="{width:syncTeachCtrl.contentWidth+\'px\', height:syncTeachCtrl.contentHeight+\'px\'}"></div>');

					var player = new YKU.Player('videoPlayer',{
						client_id: 'c865b5756563acee',
						vid: videoPath[4],
						width: '100%',
						height: '100%'
					});

					self.videoPlayer = {target: player, type: 'youku'};

					$compile(document.getElementById('videoPlayer'))($scope);
				}
				else {
					var videoId = Date.now();
					var option = {
						controls: true,
						preload: 'auto',
						forceSSL: true,
						forceHTML5: true,
						techOrder: videoPath[2] === 'youtube' ? ['youtube'] : (videoPath[2] === 'vimeo' ? ['vimeo'] : []),
						src: self.currentUnit.content_url,
						ytcontrols: true
					}

					$('#videoContainer').html(
						['<video id="video-', videoId,'"',
							' src="', self.currentUnit.content_url, (self.currentUnit.content_url.indexOf("?") != -1 ? '&' : '?'), videoId, '"',
							' width="100%" height="100%"',
							' class="video-js vjs-default-skin vjs-big-play-centered">',
						'</video>'].join('')
					);

					videojs(['video-', videoId].join(''), option, function() {
						self.videoPlayer = {target: this, type: 'videojs'};
					});

					$(['#video-', videoId].join('')).attr('ng-style', '{width:syncTeachCtrl.contentWidth+\'px\', height:syncTeachCtrl.contentHeight+\'px\'}');
					$compile(document.getElementById(['video-', videoId].join('')))($scope);
				}
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

				videojs(['video-', videoId].join(''), {controls: true, preload: 'auto'}, function() {
					self.videoPlayer = {target: this, type: 'videojs'};
				});

				$(['#video-', videoId].join('')).attr('ng-style', '{width:syncTeachCtrl.contentWidth+\'px\', height:syncTeachCtrl.contentHeight+\'px\'}');
				$compile(document.getElementById(['video-', videoId].join('')))($scope);
			}
		}
	}

	self.videoPlay = function() {
		if (self.videoPlayer.type === 'youku')
			self.videoPlayer.target.playVideo();
		else if (self.videoPlayer.type === 'videojs')
			self.videoPlayer.target.play();
	}

	self.videoPause = function() {
		if (self.videoPlayer.type === 'youku')
			self.videoPlayer.target.pauseVideo();
		else if (self.videoPlayer.type === 'videojs')
			self.videoPlayer.target.pause();
	}

	self.toggleUnitView = function(type) {
		self.currentUnit.viewType = type;

		if (type !== 'question')
			self.loadResult();
	}

	self.loadResult = function() {
		var student = [];
		angular.forEach(self.students, function(item) {
			if (item.online)
				student.push(item.uqid);
		});

		$http.get([$utility.SERVICE_URL, '/classroom/', self.target , '/teach/studyResult?unitUqid=', self.currentUnit.uqid, '&userUqid=', student].join(''))
		.success(function(response, status) {
			angular.forEach(response.unit.quizzes, function(quiz) {
				quiz.full_content = function(quiz) {
					return [parseInt(quiz.quiz_no, 10) < 10 ? '0' + quiz.quiz_no : quiz.quiz_no, quiz.content.replace(/<(?:.|\n)*?>/gm, '')].join('. ');
				}
			});

			angular.forEach(self.students, function(student) {
				angular.forEach(response.user, function(item) {
					if (item.uqid === student.uqid) {
						student.units[self.currentUnit.uqid].result = item.result;
						student.units[self.currentUnit.uqid].learning_time = item.learning_time;
					}
				});
			});

			if (self.currentUnit.viewType === 'statistics') {
				if (self.currentUnit.unit_type === 'quiz') {
					self.parseQuizResult();
					self.drawQuizChart();
				}
				else if (self.currentUnit.unit_type === 'poll') {
					self.drawPollChart();
				}
			} else if (self.currentUnit.viewType === 'record') {
				if (self.currentUnit.unit_type === 'quiz') {
					self.parseQuizResult();

					angular.forEach(self.students, function(item) {
						if (self.currentUnit.targetItem === undefined && item.online) {
							self.currentUnit.targetItem = item;
						}
					});

					self.changeTargetItem = function(item) {
						self.currentUnit.targetItem = item;
					}
				}
				else if (self.currentUnit.unit_type === 'qa') {
					angular.forEach(self.students, function(item) {
						if (self.currentUnit.targetItem === undefined && item.online) {
							self.currentUnit.targetItem = item;
						}
					});

					self.changeTargetItem = function(item) {
						self.currentUnit.targetItem = item;
					}
				}
			}
		});
	}

	self.drawPollChart = function() {
		var data = [], count = 0;

		angular.forEach(self.currentUnit.content.options, function(option) {
			data.push({
				name: option.item,
				value: option.value,
				y: 0
			});
		});

		angular.forEach(self.students, function(item) {
			if (item.units[self.currentUnit.uqid].send_result) {
				angular.forEach(item.units[self.currentUnit.uqid].result, function(result) {
					angular.forEach(data, function(key) {
						if (key.value === result) {
							key.y += 1;
							count += 1;
						}
					});
				});
			}
		});

		if (count > 0) {
			$('#chart_poll').highcharts({
				credits: { enabled: false },
				title: {
					align: 'left',
					text: ['<h3>', self.currentUnit.content.content, '</h3>'].join(''),
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
								fontSize: 20
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

		angular.forEach(self.currentUnit.quizzes, function(item, index) {
			categories.push(index+1);

			var tooltip = [];
			angular.forEach(item.options, function(option, j) {
				tooltip.push(['<tr><td style="padding:4px">(', (option.correct ? '<i class="fa fa-fw fa-circle-o text-success"></i>' : '<i class="fa fa-fw fa-times text-danger"></i>'), ') ', option.item, '</td><td style="padding:4px">:</td><td style="padding:4px">', option.result_count, '</td></tr>'].join(''));
			});
			tooltip = ['<table><thead><tr><td colspan="3">', item.content, '</td></tr></thead><tbody>', tooltip.join(''), '</tbody></table>'].join('');
			datas.push({ y: 0, tooltip: tooltip });
		});

		angular.forEach(self.students, function(item) {
			if (item.units[self.currentUnit.uqid].send_result) {
				angular.forEach(item.quizzes, function(quiz, index) {
					if (quiz.correct) datas[index].y += 1;
				});
			}
		});

		var height = self.currentUnit.quizzes.length * 36;
		height = height < 240 ? 240 : height;
		$('#chart_quiz').css('height', height);
		$('#chart_quiz').highcharts({
			credits: { enabled: false },
			title: { text: null },
			xAxis: {
				categories: categories,
				title: {
					text: translations[$utility.LANGUAGE.type]['K013'],//題目
				}
			},
			yAxis: {
				min: 0,
				max: self.onlineStudents,
				tickInterval: 1,
				opposite: true,
				title: {
					text: [translations[$utility.LANGUAGE.type]['K014'], '(', self.onlineStudents,, ')'].join('')//答對人數 / 總人數
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
		angular.forEach(self.currentUnit.quizzes, function(item) {
			angular.forEach(item.options, function(option) {
				option.result_count = 0;
			});
		});

		angular.forEach(self.students, function(user) {
			if (user.units[self.currentUnit.uqid].send_result) {
				user.score = {
					success: 0,
					total: self.currentUnit.quizzes.length
				};

				user.quizzes = [];
				angular.forEach(self.currentUnit.quizzes, function(item, index) {
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

					angular.forEach(user.units[self.currentUnit.uqid].result.result, function(key) {
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

					user.quizzes.push(quiz);
				});
			}
		});
	}

	self.showTargetItemResult = function(item) {
		self.currentUnit.targetItem = item;

		$timeout(function() {
			$('#draw-board').html('<canvas></canvas>');
			$('#draw-board').literallycanvas({
				imageURLPrefix: '/library/literallycanvas/img',
				backgroundColor: 'rgba(0, 0, 0, 0)',
				primaryColor: '#f00'
			});

			$('#draw-board .custom-button').before(
				['<div id="draw-exit" class="btn btn-xs btn-primary" style="margin:-4px 4px 0">',
					'<span translate="K015"></span>',
				'</div>',
				'<div class="btn-group" style="margin:-4px 4px 0">',
					'<div id="draw-replay-high" class="btn btn-xs btn-primary">',
						'<span translate="K016"></span>',
					'</div>',
					'<div id="draw-replay-normal" class="btn btn-xs btn-primary">',
						'<span translate="K017"></span>',
					'</div>',
				'</div>'].join(''));

			var lc = $('#draw-board').literallyCanvasInstance();
			if (item.units[self.currentUnit.uqid].result !== null)
				lc.addShapes(item.units[self.currentUnit.uqid].result.result.strokes);

			$('#draw-exit').click(function() {
				$scope.$apply(function() {
					delete self.currentUnit.targetItem;
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

			if (self.currentUnit.content.description !== '') {
				self.drawDescription = self.currentUnit.content.description;

				$('#draw-board .custom-button').before('<div id="draw-description" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="K018"></span></div>');
				$('#draw-description').click(function() {
					$('#drawDescriptionModal').on('hidden.bs.modal', function() {
						delete self.drawDescription;
					});
					$('#drawDescriptionModal').modal('show');
				});
			}

			if (self.currentUnit.content.background !== '') {
				$('#draw-board .custom-button').before('<div id="draw-background" class="btn btn-xs btn-primary" style="margin:-4px 4px 0"><span translate="K019"></span></div>');
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

	self.showAddMemberBehavior = function(item) {
		self.targetMember = item;
		$("#memberBehaviorModal").modal('show');
	}

	self.addMemberBehavior = function(item) {
		var data = {
			memberUqid: self.targetMember.item_uqid,
			behaviorUqid: item.uqid
		};

		$http.post([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/memberBehaviors'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				self.targetMember.behavior_points = response.behavior_points;
				$("#memberBehaviorModal").modal('hide');

				self.socket.send( {
					poster: $utility.account.uqid,
					type: 'student-behavior-points-changed',
					message: {
						uqid: response.item_uqid,
						name: response.behavior.name,
						icon: response.behavior.icon,
						points: response.behavior.points
					}
				});

				delete self.targetMember;
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
		self.layout = 'content';
		self.whiteBoard = { show: false };
		self.lockedScreen = false;
		self.onlineStudents = 0;
		self.showBehavior = false;
		self.students = [];
		self.listBehavior();
		self.loadStatus(function() {
			self.loadStudents(function() {
				self.changeLayout('attendance');
			});
		});

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/teacherStatus'].join(''), { status: 'online' })
		.success(function(response, status) {});

		$scope.mainCtrl.toggleVisible(false);
		self.initWebSocket();
	}

	self.initWebSocket = function() {
		self.socket = new WebSocketRails(window.location.host + "/websocket");
		self.socket.channel = self.socket.subscribe(['1know-classroom-', self.target].join(''));
		self.socket.channel.bind('new_message', function(msg) {
			$scope.$apply(function() {
				if (msg.type === 'student-status-changed') {
					var onlineStudents = 0;

					angular.forEach(self.students, function(item) {
						if (item.uqid === msg.message.user_uqid) {
							item.online = (msg.message.status === 'online');
							item.status = msg.message.status;
						}
					});

					angular.forEach(self.students, function(item) {
						if (item.online)
							onlineStudents += 1;
					});

					self.onlineStudents = onlineStudents;
				}
				else if (msg.type === 'unit-study-result') {
					angular.forEach(self.students, function(item) {
						if (item.online && (item.uqid === msg.message.user_uqid)) {
							item.units[msg.message.unit_uqid].send_result = true;
						}
					});

					angular.forEach(self.units, function(unit) {
						unit.result_count = 0;
						angular.forEach(self.students, function(student) {
							if (student.online && student.units[msg.message.unit_uqid].send_result) {
								if (unit.uqid === msg.message.unit_uqid)
									unit.result_count += 1;
							}
						});
					});

					self.loadResult();
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
				type: 'teacher-status-changed',
				message: 'online'
			});

			self.attendance();
		},1000);

		$interval(function(){
			console.log(self.socket.state);
			if (self.socket.state == 'disconnected') self.socket.on_close('');
		}, 1000);
	}

	self.leaveClassroom = function() {
		$location.path(['/join/group/', self.target].join(''));
	}

	self.changeSize = function() {
		self.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
		self.contentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 38;

		self.contentWidth = self.contentWidth < 970 ? 970 : self.contentWidth;
		self.contentHeight = self.contentHeight < 640 ? 640 : self.contentHeight;

		if ($('#teach-white-board canvas').length === 1) {
			$('#teach-white-board canvas').attr({ 'width': self.contentWidth, 'height': self.contentHeight });
			$('#teach-white-board canvas').css({ 'width': self.contentWidth, 'height': self.contentHeight });
			if ($('#teach-white-board').literallyCanvasInstance() !== undefined)
				$('#teach-white-board').literallyCanvasInstance().repaint();
		}

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
			type: 'teacher-status-changed',
			message: 'offline'
		});

		$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/teacherStatus'].join(''), { status: 'offline' })
		.success(function(response, status) {});
	}

	$scope.$location = $location;
	$scope.$watch('$location.path()', function() {
		if ($location.path() !== ['/join/group/', $routeParams.t, '/teach'].join('')) {
			self.socket.send( {
				poster: $utility.account.uqid,
				type: 'teacher-status-changed',
				message: 'offline'
			});

			$http.put([$utility.SERVICE_URL, '/classroom/', self.target, '/teach/teacherStatus'].join(''), { status: 'offline' })
			.success(function(response, status) {});
		}
	});

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})