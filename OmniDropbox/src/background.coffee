# WARNING: consumer key/secret shouldn't appear in insecure code like this.
# TODO (Dropbox): Upgrade to OAuth 2.0.
CONSUMER_KEY = "7dgdzqp9j5cqay3"
CONSUMER_SECRET = "fbs5cpk15qpl12o"
dropbox = new Dropbox CONSUMER_KEY, CONSUMER_SECRET, "dropbox"

dropbox.authorize().then () ->

    chrome.omnibox.setDefaultSuggestion
        description: "Search Dropbox"

    chrome.omnibox.onInputChanged.addListener (text, suggest) ->
        if text
            # Search Dropbox whenever we have non-empty text after our keyword.
            textPattern = new RegExp text, "g"
            dropbox.search "/",
                query: text
                file_limit: 5
            .then (results) ->
                suggestions = []
                for result in results
                    # Strip leading "/"
                    path = result.path.replace /^\//, ""
                    # Emphasize matching text
                    description = path.replace textPattern,
                        (match) -> "<match>#{match}</match>"
                    # Style file path as a URL
                    description = "<url>" + description + "</url>"
                    # Append file size for files only
                    if not result.is_dir
                        description += " - <dim>#{result.size}</dim>"
                    suggestions.push
                        content: path
                        description: description

                suggest suggestions

    chrome.omnibox.onInputEntered.addListener (text) ->
        if text
            # Open the preview page when a file or folder is selected.
            dropbox.shares(text)
            .then (response) ->
                if response.url
                    window.open response.url
        else
            # Open Dropbox home if the default suggestion (no text) is selected.
            window.open "http://dropbox.com"
