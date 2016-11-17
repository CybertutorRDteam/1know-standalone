var _1know = angular.module('1know', ['ngRoute', 'ngAnimate', 'pascalprecht.translate', 'mgcrea.ngStrap'])
.config(function($routeProvider, $locationProvider, $sceProvider, $translateProvider) {
	$routeProvider
		.when('/', {
			redirectTo: '/discover'
		})
		.when('/discover', {
			templateUrl: ['/template/discovery.html?', Date.now()].join(''),
			controller: 'DiscoveryCtrl',
			controllerAs: 'discoveryCtrl'
		})
		.when('/discover/:t', {
			templateUrl: ['/template/discovery.html?', Date.now()].join(''),
			controller: 'DiscoveryCtrl',
			controllerAs: 'discoveryCtrl'
		})
		.when('/discover/:t/:c', {
			templateUrl: ['/template/discovery.html?', Date.now()].join(''),
			controller: 'DiscoveryCtrl',
			controllerAs: 'discoveryCtrl'
		})
		.when('/learn', {
			templateUrl: ['/template/learning.html?', Date.now()].join(''),
			controller: 'LearningCtrl',
			controllerAs: 'learningCtrl'
		})
		.when('/learn/:t', {
			templateUrl: ['/template/learning.html?', Date.now()].join(''),
			controller: 'LearningCtrl',
			controllerAs: 'learningCtrl'
		})
		.when('/learn/:c/:t', {
			templateUrl: ['/template/watch.html?', Date.now()].join(''),
			controller: 'WatchCtrl',
			controllerAs: 'watchCtrl'
		})
		.when('/join', {
			templateUrl: ['/template/community.html?', Date.now()].join(''),
			controller: 'CommunityCtrl',
			controllerAs: 'communityCtrl'
		})
		.when('/join/:t', {
			templateUrl: ['/template/community.html?', Date.now()].join(''),
			controller: 'CommunityCtrl',
			controllerAs: 'communityCtrl'
		})
		.when('/join/:c/:t', {
			templateUrl: ['/template/classroom.html?', Date.now()].join(''),
			controller: 'ClassroomCtrl',
			controllerAs: 'classroomCtrl'
		})
		.when('/create', {
			templateUrl: ['/template/creation.html?', Date.now()].join(''),
			controller: 'CreationCtrl',
			controllerAs: 'creationCtrl'
		})
		.when('/create/:t', {
			templateUrl: ['/template/creation.html?', Date.now()].join(''),
			controller: 'CreationCtrl',
			controllerAs: 'creationCtrl'
		})
		.when('/create/knowledge/:t', {
			templateUrl: ['/template/modify_knowledge.html?', Date.now()].join(''),
			controller: 'ModifyKnowledgeCtrl',
			controllerAs: 'modifyKnowledgeCtrl'
		})
		.when('/create/channel/:t', {
			templateUrl: ['/template/modify_channel.html?', Date.now()].join(''),
			controller: 'ModifyChannelCtrl',
			controllerAs: 'modifyChannelCtrl'
		})
		.when('/join/group/:t/teach', {
			templateUrl: ['/template/synchronous_teach.html?', Date.now()].join(''),
			controller: 'SynchronousTeachCtrl',
			controllerAs: 'syncTeachCtrl',
		})
		.when('/join/group/:t/study', {
			templateUrl: ['/template/synchronous_study.html?', Date.now()].join(''),
			controller: 'SynchronousStudyCtrl',
			controllerAs: 'syncStudyCtrl',
		})
		.when('/personal', {
			templateUrl: ['/template/personal.html?', Date.now()].join(''),
			controller: 'PersonalCtrl',
			controllerAs: 'personalCtrl'
		})
		.when('/background', {
			templateUrl: ['/template/background.html?', Date.now()].join(''),
			controller: 'BackgroundCtrl',
			controllerAs: 'backgroundCtrl'
		})
		.otherwise({
			redirectTo: '/'
		});

	$locationProvider.hashPrefix('!');
	$sceProvider.enabled(false);

	//$translateProvider.translations('zh-tw', translations['zh-tw']);
	$translateProvider.translations('zh-cn', translations['zh-cn']);
	$translateProvider.translations('en-us', translations['en-us']);
	// $translateProvider.translations('es-ar', translations['es-ar']);
	// $translateProvider.translations('es-pe', translations['es-pe']);
	// $translateProvider.translations('de-de', translations['de-de']);
})
.factory('$utility', function($location) {
	var self = {
		account: 'NotLogin',
		BASE_URL: location.origin,
		SERVICE_URL: [location.origin, '/private'].join(''),
		GOOGLE_CLIEND_ID: 'xxxxxxxxxxxx.apps.googleusercontent.com',
		GOOGLE_DEVELOPER_KEY: 'xxxxxxxxxxxx',
		GOOGLE_OAUTH_TOKEN: null,
		GOOGLE_OAUTH_SCOPE: ['https://www.googleapis.com/auth/drive'],
		LANGUAGE: {
			title: 'English',
			type: 'en-us'
		},

		detectmobile: function() {
			if (navigator.userAgent.match(/Android/i) || navigator.userAgent.match(/webOS/i) || navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/iPad/i) || navigator.userAgent.match(/iPod/i) || navigator.userAgent.match(/BlackBerry/i) || navigator.userAgent.match(/Windows Phone/i)) {
				return true;
			} else {
				return false;
			}
		},

		timeToDesc: function(time) {
			var timeDesc = '';

			if (time !== null && time !== '') {
				var now = new Date();
				var date = new Date(time);

				var timeDiff = now - date;
				timeDesc = [
					Math.floor(timeDiff / 1000 / 60 / 60 / 24),
					Math.floor(timeDiff / 1000 / 60 / 60),
					Math.floor(timeDiff / 1000 / 60),
					Math.floor(timeDiff / 1000)
				]

				if (timeDesc[0] >= 1)
					timeDesc = time.substr(0, 10);
				else if (now.getDate() - date.getDate() === 1 || now.getDate() - date.getDate() < 0)
					timeDesc = [translations[this.LANGUAGE.type]['A030'], date.toLocaleTimeString()].join(' ');//昨天
				else if (timeDesc[1] > 0)
					timeDesc = [timeDesc[1], translations[this.LANGUAGE.type]['A031']].join(' ');//小時前
				else if (timeDesc[2] > 0)
					timeDesc = [timeDesc[2], translations[this.LANGUAGE.type]['A032']].join(' ');//分鐘前
				else if (timeDesc[3] > 0)
					timeDesc = [timeDesc[3], translations[this.LANGUAGE.type]['A033']].join(' ');//秒前
				else
					timeDesc = translations[this.LANGUAGE.type]['A034'];//剛才
			}

			return timeDesc;
		},

		timeToFormat: function(time) {
			if (time !== null && time !== '') {
				time = Math.ceil(time);

				var format_time = [Math.floor(time / 3600), Math.floor((time % 3600) / 60), (time % 60)];
				format_time[0] = format_time[0] > 0 && format_time[0] < 10 ? ['0', format_time[0], ':'].join('') : (format_time[0] >= 10 ? [format_time[0], ':'].join('') : '');
				format_time[1] = format_time[1] > 0 && format_time[1] < 10 ? ['0', format_time[1], ':'].join('') : (format_time[1] >= 10 ? [format_time[1], ':'].join('') : '00:');
				format_time[2] = format_time[2] > 0 && format_time[2] < 10 ? ['0', format_time[2], ''].join('') : (format_time[2] >= 10 ? [format_time[2], ''].join('') : '00');

				return format_time.join('');
			} else
				return '';
		},

		chooseGoogleFile: function(elementId, callback) {
			if (self.GOOGLE_OAUTH_TOKEN === null) {
				gapi.auth.authorize({
					'client_id': self.GOOGLE_CLIEND_ID,
					'scope': self.GOOGLE_OAUTH_SCOPE,
					'immediate': false
				}, function(token) {
					if (token && !token.error) {
						self.GOOGLE_OAUTH_TOKEN = token.access_token;
						self.chooseGoogleFile(elementId, callback);
					}
				});
			} else {
				var picker = new google.picker.PickerBuilder()
					.addView(google.picker.ViewId.DOCS)
					.addView(new google.picker.DocsUploadView())
					.enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
					.setOAuthToken(self.GOOGLE_OAUTH_TOKEN)
					.setDeveloperKey(self.GOOGLE_DEVELOPER_KEY)
					.build();
				picker.setVisible(true);

				if (callback)
					picker.setCallback(callback);
			}
		},

		chooseDropboxFile: function(elementId, callback) {
			var options = {
				linkType: "preview",
				multiselect: true,
				success: callback || function(files) {},
				cancel: function() {}
			};

			Dropbox.choose(options);
		}
	}

	return self;
})
.directive('main', function() {
	return {
		templateUrl: ['/template/main.html?', Date.now()].join(''),
		controller: 'MainCtrl',
		controllerAs: 'mainCtrl',
		restrict: 'E'
	}
})
.directive("mathjaxBind", function() {
	return {
		restrict: "A",
		controller: ["$scope", "$element", "$attrs",
			function($scope, $element, $attrs) {
				$scope.$watch($attrs.mathjaxBind, function(texExpression) {
					var texScript = angular.element("<script type='math/tex'>").html(texExpression ? texExpression :  "");
					$element.html("");
					$element.append(texScript);
					MathJax.Hub.Queue(["Reprocess", MathJax.Hub, $element[0]]);
				});
			}
		]
	};
})
.controller('MainCtrl', function($scope, $http, $location, $timeout, $translate, $compile, $utility, $window) {
	var self = this;

	self.web_name = $window.web_name;
	self.logo = $window.logo;
	self.copyright = $window.copyright;
	self.service_email = $window.service_email;

	self.password = {};
	self.auth_url = [$utility.BASE_URL, '/oauth/ischool'].join('');
	self.visible = true;

	self.toggleVisible = function(visible) {
		self.visible = visible;
	}

	self.showShareModal = function(target, type) {
		if (type === 'group') {
			self.shareTarget = {
				uqid: target.uqid,
				name: target.name,
				page: target.page,
				langing_page: target.page,
				encodePage: encodeURIComponent(target.page),
				embed: {
					width: 800,
					height: 600,
					code: ['<iframe width="800" height="600" src="', target.page, '" frameborder="0" allowfullscreen></iframe>'].join('')
				},
				email: {
					user: '',
					memo: ''
				},
				type: 'social',
				shareType: 'group'
			};

			$('#shareModal').modal('show');
		} else if (type === 'channel') {
			self.shareTarget = {
				uqid: target.uqid,
				name: target.name,
				page: target.page,
				langing_page: target.page,
				encodePage: encodeURIComponent(target.page),
				embed: {
					width: 800,
					height: 600,
					code: ['<iframe width="800" height="600" src="', target.page, '" frameborder="0" allowfullscreen></iframe>'].join('')
				},
				email: {
					user: '',
					memo: ''
				},
				type: 'social',
				shareType: 'channel'
			};

			$('#shareModal').modal('show');
		} else if (type === 'knowledge') {
			$http.get([$utility.SERVICE_URL, '/discovery/knowledges/', target.uqid, '/units'].join(''))
				.success(function(response, status) {
					self.shareTarget = {
						uqid: target.uqid,
						name: target.name,
						langing_page: target.page,
						base_page: target.share_page,
						page: target.share_page,
						encodePage: encodeURIComponent(target.share_page),
						embed: {
							width: 800,
							height: 600,
							code: ['<iframe width="800" height="600" src="', target.share_page, '" frameborder="0" allowfullscreen></iframe>'].join('')
						},
						email: {
							user: '',
							memo: ''
						},
						shareNote: false,
						units: response,
						shareUnit: response[0],
						type: 'social',
						shareType: 'knowledge'
					};

					self.changeShareParams(response[0]);
					$('#shareModal').modal('show');
				});
		}
	}

	self.changeShareEmbed = function() {
		self.shareTarget.embed.code = ['<iframe width="', self.shareTarget.embed.width, '" height="', self.shareTarget.embed.height, '" src="', self.shareTarget.page, '" frameborder="0" allowfullscreen></iframe>'].join('');
	}

	self.changeShareParams = function(unit) {
		if (unit)
			self.shareTarget.shareUnit = unit;

		if (self.shareTarget.shareNote)
			self.shareTarget.page = [self.shareTarget.base_page, '&u=', self.shareTarget.shareUnit.uqid, '&n=', self.account.uqid].join('');
		else
			self.shareTarget.page = [self.shareTarget.base_page, '&u=', self.shareTarget.shareUnit.uqid].join('');

		self.shareTarget.encodePage = encodeURIComponent(self.shareTarget.page);
		self.shareTarget.embed.code = ['<iframe width="', self.shareTarget.embed.width, '" height="', self.shareTarget.embed.height, '" src="', self.shareTarget.page, '" frameborder="0" allowfullscreen></iframe>'].join('');
	}

	self.sendShareEmail = function() {
		if (self.shareTarget.email.user !== undefined && self.shareTarget.email.user !== '') {
			var data = {
				url: self.shareTarget.page,
				uqid: self.shareTarget.uqid,
				email: self.shareTarget.email.user,
				memo: self.shareTarget.email.memo,
				type: self.shareTarget.shareType
			};

			$http.post([$utility.SERVICE_URL, '/utility/sendMail'].join(''), data)
				.success(function(response, status) {
					$('#shareModal').modal('hide');
				});
		}
	}

	self.changeLanguage = function(lang) {
		lang = lang.toLowerCase();

		if (lang === 'code')
			lang = {title: 'Language Code',type: 'code'};
		// else if (lang === 'zh-tw')
		// 	lang = {title: '繁體中文',type: 'zh-tw'};
		else if (lang === 'zh-cn')
			lang = {title: '简体中文',type: 'zh-cn'};
		else if (lang === 'en-us')
			lang = {title: 'English',type: 'en-us'};
		// else if (lang === 'es-ar')
		// 	lang = {title: 'Español (Argentina)',type: 'es-ar'};
		// else if (lang === 'es-pe')
		// 	lang = {title: 'Español (Perú)',type: 'es-pe'};
		// else if (lang === 'de-de')
		// 	lang = {title: 'Deutsch',type: 'de-de'};
		else
			lang = {title: '简体中文',type: 'zh-cn'};

		$utility.LANGUAGE.title = lang.title;
		$utility.LANGUAGE.type = lang.type;
		self.language = $utility.LANGUAGE;

		$translate.uses(lang.type);

		if (lang !== 'code') {
			$http.put([$utility.SERVICE_URL, '/personal/profile'].join(''), {language: JSON.stringify(lang)})
			.success(function(response, status) {});
		}
	}

	self.showChangePassowrd = function() {
		$('#changePasswordModal').modal('show');
		$('#changePasswordModal').on('hidden.bs.modal', function() {
			self.password = {};
		});
	}

	self.changePassword = function() {
		if (self.password.old === undefined || self.password.old === '' ||
			self.password.new === undefined || self.password.new === '')
			self.password.message = translations[$utility.LANGUAGE.type]['A035'];//密碼不可為空白!
		else if (self.password.new.length < 6)
			self.password.message = translations[$utility.LANGUAGE.type]['A036'];//密碼太短!
		else if (self.password.new !== undefined && self.password.new !== '' &&
			self.password.confirm !== undefined && self.password.confirm !== '' &&
			self.password.new === self.password.confirm) {
			delete self.password.message;

			var data = {
				oldpassword: self.password.old,
				newpassword: self.password.new
			};

			$http.put([$utility.SERVICE_URL, '/personal/password'].join(''), data)
				.success(function(response, status) {
					if (!response.error) {
						self.password.message = translations[$utility.LANGUAGE.type]['A037'];//修改完成!
						self.password.change = true;
					} else
						self.password.message = response.error;
				});
		} else
			self.password.message = translations[$utility.LANGUAGE.type]['A038'];//新密碼不一樣!
	}

	self.signout = function() {
		$(document.body).append('<iframe id="logout" style="display:none;"></iframe>');
		$('iframe#logout').attr('src', 'https://auth.ischoolcenter.com/logout.php');
		$('iframe#logout').load(function() {
			$('iframe#logout').remove();
			$http.post([$utility.BASE_URL, '/account/logout'].join(''))
			.success(function(response, status) {
				window.location.href = $utility.BASE_URL;
			});
		});
	}

	self.getUserInfo = function() {
		$http.get([$utility.BASE_URL, '/account/user'].join(''))
			.success(function(response, status) {
				if (!response.error) {
					$utility.account = response;
					self.account = $utility.account;

					if ($utility.account.language === null) {
						//var lang = 'en-us';
						var lang = 'zh-cn';
						if (window.navigator.language !== undefined)
							lang = window.navigator.language.toLowerCase();
						else if (window.navigator.systemLanguage !== undefined)
							lang = window.navigator.systemLanguage.toLowerCase();

						self.changeLanguage(lang);
					} else {
						$utility.LANGUAGE.title = response.language.title;
						$utility.LANGUAGE.type = response.language.type.toLowerCase();
						self.language = $utility.LANGUAGE;

						$translate.uses($utility.LANGUAGE.type);
					}

					if ($location.path() === '/')
						$location.path('/discover');
				} else {
					$utility.account = 'NotLogin';
					$location.path('/');
				}
			});
	}

	//var lang = 'en-us';
	var lang = 'zh-cn';
	if (window.navigator.language !== undefined)
		lang = window.navigator.language.toLowerCase();
	else if (window.navigator.systemLanguage !== undefined)
		lang = window.navigator.systemLanguage.toLowerCase();

	if (lang === 'code')
		lang = {title: 'Language Code',type: 'code'};
	// else if (lang === 'zh-tw')
	// 	lang = {title: '繁體中文',type: 'zh-tw'};
	else if (lang === 'zh-cn')
		lang = {title: '简体中文',type: 'zh-cn'};
	else if (lang === 'en-us')
		lang = {title: 'English',type: 'en-us'};
	// else if (lang === 'es-ar')
	// 	lang = {title: 'Español (Argentina)',type: 'es-ar'};
	// else if (lang === 'es-pe')
	// 	lang = {title: 'Español (Perú)',type: 'es-pe'};
	// else if (lang === 'de-de')
	// 	lang = {title: 'Deutsch',type: 'de-de'};
	else
		lang = {title: '简体中文',type: 'zh-cn'};

	$translate.uses(lang.type);

	$scope.$location = $location;
	$scope.$watch('$location.path()', function() {
		self.toggleVisible(true);
	});

	self.getUserInfo();
})
