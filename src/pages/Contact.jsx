import { useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { useApp } from '../app/AppContext'
import { ErrorBox } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'

const TYPES = ['프로젝트 문의', '채용 제안', '기술 질문', '기타']

export default function Contact() {
  const { site } = useApp()
  const [f, setF] = useState({
    contactType: TYPES[0],
    name: '',
    company: '',
    email: '',
    mobile: '',
    subject: '',
    content: '',
    agree: false,
  })
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState(null)
  const [done, setDone] = useState('')

  const set = (k) => (e) => {
    const v = e.target.type === 'checkbox' ? e.target.checked : e.target.value
    setF((p) => ({ ...p, [k]: v }))
  }

  const submit = async (e) => {
    e.preventDefault()
    setErr(null)
    setBusy(true)
    try {
      const res = await api.contact(f)
      setDone(res.message)
    } catch (e2) {
      setErr(e2)
    } finally {
      setBusy(false)
    }
  }

  if (done) {
    return (
      <div className="wrap wrap-narrow">
        <div className="page-head">
          <h2>문의 접수 완료</h2>
        </div>
        <div className="alert alert-info">{done}</div>
        <div className="btn-row mt-4">
          <Link className="btn btn-primary" to="/">
            메인으로
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="wrap wrap-narrow">
      <div className="page-head">
        <Breadcrumb items={[{ to: '/', label: 'HOME' }, { label: 'CONTACT' }]} />
        <h2>문의하기</h2>
        <p className="desc">프로젝트 · 채용 · 기술 문의를 남겨주세요.</p>
      </div>

      <div className="contact-grid">
        <form onSubmit={submit}>
          <div className="form-group">
            <label className="form-label" htmlFor="ct-type">
              문의 유형
            </label>
            <select id="ct-type" className="select" value={f.contactType} onChange={set('contactType')}>
              {TYPES.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </div>

          <div className="form-inline mb-3">
            <input className="input" placeholder="이름" maxLength={50} value={f.name} onChange={set('name')} required />
            <input className="input" placeholder="회사 / 소속" maxLength={100} value={f.company} onChange={set('company')} />
          </div>

          <div className="form-inline mb-3">
            <input
              type="email"
              className="input"
              placeholder="이메일"
              maxLength={100}
              value={f.email}
              onChange={set('email')}
              required
            />
            <input className="input" placeholder="연락처" maxLength={20} value={f.mobile} onChange={set('mobile')} />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="ct-subject">
              제목
            </label>
            <input
              id="ct-subject"
              className="input"
              maxLength={200}
              value={f.subject}
              onChange={set('subject')}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="ct-content">
              내용
            </label>
            <textarea
              id="ct-content"
              className="textarea"
              rows={10}
              maxLength={4000}
              value={f.content}
              onChange={set('content')}
              required
            />
            <div className="form-help tr">{f.content.length} / 4000 (10자 이상)</div>
          </div>

          <div className="privacy-box">
            <label className="check">
              <input type="checkbox" checked={f.agree} onChange={set('agree')} required /> 개인정보 수집 및 이용에
              동의합니다.
            </label>
            <p className="form-help mt-2">
              수집 항목 : 이름 · 이메일 · 연락처 · 문의 내용 / 보유 기간 : 문의 처리 후 1년
            </p>
          </div>

          <ErrorBox error={err} />

          <div className="btn-row right mt-4">
            <button type="submit" className="btn btn-primary" disabled={busy}>
              {busy ? '보내는 중…' : '문의 보내기'}
            </button>
          </div>
        </form>

        <aside className="contact-info">
          <h3>직접 연락</h3>
          <ul className="info-list">
            {site.ownerName && (
              <li>
                <span>담당</span>
                <strong>{site.ownerName}</strong>
              </li>
            )}
            {site.ownerEmail && (
              <li>
                <span>이메일</span>
                <strong>
                  <a href={`mailto:${site.ownerEmail}`}>{site.ownerEmail}</a>
                </strong>
              </li>
            )}
            {site.github && (
              <li>
                <span>GitHub</span>
                <strong>
                  <a href={site.github} target="_blank" rel="noopener noreferrer">
                    바로가기 ↗
                  </a>
                </strong>
              </li>
            )}
          </ul>
        </aside>
      </div>
    </div>
  )
}
