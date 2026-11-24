import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import { useApp } from '../app/AppContext'
import { useAsync } from '../app/useAsync'
import { Async, ErrorBox } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'
import Pagination from '../components/Pagination'

/**
 * 게시판 목록.
 * ASP 와 같이 게시판 1개 = tb_board_master 1행이고, skin_type 으로 화면만 바뀐다.
 * 여기서도 컴포넌트 하나가 list / gallery / blog / guest 4개 스킨을 모두 그린다.
 */
export default function BoardList() {
  const { bid } = useParams()
  const [sp] = useSearchParams()

  const page = Number(sp.get('page') || 1)
  const cid = Number(sp.get('cid') || 0)
  const sf = sp.get('sf') || 'all'
  const sw = sp.get('sw') || ''

  const state = useAsync(() => api.boardList({ bid, page, cid, sf, sw }), [bid, page, cid, sf, sw])
  const d = state.data
  const b = d?.board

  const isSearching = sw.length > 0

  return (
    <div className="wrap">
      <div className="page-head">
        <Breadcrumb items={[{ to: '/', label: 'HOME' }, { label: b?.name || bid }]} />
        <h2>{b?.name || bid}</h2>
        {b?.boardDesc && <p className="desc">{b.boardDesc}</p>}
      </div>

      {d && d.categories.length > 0 && (
        <nav className="cate-tabs" aria-label="분류">
          <Link to={`/board/${bid}`} className={cid === 0 ? 'is-on' : ''}>
            전체
          </Link>
          {d.categories.map((c) => (
            <Link key={c.id} to={`/board/${bid}?cid=${c.id}`} className={cid === c.id ? 'is-on' : ''}>
              {c.name}
            </Link>
          ))}
        </nav>
      )}

      {d && (
        <div className="board-head">
          <span className="count">
            총 <strong>{d.paging.totalCount}</strong>건 <span className="sep">|</span> {d.paging.page} /{' '}
            {d.paging.totalPage} 페이지
          </span>
          {b.perm.write && b.skin !== 'guest' && (
            <Link className="btn btn-primary btn-sm" to={`/board/${bid}/write`}>
              글쓰기
            </Link>
          )}
        </div>
      )}

      {isSearching && d && (
        <div className="alert alert-info">
          <strong>&ldquo;{sw}&rdquo;</strong> 검색 결과 {d.paging.totalCount}건{' '}
          <Link to={`/board/${bid}`} style={{ marginLeft: 8, textDecoration: 'underline' }}>
            검색 초기화
          </Link>
        </div>
      )}

      <Async state={state}>
        {d && (
          <>
            {b.skin === 'gallery' && <GallerySkin bid={bid} items={d.items} isSearching={isSearching} />}
            {b.skin === 'blog' && <BlogSkin bid={bid} d={d} isSearching={isSearching} />}
            {b.skin === 'guest' && <GuestSkin bid={bid} d={d} onDone={state.reload} />}
            {b.skin !== 'gallery' && b.skin !== 'blog' && b.skin !== 'guest' && (
              <ListSkin bid={bid} d={d} isSearching={isSearching} />
            )}

            <Pagination page={d.paging.page} totalPage={d.paging.totalPage} pageBlock={b.pageBlock || 10} />
            <SearchBox bid={bid} sf={sf} sw={sw} />
          </>
        )}
      </Async>
    </div>
  )
}

/* ------------------------------------------------------------------ 스킨 */

function ListSkin({ bid, d, isSearching }) {
  const rows = [...d.notices.map((n) => ({ ...n, _notice: true })), ...d.items]
  const hasCate = d.categories.length > 0

  return (
    <table className="board-list">
      <caption className="sr-only">{d.board.name} 목록</caption>
      <thead>
        <tr>
          <th scope="col" className="col-no">번호</th>
          {hasCate && <th scope="col" className="col-cate">분류</th>}
          <th scope="col" className="col-title">제목</th>
          <th scope="col" className="col-writer">작성자</th>
          <th scope="col" className="col-date">작성일</th>
          <th scope="col" className="col-hit">조회</th>
        </tr>
      </thead>
      <tbody>
        {rows.length === 0 ? (
          <tr>
            <td colSpan={6} style={{ padding: 0, border: 0 }}>
              <div className="empty">{isSearching ? '검색 결과가 없습니다.' : '등록된 게시물이 없습니다.'}</div>
            </td>
          </tr>
        ) : (
          rows.map((a) => (
            <tr key={`${a._notice ? 'n' : 'a'}-${a.id}`} className={a._notice ? 'is-notice' : ''}>
              <td className="col-no">
                {a._notice ? <span className="badge badge-notice">공지</span> : a.depth > 0 ? '-' : a.no}
              </td>
              {hasCate && <td className="col-cate">{a.categoryName}</td>}
              <td className="col-title">
                {a.depth > 0 && (
                  <span className="reply-arrow" aria-hidden="true">
                    {'-'.repeat(a.depth)}&nbsp;↳
                  </span>
                )}
                <Link to={`/board/${bid}/${a.id}`}>
                  {a.isSecret && (
                    <span className="ico" title="비밀글">
                      🔒
                    </span>
                  )}
                  {a.title}
                </Link>
                {a.commentCount > 0 && <span className="cmt">[{a.commentCount}]</span>}
                {a.fileCount > 0 && (
                  <span className="ico" title="첨부파일">
                    📎
                  </span>
                )}
                {a.isNew && <span className="badge badge-new">N</span>}
                <div className="meta">
                  <span className="writer">{a.writerName}</span>
                  <span>{a.regDate}</span>
                  <span>조회 {a.hitCount}</span>
                </div>
              </td>
              <td className="col-writer">{a.writerName}</td>
              <td className="col-date">{a.regDate}</td>
              <td className="col-hit">{a.hitCount}</td>
            </tr>
          ))
        )}
      </tbody>
    </table>
  )
}

function GallerySkin({ bid, items, isSearching }) {
  if (items.length === 0)
    return <div className="empty">{isSearching ? '검색 결과가 없습니다.' : '등록된 게시물이 없습니다.'}</div>

  return (
    <div className="gallery-grid">
      {items.map((a) => (
        <Link className="gallery-item" key={a.id} to={`/board/${bid}/${a.id}`}>
          <span className="thumb" style={a.thumb ? { backgroundImage: `url('${a.thumb}')` } : undefined}>
            {!a.thumb && <span className="no-img">이미지 없음</span>}
          </span>
          <span className="tit">{a.title}</span>
          <span className="meta">
            {a.writerName} · {a.regDate}
            {a.commentCount > 0 && ` · 댓글 ${a.commentCount}`}
          </span>
        </Link>
      ))}
    </div>
  )
}

function BlogSkin({ bid, d, isSearching }) {
  return (
    <>
      {d.tags.length > 0 && (
        <div className="mb-4">
          {d.tags.map((t) => (
            <Link className="chip" key={t.name} to={`/board/${bid}?sf=tags&sw=${encodeURIComponent(t.name)}`}>
              #{t.name} {t.count}
            </Link>
          ))}
        </div>
      )}

      {d.items.length === 0 ? (
        <div className="empty">{isSearching ? '검색 결과가 없습니다.' : '등록된 글이 없습니다.'}</div>
      ) : (
        <div className="blog-list">
          {d.items.map((a) => (
            <article className="blog-item" key={a.id}>
              {a.thumb && (
                <Link
                  className="thumb"
                  to={`/board/${bid}/${a.id}`}
                  style={{ backgroundImage: `url('${a.thumb}')` }}
                  aria-hidden="true"
                />
              )}
              <div>
                {a.categoryName && <span className="cate">{a.categoryName}</span>}
                <h3>
                  <Link to={`/board/${bid}/${a.id}`}>{a.title}</Link>
                </h3>
                <p className="summary">{a.summary}</p>
                <div className="meta">
                  <span>{(a.regDt || '').slice(0, 10)}</span>
                  <span>조회 {a.hitCount}</span>
                  {a.commentCount > 0 && <span>댓글 {a.commentCount}</span>}
                </div>
                {a.tags && (
                  <div className="mt-2">
                    {a.tags
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
              </div>
            </article>
          ))}
        </div>
      )}
    </>
  )
}

/** 방명록 : 목록 위에 바로 작성 폼이 붙는다 */
function GuestSkin({ bid, d, onDone }) {
  const { me } = useApp()
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
      await api.articleWrite(bid, {
        mode: 'write',
        title: '방명록',
        content,
        guestName: name,
        guestPw: pw,
      })
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
    <>
      {d.board.perm.write ? (
        <form className="guest-write" onSubmit={submit}>
          {!me.isLogin && (
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
                placeholder="비밀번호 (수정·삭제용)"
                maxLength={20}
                value={pw}
                onChange={(e) => setPw(e.target.value)}
                required
              />
            </div>
          )}
          <div className="form-group mb-3">
            <label className="sr-only" htmlFor="gb-content">
              방명록 내용
            </label>
            <textarea
              id="gb-content"
              className="textarea"
              rows={4}
              maxLength={1000}
              placeholder="다녀가신 흔적을 남겨주세요."
              value={content}
              onChange={(e) => setContent(e.target.value)}
              required
            />
            <div className="form-help tr">{content.length} / 1000</div>
          </div>
          <ErrorBox error={err} />
          <div className="btn-row right">
            <button type="submit" className="btn btn-primary" disabled={busy}>
              {busy ? '저장 중…' : '남기기'}
            </button>
          </div>
        </form>
      ) : (
        <div className="alert alert-info">방명록을 남기려면 로그인이 필요합니다.</div>
      )}

      {d.items.length === 0 ? (
        <div className="empty">아직 남겨진 글이 없습니다.</div>
      ) : (
        <ul className="guest-list">
          {d.items.map((a) => (
            <li className="guest-item" key={a.id}>
              <div className="meta">
                <strong>{a.writerName}</strong>
                <span>{a.regDate}</span>
              </div>
              <p>{a.summary}</p>
              <Link className="fs-xs muted" to={`/board/${bid}/${a.id}`}>
                자세히 보기 →
              </Link>
            </li>
          ))}
        </ul>
      )}
    </>
  )
}

/* --------------------------------------------------------------- 검색 */

function SearchBox({ bid, sf, sw }) {
  const navigate = useNavigate()
  const [field, setField] = useState(sf)
  const [word, setWord] = useState(sw)

  useEffect(() => {
    setField(sf)
    setWord(sw)
  }, [sf, sw])

  const submit = (e) => {
    e.preventDefault()
    const q = new URLSearchParams()
    if (field && field !== 'all') q.set('sf', field)
    if (word) q.set('sw', word)
    navigate(`/board/${bid}${q.toString() ? `?${q}` : ''}`)
  }

  return (
    <form className="search-box" onSubmit={submit} role="search">
      <select className="select" value={field} onChange={(e) => setField(e.target.value)} aria-label="검색 대상">
        <option value="all">전체</option>
        <option value="title">제목</option>
        <option value="content">내용</option>
        <option value="writer">작성자</option>
        <option value="tags">태그</option>
      </select>
      <input
        type="search"
        className="input"
        placeholder="검색어"
        maxLength={50}
        value={word}
        onChange={(e) => setWord(e.target.value)}
        aria-label="검색어"
      />
      <button type="submit" className="btn">
        검색
      </button>
    </form>
  )
}
