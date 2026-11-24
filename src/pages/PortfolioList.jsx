import { Link, useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import { useAsync } from '../app/useAsync'
import { Async } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'
import Pagination from '../components/Pagination'
import PortfolioCard from '../components/PortfolioCard'

export default function PortfolioList() {
  const [sp] = useSearchParams()
  const category = sp.get('category') || ''
  const page = Number(sp.get('page') || 1)

  const state = useAsync(() => api.portfolioList({ category, page }), [category, page])
  const d = state.data

  return (
    <div className="wrap">
      <div className="page-head">
        <Breadcrumb items={[{ to: '/', label: 'HOME' }, { label: 'PORTFOLIO' }]} />
        <h2>포트폴리오</h2>
        <p className="desc">직접 설계하고 구현한 프로젝트입니다.</p>
      </div>

      {d && d.categories.length > 0 && (
        <nav className="cate-tabs" aria-label="분류">
          <Link to="/portfolio" className={category === '' ? 'is-on' : ''}>
            전체
          </Link>
          {d.categories.map((c) => (
            <Link
              key={c.name}
              to={`/portfolio?category=${encodeURIComponent(c.name)}`}
              className={category === c.name ? 'is-on' : ''}
            >
              {c.name} ({c.count})
            </Link>
          ))}
        </nav>
      )}

      <Async state={state} empty={d && d.items.length === 0 ? '등록된 프로젝트가 없습니다.' : null}>
        {d && (
          <>
            <div className="board-head">
              <span className="count">
                총 <strong>{d.paging.totalCount}</strong>건 <span className="sep">|</span> {d.paging.page} /{' '}
                {d.paging.totalPage} 페이지
              </span>
            </div>

            <div className="pf-grid">
              {d.items.map((p) => (
                <PortfolioCard key={p.id} item={p} />
              ))}
            </div>

            <Pagination page={d.paging.page} totalPage={d.paging.totalPage} />
          </>
        )}
      </Async>
    </div>
  )
}
