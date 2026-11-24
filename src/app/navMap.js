/**
 * DB 메뉴(tb_menu) -> React 라우트 변환
 * ---------------------------------------------------------------------------
 * tb_menu.menu_url 은 ASP 화면 기준 경로(`/board/List.asp?bid=free`)다.
 * 4개 스택이 같은 메뉴 테이블을 쓰므로 이 값을 바꿀 수는 없다.
 * 그래서 읽는 쪽에서 변환한다.
 *
 * React 스택이 구현하지 않은 화면(후원/결제, 회원가입, 관리자)은 억지로 흉내내지 않고
 * ASP 스택 URL 로 그대로 내보낸다. external: true 로 표시해서 <a> 로 렌더한다.
 *   - 결제(토스/이니시스)는 PG 창이 ASP 페이지의 콜백 URL 에 묶여 있다.
 *     React 로 옮기려면 PG 콘솔의 리턴 URL 을 새로 등록해야 해서 범위를 넘는다.
 */

import { ASP_VIEW_ROOT } from './config'

export function toRoute(aspUrl) {
  const url = (aspUrl || '').trim()
  if (!url) return null

  const [path, query = ''] = url.split('?')
  const bid = new URLSearchParams(query).get('bid')

  if (path.startsWith('/main/')) return { to: '/', external: false }
  if (path.startsWith('/about/')) return { to: aboutTab(path), external: false }
  if (path.startsWith('/portfolio/')) return { to: '/portfolio', external: false }
  if (path.startsWith('/contact/')) return { to: '/contact', external: false }
  if (path.startsWith('/board/') && bid) return { to: `/board/${bid}`, external: false }
  if (path.startsWith('/member/Login')) return { to: '/login', external: false }

  // 그 밖은 ASP 화면 계층으로 보낸다.
  // ASP_VIEW_ROOT 가 비어 있으면(ASP 스택 없이 React 만 띄운 경우) 링크를 만들지 않는다.
  if (!ASP_VIEW_ROOT) return null
  return { to: ASP_VIEW_ROOT + url, external: true }
}

function aboutTab(path) {
  if (path.includes('Career')) return '/about?tab=career'
  if (path.includes('Skill')) return '/about?tab=skill'
  if (path.includes('Resume')) return '/about?tab=resume'
  return '/about'
}

/** 1depth 메뉴 + 그 하위 메뉴를 트리로 묶는다 */
export function buildMenuTree(menus) {
  const roots = menus.filter((m) => m.depth === 1)
  return roots.map((r) => ({
    ...r,
    route: toRoute(r.aspUrl),
    children: menus
      .filter((m) => m.parentId === r.id)
      .map((c) => ({ ...c, route: toRoute(c.aspUrl) })),
  }))
}

/** 현재 경로에서 활성화할 1depth 메뉴 코드를 고른다 */
export function activeRootCode(pathname, tree) {
  for (const root of tree) {
    const all = [root, ...root.children]
    for (const m of all) {
      if (!m.route || m.route.external) continue
      const base = m.route.to.split('?')[0]
      if (base === '/' ? pathname === '/' : pathname.startsWith(base)) return root.code
    }
  }
  return ''
}
