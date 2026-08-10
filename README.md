# 미래탐험대 (Future Odyssey)

초등학생이 교실의 실제 직업 활동과 경제생활을 경험하며 자신의 흥미와 핵심역량을 발견하는 진로·경제 시뮬레이션 웹앱입니다.

## 기술 구성

- Next.js 16, React 19, TypeScript
- Supabase PostgreSQL 및 안전한 RPC 기반 학생 세션
- GitHub 소스 관리
- Vercel 자동 배포
- OpenAI Sites 호환 배포 유지

## 시작하기

Node.js 22.13 이상과 pnpm을 사용합니다.

```bash
pnpm install
pnpm dev
```

기본 접속 주소는 `http://localhost:3000`입니다.

## 환경 변수

Vercel의 Production, Preview, Development 환경에 다음 값을 설정합니다.

```text
SUPABASE_URL=https://okbrapkebgyieyvuxamb.supabase.co
SUPABASE_PUBLISHABLE_KEY=Supabase publishable key
```

브라우저에는 Supabase 비밀 키를 전달하지 않습니다. 학생 로그인 세션은 서버가 `HttpOnly`, `SameSite=Strict` 쿠키로 관리합니다.

## 검증과 배포

```bash
pnpm test
```

`main` 브랜치에 변경사항이 올라가면 연결된 Vercel 프로젝트가 새 배포를 만듭니다. Sites용 배포가 필요할 때는 다음 빌드를 사용합니다.

```bash
pnpm sites:build
```

## 핵심 원칙

- 돈과 역량은 분리합니다.
- 역량은 실제 업무 수행으로만 성장합니다.
- 학생 간 순위와 직업 레벨을 사용하지 않습니다.
- 금액 변경은 클라이언트가 아닌 서버와 데이터베이스 함수가 처리합니다.
- 모든 공개 데이터 테이블에는 Row Level Security를 적용합니다.
