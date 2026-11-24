import { Link } from 'react-router-dom'

export default function NotFound() {
  return (
    <div className="wrap wrap-narrow">
      <div className="page-head">
        <h2>페이지를 찾을 수 없습니다</h2>
        <p className="desc">주소가 바뀌었거나 삭제된 페이지입니다.</p>
      </div>
      <div className="btn-row mt-4">
        <Link className="btn btn-primary" to="/">
          메인으로
        </Link>
      </div>
    </div>
  )
}
