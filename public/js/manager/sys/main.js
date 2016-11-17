var _1know = angular.module('1know', ['ngRoute', 'ngAnimate', 'pascalprecht.translate', 'mgcrea.ngStrap'])
.config(function($routeProvider, $locationProvider, $sceProvider, $translateProvider) {
    $routeProvider
    // .when('/dashboard/index', {
    //   templateUrl: ['/template/manager/sys/dashboard.html?', Date.now()].join(''),
    //   controller: 'DashboardCtrl',
    //   controllerAs: 'dashboardCtrl'
    // })
    .when('/permission', {
      templateUrl: ['/template/manager/sys/permission.html?', Date.now()].join(''),
      controller: 'PermissionCtrl',
      controllerAs: 'permissionCtrl'
    })
    .when('/config', {
      templateUrl: ['/template/manager/sys/config.html?', Date.now()].join(''),
      controller: 'ConfigCtrl',
      controllerAs: 'configCtrl'
    })
    .otherwise({
      redirectTo: '/permission'
    });

    $locationProvider.hashPrefix('!');
    $sceProvider.enabled(false);

    $translateProvider.translations('zh-tw', translations['zh-tw']);
    $translateProvider.translations('zh-cn', translations['zh-cn']);
})
.factory('$utility', function($location) {
    var self = {
        account: 'NotLogin',
        BASE_URL: location.origin,
        SERVICE_URL: [location.origin, '/private'].join(''),
        LANGUAGE: {
            title: '简体中文',
            type: 'zh-cn'
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
        }
    }

    return self;
})
.directive('main', function() {
    return {
        templateUrl: ['/template/manager/sys/main.html?', Date.now()].join(''),
        controller: 'MainCtrl',
        controllerAs: 'mainCtrl',
        restrict: 'E'
    }
})
.controller('MainCtrl', function($scope, $http, $location, $timeout, $translate, $utility) {
    var self = this;
    self.visible = true;

    self.toggleVisible = function(visible) {
        self.visible = visible;
    }

    var lang = 'zh-cn';
    // if (window.navigator.language !== undefined)
    //     lang = window.navigator.language.toLowerCase();
    // else if (window.navigator.systemLanguage !== undefined)
    //     lang = window.navigator.systemLanguage.toLowerCase();

    if (lang === 'code')
        lang = {title: 'Language Code',type: 'code'};
    else if (lang === 'zh-tw')
        lang = {title: '繁體中文',type: 'zh-tw'};
    else
        lang = {title: '简体中文',type: 'zh-cn'};

    $translate.uses(lang.type);
    $utility.LANGUAGE.title = lang.title;
    $utility.LANGUAGE.type = lang.type;

    $scope.$location = $location;
    $scope.$watch('$location.path()', function() {
        self.toggleVisible(true);
    });
})
