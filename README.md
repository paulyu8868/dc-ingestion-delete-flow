# [테스트 완료] Ingestion API 삭제 자동화 (Data Cloud Triggered Flow → Apex) 세팅 가이드

<img width="895" height="644" alt="image" src="https://github.com/user-attachments/assets/4ab3390a-5378-4e2e-b0c0-3f1cfe3e9aad" />


`삭제할 PK 목록을 담는 DMO`에 레코드가 들어오면, Data Cloud-Triggered Flow가
**Invocable Apex**를 호출하고 `타겟 DLO`의 레코드를 삭제한다(**Ingestion DELETE API**).

```
삭제-id DMO ──(record created)──▶ Data Cloud-Triggered Flow
                                    │  fm_pk 를 컬렉션으로 수집
                                    ▼
                          Invocable Apex (DataCloudIngestDelete)
                                    │  ids 200개씩 청크
                                    ▼
                    DELETE callout:{NamedCredential}/api/v1/ingest/sources/{source}/{object}
                                    │  body {"ids":[...]}  →  202 (async ~3분)
                                    ▼
                          원본 DLO 에서 해당 레코드(pk기준) 삭제
```

구조·원리(왜 이렇게 나뉘는지, 인증 동작 원리, Apex 코드 구조)는 → [`docs/concept.md`](docs/concept.md)

---
# 세팅 방법

## 사전 준비
- **삭제 대상(Ingestion API)**: `Ingestion API` 커넥터를 사용중인 DLO만 해당.
- **트리거 소스(DMO)**: 삭제할 **PK 목록을 담은 DMO**. 채우는 방법은 무관(Data Transform · Data Stream · 별도 적재 등).
  Triggered Flow 는 DMO/CIO 에만 적용 가능하므로, DLO는 DMO 로 매핑해 사용한다.
- **배포 및 권한 설정**: 아래 `세팅 순서` 참고.

## 세팅 순서

이 저장소가 다루는 범위는 **인증 + Apex + 트리거 Flow**다. (PK 목록 DMO 를 채우는 방식은 범위 밖)

| # | 단계 | 문서 |
|---|---|---|
| 1 | Connected App (client credentials) | [`docs/01-connected-app.md`](docs/01-connected-app.md) |
| 2 | Apex 배포 | [`docs/02-deploy-apex.md`](docs/02-deploy-apex.md) |
| 3 | Auth Provider | [`docs/03-auth-provider.md`](docs/03-auth-provider.md) |
| 4 | Remote Site Setting | [`docs/04-remote-site.md`](docs/04-remote-site.md) |
| 5 | Named Credential | [`docs/05-named-credential.md`](docs/05-named-credential.md) |
| 6 | Data Cloud-Triggered Flow | [`docs/06-triggered-flow.md`](docs/06-triggered-flow.md) |

## 검증 (스모크 테스트)
Named Credential 인증 후, Apex 를 직접 호출(Developer Console)해 삭제 경로 확인:
```apex
DataCloudIngestDelete.Request q = new DataCloudIngestDelete.Request();
q.ids = new List<String>{ '<실제 fm_pk 1개>' };
q.sourceApi = '<Ingestion 소스명>';
q.objectName = '<Ingestion object명>';
q.namedCredential = '<Named Credential 이름>';
System.debug(DataCloudIngestDelete.run(new List<DataCloudIngestDelete.Request>{ q }));
```
`success=true`, 202 접수 → ~3분 뒤 원본 DLO 에서 해당 행 삭제 확인.

## 레포 구성
표준 SFDX 프로젝트 — VS Code / sf CLI 로 clone → 인증 → 배포가 그대로 된다.
```
sfdx-project.json                 SFDX 프로젝트 정의
force-app/main/default/
  classes/                        Apex (DataCloudIngestDelete, DataCloudAuthProvider, 각 Test)
  objects/                        DataCloud_Auth_Provider__mdt (Auth Provider 설정 CMDT)
deploy_apex.py                    sf CLI 없는 환경용 fallback 배포 (→ docs/02)
docs/                             세팅 상세 + 개념 문서
```

## 참고
- `DataCloudIngestDelete` 는 source/object/NamedCredential 을 **필수 인자**로 받는 범용 컴포넌트다.
  대상이 다른 DMO 여도 이 세 값만 바꿔 재사용한다. (Apex 상세: [`docs/concept.md`](docs/concept.md))
- 삭제는 **비동기(~3분)**. 실제 반영은 시차가 있다.
