// Generated by CoffeeScript 1.3.1
(function() {
  var oauth;

  oauth = new OAuthWrapper;

  oauth.authorize(function() {
    return oauth.getAccount(function(data) {
      return console.log(data);
    });
  });

}).call(this);
