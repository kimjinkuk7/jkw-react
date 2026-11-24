import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { AppProvider } from './app/AppContext'

/**
 * basename 을 BASE_URL 로 받는 이유
 *   개발은 '/', 운영 빌드는 '/react/dist/' 로 base 가 달라진다 (vite.config.js).
 *   하드코딩하면 둘 중 한쪽이 깨지므로 Vite 가 주입하는 값을 그대로 쓴다.
 *   끝의 슬래시는 떼어낸다 ('/' 하나만 남는 개발 환경은 그대로 둔다).
 */
const basename = import.meta.env.BASE_URL.replace(/\/+$/, '') || '/'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter basename={basename}>
      <AppProvider>
        <App />
      </AppProvider>
    </BrowserRouter>
  </StrictMode>
)
