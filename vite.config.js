import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

/**
 * jkw.com - React 스택
 *
 * 이 리포지토리는 자립형이다. SPA 와 그 백엔드(Classic ASP JSON API)가 한 폴더에 있다.
 *
 *   react/
 *   ├─ src/         SPA 원본
 *   ├─ dist/        빌드 산출물        <- IIS 가 서비스하는 것
 *   ├─ public/      그대로 dist 로 복사 (assets/, web.config)
 *   ├─ server-asp/  Classic ASP JSON API (동봉된 백엔드)
 *   ├─ upload/      업로드 파일
 *   └─ db/mssql/    DB 스키마
 *
 * 개발 : http://localhost:5173/                (base '/')
 * 운영 : http://localhost:8080/react/dist/     (base '/react/dist/')
 *
 * base 를 빌드할 때만 바꾸는 이유
 *   라우터 basename 을 import.meta.env.BASE_URL 로 받으면 개발/운영 모두
 *   같은 코드로 동작한다. 개발 중에 /react/dist/ 를 치고 다닐 필요가 없다.
 *
 * 프록시를 쓰는 이유 (CORS 를 쓰지 않는 이유)
 *   ASP 세션은 쿠키로 유지된다. 5173 -> 8080 을 교차 출처로 부르면
 *   SameSite / credentials / Set-Cookie 도메인 문제가 한꺼번에 몰려온다.
 *   dev 서버가 같은 출처인 척 중계하면 쿠키가 그대로 붙어 그 문제가 전부 사라진다.
 *   운영에서는 SPA 와 API 가 같은 IIS 사이트이므로 애초에 동일 출처다.
 *
 *   ※ /assets 는 프록시하지 않는다. public/assets/ 가 dev 서버에서 바로 서빙된다.
 *     (이 리포지토리가 CSS/JS 사본을 직접 들고 있기 때문)
 *
 * 디버그 빌드 (npm run build:debug)
 *   dist 의 번들은 기본적으로 압축돼 있어 사람이 읽을 수 없다.
 *   그건 정상이다. dist 는 "브라우저가 읽는 결과물"이고,
 *   사람이 읽는 원본은 src/ 다. dist 를 직접 고치면 다음 빌드에 덮어써진다.
 *
 *   다만 브라우저에서 실제로 도는 코드를 따라가며 봐야 할 때가 있다.
 *   그때는 --mode debug 로 빌드한다.
 *     minify   : false  -> 번들이 줄바꿈·들여쓰기된 상태로 나온다
 *     sourcemap: true   -> 개발자도구가 압축본 대신 원본 .jsx 를 보여준다
 *
 *   ★ 확인이 끝나면 npm run build 로 되돌릴 것.
 *     디버그 빌드는 용량이 3배 가까이 크고 소스가 그대로 노출된다.
 */
export default defineConfig(({ command, mode }) => ({
  plugins: [react()],

  base: command === 'build' ? '/react/dist/' : '/',

  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      // 동봉된 Classic ASP JSON API + 첨부 다운로드
      '/react/server-asp': { target: 'http://localhost:8080', changeOrigin: false },
      // 업로드 이미지 (게시판 썸네일 / 포트폴리오 대표 이미지)
      '/react/upload': { target: 'http://localhost:8080', changeOrigin: false },
      // React 로 옮기지 않은 화면(회원가입·소셜·결제·관리자) 링크 확인용.
      // src/app/config.js 의 ASP_VIEW_ROOT 를 비우면 필요 없다.
      '/asp': { target: 'http://localhost:8080', changeOrigin: false },
    },
  },

  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // mode 가 'debug' 일 때만 압축을 끄고 소스맵을 붙인다
    minify: mode === 'debug' ? false : 'esbuild',
    sourcemap: mode === 'debug',
  },
}))
