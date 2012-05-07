dropbox = new Dropbox

success = (response) ->
    console.log response

failure = (response) ->
    console.log "Error", response

dropbox.authorize () ->
    dropbox.metadata()
    .then(success)
    .fail(failure)

    dropbox.search("", query: "me.jpg")
    .then(success)
    .fail(failure)

    dropbox.put_file("example.txt", null, "text content")
    .then(success)
    .fail(failure)
