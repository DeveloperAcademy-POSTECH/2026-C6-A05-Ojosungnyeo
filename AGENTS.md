# AI Agent Guidelines

## 1. Project Overview

본 프로젝트는 친구와 여행 중 각자의 시간을 자유롭게 보내고, 다시 합류할 수 있도록 돕는 iOS 여행 애플리케이션입니다.

### Core Features

- 여행 생성 및 일정 관리
- 여행 장소 선택 및 그룹화
- 일자별 여행 동선 확인
- 친구와 일정 분리
- 친구와 재합류 알림

### Tech Stack

- Language: Swift
- UI Framework: SwiftUI
- Architecture: TCA (The Composable Architecture)
- Map: MapKit
- Location: CoreLocation
- Backend: Firebase
- Notification: UserNotifications

---

## 2. Architecture Principles

본 프로젝트는 TCA를 기반으로 단방향 데이터 흐름을 따릅니다.

```text
State → View → Action → Reducer → State
```

### Core Rules

1. 주요 화면 단위로 Feature를 분리합니다.
2. 각 Feature는 `State`, `Action`, `Reducer`로 구성합니다.
3. State 변경은 Reducer를 통해 처리합니다.
4. View는 UI 렌더링과 Action 전달에 집중합니다.
5. 비동기 작업은 Effect를 통해 처리합니다.
6. 외부 서비스는 TCA Dependency를 통해 주입합니다.
7. 기존 아키텍처를 임의로 변경하지 않습니다.
8. 불필요한 추상화나 새로운 아키텍처 패턴을 도입하지 않습니다.
9. 프로젝트에서 사용하는 TCA 버전과 기존 구현 패턴을 우선합니다.
10. 문서의 예제보다 현재 프로젝트에서 정상적으로 컴파일되는 구현을 우선합니다.

---

## 3. Project Structure

프로젝트는 별도의 모듈화 도구 없이 화면 단위 Feature 구조로 관리합니다.

```text
ddaddo/
├── App/
│   ├── ddaddoApp.swift
│   └── RootFeature.swift
├── Features/
│   ├── Home/
│   ├── TripPlanning/
│   │   ├── TripSetUp/
│   │   ├── PlaceSelection/
│   │   └── PlaceGrouping/
│   └── TripItinerary/
│       ├── RouteOverview/
│       └── DailyItinerary/
├── Models/
├── Dependencies/
├── Services/
├── DesignSystem/
└── Resources/
```

### Directory Responsibilities

- `App`: 앱 진입점과 최상위 Feature를 관리합니다.
- `Features`: 화면별 Feature와 View를 관리합니다.
- `Models`: 여러 화면에서 사용하는 데이터 모델을 관리합니다.
- `Dependencies`: Feature에서 사용하는 외부 기능의 Client 인터페이스를 관리합니다.
- `Services`: Firebase 등 외부 SDK의 실제 구현을 관리합니다.
- `DesignSystem`: 공통 색상, 폰트 및 UI 컴포넌트를 관리합니다.
- `Resources`: 이미지와 기타 리소스를 관리합니다.

### Structure Rules

- 하나의 주요 화면은 하나의 Feature를 가집니다.
- Feature 이름은 `화면명 + Feature` 형식을 사용합니다.
- View 이름은 `화면명 + View` 형식을 사용합니다.
- 작은 UI 요소는 해당 Feature의 `Components` 폴더에 작성합니다.
- 여러 화면에서 사용하는 모델은 `Models`에 작성합니다.
- 외부 서비스 접근 인터페이스는 `Dependencies`에 작성합니다.
- 외부 SDK의 실제 구현은 `Services`에서 관리합니다.
- 모든 UI 컴포넌트를 별도의 Feature로 만들지 않습니다.
- 하나의 주요 타입은 하나의 파일에 작성하는 것을 권장합니다.
- 파일명은 파일의 주요 타입 이름과 일치시킵니다.

---

## 4. Root Feature Rules

앱의 최상위 상태와 화면 구성은 `RootFeature`와 `RootView`에서 관리합니다.

### Responsibilities

- `ddaddoApp`: 최상위 Store를 생성합니다.
- `RootFeature`: 앱의 최상위 상태와 하위 Feature를 조합합니다.
- `RootView`: 최상위 Store를 받아 현재 루트 화면을 표시합니다.
- `HomeFeature`: 홈 화면의 상태와 비즈니스 로직을 관리합니다.
- `HomeView`: 홈 화면의 UI를 렌더링합니다.

### Rules

- 앱 진입점에서 개별 화면의 비즈니스 로직을 처리하지 않습니다.
- 앱 진입점은 최상위 Store 생성과 `RootView` 표시에 집중합니다.
- 앱의 첫 번째 화면은 `RootView`에서 구성합니다.
- 하위 Feature를 연결할 때는 TCA의 `Scope`를 사용합니다.
- 화면 전환 상태가 필요해질 때 `RootFeature.State`에서 관리합니다.
- 요청되지 않은 탭, 내비게이션 및 화면 전환 구조를 임의로 추가하지 않습니다.
- 기존 화면을 루트에 연결하는 작업에서는 기존 UI를 임의로 변경하지 않습니다.

---

## 5. TCA Feature Rules

모든 주요 Feature는 다음 구조를 기본으로 작성합니다.

```swift
import ComposableArchitecture

struct ExampleFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var isLoading = false
    }

    enum Action {
        case onAppear
        case buttonTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .buttonTapped:
                return .none
            }
        }
    }
}
```

TCA 버전과 Xcode 설정에 따라 `@Reducer`와 `ReducerOf<Self>`를 사용할 수 있습니다. 다만 프로젝트에서 순환 참조 등의 컴파일 오류가 발생한다면 현재 프로젝트에서 컴파일되는 기존 패턴을 우선합니다.

### State Rules

- UI 결과에 영향을 주는 상태를 관리합니다.
- State 변경은 Reducer를 통해 수행합니다.
- 동일한 데이터를 불필요하게 중복 저장하지 않습니다.
- 계산 가능한 값은 연산 프로퍼티 사용을 고려합니다.
- 공유 상태의 소유권을 명확하게 정의합니다.
- 단순 UI 표현만을 위한 상태는 View의 로컬 상태로 관리할 수 있습니다.

### Action Naming

Action은 발생한 이벤트나 Effect 결과를 명확하게 표현합니다.

```swift
case onAppear
case saveButtonTapped
case placeSelected(Place)
case searchTextChanged(String)
case placesResponse(Result<[Place], Error>)
case friendLocationUpdated(Location)
```

### Action Rules

- 사용자 이벤트는 `대상 + 동작` 형태로 작성합니다.
- 모호한 `update`, `handle`, `process` 등의 이름을 지양합니다.
- 비동기 작업의 결과는 Action으로 Reducer에 전달합니다.
- Action에 View나 외부 SDK의 구현 타입을 불필요하게 노출하지 않습니다.

### Reducer Rules

- 비즈니스 로직과 상태 변경을 담당합니다.
- 외부 SDK를 직접 호출하지 않습니다.
- 비동기 작업은 Effect를 통해 처리합니다.
- 외부 서비스는 Dependency로 주입받습니다.
- Reducer가 복잡해지면 하위 Feature 분리를 고려합니다.
- 단순 UI 컴포넌트를 불필요하게 하위 Feature로 만들지 않습니다.

---

## 6. View Rules

View는 UI 렌더링과 사용자 이벤트 전달을 담당합니다.

### Rules

- View에서 Firebase API를 직접 호출하지 않습니다.
- View에서 비즈니스 로직을 처리하지 않습니다.
- 사용자 이벤트는 Store에 Action으로 전달합니다.
- 화면의 주요 상태는 Store에서 관리합니다.
- 단순한 UI 표현을 위한 로컬 `@State` 사용은 허용합니다.
- 디자인에 없는 기능이나 인터랙션을 임의로 추가하지 않습니다.
- 가능한 경우 SwiftUI Preview를 제공합니다.
- 접근성과 다양한 화면 크기를 고려합니다.
- 불필요한 View 분리 및 추상화를 지양합니다.

### Example Structure

```text
Map/
├── MapFeature.swift
├── MapView.swift
└── Components/
    ├── PlaceMarkerView.swift
    └── PlaceDetailCard.swift
```

- `MapFeature`: 상태 및 비즈니스 로직
- `MapView`: TCA Store 연결 및 화면 구성
- `Components`: 재사용 가능한 UI 요소

---

## 7. Design and Figma Rules

디자인팀은 Figma를 통해 디자인을 전달하고, 개발팀은 이를 기반으로 SwiftUI와 TCA를 사용하여 구현합니다.

### Rules

1. Figma 디자인의 레이아웃과 스타일을 최대한 유지합니다.
2. 모든 화면은 SwiftUI로 구현합니다.
3. 주요 화면은 TCA Feature와 연결합니다.
4. 기존 DesignSystem과 공통 컴포넌트를 우선 사용합니다.
5. 공통 색상, 폰트 및 간격 값을 임의로 중복 정의하지 않습니다.
6. 디자인에 없는 기능이나 비즈니스 로직을 임의로 추가하지 않습니다.
7. 디자인에 명시되지 않은 인터랙션을 추측해서 구현하지 않습니다.
8. 필요한 정보가 부족하면 구현 전에 사용자에게 확인합니다.
9. 기존 Feature와 Dependency 구조를 임의로 변경하지 않습니다.
10. UI 구현을 위해 새로운 아키텍처를 도입하지 않습니다.

### Component Example

```swift
struct PlaceCard: View {
    let title: String
    let address: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                Text(title)
                Text(address)
            }
        }
    }
}
```

---

## 8. Dependency Rules

외부 서비스는 TCA Dependency 시스템을 통해 관리합니다.

### Dependency Flow

```text
Feature
   ↓
TripClient
   ↓
FirebaseTripService
   ↓
Firebase
```

### Principles

- Feature는 외부 SDK 구현에 직접 의존하지 않습니다.
- Client는 Feature에서 필요한 기능을 정의합니다.
- Service는 외부 SDK의 실제 연동을 담당합니다.
- 외부 서비스의 구현 세부 사항을 Feature에 노출하지 않습니다.
- Dependency의 테스트용 구현을 제공합니다.
- API Key와 인증 정보 등 민감한 값을 하드코딩하지 않습니다.
- 필요 이상의 추상화를 만들지 않습니다.

### Naming

- `TripClient`
- `MapClient`
- `LocationClient`
- `RecordClient`
- `NotificationClient`
- `LiveActivityClient`

---

## 9. MapKit and Location Rules

지도 및 위치 기능은 UI와 비즈니스 로직을 분리합니다.

### Responsibilities

#### MapView

- 지도 렌더링
- 마커 표시
- 지도 UI 구성
- 비즈니스 로직과 무관한 카메라 상태 관리

#### MapFeature

- 선택된 장소 관리
- 장소 검색 상태 관리
- 지도와 관련된 비즈니스 로직 처리

#### MapClient

- 장소 검색
- 경로 계산
- 지도와 관련된 외부 기능 제공

#### LocationClient

- 위치 권한 확인
- 사용자 위치 조회
- 위치 업데이트 스트림 제공

### Rules

- 모든 카메라 이동을 TCA Action으로 전달하지 않습니다.
- 단순 지도 UI 상태는 View 내부에서 관리할 수 있습니다.
- 비즈니스 로직에 필요한 지도 이벤트만 Action으로 전달합니다.
- 위치 기능은 `LocationClient`를 통해 사용합니다.
- 위치 권한 요청과 실제 위치 조회 로직을 View에서 직접 처리하지 않습니다.

---

## 10. Firebase Rules

Firebase 접근은 Dependency와 Service를 통해 수행합니다.

### Rules

1. Feature와 View에서 Firebase SDK를 직접 호출하지 않습니다.
2. Firebase 접근은 Dependency Client를 통해 수행합니다.
3. 실제 Firebase 구현은 `Services`에서 관리합니다.
4. Firestore 데이터는 앱 내부 Model로 변환합니다.
5. Firebase 타입을 View에 직접 전달하지 않습니다.
6. 비동기 요청 결과는 Action으로 전달합니다.
7. 실시간 데이터 구독은 Dependency에서 관리합니다.
8. 화면 종료 또는 작업 취소 시 리스너와 Effect를 정리합니다.
9. 인증과 Firestore 보안 규칙을 고려합니다.
10. API Key, 인증 파일 및 기타 비밀값을 저장소에 직접 추가하지 않습니다.

Firebase 도입이 확정되지 않은 기능은 특정 Firebase 구현에 강하게 결합하지 않습니다.

---

## 11. Testing Rules

### Test Priorities

1. 여행 일정 생성 및 수정
2. 일정 분리 및 합류
3. 재합류 상태 변경
4. 위치 업데이트
5. 여행 기록 저장 및 공유

### Rules

- Reducer의 상태 변화를 테스트합니다.
- 비동기 Effect의 결과를 테스트합니다.
- 외부 Dependency는 테스트용 구현으로 대체합니다.
- 실제 Firebase 및 위치 서비스에 의존하지 않는 단위 테스트를 작성합니다.
- 주요 사용자 흐름을 우선적으로 테스트합니다.
- 테스트 타깃이 없는 경우 요청 없이 대규모 테스트 구조를 추가하지 않습니다.
- 테스트를 실행하지 못했다면 성공했다고 보고하지 않습니다.

---

## 12. Naming Convention

### Types

- Feature: `MapFeature`
- View: `MapView`
- Component: `PlaceCard`
- Model: `Trip`
- Dependency: `TripClient`
- Service: `FirebaseTripService`

### Variables

- Swift camelCase를 사용합니다.
- Bool 변수는 `is`, `has`, `can`, `should` 등의 접두어를 권장합니다.
- 축약어보다 의미가 명확한 이름을 사용합니다.
- 역할이 불분명한 `data`, `value`, `item` 등의 이름을 지양합니다.

### Files

- 하나의 주요 타입은 하나의 파일에 작성하는 것을 권장합니다.
- 파일명은 주요 타입명과 일치시킵니다.
- 화면별 파일은 해당 Feature 폴더에 배치합니다.

---

## 13. Swift Package Rules

- 패키지를 추가하기 전에 현재 프로젝트에 같은 기능이 이미 있는지 확인합니다.
- 프로젝트의 Deployment Target 및 Swift 버전과 호환되는 버전을 사용합니다.
- 공식 저장소와 공식 문서를 우선적으로 확인합니다.
- 패키지 추가 시 Xcode 프로젝트 설정과 `Package.resolved`를 함께 반영합니다.
- 특별한 이유가 없다면 안정적인 릴리스 버전을 사용합니다.
- 패키지 버전을 임의로 변경하거나 업그레이드하지 않습니다.
- 패키지 추가 후 의존성 해석과 빌드를 확인합니다.

---

## 14. AI Agent Scope Rules

AI Agent는 사용자가 요청한 범위 안에서만 작업합니다.

### Required Rules

1. 작업 전에 기존 프로젝트 구조를 확인합니다.
2. 현재 사용 중인 TCA 버전과 기존 구현 패턴을 확인합니다.
3. 관련 Feature, Model, Dependency 및 공통 컴포넌트를 확인합니다.
4. 요청하지 않은 UI나 샘플 기능을 임의로 추가하지 않습니다.
5. 빈 화면 또는 기존 화면을 TCA에 연결할 때 기존 UI를 유지합니다.
6. 디자인에 없는 기능이나 인터랙션을 임의로 만들지 않습니다.
7. 요청 범위 밖의 파일을 불필요하게 수정하지 않습니다.
8. 기존 아키텍처를 임의로 변경하지 않습니다.
9. 새로운 아키텍처 패턴을 임의로 도입하지 않습니다.
10. 불필요한 보일러플레이트 코드를 생성하지 않습니다.
11. 기존 작업 트리의 변경 사항을 사용자 소유로 간주합니다.
12. 사용자의 기존 변경 사항을 임의로 삭제하거나 되돌리지 않습니다.
13. 커밋과 브랜치 생성은 사용자가 명시적으로 요청한 경우에만 수행합니다.
14. Issue 번호를 임의로 생성하지 않습니다.
15. 실행하지 않은 빌드나 테스트를 성공했다고 보고하지 않습니다.

### Before Implementation

- 프로젝트 구조 확인
- Git 작업 트리 상태 확인
- 관련 Feature 확인
- 관련 Model 확인
- 관련 Dependency 확인
- 공통 컴포넌트 확인
- TCA 및 패키지 버전 확인
- 요청 범위 확인

### After Implementation

- 컴파일 오류 확인
- TCA 데이터 흐름 확인
- 불필요한 상태 중복 확인
- Dependency 분리 여부 확인
- Preview 확인
- 관련 테스트 확인
- 요청 범위를 벗어난 변경이 없는지 확인

---

## 15. Git Convention

### Commit Convention

- 태그는 반드시 소문자로 작성합니다.
- 커밋 내용은 한글로 작성합니다.
- 제목은 50자를 넘지 않도록 작성합니다.
- 제목은 간단한 명령조로 작성합니다.
- 추가 설명이 필요하면 본문에 작성합니다.
- 사용자가 요청하지 않으면 커밋하지 않습니다.
- Issue 번호를 임의로 만들지 않습니다.

### Commit Examples

```text
[feat/#1] 홈 화면 구현
[fix/#12] 위치 갱신 오류 수정
[refactor/#21] 여행 생성 로직 분리
[merge/#1] pull develop
[merge/#1] feat/#1 -> develop
[conflict/#1] 충돌 해결
```

### Branch Convention

브랜치 이름은 다음 형식을 사용합니다.

```text
type/#issue-description
```

브랜치 설명은 소문자 kebab-case를 사용합니다.

```text
feat/#1-login-ui
fix/#12-location-update
refactor/#53-home-feature
```

### Pull Request Rules

- PR은 하나의 작업 목적을 중심으로 작성합니다.
- 변경 사항과 구현 이유를 명확하게 설명합니다.
- UI 변경 시 스크린샷 첨부를 권장합니다.
- 아키텍처 변경 시 변경 이유를 작성합니다.
- 기존 기능에 영향을 주는 변경은 관련 테스트 결과를 작성합니다.
- 사용자가 요청하지 않으면 PR을 생성하지 않습니다.

---

## 16. Security Rules

- API Key, 비밀번호, 인증 토큰 및 개인키를 하드코딩하지 않습니다.
- `.env`, Firebase 인증 파일 및 개인 설정 파일을 커밋하지 않습니다.
- 로그에 사용자 위치나 개인정보를 불필요하게 출력하지 않습니다.
- 민감한 파일을 추가하기 전에 `.gitignore`를 확인합니다.
- 실제 사용자 데이터를 Preview와 테스트에 사용하지 않습니다.
- 위치와 알림 권한은 필요한 시점에 요청합니다.

---

## 17. Important Principles

### DO

- Follow the existing TCA architecture.
- Keep Features small and focused.
- Separate View and business logic.
- Use Dependency Injection.
- Reuse existing UI components.
- Follow existing project conventions.
- Preserve existing user changes.
- Write testable code.
- Verify builds and tests before reporting success.

### DON'T

- Do not introduce MVVM or another architecture without approval.
- Do not call Firebase directly from Views or Features.
- Do not modify State outside Reducers.
- Do not add unnecessary abstractions.
- Do not duplicate existing components.
- Do not change unrelated files.
- Do not introduce Tuist or unnecessary modularization.
- Do not hardcode secrets.
- Do not add sample UI or behavior that was not requested.
- Do not commit or create branches without explicit user approval.

---

## 18. Final Guideline

본 프로젝트의 최우선 목표는 팀원과 AI Agent가 동일한 아키텍처와 작업 규칙을 따르는 것입니다.

모든 코드는 다음 원칙을 기준으로 작성합니다.

1. 일관성
2. 명확한 책임 분리
3. 협업 용이성
4. 테스트 가능성
5. 유지보수성
6. 요청 범위 준수

새로운 구현 방식이 기존 코드 또는 본 문서의 규칙과 충돌하면 임의로 구조를 변경하지 않습니다.

우선순위는 다음과 같습니다.

1. 사용자의 현재 요청
2. 현재 프로젝트에서 컴파일되는 기존 구현
3. 본 문서의 프로젝트 규칙
4. 공식 문서 및 일반적인 권장 방식

판단에 따라 결과가 크게 달라질 수 있거나 요청 범위를 넘어서는 변경이 필요한 경우, 구현 전에 사용자 또는 팀의 확인을 받습니다.
