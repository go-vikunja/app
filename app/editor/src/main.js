import './polyfills.js'
import {createBridge} from './bridge.js'

const bridge = createBridge({
  mount: document.getElementById('editor'),
  root: document.documentElement,
  post: text => window.RuranaEditor?.postMessage(text),
})

Object.defineProperty(window, 'rurana', {
  value: Object.freeze({receive: bridge.receive}),
  enumerable: false,
  configurable: false,
  writable: false,
})

window.addEventListener('resize', bridge.keepCaretVisible)

document.addEventListener(
  'click',
  event => {
    if (event.target?.closest?.('a')) event.preventDefault()
  },
  true,
)

// The app's channel object is injected by the WebView before the page
// loads; waiting a little covers a platform that injects it later.
function announce(attempt) {
  if (window.RuranaEditor) bridge.ready()
  else if (attempt < 100) setTimeout(() => announce(attempt + 1), 50)
}
announce(0)
