oauth = new OAuthWrapper
oauth.authorize () ->
    oauth.getAccount (data) ->
        console.log data
