#
# Dropbox.coffee
#
# A Dropbox API for Javascript.
#

CONSUMER_KEY = "5y95sf8dgsiov5q"
CONSUMER_SECRET = "xq3uvt45e1imrzi"

ROOT_PATH = window.location.href.replace /[^\/]+\.html/, ""

URL =
    requestToken: "https://api.dropbox.com/1/oauth/request_token"
    authorize:    "https://www.dropbox.com/1/oauth/authorize"
    accessToken:  "https://api.dropbox.com/1/oauth/access_token"
    callback: ROOT_PATH + "oauth_callback.html"


# Save tokens persistently in localStorage.
TOKEN_KEY = "oauth_token"
TOKEN_SECRET_KEY = "oauth_token_secret"
Tokens =
    get: () ->
        return [
            localStorage.getItem(TOKEN_KEY)
            localStorage.getItem(TOKEN_SECRET_KEY)
        ]

    set: (token, token_secret) ->
        localStorage.setItem(TOKEN_KEY, token)
        localStorage.setItem(TOKEN_SECRET_KEY, token_secret)

    exist: () ->
        tokens = Tokens.get()
        return tokens[0]? and tokens[1]?

    clear: () ->
        localStorage.removeItem(TOKEN_KEY)
        localStorage.removeItem(TOKEN_SECRET_KEY)


# Fetch and store an OAuth access token and secret.
class OAuthClient
    constructor: () ->
        @oauth = new OAuth
            consumerKey: CONSUMER_KEY
            consumerSecret: CONSUMER_SECRET
            requestTokenUrl: URL.requestToken
            authorizationUrl: URL.authorize
            accessTokenUrl: URL.accessToken
            callbackUrl: URL.callback

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
    #   params - Request parameters.
    #   method - An HTTP method (e.g. "PUT").
    #   contentHost - Boolean indicating whether this is a content server request.
    request: (success, failure, target, params = {}, method = "GET", contentHost = false) ->
        host = if contentHost then @API_CONTENT_HOST else @API_HOST
        url = "https://#{host}/#{@API_VERSION}#{target}"
        @oauth.request
            method: method
            url: url
            data: params
            success: (data) -> success JSON.parse data.text
            failure: failure

    account_info: (success, failure, params) =>
        @request success, failure, "/account/info", params

    metadata: (success, failure, path, params) =>
        path = escapePath path
        @request success, failure, "/metadata/#{@root}/#{path}", params

    search: (success, failure, path, params) =>
        path = escapePath path
        @request success, failure, "/search/#{@root}/#{path}", params


# Escape a path string as a URI component (but leave '/' alone).
escapePath = (path = "") ->
    path = encodeURIComponent(path)
        .replace(/%2F/g, "/")
        .replace(/^\/+|\/+$/g, "")  # Strip leading/trailing '/'


window.Dropbox = Dropbox
