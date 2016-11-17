var _1know = angular.module('1know', ['ngRoute', 'ngAnimate', 'pascalprecht.translate'])
		.config(function($routeProvider, $locationProvider, $sceProvider, $translateProvider) {
			$routeProvider
				.when('/activation_code', {
					templateUrl: ['/template/activation_code.html?', Date.now()].join(''),
					// templateUrl: ['/template/welcome_code.html?', Date.now()].join(''),
					controller: 'ActivationCodeCtrl'
				})
				.when('/', {
					redirectTo: '/activation_code'
				})
				.otherwise({
					redirectTo: '/'
				});

			$locationProvider.hashPrefix('!');
			$sceProvider.enabled(false);

			$translateProvider.translations('zh-cn', translations['zh-cn']);
		})
.controller('ActivationCodeCtrl', function($scope, $http, $translate, $timeout, $window) {
	$scope.web_name = $window.web_name;
	$scope.logo = $window.logo;
	$scope.copyright = $window.copyright;
	$scope.service_email = $window.service_email;

	$scope.sendACode = function() {
		$scope.isActivateSuccess = false;
		$scope.hasError = false;
		$http.post('/account/setACode', {"code": $scope.a_code}).
		  success(function(data, status, headers, config) {
		  	if (data.err) {
		  		$scope.errMsg = data.err;
		  		$scope.hasError = true;
		  		//alert(data.err);
		  	}
		  	else {
		  		$scope.isActivateSuccess = true;
		  		$scope.exp_date = data.user.expired_date;
		  		//window.location.href="/";
		  		$scope.hasError = false;
		  	}
		  }).
		  error(function(data, status, headers, config) {
		    // called asynchronously if an error occurs
		    // or server returns response with an error status.
		    	$scope.hasError = true;
		  });
	}

	$scope.signout = function() {
		$(document.body).append('<iframe id="logout" style="display:none;"></iframe>');
		$('iframe#logout').attr('src', 'https://auth.ischoolcenter.com/logout.php');
		$('iframe#logout').load(function() {
			$('iframe#logout').remove();
			$http.post( '/account/logout')
			.success(function(response, status) {
				window.location.href = '/';
			});
		});
	}

	$scope.getUserInfo = function() {
		$http.get('/account/user')
			.success(function(response, status) {
				if (!response.error) {

					$scope.account = response;

					if ($scope.account.language === null) {
						var lang = 'en-us';

						if (window.navigator.language !== undefined)
							lang = window.navigator.language.toLowerCase();
						else if (window.navigator.systemLanguage !== undefined)
							lang = window.navigator.systemLanguage.toLowerCase();

						// $scope.changeLanguage(lang);
						var lang2 = {title: '简体中文',type: 'zh-cn'};
						$http.put(['/private', '/personal/profile'].join(''), {language: JSON.stringify(lang2)})
							.success(function(response, status) {
								$scope.account.photo = response.photo + '?' + Date.now();
							});
					} else {
						var lang = {};
						lang.title = response.language.title;
						lang.type = response.language.type.toLowerCase();
						$scope.language = lang;

						$translate.uses(lang.type);
					}

				}
		});

	}
	lang = {title: '简体中文',type: 'zh-cn'};
	$translate.uses(lang.type);

	$scope.getUserInfo();
});

