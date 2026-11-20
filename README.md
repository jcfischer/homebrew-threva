# homebrew-threva

Homebrew tap for [Threva](https://github.com/jcfischer/threva-app).

```sh
brew install jcfischer/threva/threva
threva setup
```

The formula installs a tagged threva-app release, the pinned Cortex release and the cortex-desk-adapters release. It builds the macOS calendar and reminder adapters into `$(brew --prefix)/var/threva/bin`, and copies the untouched threva-app and Cortex source archives to `$(brew --prefix)/opt/threva/share/threva/source`.
