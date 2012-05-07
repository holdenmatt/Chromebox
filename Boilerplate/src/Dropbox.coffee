#
# Dropbox.coffee
#
# A Dropbox API client for Javascript.
#

CONSUMER_KEY = "5y95sf8dgsiov5q"
CONSUMER_SECRET = "xq3uvt45e1imrzi"

ROOT_PATH = window.location.href.replace /[^\/]+\.html/, ""

URL =
    requestToken: "https://api.dropbox.com/1/oauth/request_token"
    authorize:    "https://www.dropbox.com/1/oauth/authorize"
    accessToken:  "https://api.dropbox.com/1/oauth/access_token"
    callback: ROOT_PATH + "oauth_callback.html"


toQueryString = (obj) ->
    encode = OAuth.urlencode
    params = []
    for own key, value of obj
        param = encode(key) + "=" + encode(value)
        params.push param

    return params.join("&")


buildUrl = (path, params) ->
    qs = toQueryString params
    if qs then path + "?" + qs else path


# Save tokens persistently in localStorage.
Tokens =
    TOKEN: "oauth_token"
    TOKEN_SECRET: "oauth_token_secret"

    get: () ->
        return [
            localStorage.getItem(Tokens.TOKEN)
            localStorage.getItem(Tokens.TOKEN_SECRET)
        ]

    set: (token, token_secret) ->
        localStorage.setItem(Tokens.TOKEN, token)
        localStorage.setItem(Tokens.TOKEN_SECRET, token_secret)

    exist: () ->
        tokens = Tokens.get()
        return tokens[0]? and tokens[1]?

    clear: () ->
        localStorage.removeItem(Tokens.TOKEN)
        localStorage.removeItem(Tokens.TOKEN_SECRET)


# Fetch and store an OAuth access token and secret.
class OAuthClient
    constructor: () ->
        @oauth = new OAuth
            consumerKey: CONSUMER_KEY
            consumerSecret: CONSUMER_SECRET
            requestTokenUrl: URL.requestToken
            authorizationUrl: URL.authorize
            accessTokenUrl: URL.accessToken

    showError: (message) ->
        alert "Error: #{message}"

    # If we have a saved access token, call a callback immediately.
    # Otherwise start the OAuth dance by fetching a request token and
    # redirecting to the authorize page.
    authorize: (callback) =>

        success = () =>
            [token, token_secret] = @oauth.getAccessToken()
            Tokens.set token, token_secret

            callback = encodeURIComponent URL.callback
            @oauth.setCallbackUrl URL.callback
            url = URL.authorize + "?oauth_token=#{token}&oauth_callback=#{callback}"
            window.open url

        error = (response) =>
            console.log response
            @showError "Failed to fetch a request token"

        if Tokens.exist()
            [token, token_secret] = Tokens.get()
            @oauth.setAccessToken token, token_secret
            callback()
        else
            @oauth.fetchRequestToken success, error

    # Exchange our request token/secret for a persistent access token/secret.
    # Private: this is called by the oauth_callback page after authorization.
    _fetchAccessToken: () =>

        closeSelectedTab = () ->
            chrome.tabs.getSelected null, (tab) ->
                chrome.tabs.remove tab.id

        success = () =>
            [token, token_secret] = @oauth.getAccessToken()
            Tokens.set token, token_secret
            closeSelectedTab()

        error = (response) =>
            console.log response
            @showError "Failed to fetch an access token"
            closeSelectedTab()

        if Tokens.exist()
            [token, token_secret] = Tokens.get()
            @oauth.setAccessToken token, token_secret
            @oauth.fetchAccessToken success, error
        else
            @showError "Failed to retrieve a saved access token"


class Dropbox extends OAuthClient

    API_VERSION: "1"
    API_HOST: "api.dropbox.com"
    API_CONTENT_HOST: "api-content.dropbox.com"

    # Set the root for this client ("dropbox" or "sandbox").
    constructor: (@root = "sandbox") ->
        super

    # Wrapper to make a single API request and parse the JSON response.
    # Args:
    #   success - Success callback.
    #   failure - Failure callback.
    #   target - The target URL with leading slash (e.g. '/metadata').
    #   data - Request data or parameters.
    #   method - An HTTP method (e.g. "PUT").
    #   contentHost - Boolean indicating whether this is a content server request.
    request: (success, failure, target, data = {}, method = "GET", contentHost = false, headers = {}) ->
        host = if contentHost then @API_CONTENT_HOST else @API_HOST
        target = escapePath target
        url = "https://#{host}/#{@API_VERSION}/#{target}"
        @oauth.request
            method: method
            url: url
            data: data
            headers: headers
            success: (data) -> success JSON.parse data.text
            failure: failure

        # TODO: x-dropbox-metadata

    # Return information about the user's account.
    account_info: (success, failure, params) =>
        @request success, failure, "/account/info", params

    get_file: (success, failure, path, params) =>
        @request success, failure, "/files/#{@root}/#{path}", params, "GET", true

    # Upload a file.
    # TODO: make this work with a screenshot; how to handle content-type?
    put_file: (success, failure, path, params, fileData) =>
        target = buildUrl "/files_put/#{@root}/#{path}", params
        headers =
            "Content-Type": "text/plain"

        @request success, failure, target, fileData, "PUT", true, headers

    metadata: (success, failure, path = "", params) =>
        target = "/metadata/#{@root}/#{path}"
        @request success, failure, target, params

    delta: (success, failure, params) =>
        target = "/delta"
        @request success, failure, target, params, "POST"

    revisions: (success, failure, path = "", params) =>
        target = "/revisions/#{@root}/#{path}"
        @request success, failure, target, params

    restore: (success, failure, path = "", params) =>
        target = "/restore/#{@root}/#{path}"
        @request success, failure, target, params, "POST"

    search: (success, failure, path = "", params) =>
        target = "/search/#{@root}/#{path}"
        @request success, failure, target, params

    shares: (success, failure, path = "", params) =>
        target = "/shares/#{@root}/#{path}"
        @request success, failure, target, params, "POST"

    media: (success, failure, path = "", params) =>
        target = "/media/#{@root}/#{path}"
        @request success, failure, target, params, "POST"

    copy_ref: (success, failure, path = "", params) =>
        target = "/copy_ref/#{@root}/#{path}"
        @request success, failure, target, params

    thumbnails: (success, failure, path = "", params) =>
        target = "/thumbnails/#{@root}/#{path}"
        @request success, failure, target, params, "GET", true

# Escape a path string as a URI component (but leave '/' alone).
escapePath = (path = "") ->
    path = encodeURIComponent(path)
        .replace(/%2F/g, "/")
        .replace(/^\/+|\/+$/g, "")  # Strip leading/trailing '/'


window.Dropbox = Dropbox
