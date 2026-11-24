import { Link } from 'react-router-dom'

/** 로딩 자리표시자 */
export function Loading({ text = '불러오는 중…' }) {
  return (
    <div className="empty" role="status" aria-live="polite">
      {text}
    </div>
  )
}

/** 비어 있음 */
export function Empty({ text = '내용이 없습니다.' }) {
  return <div className="empty">{text}</div>
}

/**
 * 오류 표시.
 * ApiError 의 code 별로 안내를 달리한다. 로그인이 필요한 경우엔 링크까지 준다.
 */
export function ErrorBox({ error, onRetry }) {
  if (!error) return null

  const code = error.code || ''
  const needLogin = code === 'LOGIN_REQUIRED'

  return (
    <div className="alert alert-error" role="alert">
      <strong>{error.message}</strong>
      {code && <div className="fs-xs muted mt-2">코드 : {code}</div>}
      <div className="btn-row mt-3">
        {needLogin && (
          <Link className="btn btn-sm btn-primary" to="/login">
            로그인
          </Link>
        )}
        {onRetry && (
          <button type="button" className="btn btn-sm" onClick={onRetry}>
            다시 시도
          </button>
        )}
      </div>
    </div>
  )
}

/** loading / error / empty 를 한 번에 처리하는 래퍼 */
export function Async({ state, empty, children }) {
  if (state.loading) return <Loading />
  if (state.error) return <ErrorBox error={state.error} onRetry={state.reload} />
  if (empty) return <Empty text={empty} />
  return children
}
