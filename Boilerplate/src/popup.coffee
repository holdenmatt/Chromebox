dropbox = new Dropbox
failure = (response) ->
    console.log "Error", response

dropbox.authorize () ->
    dropbox.metadata(
        (data) -> console.log data
        failure
    )

    params =
        query: "jpg"
    dropbox.search(
        (data) -> console.log data
        failure
        null
        params
    )

