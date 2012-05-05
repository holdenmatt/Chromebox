dropbox = new Dropbox
dropbox.authorize () ->
    dropbox.getAccount (data) ->
        console.log data
