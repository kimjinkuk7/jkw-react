import { Link, useParams } from 'react-router-dom'
import { api } from '../api/client'
import { useAsync } from '../app/useAsync'
import { Async } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'

export default function PortfolioDetail() {
  const { id } = useParams()
  const state = useAsync(() => api.portfolioView(id), [id])
  const d = state.data

  return (
    <div className="wrap wrap-narrow">
      <Async state={state}>
        {d && (
          <>
            <div className="page-head">
              <Breadcrumb
                items={[{ to: '/', label: 'HOME' }, { to: '/portfolio', label: 'PORTFOLIO' }, { label: d.item.title }]}
              />
              <h2>{d.item.title}</h2>
              {d.item.subtitle && <p className="desc">{d.item.subtitle}</p>}
            </div>

            {d.skills.length > 0 && (
              <div className="stack mb-4">
                {d.skills.map((s) => (
                  <span className="chip" key={s.name} style={s.color ? { borderColor: s.color } : undefined}>
                    {s.name}
                  </span>
                ))}
              </div>
            )}

            <ul className="info-list pf-info">
              <Info label="기간" value={d.item.period} />
              <Info label="분류" value={d.item.category} />
              <Info label="고객사" value={d.item.client} />
              <Info label="역할" value={d.item.role} />
              <Info label="인원" value={d.item.teamSize} />
              {d.item.siteUrl && (
                <li>
                  <span>사이트</span>
                  <strong>
                    <a href={d.item.siteUrl} target="_blank" rel="noopener noreferrer">
                      {d.item.siteUrl} ↗
                    </a>
                  </strong>
                </li>
              )}
              {d.item.repoUrl && (
                <li>
                  <span>저장소</span>
                  <strong>
                    <a href={d.item.repoUrl} target="_blank" rel="noopener noreferrer">
                      {d.item.repoUrl} ↗
                    </a>
                  </strong>
                </li>
              )}
            </ul>

            {/* contentHtml 은 서버(StringUtil.SafeHtml)에서 스크립트/이벤트 속성을 제거한 값이다.
                관리자만 입력할 수 있는 필드이기도 하다. */}
            <div className="view-body" dangerouslySetInnerHTML={{ __html: d.item.contentHtml || '' }} />

            <nav className="view-nav">
              {d.prev ? (
                <Link to={`/portfolio/${d.prev.id}`}>← {d.prev.title}</Link>
              ) : (
                <span className="muted">← 이전 프로젝트 없음</span>
              )}
              {d.next ? (
                <Link to={`/portfolio/${d.next.id}`}>{d.next.title} →</Link>
              ) : (
                <span className="muted">다음 프로젝트 없음 →</span>
              )}
            </nav>

            <div className="btn-row mt-4">
              <Link className="btn" to="/portfolio">
                목록
              </Link>
            </div>
          </>
        )}
      </Async>
    </div>
  )
}

function Info({ label, value }) {
  if (!value) return null
  return (
    <li>
      <span>{label}</span>
      <strong>{value}</strong>
    </li>
  )
}
