/**
 * 배치 경로 설정 — 이 리포지토리의 유일한 "위치" 설정
 * ---------------------------------------------------------------------------
 * 이 스택은 세 덩어리가 한 폴더 안에 들어 있다.
 *
 *   react/
 *   ├─ dist/        빌드된 SPA        <- 브라우저가 받는 화면
 *   ├─ server-asp/  Classic ASP API  <- 이 SPA 의 백엔드 (동봉)
 *   └─ upload/      업로드 파일
 *
 * 세 경로는 같은 IIS 사이트 안에 있으므로 동일 출처다. CORS 설정이 필요 없고
 * ASP 세션 쿠키가 그대로 붙는다.
 *
 * 값을 바꿔야 할 때는 .env 파일로 덮어쓴다. 소스를 고칠 필요는 없다.
 *
 *   .env.local
 *     VITE_API_BASE=/server-asp/api      # react 폴더가 사이트 루트일 때
 *     VITE_ASP_VIEW=                     # ASP 화면 연동 끄기
 */

/** Classic ASP JSON API 의 베이스 경로 */
export const API_BASE =
  import.meta.env.VITE_API_BASE || '/react/server-asp/api'

/**
 * React 로 옮기지 않은 화면(회원가입 · 소셜 로그인 · 휴대폰 인증 · 후원 결제 · 관리자)을
 * 어디로 보낼지. 1차 Classic ASP 스택의 화면 계층 주소다.
 *
 * 왜 React 로 안 옮겼나
 *   소셜 로그인과 PG(토스/이니시스)는 리다이렉트·콜백 URL 이 ASP 주소로
 *   외부 개발자 콘솔에 등록돼 있다. React 로 옮기려면 그 등록부터 바꿔야 해서
 *   "렌더링 방식만 비교한다"는 이 스택의 범위를 넘는다.
 *
 * 빈 문자열이면 해당 링크를 화면에서 숨긴다 (ASP 스택 없이 React 만 띄울 때).
 */
export const ASP_VIEW_ROOT =
  import.meta.env.VITE_ASP_VIEW !== undefined
    ? import.meta.env.VITE_ASP_VIEW
    : '/asp/view'

/** ASP 화면 링크를 만든다. ASP_VIEW_ROOT 가 비어 있으면 null (링크를 걸지 않는다). */
export function aspView(path) {
  if (!ASP_VIEW_ROOT) return null
  return ASP_VIEW_ROOT + path
}
