import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api/client'
import { useApp } from '../app/AppContext'
import { useAsync } from '../app/useAsync'
import { Async, ErrorBox } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'

export default function ArticleDetail() {
  const { bid, id } = useParams()
  const navigate = useNavigate()
  const state = useAsync(() => api.articleView(bid, id), [bid, id])
  const d = state.data

  const [actErr, setActErr] = useState(null)

  const onDelete = async () => {
    setActErr(null)
    let guestPw = ''
    // 비회원 글은 비밀번호로 본인 확인을 한다.
    // (ASP 는 PwCheck.asp 라는 별도 화면을 거치지만, SPA 에서는 그 자리에서 받는다)
    if (d.perm.guestPw && !d.board.perm.admin) {
      guestPw = window.prompt('작성 시 입력한 비밀번호를 입력하세요.') || ''
      if (!guestPw) return
    } else if (!window.confirm('이 게시물을 삭제하시겠습니까?')) {
      return
    }

    try {
      await api.articleDelete(bid, { id: Number(id), guestPw })
      navigate(`/board/${bid}`)
    } catch (e) {
      setActErr(e)
    }
  }

  return (
    <div className="wrap wrap-narrow">
      <Async state={state}>
        {d && (
          <>
            <div className="page-head">
              <Breadcrumb
                items={[{ to: '/', label: 'HOME' }, { to: `/board/${bid}`, label: d.board.name }, { label: '본문' }]}
              />
            </div>

            <article>
              <header className="view-head">
                {d.article.categoryName && <span className="cate">{d.article.categoryName}</span>}
                <h2>
                  {d.article.isNotice && <span className="badge badge-notice">공지</span>}{' '}
                  {d.article.isSecret && (
                    <span className="ico" title="비밀글">
                      🔒
                    </span>
                  )}{' '}
                  {d.article.title}
                </h2>
                <div className="view-meta">
                  <span className="writer">{d.article.writerName}</span>
                  <span>{(d.article.regDt || '').slice(0, 16)}</span>
                  {d.article.updDt && <span>수정 {(d.article.updDt || '').slice(0, 16)}</span>}
                  <span>조회 {d.article.hitCount}</span>
                  {d.board.useComment && <span>댓글 {d.article.commentCount}</span>}
                </div>
              </header>

              {d.files.length > 0 && (
                <div className="attach">
                  <div className="tit">첨부파일 {d.files.length}개</div>
                  <ul>
                    {d.files.map((f) => (
                      <li key={f.id}>
                        {/* 다운로드는 ASP 화면 계층의 Download.asp 를 그대로 쓴다.
                            권한 검사와 다운로드 카운트가 한 곳에만 있게 된다. */}
                        <a href={f.downUrl}>
                          <span aria-hidden="true">📎</span>
                          <span>{f.name}</span>
                          <span className="size">
                            ({f.sizeText} · {f.downCount}회)
                          </span>
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {/* contentHtml 은 서버(StringUtil.SafeHtml)에서 스크립트/이벤트 속성을 제거한 값 */}
              <div className="view-body" dangerouslySetInnerHTML={{ __html: d.article.contentHtml || '' }} />

              {d.article.linkUrl && (
                <div className="view-tags">
                  <a className="btn btn-sm" href={d.article.linkUrl} target="_blank" rel="noopener noreferrer">
                    관련 링크 열기 ↗
                  </a>
                </div>
              )}

              {d.article.tags && (
                <div className="view-tags">
                  {d.article.tags
                    .split(',')
                    .map((t) => t.trim())
                    .filter(Boolean)
                    .map((t) => (
                      <Link className="chip" key={t} to={`/board/${bid}?sf=tags&sw=${encodeURIComponent(t)}`}>
                        #{t}
                      </Link>
                    ))}
                </div>
              )}
            </article>

            <ErrorBox error={actErr} />

            <div className="btn-row between mt-4">
              <Link className="btn" to={`/board/${bid}`}>
                목록
              </Link>
              <span className="btn-row">
                {d.perm.reply && (
                  <Link className="btn" to={`/board/${bid}/write?mode=reply&id=${id}`}>
                    답변
                  </Link>
                )}
                {d.perm.edit && (
                  <>
                    <Link className="btn" to={`/board/${bid}/write?mode=modify&id=${id}`}>
                      수정
                    </Link>
                    <button type="button" className="btn btn-danger" onClick={onDelete}>
                      삭제
                    </button>
                  </>
                )}
              </span>
            </div>

            <ul className="view-nav">
              {d.prev && (
                <li>
                  <span className="dir">이전글</span>
                  <Link className="tit" to={`/board/${bid}/${d.prev.id}`}>
                    {d.prev.title}
                  </Link>
                </li>
              )}
              {d.next && (
                <li>
                  <span className="dir">다음글</span>
                  <Link className="tit" to={`/board/${bid}/${d.next.id}`}>
                    {d.next.title}
                  </Link>
                </li>
              )}
              {!d.prev && !d.next && (
                <li>
                  <span className="dir muted">-</span>
                  <span className="tit muted">이전/다음 글이 없습니다.</span>
                </li>
              )}
            </ul>

            {d.board.useComment && <Comments bid={bid} articleId={Number(id)} d={d} onChanged={state.reload} />}
          </>
        )}
      </Async>
    </div>
  )
}

/* --------------------------------------------------------------- 댓글 */

function Comments({ bid, articleId, d, onChanged }) {
  const { me } = useApp()
  const [replyTo, setReplyTo] = useState(0)
  const [err, setErr] = useState(null)

  const del = async (c) => {
    setErr(null)
    let guestPw = ''
    if (c.writerId === 0 && !d.board.perm.admin) {
      guestPw = window.prompt('댓글 비밀번호를 입력하세요.') || ''
      if (!guestPw) return
    } else if (!window.confirm('이 댓글을 삭제하시겠습니까?')) {
      return
    }
    try {
      await api.commentDelete(bid, { articleId, commentId: c.id, guestPw })
      onChanged()
    } catch (e) {
      setErr(e)
    }
  }

  return (
    <section className="comment-area">
      <h3>
        댓글 <span className="num">{d.comments.length}</span>
      </h3>

      <ErrorBox error={err} />

      {d.comments.length > 0 && (
        <div className="comment-list">
          {d.comments.map((c) => (
            <div className={`comment-item ${c.depth > 0 ? 'is-reply' : ''}`} key={c.id}>
              <div className="head">
                <span className="name">{c.writerName}</span>
                <span className="date">{c.regDate}</span>
              </div>
              <div className="body" style={{ whiteSpace: 'pre-wrap' }}>
                {c.content}
              </div>
              <div className="act">
                {c.depth === 0 && d.board.perm.comment && (
                  <button type="button" onClick={() => setReplyTo(replyTo === c.id ? 0 : c.id)}>
                    답글
                  </button>
                )}
                {c.canEdit && (
                  <button type="button" onClick={() => del(c)}>
                    삭제
                  </button>
                )}
              </div>

              {replyTo === c.id && (
                <div className="reply-form mt-3">
                  <CommentForm
                    bid={bid}
                    articleId={articleId}
                    parentId={c.id}
                    isLogin={me.isLogin}
                    submitLabel="답글 등록"
                    rows={2}
                    onDone={() => {
                      setReplyTo(0)
                      onChanged()
                    }}
                  />
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {d.board.perm.comment ? (
        <CommentForm bid={bid} articleId={articleId} parentId={0} isLogin={me.isLogin} onDone={onChanged} />
      ) : (
        <div className="alert alert-info">
          댓글을 남기려면{' '}
          <Link to="/login" style={{ textDecoration: 'underline' }}>
            로그인
          </Link>
          이 필요합니다.
        </div>
      )}
    </section>
  )
}

function CommentForm({ bid, articleId, parentId, isLogin, onDone, submitLabel = '댓글 등록', rows = 3 }) {
  const [content, setContent] = useState('')
  const [name, setName] = useState('')
  const [pw, setPw] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState(null)

  const submit = async (e) => {
    e.preventDefault()
    setErr(null)
    setBusy(true)
    try {
      await api.commentWrite(bid, { articleId, parentId, content, guestName: name, guestPw: pw })
      setContent('')
      setPw('')
      onDone()
    } catch (e2) {
      setErr(e2)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className={parentId ? '' : 'comment-form'} onSubmit={submit}>
      {!isLogin && (
        <div className="form-inline mb-3">
          <input
            type="text"
            className="input"
            placeholder="이름"
            maxLength={20}
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
          <input
            type="password"
            className="input"
            placeholder="비밀번호 (삭제용)"
            maxLength={20}
            value={pw}
            onChange={(e) => setPw(e.target.value)}
            required
          />
        </div>
      )}
      <textarea
        className="textarea"
        rows={rows}
        maxLength={1000}
        placeholder={parentId ? '답글을 입력하세요.' : '댓글을 입력하세요.'}
        value={content}
        onChange={(e) => setContent(e.target.value)}
        required
      />
      <div className="form-help tr">{content.length} / 1000</div>
      <ErrorBox error={err} />
      <div className="btn-row right mt-2">
        <button type="submit" className={parentId ? 'btn btn-sm btn-primary' : 'btn btn-primary'} disabled={busy}>
          {busy ? '등록 중…' : submitLabel}
        </button>
      </div>
    </form>
  )
}
