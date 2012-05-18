## OmniDropbox: Search your Dropbox files from the Chrome Omnibox.

- Runs as a Chrome extension background page.

- Authorize Dropbox access on extension install.

To install, download and open [OmniDropbox.crx](https://github.com/holdenmatt/OmniDropbox/blob/master/OmniDropbox.crx).

## Dropbox-sdk.js: a JavaScript client SDK for the Dropbox API.

- Handles OAuth, token storage, response parsing, etc.

- Requires cross-domain AJAX calls, so only intended in e.g. Chrome extensions
where this can be enabled.

Install coffeescript:
$ npm install -g coffee-script

Build/watch:
$ cd Dropbox-sdk.js
$ coffee -o libs/ -cw src/
