var _1know;

if (!$.browser.msie && !$.browser.webkit && !$.browser.mozilla) {
	alert('抱歉，您目前使用的浏览器不支援1know的HTML5使用环境，建议使用Internet Explorer 11以上版本或Google Chrome 43.0以上版本，若您是使用360浏览器，请切换为"极速模式"，以便能正常显示。谢谢。');
} else if ($.browser.msie && $.browser.version < 10) {
	alert('抱歉，您目前使用的浏览器不支援1know的HTML5使用环境，建议使用Internet Explorer 11以上版本或Google Chrome 43.0以上版本，若您是使用360浏览器，请切换为"极速模式"，以便能正常显示。谢谢。');
} else if ($.browser.webkit && $.browser.version < 43) {
	alert('抱歉，您目前使用的浏览器不支援1know的HTML5使用环境，建议使用Internet Explorer 11以上版本或Google Chrome 43.0以上版本，若您是使用360浏览器，请切换为"极速模式"，以便能正常显示。谢谢。');
} else {
	_1know = angular.module('1know', ['ngRoute', 'ngAnimate', 'pascalprecht.translate'])
		.config(function($routeProvider, $locationProvider, $sceProvider, $translateProvider) {
			$routeProvider
				.when('/', {
					templateUrl: ['/template/welcome.html?', Date.now()].join(''),
					// templateUrl: ['/template/welcome_code.html?', Date.now()].join(''),
					controller: 'WelcomeCtrl',
					controllerAs: 'welcomeCtrl'
				})
				.when('/oauth', {
					templateUrl: ['/template/welcome_oauth.html?', Date.now()].join(''),
					controller: 'WelcomeCtrl',
					controllerAs: 'welcomeCtrl'
				})
				.when('/code', {
					templateUrl: ['/template/welcome_code.html?', Date.now()].join(''),
					controller: 'WelcomeCtrl',
					controllerAs: 'welcomeCtrl'
				})
				.otherwise({
					redirectTo: '/'
				});

			$locationProvider.hashPrefix('!');
			$sceProvider.enabled(false);

			$translateProvider.translations('zh-cn', translations['zh-cn']);
			$translateProvider.translations('zh-tw', translations['zh-tw']);
			$translateProvider.translations('en-us', translations['en-us']);
		})
		.controller('WelcomeCtrl', function($scope, $http, $location, $timeout, $translate, $window) {
			var self = this;

			self.web_name = $window.web_name;
			self.hideSysIntroduce = $window.hide_sys_introduce;
			self.enableTrialAccount = $window.enable_trial_account;
			self.enableTempUseCode = $window.enable_tempuse_code;
			self.enableOauthLogin = $window.enable_oauth_login;
			self.enableDefaultLogin = $window.enable_default_login;
			self.logo = $window.logo;
			self.copyright = $window.copyright;
			self.service_email = $window.service_email;
			self.background = {img: $window.welcome_img, color: $window.welcome_color};
			var oauth_server = $window.oauth_server;
			self.BASE_URL = [$location.protocol(), '://', $location.host(), ($location.port() == 80 ? '' : ':' + $location.port())].join('');
			self.language = {
				title: 'English',
				type: 'en-us'
			};

			self.scrollTo = function() {
				$("html, body").animate({
					scrollTop: 658
				}, 1000);
			}

			var lang = $window.default_language;
			if (lang === 'code')
				lang = {title: 'Language Code',type: 'code'};
			else if (lang === 'zh-tw')
				lang = {title: '繁體中文',type: 'zh-tw'};
			else if (lang === 'zh-cn')
				lang = {title: '简体中文',type: 'zh-cn'};
			else if (lang === 'es-es')
				lang = {title: 'Español (Perú)',type: 'es-es'};
			else if (lang === 'de-de')
				lang = {title: 'Deutsch',type: 'de-de'};
			else
				lang = {title: 'English',type: 'en-us'};
			self.language = lang;
			$translate.uses(lang.type);

			self.account = 'NotLogin';

			window.onresize = function() {
				$scope.$apply(function() {
					self.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
					self.contentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 91;
				});
			}

			self.signinWithGuest = function() {
				$http.post([self.BASE_URL, '/account/guest'].join(''))
					.success(function(response, status) {
						window.location.reload();
					});
			}

			self.signinWithOauth = function() {
				var width = screen.width * 0.78;
				var height = 700;
				var top = (screen.height / 2) - (height / 2);
				var left = (screen.width / 2) - (width / 2);
				var target = [oauth_server, '/oauth2/authorize?client_id=', client_id, '&response_type=code&state=ischool_authbug_code&redirect_uri=', redirect_uri, '&scope=userinfo'].join('');

				window.open(target, '1409620722041', ['width=', width, ',height=', height, ',menubar=0,titlebar=0,status=0,top=', top, ',left=', left].join(''));
			}

			self.loginGuest = function(event) {
				if (event !== undefined)
					if (event.keyCode !== 13)
						return;

				if (self.guestCode === undefined || self.guestCode === '') return;

				$http.post([self.BASE_URL, '/account/switch'].join(''), {
						email: [self.guestCode, '@1know.net'].join('')
					})
					.success(function(response, status) {
						if (!response.error)
							window.location.reload();
					});
			}

			self.loginDefault = function(event){
				if (event !== undefined)
					if (event.keyCode !== 13)
						return;

				if (self.loginAccount === undefined || self.loginAccount.trim() === '') return;
				if (self.loginPassword === undefined || self.loginPassword.trim() === '') return;

				$http.post([self.BASE_URL, '/account/switch2'].join(''), {
						email: [self.loginAccount, '@dr-cloud.net'].join(''),
						pwd: self.loginPassword
					})
					.success(function(response, status) {
						window.location.reload();
					});
			}

			self.contentWidth = (window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth);
			self.contentHeight = (window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight) - 91;

			self.supportBrowser = true;
			if ($.browser.msie && $.browser.version < 11)
				self.supportBrowser = false;
			else if (!$.browser.msie && !$.browser.webkit && !$.browser.mozilla)
				self.supportBrowser = false;

		}).directive("resetBackground",function($timeout){
			return {
				scope: {
					bg: '=resetBackground'
				},
				link: function(scope,element,attr){
					$timeout(function(){
						var img = scope.bg;
						if(img){
							var mW = $(document).innerWidth();
							var mH = mW/2;
							$(element[0]).css('background', 'url('+img+') 0px 0px/cover no-repeat fixed');
							$(element[0]).animate({width: mW, height: mH},1000);
							$(element[0]).children().animate({'padding-top': mH/3+'px'},1000);
							console.log(mW,mH);
						}else{
							$(element[0]).css('background', 'url(/img/index_cover.png) 0px 0px/cover no-repeat fixed').height(600);
						}
					});
				}
			}
		});
}
