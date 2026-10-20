import assert from 'node:assert/strict'
import {beforeEach, describe, test} from 'node:test'
import {sourceBridge, tick, waitFor} from './helpers.mjs'

const {window, bridge, posted} = await sourceBridge()
const token = 'per-load-token'
const links = {taskLinkBases: ['https://vikunja.example.com/'], apiRoot: 'https://vikunja.example.com'}

async function open(html, extra = {}) {
  posted.length = 0
  bridge.receive({type: 'init', token, html, readOnly: false, links, ...extra})
  await waitFor(posted, message => message.type === 'state')
  return bridge.editor
}

function send(message) {
  bridge.receive({...message, token})
}

let requestCount = 0
async function html() {
  const requestId = `r${++requestCount}`
  send({type: 'getHtml', requestId})
  return (await waitFor(posted, message => message.type === 'html' && message.requestId === requestId)).html
}

async function latestState() {
  await tick(80)
  return posted.filter(message => message.type === 'state').at(-1)
}

function positionOf(editor, text) {
  let found = null
  editor.state.doc.descendants((node, pos) => {
    if (found === null && node.isText && node.text.includes(text)) found = pos + node.text.indexOf(text)
  })
  return found
}

function command(name, args) {
  send({type: 'command', name, args})
}

beforeEach(() => {
  posted.length = 0
})

describe('tokens', () => {
  test('nothing is answered before init, and an init needs a token', async () => {
    bridge.receive({type: 'getHtml', requestId: 'early'})
    bridge.receive({type: 'init', token: '', html: '<p>x</p>'})
    bridge.receive(JSON.stringify({type: 'init', html: '<p>x</p>'}))
    await tick(20)
    assert.deepEqual(posted, [])
  })

  test('a string message is parsed like an object, garbage is ignored', async () => {
    await open('<p>a</p>')
    bridge.receive('{not json')
    bridge.receive(JSON.stringify({type: 'getHtml', token, requestId: 's'}))
    const reply = await waitFor(posted, message => message.type === 'html')
    assert.equal(reply.html, '<p>a</p>')
  })

  test('every page message after init carries the token', async () => {
    await open('<p>a</p>')
    command('horizontalRule')
    await html()
    await latestState()
    assert.ok(posted.length >= 3)
    for (const message of posted) assert.equal(message.token, token)
  })

  test('a message with another token is ignored', async () => {
    await open('<p>a</p>')
    posted.length = 0
    bridge.receive({type: 'getHtml', token: 'forged', requestId: 'x'})
    bridge.receive({type: 'command', token: 'forged', name: 'horizontalRule'})
    bridge.receive({type: 'getHtml', requestId: 'y'})
    await tick(80)
    assert.deepEqual(posted, [])
    assert.equal(await html(), '<p>a</p>')
  })

  test('another init must repeat the token; it then replaces the content', async () => {
    await open('<p>first</p>')
    bridge.receive({type: 'init', token: 'other', html: '<p>stolen</p>', links})
    await tick(20)
    assert.equal(await html(), '<p>first</p>')
    await open('<p>second</p>')
    assert.equal(await html(), '<p>second</p>')
  })

  test('messages sent right after init wait for the editor', async () => {
    posted.length = 0
    bridge.receive({type: 'init', token, html: '<p>queued</p>', links})
    send({type: 'getHtml', requestId: 'queued'})
    const reply = await waitFor(posted, message => message.type === 'html')
    assert.equal(reply.html, '<p>queued</p>')
    assert.equal(posted[0].type, 'state')
  })
})

describe('dirty', () => {
  test('a freshly loaded description is clean, normalised or not', async () => {
    await open('<ul data-type="taskList"><li data-checked="true" data-type="taskItem"><p>a</p></li></ul>')
    const state = posted.find(message => message.type === 'state')
    assert.equal(state.dirty, false)
    assert.equal(state.canUndo, false)
    assert.equal(state.canRedo, false)
  })

  test('an edit makes it dirty; undoing it makes it clean again', async () => {
    await open('<p>text</p>')
    command('horizontalRule')
    let state = await latestState()
    assert.equal(state.dirty, true)
    assert.equal(state.canUndo, true)

    command('undo')
    state = await latestState()
    assert.equal(state.dirty, false)
    assert.equal(state.canRedo, true)

    command('redo')
    state = await latestState()
    assert.equal(state.dirty, true)
  })

  test('an emptied description is <p></p> and dirty', async () => {
    const editor = await open('<h1>Title</h1><p>body</p>')
    editor.chain().selectAll().deleteSelection().run()
    assert.equal(await html(), '<p></p>')
    assert.equal((await latestState()).dirty, true)
  })

  test('an empty description loads as <p></p>, typing and deleting leaves it clean', async () => {
    const editor = await open('')
    assert.equal(await html(), '<p></p>')
    editor.commands.insertContent('x')
    assert.equal((await latestState()).dirty, true)
    editor.chain().selectAll().deleteSelection().run()
    assert.equal((await latestState()).dirty, false)
  })

  test('a selection change alone is not an edit', async () => {
    const editor = await open('<p>some text</p>')
    editor.commands.setTextSelection({from: 2, to: 5})
    assert.equal((await latestState()).dirty, false)
  })

  test('a change of dirty is reported at once, other changes after a pause', async () => {
    const editor = await open('<p>text</p>')
    posted.length = 0
    editor.commands.insertContentAt(5, 'a')
    assert.deepEqual(
      posted.map(message => [message.type, message.dirty]),
      [['state', true]],
    )
    editor.commands.insertContentAt(6, 'b')
    assert.equal(posted.length, 1)
    command('undo')
    assert.equal(posted.at(-1).dirty, false)
    assert.equal((await latestState()).dirty, false)
  })

  test('the html answer says whether the document differs from the one given', async () => {
    const editor = await open('<p>text</p>')
    const ask = async () => {
      const requestId = `d${++requestCount}`
      send({type: 'getHtml', requestId})
      return waitFor(posted, message => message.type === 'html' && message.requestId === requestId)
    }
    assert.deepEqual(await ask(), {type: 'html', requestId: `d${requestCount}`, html: '<p>text</p>', dirty: false, token})
    editor.commands.insertContentAt(5, 'a')
    assert.equal((await ask()).dirty, true)
    command('undo')
    const answer = await ask()
    assert.equal(answer.dirty, false)
    assert.equal(answer.html, '<p>text</p>')
  })
})

describe('commands', () => {
  async function applied(html, select, name, args) {
    const editor = await open(html)
    select(editor)
    command(name, args)
    return editor.getHTML()
  }
  const all = editor => editor.commands.selectAll()
  const inside = editor => editor.commands.setTextSelection(2)

  const marks = {bold: 'strong', italic: 'em', underline: 'u', strike: 's', code: 'code'}
  for (const [name, tag] of Object.entries(marks)) {
    test(`${name} marks the selection and shows as active`, async () => {
      const editor = await open('<p>word</p>')
      editor.commands.setTextSelection({from: 1, to: 5})
      command(name)
      assert.equal(editor.getHTML(), `<p><${tag}>word</${tag}></p>`)
      assert.equal((await latestState()).active[name], true)
      command(name)
      assert.equal(editor.getHTML(), '<p>word</p>')
    })
  }

  test('headings 1 to 3 and back to a paragraph', async () => {
    const editor = await open('<p>title</p>')
    editor.commands.setTextSelection(2)
    for (const level of [1, 2, 3]) {
      command('heading', {level})
      assert.equal(editor.getHTML(), `<h${level}>title</h${level}><p></p>`)
      assert.equal((await latestState()).active.heading, level)
    }
    command('heading', {level: 0})
    assert.equal(editor.getHTML(), '<p>title</p><p></p>')
    assert.equal((await latestState()).active.heading, 0)
    command('heading', {level: 7})
    assert.equal(editor.getHTML(), '<p>title</p><p></p>')
  })

  test('a loaded level 5 heading reports level 5', async () => {
    const editor = await open('<h5>deep</h5>')
    editor.commands.setTextSelection(2)
    assert.equal((await latestState()).active.heading, 5)
  })

  test('lists, quote, code block and divider', async () => {
    assert.equal(await applied('<p>a</p>', inside, 'bulletList'), '<ul><li><p>a</p></li></ul><p></p>')
    assert.equal(await applied('<p>a</p>', inside, 'orderedList'), '<ol><li><p>a</p></li></ol><p></p>')
    assert.match(
      await applied('<p>a</p>', inside, 'taskList'),
      /^<ul data-type="taskList"><li data-checked="false" data-task-id="[\w-]{8}" data-type="taskItem"><label><input type="checkbox"><span><\/span><\/label><div><p>a<\/p><\/div><\/li><\/ul><p><\/p>$/,
    )
    assert.equal(await applied('<p>a</p>', inside, 'blockquote'), '<blockquote><p>a</p></blockquote><p></p>')
    assert.equal(await applied('<p>a</p>', inside, 'codeBlock'), '<pre><code>a</code></pre><p></p>')
    assert.equal(await applied('<p>a</p>', all, 'horizontalRule'), '<hr><p></p>')
  })

  test('the active state follows the cursor', async () => {
    const editor = await open('<ul><li><p>a</p></li></ul><blockquote><p>b</p></blockquote><pre><code>c</code></pre>')
    editor.commands.setTextSelection(3)
    let {active} = await latestState()
    assert.equal(active.bulletList, true)
    assert.equal(active.blockquote, false)
    editor.commands.setTextSelection(positionOf(editor, 'c'))
    ;({active} = await latestState())
    assert.equal(active.codeBlock, true)
    assert.equal(active.bulletList, false)
  })

  test('tables: insert with a header row, add and delete rows and columns, delete', async () => {
    const editor = await open('<p>a</p>')
    editor.commands.setTextSelection(2)
    command('insertTable', {rows: 2, cols: 2})
    assert.equal(editor.view.dom.querySelectorAll('th').length, 2)
    assert.equal(editor.view.dom.querySelectorAll('td').length, 2)
    assert.equal((await latestState()).active.table, true)
    command('addRowAfter')
    command('addColumnAfter')
    assert.equal(editor.view.dom.querySelectorAll('tr').length, 3)
    assert.equal(editor.view.dom.querySelectorAll('tr')[0].children.length, 3)
    command('deleteRow')
    command('deleteColumn')
    assert.equal(editor.view.dom.querySelectorAll('tr').length, 2)
    assert.equal(editor.view.dom.querySelectorAll('tr')[0].children.length, 2)
    command('deleteTable')
    assert.equal(editor.view.dom.querySelectorAll('table').length, 0)
  })

  test('table sizes are clamped', async () => {
    const editor = await open('<p>a</p>')
    command('insertTable', {rows: 500, cols: 'x'})
    assert.equal(editor.view.dom.querySelectorAll('tr').length, 20)
    assert.equal(editor.view.dom.querySelectorAll('tr')[0].children.length, 3)
  })

  test('clear formatting removes marks and blocks', async () => {
    const editor = await open('<h2><strong>bold</strong> <em>title</em></h2>')
    editor.commands.selectAll()
    command('clearFormatting')
    assert.equal(editor.getHTML(), '<p>bold title</p><p></p>')
  })

  test('highlight does nothing, the schema has no such mark', async () => {
    const editor = await open('<p>word</p>')
    editor.commands.selectAll()
    command('highlight')
    assert.equal(editor.getHTML(), '<p>word</p>')
    const state = await latestState()
    assert.equal(state.active.highlight, false)
    assert.equal(posted.some(message => message.type === 'error'), false)
  })

  test('an unknown command or message is reported without content', async () => {
    await open('<p>secret</p>')
    command('format-disk')
    send({type: 'explode'})
    const errors = posted.filter(message => message.type === 'error')
    assert.deepEqual(
      errors.map(message => message.message),
      ['unknown command', 'unknown message'],
    )
  })
})

describe('links', () => {
  test('setLink links the selection with the web attributes', async () => {
    const editor = await open('<p>docs</p>')
    editor.commands.setTextSelection({from: 1, to: 5})
    command('setLink', {href: 'https://example.com/a'})
    assert.equal(
      editor.getHTML(),
      '<p><a target="_blank" rel="noopener noreferrer nofollow" href="https://example.com/a">docs</a></p>',
    )
    assert.equal((await latestState()).active.link, true)
  })

  test('setLink at a cursor outside a link inserts the address as linked text', async () => {
    const editor = await open('<p>see </p>')
    editor.commands.setTextSelection(5)
    command('setLink', {href: 'https://example.com'})
    assert.equal(
      editor.getHTML(),
      '<p>see <a target="_blank" rel="noopener noreferrer nofollow" href="https://example.com">https://example.com</a></p>',
    )
  })

  test('setLink inside a link changes the whole link, an empty href removes it', async () => {
    const editor = await open('<p><a href="https://old.example.com">old</a> text</p>')
    editor.commands.setTextSelection(2)
    command('setLink', {href: 'https://new.example.com'})
    assert.equal(
      editor.getHTML(),
      '<p><a target="_blank" rel="noopener noreferrer nofollow" href="https://new.example.com">old</a> text</p>',
    )
    editor.commands.setTextSelection(2)
    command('setLink', {href: ''})
    assert.equal(editor.getHTML(), '<p>old text</p>')
  })

  test('unsetLink removes the link around the cursor', async () => {
    const editor = await open('<p><a href="https://x.example.com">x link</a></p>')
    editor.commands.setTextSelection(3)
    command('unsetLink')
    assert.equal(editor.getHTML(), '<p>x link</p>')
  })

  test('a javascript: link is refused', async () => {
    const editor = await open('<p>word</p>')
    editor.commands.selectAll()
    command('setLink', {href: 'javascript:alert(1)'})
    assert.equal(editor.getHTML(), '<p>word</p>')
    editor.commands.setTextSelection(5)
    command('setLink', {href: ' JavaScript:alert(1)'})
    assert.equal(editor.getHTML(), '<p>word</p>')
  })

  test('a tap on a link does not navigate and asks the app nothing', async () => {
    const editor = await open('<p>go <a href="https://example.com/x">there</a></p>')
    const anchor = editor.view.dom.querySelector('a')
    const plugin = editor.state.plugins.find(candidate => candidate.key.startsWith('editorEvents'))
    let prevented = false
    posted.length = 0
    plugin.props.handleClick(editor.view, 5, {target: anchor.firstChild.parentElement, preventDefault: () => (prevented = true)})
    assert.equal(prevented, true)
    await tick(80)
    assert.deepEqual(posted, [])
  })

  test('the state names the address of the link at the cursor', async () => {
    const editor = await open('<p>go <a href="https://example.com/x">there</a> now</p>')
    editor.commands.setTextSelection(positionOf(editor, 'here'))
    let {active} = await latestState()
    assert.equal(active.link, true)
    assert.equal(active.linkHref, 'https://example.com/x')
    editor.commands.setTextSelection(positionOf(editor, 'now') + 1)
    ;({active} = await latestState())
    assert.equal(active.link, false)
    assert.equal(active.linkHref, null)
  })
})

describe('images', () => {
  const src = 'https://vikunja.example.com/api/v2/tasks/3/attachments/9'

  test('insertImage puts an attachment at the cursor, written the web way', async () => {
    const editor = await open('<p>ab</p>')
    editor.commands.setTextSelection(2)
    command('insertImage', {src, id: 'tiptap-image-3-9'})
    assert.equal(editor.getHTML(), `<p>a</p><img data-src="${src}" src="#" id="tiptap-image-3-9"><p>b</p>`)
    assert.equal((await latestState()).dirty, true)
    assert.equal(posted.some(message => message.type === 'error'), false)
  })

  test('insertImage keeps an alt text and needs no id', async () => {
    const editor = await open('<p></p>')
    command('insertImage', {src, alt: ' plan '})
    assert.equal(editor.getHTML(), `<img data-src="${src}" src="#" alt="plan" id="tiptap-image-3-9"><p></p>`)
  })

  test('the inserted image is a placeholder, never loaded', async () => {
    const editor = await open('<p></p>')
    command('insertImage', {src, alt: 'plan'})
    assert.equal(editor.view.dom.querySelectorAll('img').length, 0)
    assert.equal(editor.view.dom.querySelectorAll('.image-placeholder').length, 1)
  })

  test('only an attachment of this server with its own id goes in', async () => {
    const editor = await open('<p>a</p>')
    for (const args of [
      {src: 'https://images.example.com/cat.png'},
      {src: 'https://other.example.com/api/v2/tasks/3/attachments/9'},
      {src: 'javascript:alert(1)'},
      {src, id: 'tiptap-image-3-10'},
      {src: ''},
      {},
    ]) {
      command('insertImage', args)
    }
    assert.equal(editor.getHTML(), '<p>a</p>')
  })

  test('nothing is inserted while read-only', async () => {
    const editor = await open('<p>a</p>')
    send({type: 'setReadOnly', readOnly: true})
    command('insertImage', {src})
    assert.equal(editor.getHTML(), '<p>a</p>')
  })
})

describe('mentions', () => {
  test('typing @ asks the app, a pick inserts the web mention and a space', async () => {
    const editor = await open('<p>Hi </p>')
    editor.commands.setTextSelection(4)
    editor.commands.insertContent('@ja')
    const query = await waitFor(posted, message => message.type === 'mentionQuery' && message.query === 'ja')
    assert.deepEqual(Object.keys(query.caret).sort(), ['height', 'x', 'y'])

    send({type: 'insertMention', id: 7, username: 'jdoe', label: 'Jane Doe'})
    assert.equal(
      editor.getHTML(),
      '<p>Hi <mention-user data-id="jdoe" data-label="Jane Doe" data-mention-suggestion-char="@"></mention-user> </p>',
    )
    await waitFor(posted, message => message.type === 'mentionEnd')
    assert.equal(editor.view.dom.querySelector('.mention').textContent, '@Jane Doe')
  })

  test('an empty query starts the list too; moving away ends it', async () => {
    const editor = await open('<p>x </p>')
    editor.commands.setTextSelection(3)
    editor.commands.insertContent('@')
    await waitFor(posted, message => message.type === 'mentionQuery' && message.query === '')
    editor.commands.setTextSelection(1)
    await waitFor(posted, message => message.type === 'mentionEnd')
  })

  test('a pick without a running query or without a username does nothing', async () => {
    const editor = await open('<p>plain</p>')
    send({type: 'insertMention', id: 1, username: 'jdoe', label: 'Jane'})
    assert.equal(editor.getHTML(), '<p>plain</p>')
    editor.commands.setTextSelection(6)
    editor.commands.insertContent(' @j')
    await waitFor(posted, message => message.type === 'mentionQuery')
    send({type: 'insertMention', id: 1, username: '', label: 'Nobody'})
    assert.equal(editor.getHTML(), '<p>plain @j</p>')
  })

  test('a mention without a label uses the username', async () => {
    const editor = await open('<p></p>')
    editor.commands.insertContent('@j')
    await waitFor(posted, message => message.type === 'mentionQuery')
    send({type: 'insertMention', username: 'jdoe'})
    assert.equal(
      editor.getHTML(),
      '<p><mention-user data-id="jdoe" data-label="jdoe" data-mention-suggestion-char="@"></mention-user> </p>',
    )
  })
})

describe('init options', () => {
  test('readOnly makes the editor not editable', async () => {
    const editor = await open('<p>a</p>', {readOnly: true})
    assert.equal(editor.isEditable, false)
    const editable = await open('<p>a</p>')
    assert.equal(editable.isEditable, true)
  })

  test('the placeholder is the empty text and, without a label, the accessible name', async () => {
    const editor = await open('', {l10n: {placeholder: 'Beschreibung schreiben …'}})
    assert.equal(editor.view.dom.getAttribute('aria-label'), 'Beschreibung schreiben …')
    assert.equal(editor.view.dom.getAttribute('role'), 'textbox')
    assert.equal(editor.view.dom.querySelector('p').getAttribute('data-placeholder'), 'Beschreibung schreiben …')
  })

  test('the label names the editor, the locale sets the language of the page', async () => {
    const root = window.document.documentElement
    const editor = await open('<p>Einkaufsliste</p>', {
      l10n: {placeholder: 'Beschreibung schreiben …', label: 'Beschreibung', locale: 'de'},
    })
    assert.equal(editor.view.dom.getAttribute('aria-label'), 'Beschreibung')
    assert.equal(root.lang, 'de')
    await open('<p>x</p>', {l10n: {locale: 'en-GB'}})
    assert.equal(root.lang, 'en-GB')
    await open('<p>x</p>', {l10n: {locale: 'de" onload="x'}})
    assert.equal(root.lang, 'en-GB')
  })

  test('setReadOnly stops and allows editing', async () => {
    const editor = await open('<p>a</p>')
    send({type: 'setReadOnly', readOnly: true})
    assert.equal(editor.isEditable, false)
    command('horizontalRule')
    assert.equal(editor.getHTML(), '<p>a</p>')
    send({type: 'setReadOnly', readOnly: false})
    assert.equal(editor.isEditable, true)
  })

  test('theme colours, dark mode and the text scale become CSS variables', async () => {
    const root = window.document.documentElement
    await open('<p>a</p>', {
      theme: {
        dark: true,
        colors: {text: '#e6e1e5', background: 0xff1c1b1f, primary: 'rgb(208, 188, 255)', link: 'url(https://x)', error: 'red'},
        fontScale: 2,
      },
    })
    assert.equal(root.style.colorScheme, 'dark')
    assert.equal(root.style.getPropertyValue('--text'), '#e6e1e5')
    assert.equal(root.style.getPropertyValue('--background'), 'rgba(28, 27, 31, 1)')
    assert.equal(root.style.getPropertyValue('--primary'), 'rgb(208, 188, 255)')
    assert.equal(root.style.getPropertyValue('--link'), '')
    assert.equal(root.style.getPropertyValue('--error'), '')
    assert.equal(root.style.getPropertyValue('--font-scale'), '2')

    send({type: 'setTheme', theme: {dark: false, colors: {text: 0x80000000}, fontScale: 9}})
    await tick(10)
    assert.equal(root.style.colorScheme, 'light')
    assert.equal(root.style.getPropertyValue('--text'), 'rgba(0, 0, 0, 0.502)')
    assert.equal(root.style.getPropertyValue('--font-scale'), '4')
  })

  test('focus puts the cursor at the end the first time', async () => {
    const editor = await open('<p>one</p><p>two</p>')
    send({type: 'focus'})
    assert.equal(editor.state.selection.from, editor.state.doc.content.size - 1)
  })

  test('a document taller than the page gets the cursor at its start, without scrolling', async () => {
    const page = window.document.documentElement
    Object.defineProperty(page, 'scrollHeight', {configurable: true, get: () => window.innerHeight * 3})
    try {
      const editor = await open('<p>one</p><p>two</p>')
      const scrolled = []
      editor.on('transaction', ({transaction}) => scrolled.push(transaction.scrolledIntoView))
      send({type: 'focus'})
      assert.equal(editor.state.selection.from, 1)
      assert.equal(scrolled.includes(true), false)
    } finally {
      delete page.scrollHeight
    }
  })

  test('keeping the caret in sight does nothing without focus and never fails', async () => {
    await open('<p>one</p>')
    posted.length = 0
    bridge.keepCaretVisible()
    send({type: 'focus'})
    bridge.keepCaretVisible()
    await tick(20)
    assert.equal(posted.some(message => message.type === 'error'), false)
  })
})
