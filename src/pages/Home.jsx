import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { useAsync } from '../app/useAsync'
import { Async } from '../components/Status'
import PortfolioCard from '../components/PortfolioCard'

/** 메인. ASP 의 view/main/Default.asp 와 같은 구성 */
export default function Home() {
  const state = useAsync(() => api.main(), [])
  const d = state.data

  if (state.loading || state.error) {
    return (
      <div className="wrap" style={{ paddingTop: 40 }}>
        <Async state={state}>{null}</Async>
      </div>
    )
  }

  return (
    <>
      <section className="hero">
        <div className="wrap">
          <span className="eyebrow">Backend Developer</span>
          <h1>{d.hero.headline}</h1>
          <p className="lead">{d.hero.sub}</p>

          <div className="btn-row">
            <Link className="btn btn-primary btn-lg" to="/portfolio">
              포트폴리오 보기
            </Link>
            <Link className="btn btn-lg" to="/about?tab=resume">
              이력서
            </Link>
            <Link className="btn btn-lg btn-ghost" to="/contact">
              문의하기
            </Link>
          </div>

          {d.skills.length > 0 && (
            <div className="stack">
              {d.skills.map((s) => (
                <span className="chip" key={s}>
                  {s}
                </span>
              ))}
            </div>
          )}

          <div className="stat-row">
            <Stat num={d.stats.years} lbl="경력 (년)" />
            <Stat num={comma(d.stats.projects)} lbl="프로젝트" />
            <Stat num={comma(d.stats.posts)} lbl="블로그 글" />
            <Stat num={comma(d.stats.visits)} lbl="누적 방문" />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <h3>대표 프로젝트</h3>
            <Link className="more" to="/portfolio">
              전체 보기 →
            </Link>
          </div>

          {d.portfolios.length === 0 ? (
            <div className="empty">등록된 프로젝트가 없습니다.</div>
          ) : (
            <div className="pf-grid main-pf-list">
              {d.portfolios.map((p) => (
                <PortfolioCard key={p.id} item={p} />
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <div className="grid" style={{ gridTemplateColumns: '1fr', gap: 'var(--sp-6)' }}>
            <PostList title="최근 블로그" bid="blog" items={d.blog} emptyText="등록된 글이 없습니다." />
            <PostList title="공지사항" bid="notice" items={d.notice} emptyText="등록된 공지가 없습니다." />
          </div>
        </div>
      </section>
    </>
  )
}

function Stat({ num, lbl }) {
  return (
    <div className="stat">
      <span className="num">{num}</span>
      <span className="lbl">{lbl}</span>
    </div>
  )
}

function PostList({ title, bid, items, emptyText }) {
  return (
    <div>
      <div className="section-head">
        <h3>{title}</h3>
        <Link className="more" to={`/board/${bid}`}>
          더 보기 →
        </Link>
      </div>
      {items.length === 0 ? (
        <div className="empty">{emptyText}</div>
      ) : (
        <ul className="main-post-list">
          {items.map((a) => (
            <li key={a.id}>
              <Link to={`/board/${bid}/${a.id}`}>
                <span className="tit">
                  {a.title}
                  {a.isNew && <span className="badge badge-new">N</span>}
                </span>
                <span className="date">{(a.regDt || '').slice(0, 10)}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

function comma(n) {
  return Number(n || 0).toLocaleString('ko-KR')
}
