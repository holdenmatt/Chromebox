# WARNING: consumer key/secret shouldn't appear in insecure code like this.
# TODO (Dropbox): Upgrade to OAuth 2.0.
CONSUMER_KEY = "5y95sf8dgsiov5q"
CONSUMER_SECRET = "xq3uvt45e1imrzi"

dropbox = new Dropbox CONSUMER_KEY, CONSUMER_SECRET
failure = (response) ->
    console.log "Error", response

dropbox.authorize().fail(failure).then () ->
    dropbox.metadata()
    .then (response) ->
        console.log "metadata", response
    .fail failure

    dropbox.search("", query: "me.jpg")
    .then (response) ->
        console.log "search", response
    .fail failure

    dropbox.put_file("example.txt", null, "text content")
    .then (response) ->
        console.log "put_file", arguments
        dropbox.get_file("example.txt")
        .then (response) ->
            console.log "get_file", arguments
    .fail failure
