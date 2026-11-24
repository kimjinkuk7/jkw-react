import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useApp } from '../app/AppContext'
import { ErrorBox } from '../components/Status'
import Breadcrumb from '../components/Breadcrumb'
import { aspView } from '../app/config'

export default function Login() {
  const { login, me } = useApp()
  const navigate = useNavigate()

  const [loginId, setLoginId] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState(null)

  const submit = async (e) => {
    e.preventDefault()
    setErr(null)
    setBusy(true)
    try {
      await login(loginId, password)
      navigate('/')
    } catch (e2) {
      setErr(e2)
    } finally {
      setBusy(false)
    }
  }

  if (me.isLogin) {
    return (
      <div className="wrap wrap-narrow">
        <div className="auth-wrap">
          <div className="auth-box">
            <h2>이미 로그인되어 있습니다</h2>
            <p className="muted mt-2">{me.name} 님으로 로그인 중입니다.</p>
            <div className="btn-row mt-4">
              <Link className="btn btn-primary" to="/">
                메인으로
              </Link>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="wrap wrap-narrow">
      <div className="page-head">
        <Breadcrumb items={[{ to: '/', label: 'HOME' }, { label: '로그인' }]} />
        <h2>로그인</h2>
      </div>

      <div className="auth-wrap">
        <form className="auth-box" onSubmit={submit}>
          <div className="form-group">
            <label className="form-label" htmlFor="lg-id">
              아이디
            </label>
            <input
              id="lg-id"
              className="input"
              maxLength={30}
              autoComplete="username"
              value={loginId}
              onChange={(e) => setLoginId(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="lg-pw">
              비밀번호
            </label>
            <input
              id="lg-pw"
              type="password"
              className="input"
              maxLength={64}
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <ErrorBox error={err} />

          <div className="btn-row mt-4">
            <button type="submit" className="btn btn-primary btn-block" disabled={busy}>
              {busy ? '확인 중…' : '로그인'}
            </button>
          </div>

          {/* 회원가입 · 소셜 로그인 · 휴대폰 인증은 ASP 화면을 그대로 쓴다.
              소셜은 OAuth 리다이렉트 URI 가 ASP 콜백 주소로 등록되어 있어
              React 로 옮기려면 각 제공자 콘솔의 설정을 바꿔야 한다. */}
          <div className="auth-links mt-4">
            <a href={aspView('/member/Join.asp')}>회원가입</a>
            <a href={aspView('/member/Login.asp')}>소셜 로그인 / 아이디 찾기</a>
          </div>
        </form>
      </div>
    </div>
  )
}
