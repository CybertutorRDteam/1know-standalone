_1know.controller('PersonalCtrl', function($scope, $http, $timeout, $utility) {
	var self = this;

	self.editPicture = function(type) {
		self.editPictureType = type;
		self.setImageEvent();

		$timeout(function() {
			if (type === 'photo')
				$('#input_photo').click();
			else if (type === 'banner')
				$('#input_banner').click();
		},100);
	}

	self.savePicture = function() {
		var data = {};
		if (self.editPictureType === 'photo')
			data.photo = self.profile.edit_photo;
		if (self.editPictureType === 'banner')
			data.banner = self.profile.edit_banner;

		$http.put([$utility.SERVICE_URL, '/personal/profile'].join(''), data)
		.success(function(response, status) {
			self.profile.photo = response.photo + '?' + Date.now();
			self.profile.banner = response.banner + '?' + Date.now();
			$utility.account.photo = self.profile.photo;

			$('#pictureModal').modal('hide');
		});
	}

	self.editProfile = function() {
		self.profile.edit_first_name = self.profile.first_name;
		self.profile.edit_last_name = self.profile.last_name;
		self.profile.edit_description = self.profile.description;

		if ($('#description').redactor() !== undefined)
			$('#description').redactor('destroy');

		$('#description').html(self.profile.edit_description);
		$('#description').redactor({
			iframe: true,
			buttons: ['formatting', '|', 'bold', 'italic', 'deleted', '|', 'unorderedlist', 'orderedlist', '|', 'image', 'video', 'link'],
			plugins: ['fontcolor', 'fontsize']
		});

		$('#profileModal').modal('show');
	}

	self.saveProfile = function() {
		var data = {
			first_name: self.profile.edit_first_name,
			last_name: self.profile.edit_last_name,
			description: $('#description').redactor('get')
		}

		$http.put([$utility.SERVICE_URL, '/personal/profile'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				self.profile.first_name = response.first_name;
				self.profile.last_name = response.last_name;
				self.profile.full_name = response.full_name;
				self.profile.description = response.description;

				$utility.account.first_name = response.first_name;
				$utility.account.last_name = response.last_name;
				$utility.account.full_name = response.full_name;

				$('#profileModal').modal('hide');
			}
		});
	}

	self.editSocial = function() {
		self.profile.edit_website = self.profile.website;
		self.profile.edit_facebook = self.profile.facebook;
		self.profile.edit_twitter = self.profile.twitter;

		$('#socialModal').modal('show');
	}

	self.saveSocial = function() {
		var data = {
			website: self.profile.edit_website,
			facebook: self.profile.edit_facebook,
			twitter: self.profile.edit_twitter
		}

		$http.put([$utility.SERVICE_URL, '/personal/profile'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				self.profile.website = response.website;
				self.profile.facebook = response.facebook;
				self.profile.twitter = response.twitter;

				$('#socialModal').modal('hide');
			}
		});
	}

	self.setImageEvent = function() {
		var inputFile;
		if (self.editPictureType === 'photo') inputFile = document.getElementById('input_photo');
		if (self.editPictureType === 'banner') inputFile = document.getElementById('input_banner');
		if (inputFile === undefined) return;

		inputFile.addEventListener('click', function() {this.value = null;}, false);
		inputFile.addEventListener('change', readData, false);

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

						$('#pictureModal #title').html(self.editPictureType === 'photo' ? 'Image maximum size (200x200)' : 'Image maximum size (1000x200)');
						$('#pictureModal #content').html(['<img src="', canvas.toDataURL(), '"/>'].join(''));
						$('#pictureModal').modal('show');

						var img = $('#pictureModal #content img')[0];
						var canvas = document.createElement('canvas');

						$('#pictureModal #content img').Jcrop({
							bgColor: 'black',
							bgOpacity: .6,
							setSelect: (self.editPictureType === 'photo' ? [0, 0, 200, 200] : [0, 0, 200, (200 * 200) / 1000]),
							aspectRatio: (self.editPictureType === 'photo' ? 1 : 1000/200),
							onSelect: imgSelect,
							onChange: imgSelect
						});

						function imgSelect(selection) {
							if (self.editPictureType === 'photo') {
								canvas.width = 200;
								canvas.height = 200;
							}
							else if (self.editPictureType === 'banner') {
								canvas.width = 1000;
								canvas.height = 200;
							}

							var ctx = canvas.getContext('2d');
							ctx.drawImage(img, selection.x, selection.y, selection.w, selection.h, 0, 0, canvas.width, canvas.height);

							if (self.editPictureType === 'photo')
								self.profile.edit_photo = canvas.toDataURL();
							else if (self.editPictureType === 'banner')
								self.profile.edit_banner = canvas.toDataURL();
						}
					}
				}
			})(file);
			reader.readAsDataURL(file);
		}
	}

	self.init = function() {
		$http.get([$utility.SERVICE_URL, '/personal/profile'].join(''))
		.success(function(response, status) {
			self.profile = response;
		});
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})