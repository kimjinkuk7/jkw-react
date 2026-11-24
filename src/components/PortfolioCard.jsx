import { Link } from 'react-router-dom'

/** 포트폴리오 카드. ASP 의 .card.pf-card 마크업과 동일 */
export default function PortfolioCard({ item }) {
  return (
    <Link className="card pf-card" to={`/portfolio/${item.id}`}>
      <span
        className="thumb"
        style={item.thumb ? { backgroundImage: `url('${item.thumb}')` } : undefined}
      >
        {!item.thumb && <span className="ph">{(item.title || '').slice(0, 2)}</span>}
      </span>
      <span className="body">
        <span className="cate">{item.category}</span>
        <h3>{item.title}</h3>
        <p className="summary">{item.summary}</p>
        <span className="period">{item.period}</span>
      </span>
    </Link>
  )
}
