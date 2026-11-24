import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { api, setCsrf } from '../api/client'

/**
 * 앱 전역 상태 : 사이트 설정 · GNB 메뉴 · 게시판 목록 · 로그인 세션 · CSRF 토큰
 *
 * 전부 /asp/api/Config.asp 한 번으로 받아온다.
 * ASP 스택에서 conf/Common.Conf.asp 가 매 요청마다 하던 일을,
 * SPA 에서는 앱 기동 시 한 번만 한다.
 */
const AppContext = createContext(null)

export function AppProvider({ children }) {
  const [boot, setBoot] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const reload = useCallback(async () => {
    try {
      const data = await api.config()
      setCsrf(data.csrf)
      setBoot(data)
      setError(null)
      return data
    } catch (e) {
      setError(e)
      throw e
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    reload().catch(() => {})
  }, [reload])

  const login = useCallback(
    async (loginId, password) => {
      const data = await api.login(loginId, password)
      // 로그인하면 세션이 새로 발급되어 CSRF 토큰이 바뀐다
      setCsrf(data.csrf)
      setBoot((prev) => (prev ? { ...prev, me: data.me, csrf: data.csrf } : prev))
      // 권한에 따라 메뉴/게시판 목록이 달라지므로 다시 받는다
      await reload()
      return data.me
    },
    [reload]
  )

  const logout = useCallback(async () => {
    await api.logout()
    // Session.Abandon 은 요청이 끝날 때 세션을 파기한다.
    // 즉 방금 응답에 담긴 토큰은 이미 무효다. 반드시 다시 받아야 한다.
    await reload()
  }, [reload])

  const value = {
    boot,
    loading,
    error,
    reload,
    login,
    logout,
    site: boot?.site ?? {},
    menus: boot?.menus ?? [],
    boards: boot?.boards ?? [],
    me: boot?.me ?? { isLogin: false, level: 1, name: '' },
  }

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}

export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp 은 AppProvider 안에서만 쓸 수 있습니다.')
  return ctx
}
