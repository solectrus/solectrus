function importAll(r) {
  r.keys().forEach(r)
}

importAll(require.context("../components", true, /component.js$/))
