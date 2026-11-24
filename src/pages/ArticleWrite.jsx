import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import { useApp } from '../app/AppContext'
import { useAsync } from '../app/useAsync'
import { Async, ErrorBox } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'

/**
 * 글쓰기 / 수정 / 답변.
 *
 * 저장 순서가 두 단계인 이유
 *   1) ArticleWrite.asp  (JSON)      -> 글을 저장하고 article_id 를 받는다
 *   2) FileUpload.asp    (multipart) -> 그 id 로 첨부를 올린다
 *   Classic ASP 는 한 요청에서 JSON 본문과 파일을 동시에 받을 수 없다.
 *   Request.Form 과 Request.BinaryRead 를 함께 쓸 수 없기 때문이다.
 */
export default function ArticleWrite() {
  const { bid } = useParams()
  const [sp] = useSearchParams()
  const navigate = useNavigate()
  const { me } = useApp()

  const mode = ['write', 'modify', 'reply'].includes(sp.get('mode')) ? sp.get('mode') : 'write'
  const targetId = Number(sp.get('id') || 0)

  // 게시판 설정 + (수정/답변이면) 원본 글
  const boardState = useAsync(() => api.boardList({ bid, page: 1 }), [bid])
  const srcState = useAsync(() => api.articleView(bid, targetId), [bid, targetId], {
    skip: mode === 'write' || targetId <= 0,
  })

  const board = boardState.data?.board
  const categories = boardState.data?.categories ?? []

  const [form, setForm] = useState({
    title: '',
    content: '',
    categoryId: 0,
    tags: '',
    linkUrl: '',
    isNotice: false,
    isSecret: false,
    guestName: '',
    guestPw: '',
  })
  const [files, setFiles] = useState([])
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState(null)
  const fileRef = useRef(null)

  // 수정 모드일 때 원본을 폼에 채운다.
  // 답변 모드는 제목만 'RE: ' 로 시작하게 하고 본문은 비운다 (ASP 화면과 같은 동작).
  useEffect(() => {
    const a = srcState.data?.article
    if (!a) return
    if (mode === 'modify') {
      setForm((f) => ({
        ...f,
        title: a.title,
        content: stripHtml(a.contentHtml),
        categoryId: a.categoryId,
        tags: a.tags,
        linkUrl: a.linkUrl,
        isNotice: a.isNotice,
        isSecret: a.isSecret,
      }))
    } else if (mode === 'reply') {
      setForm((f) => ({ ...f, title: a.title.startsWith('RE:') ? a.title : `RE: ${a.title}` }))
    }
  }, [srcState.data, mode])

  const set = (k) => (e) => {
    const v = e.target.type === 'checkbox' ? e.target.checked : e.target.value
    setForm((f) => ({ ...f, [k]: v }))
  }

  const submit = async (e) => {
    e.preventDefault()
    setErr(null)
    setBusy(true)
    try {
      const res = await api.articleWrite(bid, {
        mode,
        id: targetId,
        title: form.title,
        content: form.content,
        categoryId: Number(form.categoryId) || 0,
        tags: form.tags,
        linkUrl: form.linkUrl,
        isNotice: form.isNotice,
        isSecret: form.isSecret,
        guestName: form.guestName,
        guestPw: form.guestPw,
      })

      if (files.length > 0) {
        const fd = new FormData()
        files.forEach((f, i) => fd.append(`upfile${i + 1}`, f))
        await api.fileUpload(bid, res.id, fd)
      }

      navigate(board?.skin === 'guest' ? `/board/${bid}` : `/board/${bid}/${res.id}`)
    } catch (e2) {
      setErr(e2)
    } finally {
      setBusy(false)
    }
  }

  const title = mode === 'modify' ? '글 수정' : mode === 'reply' ? '답변 쓰기' : '글쓰기'

  return (
    <div className="wrap wrap-narrow">
      <div className="page-head">
        <Breadcrumb
          items={[{ to: '/', label: 'HOME' }, { to: `/board/${bid}`, label: board?.name || bid }, { label: title }]}
        />
        <h2>{title}</h2>
      </div>

      <Async state={boardState}>
        {board && !board.perm.write ? (
          <div className="alert alert-error">
            글쓰기 권한이 없습니다.{' '}
            {!me.isLogin && (
              <Link to="/login" style={{ textDecoration: 'underline' }}>
                로그인
              </Link>
            )}
          </div>
        ) : (
          board && (
            <form onSubmit={submit}>
              {board.useCategory && categories.length > 0 && (
                <div className="form-group">
                  <label className="form-label" htmlFor="w-cate">
                    분류
                  </label>
                  <select id="w-cate" className="select" value={form.categoryId} onChange={set('categoryId')}>
                    <option value={0}>선택</option>
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {board.skin !== 'guest' && (
                <div className="form-group">
                  <label className="form-label" htmlFor="w-title">
                    제목
                  </label>
                  <input
                    id="w-title"
                    className="input"
                    maxLength={200}
                    value={form.title}
                    onChange={set('title')}
                    required
                  />
                </div>
              )}

              {!me.isLogin && (
                <div className="form-inline mb-3">
                  <input
                    className="input"
                    placeholder="작성자 이름"
                    maxLength={20}
                    value={form.guestName}
                    onChange={set('guestName')}
                    required
                  />
                  <input
                    type="password"
                    className="input"
                    placeholder={mode === 'modify' ? '비밀번호 (본인 확인)' : '비밀번호 (4자 이상)'}
                    maxLength={20}
                    value={form.guestPw}
                    onChange={set('guestPw')}
                    required={mode !== 'modify'}
                  />
                </div>
              )}

              <div className="form-group">
                <label className="form-label" htmlFor="w-content">
                  내용
                </label>
                <textarea
                  id="w-content"
                  className="textarea"
                  rows={14}
                  value={form.content}
                  onChange={set('content')}
                  required
                />
                <p className="form-help">
                  HTML 을 쓸 수 있습니다. 서버에서 script 등 위험한 태그는 제거됩니다
                  (StringUtil.SafeHtml).
                </p>
              </div>

              {board.skin === 'blog' && (
                <div className="form-group">
                  <label className="form-label" htmlFor="w-tags">
                    태그
                  </label>
                  <input
                    id="w-tags"
                    className="input"
                    placeholder="쉼표로 구분 (예: asp,react,mssql)"
                    maxLength={300}
                    value={form.tags}
                    onChange={set('tags')}
                  />
                </div>
              )}

              {board.useFile && (
                <div className="form-group">
                  <label className="form-label" htmlFor="w-files">
                    첨부파일
                  </label>
                  <input
                    id="w-files"
                    type="file"
                    className="input"
                    multiple
                    ref={fileRef}
                    onChange={(e) => setFiles(Array.from(e.target.files || []))}
                  />
                  {files.length > 0 && (
                    <ul className="file-row">
                      {files.map((f) => (
                        <li key={f.name}>
                          {f.name} ({Math.round(f.size / 1024).toLocaleString('ko-KR')} KB)
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              )}

              <div className="check-row">
                {board.useSecret && (
                  <label className="check">
                    <input type="checkbox" checked={form.isSecret} onChange={set('isSecret')} /> 비밀글
                  </label>
                )}
                {board.perm.admin && board.useNotice && (
                  <label className="check">
                    <input type="checkbox" checked={form.isNotice} onChange={set('isNotice')} /> 공지로 등록
                  </label>
                )}
              </div>

              <ErrorBox error={err} />

              <div className="btn-row between mt-4">
                <Link className="btn" to={`/board/${bid}`}>
                  취소
                </Link>
                <button type="submit" className="btn btn-primary" disabled={busy}>
                  {busy ? '저장 중…' : '저장'}
                </button>
              </div>
            </form>
          )
        )}
      </Async>
    </div>
  )
}

/**
 * 수정 화면용 : 저장된 HTML 을 편집 가능한 평문으로 되돌린다.
 * ASP 쪽은 WYSIWYG 에디터를 쓰지만 여기서는 textarea 이므로
 * <br> / </p> 를 줄바꿈으로만 바꾸고 나머지 태그는 그대로 보여준다.
 */
function stripHtml(html) {
  return (html || '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<p[^>]*>/gi, '')
}
