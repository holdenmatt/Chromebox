dropbox = new Dropbox
failure = (response) ->
    console.log "Error", response

dropbox.authorize () ->
    dropbox.metadata(
        (data) -> console.log data
        failure
    )

    params =
        query: "me.jpg"
    dropbox.search(
        (data) -> console.log data
        failure
        null
        params
    )

    dropbox.put_file(
        (data) -> console.log data
        failure
        "example.txt"
        null
        "text content"
    )
