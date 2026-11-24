import { Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import About from './pages/About'
import PortfolioList from './pages/PortfolioList'
import PortfolioDetail from './pages/PortfolioDetail'
import BoardList from './pages/BoardList'
import ArticleDetail from './pages/ArticleDetail'
import ArticleWrite from './pages/ArticleWrite'
import Login from './pages/Login'
import Contact from './pages/Contact'
import NotFound from './pages/NotFound'

/**
 * 라우트
 *   /board/:bid/write 가 /board/:bid/:id 보다 먼저 와야 한다.
 *   순서를 바꾸면 'write' 가 글 번호로 잡혀 404 가 난다.
 */
export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
        <Route path="/portfolio" element={<PortfolioList />} />
        <Route path="/portfolio/:id" element={<PortfolioDetail />} />
        <Route path="/board/:bid" element={<BoardList />} />
        <Route path="/board/:bid/write" element={<ArticleWrite />} />
        <Route path="/board/:bid/:id" element={<ArticleDetail />} />
        <Route path="/login" element={<Login />} />
        <Route path="/contact" element={<Contact />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
