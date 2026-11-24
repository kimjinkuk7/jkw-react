import { Link } from 'react-router-dom'

/** ASP 의 .breadcrumb 와 같은 마크업 */
export default function Breadcrumb({ items }) {
  return (
    <ul className="breadcrumb">
      {items.map((it, i) => (
        <li key={i}>{it.to ? <Link to={it.to}>{it.label}</Link> : it.label}</li>
      ))}
    </ul>
  )
}
