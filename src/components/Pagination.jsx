import { Link, useLocation } from 'react-router-dom'

/**
 * 번호형 페이지네이션.
 *
 * ASP 쪽 lib/Paging.Class.asp 의 Render() 와 같은 마크업(.paging > .pg)을 낸다.
 * 공용 CSS 의 `.paging a.pg:hover` 가 a 태그를 전제하므로 button 이 아니라 Link 를 쓴다.
 * 덕분에 뒤로가기 / 새 탭 열기 / 링크 공유가 그대로 된다.
 */
export default function Pagination({ page, totalPage, pageBlock = 10 }) {
  const loc = useLocation()
  if (!totalPage || totalPage <= 1) return null

  const cur = Math.min(Math.max(1, page), totalPage)
  const blockNo = Math.floor((cur - 1) / pageBlock)
  const start = blockNo * pageBlock + 1
  const end = Math.min(start + pageBlock - 1, totalPage)

  const to = (p) => {
    const sp = new URLSearchParams(loc.search)
    sp.set('page', String(p))
    return `${loc.pathname}?${sp.toString()}`
  }

  const Edge = ({ p, label, aria, enabled }) =>
    enabled ? (
      <Link className="pg pg-edge" to={to(p)} aria-label={aria}>
        {label}
      </Link>
    ) : (
      <span className="pg pg-edge is-off" aria-hidden="true">
        {label}
      </span>
    )

  const nums = []
  for (let i = start; i <= end; i++) nums.push(i)

  return (
    <nav className="paging" aria-label="페이지 이동">
      <Edge p={1} label="«" aria="첫 페이지" enabled={cur > 1} />
      <Edge p={cur - 1} label="‹" aria="이전 페이지" enabled={cur > 1} />

      {nums.map((i) =>
        i === cur ? (
          <strong key={i} className="pg is-on" aria-current="page">
            {i}
          </strong>
        ) : (
          <Link key={i} className="pg" to={to(i)}>
            {i}
          </Link>
        )
      )}

      <Edge p={cur + 1} label="›" aria="다음 페이지" enabled={cur < totalPage} />
      <Edge p={totalPage} label="»" aria="마지막 페이지" enabled={cur < totalPage} />
    </nav>
  )
}
