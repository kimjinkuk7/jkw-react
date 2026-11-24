import { Link } from 'react-router-dom'
import { useApp } from '../app/AppContext'

/**
 * 공통 하단. ASP 의 view/include/Footer.asp 와 같은 마크업.
 *
 * Today / Total 방문수는 넣지 않는다.
 * ASP 스택은 화면 요청 1건 = 방문 1건이지만, SPA 는 화면 하나에 API 를 여러 번 부른다.
 * 같은 숫자를 띄우면 두 스택의 통계가 서로 어긋나 보이므로 아예 표시하지 않는다.
 * (conf/Common.Conf.asp 에서 /api/ 요청을 방문 집계에서 제외한 것과 같은 이유)
 */
export default function Footer() {
  const { site } = useApp()

  return (
    <footer id="footer">
      <div className="wrap">
        <div className="footer-top">
          <div className="footer-brand">
            <span className="logo">
              {site.title}
              <b className="dot">.</b>
            </span>
            <p>{site.siteDesc}</p>
            {site.ownerEmail && (
              <p>
                <a href={`mailto:${site.ownerEmail}`}>{site.ownerEmail}</a>
              </p>
            )}
          </div>

          <nav className="footer-links" aria-label="하단 메뉴">
            <Link to="/about">소개</Link>
            <Link to="/portfolio">포트폴리오</Link>
            <Link to="/board/blog">블로그</Link>
            <Link to="/board/notice">공지사항</Link>
            <Link to="/board/guest">방명록</Link>
            <Link to="/contact">문의하기</Link>
            {site.github && (
              <a href={site.github} target="_blank" rel="noopener noreferrer">
                GitHub
              </a>
            )}
          </nav>
        </div>

        <div className="footer-bottom">
          <span dangerouslySetInnerHTML={{ __html: site.copyright || '' }} />
          <span className="footer-stat">
            <span>Stack <strong>React + Classic ASP</strong></span>
          </span>
        </div>
      </div>
    </footer>
  )
}
