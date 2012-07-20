// WARNING: consumer key/secret shouldn't appear in insecure code like this.
// TODO (Dropbox): Upgrade to OAuth 2.0.
var CONSUMER_KEY = "ygaedmex8axw4m1",
    CONSUMER_SECRET = "qfnm462s4lrh9tr",
    dropbox = new Dropbox(CONSUMER_KEY, CONSUMER_SECRET, "dropbox");

dropbox.authorize().then(function () {

    chrome.omnibox.setDefaultSuggestion({
        description: "Search Dropbox"
    });

    chrome.omnibox.onInputChanged.addListener(function (text, suggest) {
        // Search Dropbox whenever we have non-empty text after our keyword.
        if (text) {
            var textPattern = new RegExp(text, "g");
            dropbox.search("/", {
                query: text,
                file_limit: 5
            }).then(function (results) {
                var suggestions = results.map(function (result) {

                    // Strip leading "/"
                    var path = result.path.replace(/^\//, "");

                    // Emphasize matching text
                    var description = path.replace(textPattern, function (match) {
                        return "<match>" + match + "</match>";
                    });

                    // Style file path as a URL
                    description = "<url>" + description + "</url>";

                    // Append file size for files only
                    if (!result.is_dir) {
                        description += " - <dim>" + result.size + "</dim>";
                    }

                    return {
                        content: path,
                        description: description
                    };
                });

                suggest(suggestions);
            });
        }
    });

    chrome.omnibox.onInputEntered.addListener(function (text) {
        if (text) {
            // Open the preview page when a file or folder is selected.
            dropbox.shares(text).then(function (response) {
                if (response.url) {
                    window.open(response.url);
                }
            });
        } else {
            // Open Dropbox home if the default suggestion (no text) is selected.
            window.open("http://dropbox.com");
        }
    });
});
