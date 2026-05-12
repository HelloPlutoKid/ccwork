# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

React 19 + TypeScript + Vite 기반 노트 앱 **실습/강의 프로젝트**. UI 문구는 한국어.
`src/types/note.ts`에 `tags 필드는 아직 없음 — 강의에서 추가할 것` 주석이 남아 있어, 모델/스키마는 **강의 진도에 맞춰 점진적으로 확장**하는 것이 전제다. 미리 필드를 채워 넣거나 추측으로 스키마를 늘리지 말 것.

데이터 영속화는 별도 백엔드 없이 루트의 `db.json`을 `json-server`로 서빙하는 mock REST API(`http://localhost:3001/notes`)에 위임한다.

## 자주 쓰는 명령어

| 명령 | 동작 |
|------|------|
| `npm run dev` | Vite(5173) + json-server(3001)을 `concurrently`로 동시 실행 |
| `npm run server` | json-server만 단독 실행 |
| `npm run build` | `tsc && vite build` — 타입 체크 통과해야 번들됨 |
| `npm run lint` | `eslint . --fix` (flat config) |
| `npm run format` | Prettier 일괄 포맷 |
| `npm test` / `npm run test:watch` | Vitest (jsdom + Testing Library, setup: `src/test-setup.ts`) |

단일 테스트 실행: `npx vitest run <파일경로 또는 패턴>` (watch 중에는 `p` 로 패턴 필터, `t` 로 테스트명 필터).

**중요**: API URL이 `src/api/notes.ts`에 `http://localhost:3001`로 하드코딩되어 있다. UI 동작 확인 시 반드시 `npm run dev`로 두 서버를 함께 띄워야 한다. json-server가 죽으면 fetch가 전부 실패한다.

## 아키텍처

### 데이터 / 상태 흐름

```
db.json ─json-server─► src/api/notes.ts ─► NotesContext ─► 컴포넌트
                                              ▲                │
                                              └─ createNote/updateNote/deleteNote ◄┘
```

- **`src/api/notes.ts`** — `fetch` 기반 CRUD 4종 (`fetchNotes`/`createNote`/`updateNote`/`deleteNote`). `createdAt`/`updatedAt` 타임스탬프는 **클라이언트에서 ISO 문자열로 생성**해 서버에 전송한다 (json-server가 자동 채워주지 않음).
- **`src/context/NotesContext.tsx`** — 앱 전역 단일 노트 스토어. 마운트 시 1회 fetch → 이후 mutate는 **서버 응답으로 로컬 배열을 갱신**(낙관적 업데이트 아님). 노출 메서드는 `createNote`/`updateNote`/`deleteNote`로 **api 모듈과 같은 이름을 쓰며 namespace import(`api.*`)로 충돌을 피한다**. `useNotes()`는 Provider 밖에서 호출되면 throw하므로 신규 컴포넌트는 `<NotesProvider>` 트리 안인지 확인.
- **`src/App.tsx`** — 데이터는 손대지 않는다. `selectedNoteId`와 `isCreating` 두 가지 **UI 상태만** 보유하고, 선택/신규/완료 핸들러로 모드를 토글한다.

### 컴포넌트 구성

`Layout`은 **슬롯 패턴**으로 `sidebar`/`main`을 props로 받는다 (`src/App.tsx:28-38`). 화면 영역을 추가할 때 이 컨벤션을 유지할 것 (Layout 안에 새 영역을 박지 말고 슬롯을 늘리는 방향).

- `components/Layout.tsx` — 헤더 + 사이드바 + 메인 셸. 순수 presentational, 상태 없음.
- `components/NoteList.tsx` → `components/NoteItem.tsx` — Context에서 `notes`를 직접 구독해 렌더. 삭제도 `NoteItem`이 Context의 `deleteNote`를 호출.
- `components/NoteEditor.tsx` — 생성/편집 **겸용 폼**. `isCreating`이면 `createNote`, 아니면 `updateNote`. 선택이 바뀌면 `useEffect`로 폼 값 동기화하는데, 의존성 배열은 의도적으로 `selectedNote`를 빼고 `eslint-disable react-hooks/exhaustive-deps` 주석으로 막아두었다 — 손대지 말 것.

### 스타일링

**Tailwind v4** (`@tailwindcss/vite` 플러그인 경유, `tailwind.config.*` 없음). 디자인 토큰은 `src/index.css`의 `@theme` 블록에서 CSS 변수로 정의되어 있고(`--color-foreground`, `--color-muted-foreground`, `--color-destructive`, `--radius` 등), 마크업에서는 `bg-foreground` `text-muted-foreground` 같은 **시맨틱 클래스명**을 쓴다.

- 새 색을 hex로 직접 박지 말고 `@theme`에 토큰을 추가하거나 기존 토큰을 재사용.
- 디스플레이 글꼴 `Boogaloo`는 `Layout.tsx`에서 인라인 `style` 로 지정됨 (Tailwind 토큰으로 통일되어 있지 않은 예외).

## 구현 패턴

### 컴포넌트
- **함수 선언식 + named export** 고정: `export function Component({ ... }: ComponentProps) { ... }`. 진입점 `App`만 `export default`.
- **Props 타입**: 같은 파일 상단에 `interface {Component}Props { ... }`로 선언 (예: `LayoutProps`, `NoteItemProps`). type alias 형태는 쓰이지 않음.
- **Props 구조 분해는 시그니처에서**: 함수 본문 첫 줄 `const { ... } = props` 형태는 사용 안 함.
- **조건부 렌더는 early return**: `NoteList`는 loading/error/empty를 각각 early return, `NoteEditor`도 선택 없는 상태를 먼저 return. 삼항 중첩으로 분기시키지 말 것.
- **레이아웃은 슬롯 props로 합성**: `Layout`이 `sidebar`/`main`을 `ReactNode`로 받음 (children 다중 슬롯 패턴). 새 영역은 슬롯을 늘리는 방향으로.
- **JSX 내 섹션 주석은 한국어**: `{/* 헤더 */}`, `{/* 사이드바 */}` 식으로 큰 블록 구분 (`Layout.tsx`, `NoteEditor.tsx` 참고).
- **컴포넌트 파일당 1 컴포넌트**, 보조 컴포넌트 동일 디렉터리에 별도 파일로 분리 (`NoteList` + `NoteItem`).

### 상태 관리
- **도메인 데이터(Notes)** → `NotesContext` 단일 스토어. 컴포넌트는 `useNotes()`로만 접근.
- **UI 상태(선택, 모드)** → 가장 가까운 부모(`App.tsx`)의 `useState`.
- **폼 상태** → 폼 컴포넌트 내부 `useState` (`NoteEditor`의 `title`/`content`/`saving`). 끌어올리지 않음.
- Context value는 객체 리터럴로 한 번에 전달, `useMemo` 래핑은 하지 않음 (학습 단계상 의도된 단순화로 보임).
- Provider 밖에서 훅을 호출하면 throw하는 가드를 `useNotes()`에 둠 — 새 Context를 만들 때도 같은 가드를 둘 것.

### API 호출
- `src/api/notes.ts` **하나의 모듈에 모든 엔드포인트** 함수형으로. axios 미사용, 전부 `fetch` + `async/await`.
- 함수명은 **HTTP 의미의 동사 + 엔티티**: `fetchNotes`, `createNote`, `updateNote`, `deleteNote`. Context가 노출하는 메서드도 `create/update/deleteNote`로 **동일한 이름을 그대로 사용**해 의미 매핑을 단순화한다.
- **에러 전파/로깅 규약**: api 함수는 `if (!res.ok) throw new Error('Failed to {verb} ...')`로 throw만 한다. 호출 측에서 catch하여 **`console.error(메시지, e)`로 로깅** (UI alert 금지). 사용자에게 표시할 필요가 있는 에러는 `NotesContext`의 `error` state처럼 별도 채널을 두고 표현.
- **payload 타입은 유틸 타입으로 좁힘**: 생성은 `Omit<Note, 'id' | 'createdAt' | 'updatedAt'>`, 수정은 `Partial<Note>`.
- **타임스탬프는 클라이언트 책임**: `new Date().toISOString()`을 create/update payload에 직접 넣음 (json-server가 안 채워줌).
- Context는 `import * as api from '../api/notes'` 네임스페이스 import — Context 메서드와 api 함수 이름이 같아도 `api.createNote` vs 로컬 `createNote`로 구분된다. 컴포넌트는 api 모듈을 import하지 않음.

### 네이밍
- **파일명**: 컴포넌트 `PascalCase.tsx`, 그 외 모듈 `camelCase.ts`(`notes.ts`, `note.ts`). Context 파일도 PascalCase.
- **이벤트 핸들러 이름**:
  - props로 내려보내는 콜백: `on*` (`onSelect`, `onDelete`, `onDone`, `onNewNote`)
  - 컴포넌트 내부에서 정의한 핸들러: `handle*` (`handleSelectNote`, `handleSave`)
- **Context 메서드 = API 동사**: `createNote`/`updateNote`/`deleteNote`로 통일 (구버전의 `addNote`/`editNote`/`removeNote`는 폐기). 새 엔티티를 추가할 때도 `create`/`update`/`delete` 동사를 그대로 따를 것.
- **에러 처리 동사**: 로깅은 `console.error(...)`로만 한다 (`alert()` 금지).
- **타입**: 도메인 모델 `Note` 단수, 배열 변수는 `notes`. Props 타입은 `{Component}Props`.

### 코드 컨벤션
- TypeScript `strict` + `noUnusedLocals` + `noUnusedParameters` 켜져 있음. 미사용 import/변수는 빌드 실패.
- JSX runtime은 `react-jsx`이므로 `import React`는 불필요.
- Prettier: semi `true`, singleQuote `true`, trailingComma `"all"`, printWidth `100`, tabWidth `2`. 커밋 전 `npm run format` 권장.
- 경로 alias 없음 — 전부 상대 경로 import.
- `import type` 구문은 사용하지 않고 일반 `import { Note }`로 타입을 가져오는 것이 현 컨벤션.
- **ID는 서버 생성**: `db.json`에 수동 ID(`"1"`)와 json-server 생성 ID(`"dP_NPYuHV94"`)가 섞여 있는 것이 정상. 클라이언트에서 ID를 만들지 말 것.

## 일관성이 부족한 부분 (수정 시 주의)

코드에 실제로 섞여 있는 패턴들. 새 코드를 더할 때 어느 쪽을 따를지 의식적으로 골라야 한다.

- **Boolean 변수 prefix 불일치**: `isCreating`, `isSelected`처럼 `is*` 접두를 쓰는 곳이 있는 반면, `saving`(`NoteEditor`), `loading`(`NotesContext`)은 접두가 없다. 새 boolean state는 `is*` 쪽으로 통일하는 것을 권장.
- **사용자 노출 알림 채널 부재**: 에러 로깅이 `console.error`로 일원화되어 있어 사용자에게는 검증 실패가 직접 보이지 않는다 (`NoteEditor`의 빈 제목 케이스 등). 토스트/인라인 메시지 시스템을 도입할 때 어디서 어떤 에러를 사용자에게 보여줄지 결정 필요.
- **인라인 `style` 혼용**: 거의 모든 스타일이 Tailwind 클래스인데 `Layout.tsx`에 두 군데 인라인 style이 있음 — `fontFamily: 'Boogaloo, sans-serif'`와 `height: 'calc(100vh - 65px)'`. 폰트는 `@theme`의 `--font-display`로 토큰화되어 있지만 실제로 그 토큰을 쓰는 곳은 아직 없다.
- **`useEffect` 의존성 의도된 누락**: `NoteEditor.tsx`에서 `selectedNote`를 deps에 넣지 않고 `eslint-disable react-hooks/exhaustive-deps` 주석으로 막아둠. 같은 파일을 수정할 때 이 줄을 무심코 풀지 말 것 — 폼 입력 중 외부 변경에 덮어쓰이지 않게 하려는 의도로 보인다.
