/**
 * Classic ASP JSON API 클라이언트
 * ---------------------------------------------------------------------------
 * 서버 응답은 항상 둘 중 하나다.
 *   성공  { ok: true,  data: {...} }
 *   실패  { ok: false, error: { code, message } }
 *
 * 이 모듈은 그 껍데기를 벗겨서 data 만 돌려주고, 실패는 ApiError 로 던진다.
 * 그래서 화면 코드에는 res.ok 분기가 한 줄도 없다.
 *
 * CSRF
 *   ASP 는 세션에 토큰을 들고 있고 POST 마다 대조한다.
 *   Config.asp 가 내려준 토큰을 setCsrf() 로 보관했다가 X-CSRF-Token 헤더로 보낸다.
 *   ★ 로그인/로그아웃은 세션을 갈아끼우므로 토큰도 바뀐다. 반드시 갱신해야 한다.
 */

import { API_BASE } from '../app/config'

const BASE = API_BASE

let csrfToken = ''

export function setCsrf(t) {
  csrfToken = t || ''
}
export function getCsrf() {
  return csrfToken
}

export class ApiError extends Error {
  constructor(code, message, status) {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.status = status
  }
}

function qs(params) {
  if (!params) return ''
  const sp = new URLSearchParams()
  Object.entries(params).forEach(([k, v]) => {
    if (v === undefined || v === null || v === '') return
    sp.append(k, v)
  })
  const s = sp.toString()
  return s ? `?${s}` : ''
}

async function parse(res) {
  const text = await res.text()

  // ASP 가 런타임 오류를 내면 JSON 이 아니라 HTML 이 온다.
  // 그대로 JSON.parse 하면 "Unexpected token <" 라는 쓸모없는 메시지만 남으므로
  // 여기서 가로채 원문 일부를 붙여준다.
  let json
  try {
    json = JSON.parse(text)
  } catch {
    throw new ApiError(
      'NOT_JSON',
      `서버가 JSON 이 아닌 응답을 보냈습니다 (HTTP ${res.status}).\n` +
        text.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 300),
      res.status
    )
  }

  if (!json.ok) {
    const e = json.error || {}
    throw new ApiError(e.code || 'UNKNOWN', e.message || '알 수 없는 오류입니다.', res.status)
  }
  return json.data
}

async function get(path, params) {
  const res = await fetch(`${BASE}/${path}${qs(params)}`, {
    method: 'GET',
    credentials: 'same-origin',
    headers: { Accept: 'application/json' },
  })
  return parse(res)
}

async function post(path, body, params) {
  const res = await fetch(`${BASE}/${path}${qs(params)}`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Accept: 'application/json',
      'X-CSRF-Token': csrfToken,
    },
    body: JSON.stringify({ ...body, _csrf: csrfToken }),
  })
  return parse(res)
}

/** multipart 업로드. 파라미터는 전부 쿼리스트링으로 보낸다 (ASP BinaryRead 제약) */
async function upload(path, params, formData) {
  const res = await fetch(`${BASE}/${path}${qs({ ...params, _csrf: csrfToken })}`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { Accept: 'application/json', 'X-CSRF-Token': csrfToken },
    body: formData,
  })
  return parse(res)
}

export const api = {
  config: () => get('Config.asp'),

  login: (loginId, password) => post('Login.asp', { loginId, password }),
  logout: () => post('Logout.asp', {}),

  main: () => get('Main.asp'),
  about: (params) => get('About.asp', params),

  portfolioList: (params) => get('PortfolioList.asp', params),
  portfolioView: (id) => get('PortfolioView.asp', { id }),

  boardList: (params) => get('BoardList.asp', params),
  articleView: (bid, id) => get('ArticleView.asp', { bid, id }),

  articleWrite: (bid, body) => post('ArticleWrite.asp', body, { bid }),
  articleDelete: (bid, body) => post('ArticleDelete.asp', body, { bid }),

  commentWrite: (bid, body) => post('CommentWrite.asp', body, { bid }),
  commentDelete: (bid, body) => post('CommentDelete.asp', body, { bid }),

  fileUpload: (bid, id, formData) => upload('FileUpload.asp', { bid, id }, formData),
  fileDelete: (bid, body) => post('FileDelete.asp', body, { bid }),

  contact: (body) => post('Contact.asp', body),
}
