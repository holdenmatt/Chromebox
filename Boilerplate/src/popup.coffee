dropbox = new Dropbox
failure = (response) ->
    console.log "Error", response

dropbox.authorize () ->
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
