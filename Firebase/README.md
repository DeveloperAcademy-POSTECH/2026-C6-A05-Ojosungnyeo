# Firebase 환경 설정

Firebase CLI 설정과 Firestore 보안 규칙은 앱 환경별 폴더에서 관리합니다.

```text
Firebase/
└── Dev/
    ├── firebase.json
    └── firestore.rules
```

Dev 프로젝트에 Firestore 규칙을 배포할 때는 저장소 루트에서 실행합니다.

```shell
npx firebase-tools deploy \
  --project ddaddo-bc479 \
  --config Firebase/Dev/firebase.json \
  --only firestore:rules
```

출시용 Firebase 설정이 필요해지면 `Firebase/Production` 폴더를 추가하고 동일한 구조로 분리합니다.
