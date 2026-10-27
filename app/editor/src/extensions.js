// The Vikunja web editor's schema (TipTap 3.31.3): the same extensions in
// the same order with the options that decide the stored HTML, because the
// order of the schema decides how ProseMirror repairs markup. The UI around
// it (suggestion lists, link prompts, toolbar) is native in the app.
import {Extension, Node, mergeAttributes} from '@tiptap/core'
import {Plugin, PluginKey, TextSelection} from '@tiptap/pm/state'
import StarterKit from '@tiptap/starter-kit'
import {Blockquote} from '@tiptap/extension-blockquote'
import {CodeBlock} from '@tiptap/extension-code-block'
import {HardBreak} from '@tiptap/extension-hard-break'
import {Placeholder} from '@tiptap/extensions'
import {Typography} from '@tiptap/extension-typography'
import {Subscript} from '@tiptap/extension-subscript'
import {Superscript} from '@tiptap/extension-superscript'
import {Underline} from '@tiptap/extension-underline'
import {Link} from '@tiptap/extension-link'
import {Table, TableCell, TableHeader, TableRow} from '@tiptap/extension-table'
import {Image} from '@tiptap/extension-image'
import {ListKeymap, TaskItem, TaskList} from '@tiptap/extension-list'
import {Mention} from '@tiptap/extension-mention'
import {parseAttachmentUrl, parseTaskIdFromUrl} from './links.js'

export const linkProtocols = ['ftp', 'git', 'obsidian', 'notion', 'message']
const linkAttributes = {target: '_blank', rel: 'noopener noreferrer nofollow'}
// In the order a task link writes them.
const taskLinkAttributeNames = ['target', 'rel', 'href']

const idAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'

// StarterKit's own versions of these are replaced or configured below.
const replacedStarterKitParts = ['blockquote', 'codeBlock', 'hardBreak', 'link', 'listKeymap', 'underline']

export function newTaskItemId() {
  const bytes = crypto.getRandomValues(new Uint8Array(8))
  let id = ''
  for (const byte of bytes) id += idAlphabet[byte & 63]
  return id
}

// context: {taskLinkBases, apiRoot, placeholder, imageLabel,
// mention: {onStart(props), onUpdate(props), onExit()}}; read when used, so
// that it may change while the editor lives.
export function createExtensions(context) {
  return [
    StarterKit.configure(Object.fromEntries(replacedStarterKitParts.map(part => [part, false]))),
    ListKeymap,
    EnterReplacesSelection,
    BlockquoteWithCommentId,
    CodeBlock,
    HardBreakOnShiftEnter,
    Placeholder.configure({placeholder: () => context.placeholder ?? ''}),
    Typography,
    Subscript,
    Superscript,
    Underline,
    Link.extend({inclusive: () => false}).configure({
      openOnClick: false,
      protocols: linkProtocols,
      HTMLAttributes: linkAttributes,
    }),
    createTaskLink(context),
    Table.configure({resizable: false}),
    TableRow,
    TableHeader,
    TableCellWithBackground,
    createImage(context),
    TaskList,
    TaskItemWithId.configure({nested: true, onReadOnlyChecked: () => false, a11y: {checkboxLabel}}),
    createMention(context),
    createEditorEvents(),
  ]
}

// splitBlock cannot handle a selection that starts at the start of a block.
const EnterReplacesSelection = Extension.create({
  name: 'enterReplacesSelection',
  priority: 1000,
  addKeyboardShortcuts() {
    const startsAtBlockStart = selection =>
      selection instanceof TextSelection && !selection.empty && selection.$from.parentOffset === 0
    return {
      Enter: ({editor}) => {
        if (startsAtBlockStart(editor.state.selection)) editor.commands.deleteSelection()
        return false
      },
    }
  },
})

// A quote that answers a comment names it; anything but a positive whole
// number is no comment.
function commentIdOf(value) {
  const id = value === null ? NaN : Number(value)
  return id >= 1 && Number.isInteger(id) ? id : null
}

const BlockquoteWithCommentId = Blockquote.extend({
  addAttributes() {
    const commentId = {
      default: null,
      parseHTML: element => commentIdOf(element.getAttribute('data-comment-id')),
      renderHTML: ({commentId: id}) => (id === null || id === undefined ? {} : {'data-comment-id': `${id}`}),
    }
    return {...this.parent?.(), commentId}
  },
})

const HardBreakOnShiftEnter = HardBreak.extend({
  addKeyboardShortcuts() {
    return {
      'Mod-Enter': () => true,
      'Shift-Enter': () => this.editor.commands.setHardBreak(),
    }
  },
})

function inlineView(className, text) {
  const dom = document.createElement('span')
  dom.className = className
  dom.textContent = text
  return {dom}
}

function isInCode(state) {
  const {$from} = state.selection
  if ($from.parent.type.spec.code) return true
  return (state.storedMarks ?? $from.marks()).some(mark => mark.type.name === 'code')
}

// What the web shows as a task link: an anchor with nothing but a task link's
// attributes and no markup inside, whose text is its own task URL.
function isPlainTaskAnchor(anchor, bases) {
  const href = anchor.getAttribute('href') ?? ''
  return (
    anchor.childElementCount === 0 &&
    [...anchor.attributes].every(({name}) => taskLinkAttributeNames.includes(name)) &&
    anchor.textContent.trim() === href &&
    parseTaskIdFromUrl(href, bases) !== null
  )
}

// The pasted plain text when it is a single task URL.
function pastedTaskUrl(clipboard, bases) {
  const text = clipboard?.getData('text/plain')?.trim() ?? ''
  return /^\S+$/.test(text) && parseTaskIdFromUrl(text, bases) !== null ? text : null
}

function createTaskLink(context) {
  return Node.create({
    name: 'taskLink',
    // Its anchors are tried before the Link mark's.
    priority: 200,
    atom: true,
    inline: true,
    group: 'inline',
    addAttributes() {
      const fromAnchor = name => ({default: null, parseHTML: anchor => anchor.getAttribute(name)})
      return Object.fromEntries(taskLinkAttributeNames.map(name => [name, fromAnchor(name)]))
    },
    parseHTML() {
      const getAttrs = anchor => (isPlainTaskAnchor(anchor, context.taskLinkBases) ? {} : false)
      return [{tag: 'a[href]', priority: 100, getAttrs}]
    },
    renderHTML: ({node, HTMLAttributes}) => ['a', HTMLAttributes, node.attrs.href],
    renderText: ({node}) => node.attrs.href,
    addNodeView: () => ({node}) => inlineView('task-link', node.attrs.href),
    addProseMirrorPlugins() {
      const taskLink = this.type
      const handlePaste = (view, event) => {
        const href = pastedTaskUrl(event.clipboardData, context.taskLinkBases)
        if (href === null || !view.state.selection.empty || isInCode(view.state)) return false
        view.dispatch(view.state.tr.replaceSelectionWith(taskLink.create({...linkAttributes, href}), false))
        return true
      }
      return [new Plugin({key: new PluginKey('taskUrlPaste'), props: {handlePaste}})]
    },
  })
}

const TableCellWithBackground = TableCell.extend({
  addAttributes() {
    const backgroundColor = {
      default: null,
      parseHTML: cell => cell.getAttribute('data-background-color'),
      renderHTML: ({backgroundColor: color}) => ({'data-background-color': color, style: `background-color: ${color}`}),
    }
    return {...this.parent?.(), backgroundColor}
  },
})

// The attributes in the order they are written; stored ids are dropped,
// because an attachment image's id is derived from its URL.
const imageAttributeNames = ['src', 'alt', 'title', 'id', 'data-src']

// The web stores an attachment image with its URL in data-src, `#` as src
// and an id naming the task and the attachment.
function attachmentImageAttributes(url, {taskId, attachmentId}, {alt, title}) {
  return {'data-src': url, src: '#', alt, title, id: `tiptap-image-${taskId}-${attachmentId}`}
}

// Images are never loaded here (the page has no session and no network);
// the node keeps its attributes and shows a placeholder that says so.
function createImage(context) {
  return Image.extend({
    addAttributes() {
      const attributes = Object.fromEntries(imageAttributeNames.map(name => [name, {default: null}]))
      attributes.id.parseHTML = () => null
      return attributes
    },
    renderHTML({HTMLAttributes}) {
      const url = HTMLAttributes['data-src'] ?? HTMLAttributes.src
      const attachment = parseAttachmentUrl(url, context.apiRoot)
      const written = attachment ? attachmentImageAttributes(url, attachment, HTMLAttributes) : HTMLAttributes
      return ['img', mergeAttributes(this.options.HTMLAttributes, written)]
    },
    addNodeView() {
      return ({node}) => {
        const dom = document.createElement('div')
        dom.className = 'image-placeholder'
        dom.setAttribute('role', 'img')
        const alt = node.attrs.alt == null ? '' : String(node.attrs.alt).trim()
        const label = context.imageLabel ?? ''
        const name = [alt, label].filter(part => part !== '').join(', ')
        if (name !== '') dom.setAttribute('aria-label', name)
        dom.textContent = alt || label
        return {dom}
      }
    },
  })
}

// TipTap's own label is an English sentence. The item's text reads in any
// language, and the screen reader names the role in its own; a blank label
// (an empty item) names nothing rather than falling back to the English.
export function checkboxLabel(node) {
  return node.firstChild?.textContent.trim() || ' '
}

const withTaskItemId = id => id || newTaskItemId()

// Every task item keeps a unique id: an item without one, or with the id of
// an item before it (a split or a paste copies it), gets a new one.
const TaskItemWithId = TaskItem.extend({
  addAttributes() {
    const taskId = {
      default: null,
      parseHTML: element => withTaskItemId(element.getAttribute('data-task-id')),
      renderHTML: attributes => ({'data-task-id': withTaskItemId(attributes.taskId)}),
    }
    return {...this.parent?.(), taskId}
  },
  addProseMirrorPlugins() {
    const itemType = this.type
    const uniqueIds = new Plugin({
      key: new PluginKey('uniqueTaskItemIds'),
      appendTransaction(transactions, _, state) {
        if (!transactions.some(({docChanged}) => docChanged)) return null
        const taken = new Set()
        let fix = null
        state.doc.descendants((node, pos) => {
          if (node.type !== itemType) return
          if (node.attrs.taskId && !taken.has(node.attrs.taskId)) {
            taken.add(node.attrs.taskId)
            return
          }
          fix ??= state.tr
          fix.setNodeMarkup(pos, undefined, {...node.attrs, taskId: newTaskItemId()})
        })
        return fix
      },
    })
    return [...(this.parent?.() ?? []), uniqueIds]
  },
})

function createMention(context) {
  return Mention.extend({
    parseHTML: () => [{tag: 'mention-user'}],
    renderHTML: ({HTMLAttributes}) => ['mention-user', HTMLAttributes],
    addNodeView: () => ({node}) => inlineView('mention', `@${node.attrs.label || node.attrs.id || ''}`),
  }).configure({
    suggestion: {
      char: '@',
      items: () => [],
      render: () => ({
        onStart: props => context.mention?.onStart(props),
        onUpdate: props => context.mention?.onUpdate(props),
        onExit: () => context.mention?.onExit(),
      }),
    },
  })
}

// Links never navigate while editing: a tap places the cursor, and the
// toolbar edits the link there. Pasted or dropped files are not inserted
// (uploads are not part of this editor).
function createEditorEvents() {
  const props = {
    handleClick(view, _, event) {
      const anchor = event.target?.closest?.('a[href]')
      if (anchor && view.dom.contains(anchor)) event.preventDefault()
      return false
    },
    handlePaste(_, event) {
      const data = event.clipboardData
      const isText = type => type === 'text/plain' || type === 'text/html'
      return Boolean(data && data.files.length > 0 && !data.types.some(isText))
    },
    handleDrop: (_, event) => (event.dataTransfer?.files.length ?? 0) > 0,
  }
  return Extension.create({
    name: 'editorEvents',
    addProseMirrorPlugins: () => [new Plugin({key: new PluginKey('editorEvents'), props})],
  })
}
