import { useCallback, useEffect, useRef, useState } from 'react'

/**
 * API 호출 1건의 수명주기(loading / data / error)를 담는 훅.
 *
 * 경쟁 조건 처리
 *   목록에서 페이지를 빠르게 넘기면 이전 요청이 나중에 도착해 화면을 덮을 수 있다.
 *   요청마다 일련번호를 매겨 마지막 것만 반영한다. (AbortController 로는
 *   이미 날아간 응답의 "도착 순서"까지는 막지 못한다)
 */
export function useAsync(fn, deps, { skip = false } = {}) {
  const [state, setState] = useState({ loading: !skip, data: null, error: null })
  const seq = useRef(0)

  const run = useCallback(() => {
    if (skip) {
      setState({ loading: false, data: null, error: null })
      return
    }
    const my = ++seq.current
    setState((s) => ({ ...s, loading: true, error: null }))

    Promise.resolve()
      .then(fn)
      .then((data) => {
        if (my === seq.current) setState({ loading: false, data, error: null })
      })
      .catch((error) => {
        if (my === seq.current) setState({ loading: false, data: null, error })
      })
    // skip 도 의존성에 넣는다. mode 만 바뀌고 id 는 그대로인 경우
    // (?mode=modify&id=5 -> ?mode=reply&id=5) 에 재실행되지 않는 것을 막는다.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, skip])

  useEffect(run, [run])

  return { ...state, reload: run }
}
