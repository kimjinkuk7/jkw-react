import { Link, useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import { useAsync } from '../app/useAsync'
import { Async } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'
import { aspView } from '../app/config'

/**
 * 소개 — ASP 는 Default / Career / Skill / Resume 4개 화면이지만
 * React 에서는 한 화면 + 탭(?tab=)으로 묶는다.
 * 데이터가 About.asp 한 번에 다 오므로 탭을 바꿀 때 재요청이 없다.
 */
const TABS = [
  { key: 'career', label: '경력 · 학력' },
  { key: 'skill', label: '기술 스택' },
  { key: 'resume', label: '이력서' },
]

const TYPE_LABEL = { work: '경력', edu: '학력', cert: '자격증', award: '수상' }
const TYPE_ORDER = ['work', 'edu', 'cert', 'award']

export default function About() {
  const [sp, setSp] = useSearchParams()
  const tab = TABS.some((t) => t.key === sp.get('tab')) ? sp.get('tab') : 'career'

  const state = useAsync(() => api.about(), [])
  const d = state.data

  return (
    <div className="wrap wrap-narrow">
      <div className="page-head">
        <Breadcrumb items={[{ to: '/', label: 'HOME' }, { label: 'ABOUT' }]} />
        <h2>소개</h2>
        {d && (
          <p className="desc">
            총 경력 <strong>{d.totalYears}년</strong>
          </p>
        )}
      </div>

      <nav className="cate-tabs" aria-label="소개 메뉴">
        {TABS.map((t) => (
          <Link
            key={t.key}
            to={`/about?tab=${t.key}`}
            className={tab === t.key ? 'is-on' : ''}
            onClick={(e) => {
              e.preventDefault()
              setSp({ tab: t.key })
            }}
          >
            {t.label}
          </Link>
        ))}
      </nav>

      <Async state={state}>
        {d && (
          <>
            {tab === 'career' && <CareerView careers={d.careers} />}
            {tab === 'skill' && <SkillView skills={d.skills} groups={d.skillGroups} />}
            {tab === 'resume' && <ResumeView d={d} />}
          </>
        )}
      </Async>

      <div className="btn-row mt-5">
        <Link className="btn btn-primary" to="/portfolio">
          이 기술로 만든 프로젝트 보기
        </Link>
      </div>
    </div>
  )
}

function CareerView({ careers }) {
  const groups = TYPE_ORDER.map((t) => ({ type: t, items: careers.filter((c) => c.type === t) })).filter(
    (g) => g.items.length > 0
  )

  if (groups.length === 0) return <div className="empty">등록된 경력이 없습니다.</div>

  return (
    <>
      {groups.map((g) => (
        <section className="section" key={g.type}>
          <div className="section-head">
            <h3>{TYPE_LABEL[g.type] || g.type}</h3>
          </div>
          <ul className="timeline">
            {g.items.map((c) => (
              <li key={c.id}>
                <span className="period">{c.period}</span>
                <h4>
                  {c.orgUrl ? (
                    <a href={c.orgUrl} target="_blank" rel="noopener noreferrer">
                      {c.title} ↗
                    </a>
                  ) : (
                    c.title
                  )}
                  {c.isCurrent && <span className="badge badge-primary is-current">재직중</span>}
                </h4>
                {c.position && <span className="position">{c.position}</span>}
                {c.careerDesc && <div className="desc">{c.careerDesc}</div>}
              </li>
            ))}
          </ul>
        </section>
      ))}
    </>
  )
}

function SkillView({ skills, groups }) {
  if (groups.length === 0) return <div className="empty">등록된 기술 스택이 없습니다.</div>

  return (
    <>
      <p className="desc mb-4">막대는 숙련도, 우측 숫자는 실무 사용 기간입니다.</p>
      {groups.map((g) => (
        <section className="skill-group" key={g.name}>
          <h4>{g.name}</h4>
          <div className="skill-list">
            {skills
              .filter((s) => s.group === g.name)
              .map((s) => (
                <div className="skill-item" key={s.id}>
                  <div className="top">
                    <span className="nm">{s.name}</span>
                    <span className="yr">{s.expYear > 0 ? `${s.expYear}년` : ''}</span>
                  </div>
                  <div className="skill-bar">
                    <i style={{ width: `${s.levelPct}%`, ...(s.color ? { background: s.color } : null) }} />
                  </div>
                  {s.skillDesc && <p className="form-help">{s.skillDesc}</p>}
                </div>
              ))}
          </div>
        </section>
      ))}
    </>
  )
}

function ResumeView({ d }) {
  return (
    <>
      <div className="alert alert-info">
        인쇄용 이력서는 ASP 스택 화면을 그대로 씁니다.{' '}
        <a href={aspView('/about/Resume.asp')} target="_blank" rel="noopener noreferrer">
          이력서 열기 ↗
        </a>
      </div>

      <section className="section">
        <div className="section-head">
          <h3>요약</h3>
        </div>
        <ul className="info-list">
          <li>
            <span>총 경력</span>
            <strong>{d.totalYears}년</strong>
          </li>
          <li>
            <span>등록 경력 항목</span>
            <strong>{d.careers.length}건</strong>
          </li>
          <li>
            <span>기술 스택</span>
            <strong>{d.skills.length}개</strong>
          </li>
        </ul>
      </section>

      <section className="section">
        <div className="section-head">
          <h3>보유 기술</h3>
        </div>
        <div className="stack">
          {d.skills.map((s) => (
            <span className="chip" key={s.id}>
              {s.name}
            </span>
          ))}
        </div>
      </section>
    </>
  )
}
