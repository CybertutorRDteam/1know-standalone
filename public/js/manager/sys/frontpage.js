_1know.controller('FrontpageCtrl_mainCfg', function($scope, $http, $utility, $timeout) {
	var self = this;

	self.saveConfig = function() {
		$http({
			method: 'POST',
			url: [$utility.SERVICE_URL, '/sys/frontpage'].join(''),
			data: { "content": 
						$.extend(self.currentConfig,
							{'front_slider_obj': JSON.stringify($.map(self.slider,function(o){ if(o) return parseInt(o.id);}))},
							{'front_multiBanner_obj': JSON.stringify($.map(self.banner,function(o){ if(o) return parseInt(o.id);}))},
							{'front_tag_seq': JSON.stringify(self.tag_state)}
						)
				},
			async: false,
			cache: false,
			contentType: true,
			processData: true
		}).success(function(response, status) {
			if (response.error) {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
			}
			else {
				self.loadConfig();
				self.errMessage = '首頁配置_儲存成功';
				$('#errorMessageModal').modal('show');
			}
		});
	};

	self.loadConfig = function() {
		self.currentConfig = {};
		$http.get([$utility.SERVICE_URL, '/sys/frontpage'].join(''), {})
		.success(function(response, status) {
			if (!response.error) {
				response.forEach(function(item){
					switch (item.name) {
						case 'front_hide_default_discovery':
						case 'front_hide_search_banner':
						case 'front_multiBanner_activate':
						case 'front_slider_activate':
						case 'front_tagfunction_activate':
							self.currentConfig[item.name] = (item.content == 'true');
							break;
						case 'front_slider_obj':
							self.slider = angular.extend(new Array(3), JSON.parse(item.content));
							break;
						case 'front_multiBanner_obj':
							self.banner = angular.extend(new Array(2), JSON.parse(item.content));
							break;
						case 'front_tag_seq':
							self.tagSeq = JSON.parse(item.content);
						default:
							self.currentConfig[item.name] = item.content;
					}
				});
			}
			else {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
			}
			//change self.slider to real object for matching select's option(angular needed)
			$http.get([$utility.SERVICE_URL, '/sys/frontpage/objects'].join(''))
			.success(function(response){
				self.objectsStorage = [];
				if(!response.error){
					response.forEach(function(item){
						/*if(item.bImg != '')
							item.bigImg = '/images/frontobject/' + item.bImg;
						if(item.sImg != '')
							item.smallImg = '/images/frontobject/' + item.sImg;*/
						item.useForTag = (item.bTag == 'true' || (typeof item.bTag === 'boolean' && item.bTag));
						var index = $.inArray(item.id, self.slider);
						if( index > -1){ self.slider[index] = item; }
						index = $.inArray(item.id, self.banner);
						if( index > -1){ self.banner[index] = item; }
						index = $.inArray(item.id, self.tagSeq);
						if( index > -1){ item.seq = index; }
						self.objectsStorage.push(item);
					});
				}
			});
		});
	};

	self.checkValid = function(type){
		self[type].forEach(function(item,i){
			var index = $.inArray(item,self[type]);
			if( index != i){
				self[type][i] = null;
				self.errMessage = '首頁配置_設定重複';
				$('#errorMessageModal').modal('show');
				return false;
			}
		});
	}

	self.updateTagSeq = function(data) {
		for(var k in data){
			data[k] = parseInt(data[k]);
		}
		self.tag_state = data;
	};

	self.init = function() {
		self.objectsStorage = [];
		self.slider = new Array(3);
		self.banner = new Array(2);
		self.loadConfig();
		$('#errorMessageModal').on('hidden.bs.modal', function() {
			delete self.errMessage;
		});
	}

	self.init();
}).filter('activeOrNot',function(){
	return function(input){
		return input.useForTag;
	}
}).directive('sortable', function() {
	return {
		restrict: 'A',
		link: function(scope,element,attrs){
			var update = function(event,ui){
				var ul = $(event.target);
				if(ul.is('[need-record]')){
					scope.frontpageCtrl.updateTagSeq(ul.sortable('toArray'));
				}
			};
			element.sortable({
				cursor: "move",
				helper: 'clone',
				cancel: 'a',
				items: 'li',
				connectWith: attrs.connector,
				stop: update,
				receive: update,
			}).disableSelection();
		}
	}
});
/*--------------------------------------------------------------------------------------------------*/
_1know.service('anchorSmoothScroll', function(){
    
    this.scrollTo = function(eID) {  
        var startY = currentYPosition();
        var stopY = elmYPosition(eID);
        var distance = stopY > startY ? stopY - startY : startY - stopY;
        if (distance < 100) { scrollTo(0, stopY); return; }
        var speed = Math.round(distance / 100);
        if (speed >= 20) speed = 20;
        var step = Math.round(distance / 25);
        var leapY = stopY > startY ? startY + step : startY - step;
        var timer = 0;
        if (stopY > startY) {
            for ( var i=startY; i<stopY; i+=step ) {
                setTimeout("window.scrollTo(0, "+leapY+")", timer * speed);
                leapY += step; if (leapY > stopY) leapY = stopY; timer++;
            } return;
        }
        for ( var i=startY; i>stopY; i-=step ) {
            setTimeout("window.scrollTo(0, "+leapY+")", timer * speed);
            leapY -= step; if (leapY < stopY) leapY = stopY; timer++;
        }
        
        function currentYPosition() {
            // Firefox, Chrome, Opera, Safari
            if (self.pageYOffset) return self.pageYOffset;
            // Internet Explorer 6 - standards mode
            if (document.documentElement && document.documentElement.scrollTop)
                return document.documentElement.scrollTop;
            // Internet Explorer 6, 7 and 8
            if (document.body.scrollTop) return document.body.scrollTop;
            return 0;
        }
        
        function elmYPosition(eID) {
            var elm = document.getElementById(eID);
            var y = elm.offsetTop;
            var node = elm;
            while (node.offsetParent && node.offsetParent != document.body) {
                node = node.offsetParent;
                y += node.offsetTop;
            } return y - 50;
        }
    };
    
}).controller('FrontpageCtrl_objCfg', function($scope, $http, $location, $anchorScroll, $window, $timeout, $utility, anchorSmoothScroll) {
	var self = this;

	self.saveObject = function() {
		self.currentConfig.knowledges = $.map(self.currentConfig.knowledges,function(o){ return o.uqid; }).join(',');
		console.log(self.currentConfig);
		self.currentConfig.description = $('#front_object_description').redactor('get');
		$http({
			method: 'POST',
			url: [$utility.SERVICE_URL, '/sys/frontpage/objects'].join(''),
			data: { "content": self.currentConfig },
			async: false,
			cache: false,
			contentType: true,
			processData: true
		}).success(function(response, status) {
			if (response.error) {
				self.errMessage = response.error;
			}
			else {
				self.init();
				self.errMessage = '首頁配置_儲存成功';
			}
			$('#errorMessageModal').modal('show');
		});
	};

	self.searchKnowledage = function(kw){
		$http.post([$utility.SERVICE_URL, '/sys/frontpage/getKnowledage/'].join(''), {key: kw})
		.success(function(response, status) {
			if (response.error) {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
			}
			else {
				self.searchPool = [];
				var ary = [];
				$.each(self.currentConfig.knowledges, function(i,o){ ary.push(o.id); });
				$.grep(response.data, function(el){ 
					if ($.inArray(el.id, ary)==-1)
						self.searchPool.push(el); 
				});
			}
		});
	}
	self.toggleKnowledage = function(item){
		var inArray = false,tmp = null;
		$.each(self.currentConfig.knowledges, function(i,o){
			if(o.id == item.id){
				tmp = o;
				self.currentConfig.knowledges.splice(i,1);
				inArray = true;
				return false;
			}
		});
		if(!inArray){
			delete item.logo;
			self.currentConfig.knowledges.push(item);
		}
		self.searchKnowledage($scope.key);
	}
	self.loadObjects = function() {
		$http.get([$utility.SERVICE_URL, '/sys/frontpage/objects'].join(''))
		.success(function(response){
			if(!response.error){
				response.forEach(function(item){
					/*if(item.bImg != '')
						item.bigImg = '/images/frontobject/' + item.bImg;
					if(item.sImg != '')
						item.smallImg = '/images/frontobject/' + item.sImg;*/
					item.useForTag = (item.bTag == 'true' || (typeof item.bTag === 'boolean' && item.bTag));
					self.objects.push(item);
				});
			}
		});
	};

	self.focusItem = function(o){
		$scope.editCtrl = true;
		$scope.insertKey = '';
		self.currentConfig = angular.copy(o);
		self.initHtmlEditor('#front_object_description', self.currentConfig.description);
		$('#bigImg_container,#smallImg_container').html('');
		if(self.currentConfig.knowledges == null)
			self.currentConfig.knowledges = [];
		var wait = function(){
			if($('#editBlock:visible').length > 0){
				var id = $location.hash();
				$location.hash('editAnchor');
				anchorSmoothScroll.scrollTo('editAnchor');
				$location.hash(id);
			}else{
				$timeout(wait,100);
			}
		}
		if(self.currentConfig.bImg){
			$('#bigImg_container').html('<img src="/images/frontobject/'+self.currentConfig.bImg+'">');
		}
		if(self.currentConfig.sImg){
			$('#smallImg_container').html('<img src="/images/frontobject/'+self.currentConfig.sImg+'">');
		}
		wait();
	}

	self.reNew = function(){
		delete self.currentConfig.id;
		delete self.currentConfig.name;
		delete self.currentConfig.description;
		delete self.currentConfig.sImg;
		delete self.currentConfig.bImg;
		delete self.currentConfig.useForTag;
		self.initHtmlEditor('#front_object_description', '');
		self.currentConfig.knowledges = [];
		self.focusItem(self.currentConfig);
	}
	/*
	$window.cvImg = function(e){
		var target = $(e).data('for');
		var f = e.files[0];
		var FR = new FileReader();
		FR.onload = function(event){
			$(target).val(event.target.result);
			var $t = angular.element(target);
				$t.triggerHandler('input');
		};
		FR.readAsDataURL(f);
	}*/

	$scope.$watchCollection('insertKey', function(newValue, oldValue) {
		if(newValue.length == 0){
			self.searchPool = [];
			return false
		};
		if(newValue == oldValue) return false;
		var tmp = newValue.split('/');
		$scope.key = tmp[tmp.length-1];
		if(typeof $scope.insertRelay != "undefined")
			$timeout.cancel($scope.insertRelay);
		$scope.insertRelay = $timeout(
			function(){self.searchKnowledage($scope.key);
		}, 1000, false);
	});

	self.bindImgEvent = function(fn){
		$('#front_object_bigImg,#front_object_smallImg').on('change',readData);
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
						var input = $(evt.target);
						input.val('');
						var div = $(input.data('for')).html(['<img src="', canvas.toDataURL(), '"/>'].join(''));
						var cfg = input.data('edit');
						var img = div.find('img')[0];
						var canvas = document.createElement('canvas');
						$(img).Jcrop({
							bgColor: 'black',
							bgOpacity: .6,
							setSelect: [0, 0, 1024, 240],
		
							onSelect: imgSelect,
							onChange: imgSelect
						});

						function imgSelect(selection) {
							canvas.width = canvas.height = 200;
							var ctx = canvas.getContext('2d');
							ctx.drawImage(img, selection.x, selection.y, selection.w, selection.h, 0, 0, canvas.width, canvas.height);
							self.currentConfig[cfg] = canvas.toDataURL();
						}
					}
				}
			})(file);
			reader.readAsDataURL(file);
		}
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

	self.init = function() {
		$scope.editCtrl = false;
		self.objects = [];
		self.currentConfig = {};
		/*self.currentConfig = {
			knowledges: []
		};
		$('input[type=file]').val('');*/
		self.loadObjects();
		self.bindImgEvent();
		$('#errorMessageModal').on('hidden.bs.modal', function() {
			delete self.errMessage;
		});
	}
	
	self.init();
});