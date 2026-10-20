// Link recognition the editor needs to write what the web writes. The bases
// come from the app (the server root and /info's frontend_url), because the
// page's own origin is a local file.

export function httpBases(values) {
  const bases = []
  for (const value of Array.isArray(values) ? values : []) {
    if (typeof value !== 'string') continue
    let url
    try {
      url = new URL(value)
    } catch {
      continue
    }
    if (url.protocol !== 'http:' && url.protocol !== 'https:') continue
    const path = url.pathname.endsWith('/') ? url.pathname : `${url.pathname}/`
    bases.push({origin: url.origin, path})
  }
  return bases
}

// The id of a `<base>/tasks/<id>` URL of one of the bases, or null. A
// relative href is resolved against the first base's origin, as the app's
// own renderer does.
export function parseTaskIdFromUrl(href, bases) {
  if (typeof href !== 'string' || href === '' || bases.length === 0) return null
  let url
  try {
    url = new URL(href, `${bases[0].origin}/`)
  } catch {
    return null
  }
  for (const base of bases) {
    if (url.origin !== base.origin) continue
    const prefix = `${base.path}tasks/`
    if (!url.pathname.startsWith(prefix)) continue
    const rest = url.pathname.slice(prefix.length)
    if (!/^\d+$/.test(rest)) continue
    const id = Number(rest)
    if (id > 0 && id <= Number.MAX_SAFE_INTEGER) return id
  }
  return null
}

// The root the web compares attachment URLs with: no trailing slash and no
// /api/vN.
export function normalizeApiRoot(value) {
  if (typeof value !== 'string') return ''
  return value.replace(/\/+$/, '').replace(/\/api\/v[12]$/, '').replace(/\/+$/, '')
}

const attachmentUrl = /^(.*?)(?:\/api\/v[12])?\/tasks\/(\d+)\/attachments\/(\d+)$/

export function parseAttachmentUrl(url, apiRoot) {
  if (typeof url !== 'string') return null
  const match = attachmentUrl.exec(url)
  if (match === null || match[1] !== apiRoot) return null
  return {taskId: Number(match[2]), attachmentId: Number(match[3])}
}
