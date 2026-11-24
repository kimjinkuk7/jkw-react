import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useApp } from '../app/AppContext'
import { activeRootCode, buildMenuTree } from '../app/navMap'
import { aspView } from '../app/config'

/**
 * 공통 상단. ASP 의 view/include/Header.asp + Gnb.asp 와 같은 마크업을 낸다.
 *
 * assets/js/common.js 를 불러오지 않는 이유
 *   common.js 는 문서 로드 시점에 .nav-toggle / .theme-toggle 을 찾아 이벤트를 건다.
 *   SPA 는 그 시점에 DOM 이 비어 있고, 이후 React 가 노드를 갈아끼우므로
 *   핸들러가 죽은 노드에 남는다. 그래서 토글은 React 상태로 직접 구현한다.
 *   테마 저장 키(jkw-theme)는 ASP 스택과 같은 값을 쓴다 -> 두 스택을 오가도 유지된다.
 */
export default function Header() {
  const { site, menus, me, logout } = useApp()
  const loc = useLocation()
  const navigate = useNavigate()

  const [navOpen, setNavOpen] = useState(false)
  const [openCode, setOpenCode] = useState('')

  const tree = buildMenuTree(menus)
  const activeCode = activeRootCode(loc.pathname, tree)

  // 라우트가 바뀌면 모바일 패널을 닫는다
  useEffect(() => {
    setNavOpen(false)
    setOpenCode('')
  }, [loc.pathname, loc.search])

  // body.nav-open : 공용 CSS 가 모바일 슬라이드 패널을 여는 스위치
  useEffect(() => {
    document.body.classList.toggle('nav-open', navOpen)
    return () => document.body.classList.remove('nav-open')
  }, [navOpen])

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && setNavOpen(false)
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const toggleTheme = () => {
    const root = document.documentElement
    const cur = root.getAttribute('data-theme')
    const next =
      cur === 'dark'
        ? 'light'
        : cur === 'light'
          ? 'dark'
          : window.matchMedia('(prefers-color-scheme: dark)').matches
            ? 'light'
            : 'dark'
    root.setAttribute('data-theme', next)
    try {
      localStorage.setItem('jkw-theme', next)
    } catch {
      /* 시크릿 모드 등에서 거부될 수 있다. 테마만 못 저장할 뿐 동작엔 지장 없다 */
    }
  }

  const onLogout = async () => {
    await logout()
    navigate('/')
  }

  const MenuLink = ({ item, className }) => {
    if (!item.route) return <span className={className}>{item.name}</span>
    if (item.route.external) {
      return (
        <a className={className} href={item.route.to}>
          {item.name}
        </a>
      )
    }
    return (
      <Link className={className} to={item.route.to}>
        {item.name}
      </Link>
    )
  }

  return (
    <header id="header">
      <div className="wrap header-inner">
        <Link to="/" className="logo">
          <span>
            {site.title}
            <b className="dot">.</b>
          </span>
          {site.subtitle && <span className="sub">{site.subtitle}</span>}
        </Link>

        <nav id="gnb" aria-label="주 메뉴">
          <ul>
            {tree.map((m) => {
              const hasChild = m.children.length > 0
              const isOn = activeCode === m.code
              return (
                <li key={m.id} className={[isOn ? 'is-on' : '', openCode === m.code ? 'is-open' : ''].join(' ').trim()}>
                  {hasChild ? (
                    <>
                      <span
                        className="gnb-label"
                        role="button"
                        tabIndex={0}
                        onClick={() => setOpenCode(openCode === m.code ? '' : m.code)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault()
                            setOpenCode(openCode === m.code ? '' : m.code)
                          }
                        }}
                      >
                        {m.name}
                      </span>
                      <div className="sub-menu" style={openCode === m.code ? { display: 'flex' } : undefined}>
                        {m.children.map((c) => (
                          <MenuLink key={c.id} item={c} />
                        ))}
                      </div>
                    </>
                  ) : (
                    <MenuLink item={m} />
                  )}
                </li>
              )
            })}
          </ul>

          <div className="gnb-account">
            {me.isLogin ? (
              <>
                <a className="btn btn-sm" href={aspView('/member/Mypage.asp')}>
                  {me.name} 님
                </a>
                <button type="button" className="btn btn-sm" onClick={onLogout}>
                  로그아웃
                </button>
              </>
            ) : (
              <>
                <Link className="btn btn-sm btn-primary" to="/login">
                  로그인
                </Link>
                <a className="btn btn-sm" href={aspView('/member/Join.asp')}>
                  회원가입
                </a>
              </>
            )}
          </div>
        </nav>

        <div className="header-util">
          <button
            type="button"
            className="btn btn-sm btn-ghost theme-toggle"
            aria-label="테마 전환"
            title="테마 전환"
            onClick={toggleTheme}
          >
            ◐
          </button>

          {me.isLogin ? (
            <>
              <span className="util-name">{me.name}</span>
              <a className="util-link" href={aspView('/member/Mypage.asp')}>
                마이페이지
              </a>
              {me.isAdmin && (
                <a className="util-link" href={aspView('/admin/Default.asp')}>
                  관리자
                </a>
              )}
              <button type="button" className="util-link" onClick={onLogout}>
                로그아웃
              </button>
            </>
          ) : (
            <>
              <Link className="util-link" to="/login">
                로그인
              </Link>
              <a className="util-link" href={aspView('/member/Join.asp')}>
                회원가입
              </a>
            </>
          )}

          <button
            type="button"
            className="nav-toggle"
            aria-label={navOpen ? '메뉴 닫기' : '메뉴 열기'}
            aria-expanded={navOpen}
            aria-controls="gnb"
            onClick={() => setNavOpen((v) => !v)}
          >
            <span />
          </button>
        </div>
      </div>
    </header>
  )
}
