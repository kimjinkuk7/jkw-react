import { useEffect } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import Header from './Header'
import Footer from './Footer'
import { useApp } from '../app/AppContext'
import { ErrorBox, Loading } from './Status'
import { API_BASE } from '../app/config'

/** 라우트가 바뀌면 맨 위로 (SPA 는 브라우저가 해주지 않는다) */
function ScrollToTop() {
  const { pathname, search } = useLocation()
  useEffect(() => {
    window.scrollTo(0, 0)
  }, [pathname, search])
  return null
}

export default function Layout() {
  const { loading, error, reload } = useApp()

  // 부트스트랩(Config.asp)이 실패하면 메뉴도 사이트명도 없다.
  // 반쪽짜리 헤더를 그리는 대신 원인을 그대로 보여준다.
  if (loading) {
    return (
      <main id="content">
        <div className="wrap">
          <Loading text="사이트 설정을 불러오는 중…" />
        </div>
      </main>
    )
  }

  if (error) {
    return (
      <main id="content">
        <div className="wrap" style={{ paddingTop: 40 }}>
          <div className="page-head">
            <h2>서버에 연결하지 못했습니다</h2>
            <p className="desc">동봉된 Classic ASP API({API_BASE}/Config.asp)를 읽을 수 없습니다.</p>
          </div>
          <ErrorBox error={error} onRetry={reload} />
          <ul className="info-list mt-4">
            <li>IIS 가 켜져 있고 이 폴더(<code>react</code>)가 사이트로 등록돼 있는지</li>
            <li>개발 중이라면 <code>vite.config.js</code> 의 프록시 target 포트가 맞는지</li>
            <li>
              <code>{API_BASE}/Config.asp</code> 를 브라우저에서 직접 열어 JSON 이 나오는지
              (백엔드 문제인지 프런트 문제인지 구분)
            </li>
            <li>DB(<code>jkwcom</code>)가 올라와 있는지 — <code>server-asp/App.Conf.asp</code> 의 접속 설정</li>
          </ul>
        </div>
      </main>
    )
  }

  return (
    <>
      <ScrollToTop />
      <a className="skip-link" href="#content">
        본문 바로가기
      </a>
      <Header />
      <main id="content">
        <Outlet />
      </main>
      <Footer />
    </>
  )
}
