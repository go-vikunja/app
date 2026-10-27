// Link recognition the editor needs to write what the web writes. The bases
// come from the app (the server root and /info's frontend_url), because the
// page's own origin is a local file.

const webProtocols = new Set(['http:', 'https:'])

function parseUrl(text, base) {
  try {
    return new URL(text, base)
  } catch {
    return null
  }
}

// Each usable base as {origin, path}, the path ending in a slash.
export function httpBases(values) {
  if (!Array.isArray(values)) return []
  return values
    .map(value => (typeof value === 'string' ? parseUrl(value) : null))
    .filter(url => url !== null && webProtocols.has(url.protocol))
    .map(url => ({origin: url.origin, path: url.pathname.replace(/\/?$/, '/')}))
}

// `<directory>tasks/<digits>`, the directory ending in a slash.
const taskPathname = /^(.*\/)tasks\/(\d+)$/

// The id of a `<base>/tasks/<id>` URL of one of the bases, or null. A
// relative href is resolved against the first base's origin, as the app's
// own renderer does.
export function parseTaskIdFromUrl(href, bases) {
  if (typeof href !== 'string' || bases.length === 0) return null
  const url = parseUrl(href, `${bases[0].origin}/`)
  const match = url && taskPathname.exec(url.pathname)
  if (!match) return null
  const [, directory, digits] = match
  const id = Number(digits)
  const isBase = base => base.origin === url.origin && base.path === directory
  return id >= 1 && id <= Number.MAX_SAFE_INTEGER && bases.some(isBase) ? id : null
}

// The root the web compares attachment URLs with: no trailing slash and no
// /api/vN.
export function normalizeApiRoot(value) {
  if (typeof value !== 'string') return ''
  return value.replace(/\/+$/, '').replace(/\/api\/v[12]$/, '').replace(/\/+$/, '')
}

const attachmentUrl = /^(.*?)(?:\/api\/v[12])?\/tasks\/(\d+)\/attachments\/(\d+)$/

// {taskId, attachmentId} of an attachment URL under the API root, or null.
export function parseAttachmentUrl(url, apiRoot) {
  const [, root, task, attachment] = (typeof url === 'string' && attachmentUrl.exec(url)) || []
  if (root === undefined || root !== apiRoot) return null
  return {taskId: Number(task), attachmentId: Number(attachment)}
}
