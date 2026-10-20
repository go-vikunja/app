// The page side of the protocol between the editor page and the app. The
// app's channel carries no origin, so every message after `init` carries
// the token the app chose for this load, both ways.
import {Editor} from '@tiptap/core'
import {isAllowedUri} from '@tiptap/extension-link'
import {createExtensions, linkProtocols} from './extensions.js'
import {httpBases, normalizeApiRoot} from './links.js'
import {applyTheme} from './theme.js'

const parseOptions = {preserveWhitespace: true}
const stateDelay = 50
const maxTableSize = 20
const languageTag = /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/
const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object, key)
const textOf = value => (typeof value === 'string' ? value : '')

export function createBridge({mount, post, root}) {
  let token = null
  let editor = null
  let baseline = null
  let mentionProps = null
  let lastMention = null
  let lastState = null
  let lastDirty = false
  let stateTimer = null
  let focused = false
  let pending = []

  const context = {
    taskLinkBases: [],
    apiRoot: '',
    placeholder: '',
    imageLabel: '',
    mention: {
      onStart: props => showMention(props),
      onUpdate: props => showMention(props),
      onExit: () => {
        mentionProps = null
        lastMention = null
        send({type: 'mentionEnd'})
      },
    },
  }

  function send(message) {
    post(JSON.stringify(token === null ? message : {...message, token}))
  }

  function showMention(props) {
    mentionProps = props
    let caret = {x: 0, y: 0, height: 0}
    try {
      const rect = props.clientRect?.()
      if (rect) caret = {x: rect.left, y: rect.top, height: rect.height}
    } catch {
      // Without layout there is no caret position; the app places the list.
    }
    const message = {type: 'mentionQuery', query: props.query ?? '', caret}
    const key = JSON.stringify(message)
    if (key === lastMention) return
    lastMention = key
    send(message)
  }

  function isDirty() {
    return !editor.state.doc.eq(baseline)
  }

  function stateMessage() {
    let heading = 0
    for (let level = 1; level <= 6 && heading === 0; level++) {
      if (editor.isActive('heading', {level})) heading = level
    }
    const link = editor.isActive('link')
    const href = link ? editor.getAttributes('link').href : null
    return {
      type: 'state',
      dirty: isDirty(),
      canUndo: editor.can().undo(),
      canRedo: editor.can().redo(),
      active: {
        bold: editor.isActive('bold'),
        italic: editor.isActive('italic'),
        underline: editor.isActive('underline'),
        strike: editor.isActive('strike'),
        code: editor.isActive('code'),
        highlight: false,
        heading,
        bulletList: editor.isActive('bulletList'),
        orderedList: editor.isActive('orderedList'),
        taskList: editor.isActive('taskList'),
        blockquote: editor.isActive('blockquote'),
        codeBlock: editor.isActive('codeBlock'),
        link,
        linkHref: typeof href === 'string' ? href : null,
        table: editor.isActive('table'),
      },
    }
  }

  function sendState({force = false} = {}) {
    clearTimeout(stateTimer)
    stateTimer = null
    if (editor === null) return
    const message = stateMessage()
    lastDirty = message.dirty
    const key = JSON.stringify(message)
    if (!force && key === lastState) return
    lastState = key
    send(message)
  }

  // A change of `dirty` goes at once: the app decides on it whether leaving
  // asks first.
  function scheduleState() {
    if (editor !== null && isDirty() !== lastDirty) sendState()
    else if (stateTimer === null) stateTimer = setTimeout(() => sendState(), stateDelay)
  }

  function init(message) {
    if (typeof message.token !== 'string' || message.token === '') return
    if (token !== null && message.token !== token) return
    token = message.token
    applyTheme(root, message.theme)
    const l10n = message.l10n ?? {}
    context.placeholder = textOf(l10n.placeholder)
    context.imageLabel = textOf(l10n.image)
    if (languageTag.test(textOf(l10n.locale))) root.lang = l10n.locale
    context.taskLinkBases = httpBases(message.links?.taskLinkBases)
    context.apiRoot = normalizeApiRoot(message.links?.apiRoot)

    editor?.destroy()
    editor = null
    pending = []
    mentionProps = null
    lastMention = null
    lastDirty = false
    focused = false
    const created = new Editor({
      element: mount,
      extensions: createExtensions(context),
      editable: message.readOnly !== true,
      injectCSS: false,
      parseOptions,
      editorProps: {
        attributes: {
          role: 'textbox',
          'aria-multiline': 'true',
          'aria-label': textOf(l10n.label) || context.placeholder,
          autocapitalize: 'sentences',
        },
      },
      onTransaction: scheduleState,
    })
    // TipTap creates the extensions a tick later; the link extension
    // registers its extra schemes with linkify then, which must happen
    // before any content is parsed.
    created.on('create', () =>
      guarded('init', () => {
        if (created.isDestroyed) return
        // Loaded like the web loads it, so that the plugins normalise it
        // the same way, but outside the undo history.
        created
          .chain()
          .setMeta('addToHistory', false)
          .setContent(typeof message.html === 'string' ? message.html : '', {emitUpdate: false, parseOptions})
          .run()
        editor = created
        baseline = created.state.doc
        sendState({force: true})
        const queued = pending
        pending = []
        for (const queuedMessage of queued) handle(queuedMessage)
      }),
    )
  }

  function setLink(chain, args) {
    const href = typeof args?.href === 'string' ? args.href.trim() : ''
    if (href === '') return chain.extendMarkRange('link').unsetLink()
    if (!isAllowedUri(href, linkProtocols)) return null
    if (editor.state.selection.empty && !editor.isActive('link')) {
      return chain.insertContent({type: 'text', text: href, marks: [{type: 'link', attrs: {href}}]})
    }
    return chain.extendMarkRange('link').setLink({href})
  }

  function tableSize(value) {
    const size = Math.trunc(Number(value))
    return Number.isFinite(size) ? Math.min(Math.max(size, 1), maxTableSize) : 3
  }

  const commands = {
    bold: chain => chain.toggleBold(),
    italic: chain => chain.toggleItalic(),
    underline: chain => chain.toggleUnderline(),
    strike: chain => chain.toggleStrike(),
    code: chain => chain.toggleCode(),
    // The web's schema has no highlight mark: the web would drop it.
    highlight: () => null,
    heading: (chain, args) => {
      const level = Number(args?.level)
      if (level === 0) return chain.setParagraph()
      return [1, 2, 3].includes(level) ? chain.setHeading({level}) : null
    },
    bulletList: chain => chain.toggleBulletList(),
    orderedList: chain => chain.toggleOrderedList(),
    taskList: chain => chain.toggleTaskList(),
    blockquote: chain => chain.toggleBlockquote(),
    codeBlock: chain => chain.toggleCodeBlock(),
    horizontalRule: chain => chain.setHorizontalRule(),
    setLink,
    unsetLink: chain => chain.extendMarkRange('link').unsetLink(),
    insertTable: (chain, args) =>
      chain.insertTable({rows: tableSize(args?.rows), cols: tableSize(args?.cols), withHeaderRow: true}),
    addRowAfter: chain => chain.addRowAfter(),
    addColumnAfter: chain => chain.addColumnAfter(),
    deleteRow: chain => chain.deleteRow(),
    deleteColumn: chain => chain.deleteColumn(),
    deleteTable: chain => chain.deleteTable(),
    undo: chain => chain.undo(),
    redo: chain => chain.redo(),
    clearFormatting: chain => chain.unsetAllMarks().clearNodes(),
  }

  function command(message) {
    if (!hasOwn(commands, message.name)) {
      send({type: 'error', message: 'unknown command'})
      return
    }
    if (!editor.isEditable) return
    commands[message.name](editor.chain().focus(), message.args)?.run()
  }

  function insertMention(message) {
    const username = typeof message.username === 'string' ? message.username.trim() : ''
    if (mentionProps === null || username === '' || !editor.isEditable) return
    const label = typeof message.label === 'string' && message.label !== '' ? message.label : username
    mentionProps.command({id: username, label})
  }

  // A document taller than the page opens at its start, as the
  // description reads; a shorter one with the cursor at its end.
  function firstFocus() {
    const page = document.scrollingElement ?? document.documentElement
    if (page.scrollHeight > window.innerHeight) editor.commands.focus('start', {scrollIntoView: false})
    else editor.commands.focus('end')
  }

  const handlers = {
    command,
    insertMention,
    getHtml: message =>
      send({type: 'html', requestId: message.requestId, html: editor.getHTML(), dirty: isDirty()}),
    setTheme: message => applyTheme(root, message.theme),
    setReadOnly: message => editor.setEditable(message.readOnly !== true),
    focus: () => {
      if (focused) editor.commands.focus()
      else firstFocus()
      focused = true
    },
  }

  // The view shrinks when the keyboard or the suggestions come up; the line
  // being typed stays in sight.
  function keepCaretVisible() {
    if (editor === null || !editor.isFocused) return
    guarded('scroll', () => editor.commands.scrollIntoView())
  }

  // Library errors can quote the document, so only the step is named.
  function guarded(step, action) {
    try {
      action()
    } catch {
      if (token !== null) send({type: 'error', message: `${step} failed`})
    }
  }

  function handle(message) {
    if (!hasOwn(handlers, message.type)) {
      send({type: 'error', message: 'unknown message'})
      return
    }
    const step = message.type === 'command' && hasOwn(commands, message.name) ? message.name : message.type
    guarded(step, () => handlers[message.type](message))
  }

  function receive(raw) {
    let message
    try {
      message = typeof raw === 'string' ? JSON.parse(raw) : raw
    } catch {
      return
    }
    if (message === null || typeof message !== 'object') return
    if (message.type === 'init') {
      guarded('init', () => init(message))
      return
    }
    if (token === null || message.token !== token) return
    if (editor === null) pending.push(message)
    else handle(message)
  }

  return {
    receive,
    keepCaretVisible,
    ready: () => send({type: 'ready'}),
    get editor() {
      return editor
    },
  }
}
