# 06. Data Cloud-Triggered Flow

## 무엇 / 왜
**삭제할 PK 목록이 담긴 DMO** 에 레코드가 생기면 발동해, PK(`fm_pk`)를 모아
Invocable Apex(`DataCloudIngestDelete`)를 호출. DLO/DMO 엔 Apex 트리거가 안 걸리므로
이 Flow 가 "레코드 트리거" 역할을 한다.

> 이 DMO 를 **어떻게 채우는지는 무관**하다(Data Transform, 별도 ingestion, 수동 등).
> 요건은 "삭제할 PK 목록을 담은 **DMO**" 하나뿐. (DLO 라면 DMO 로 매핑 필요 — 트리거는 DMO/CIO 에만 걸림)

## 선행 조건
- Apex 배포(02), 인증 완료(05 인증됨)
- 삭제할 PK 목록을 담은 **DMO** 존재 + 그 DMO 에 PK 필드(`fm_pk`) 노출

## 방법
### 1) Flow 생성
- Setup > **Flows** > New Flow > **Data Cloud-Triggered Flow**
- Object: **삭제-id DMO**, Trigger: *A record is created*
  > 📷 [스크린샷] 트리거 설정

### 2) 컬렉션 변수
- New Resource > Variable, Data Type **Text**, **Allow multiple values** ✅, 이름 예 `fmPkList`
  > 📷 [스크린샷] 컬렉션 변수 생성

### 3) fm_pk 담기 (Assignment)
- Variable `{!fmPkList}` / Operator **Add** / Value `{!$Record.fm_pk__c}`
- ⚠️ DMO 의 **PK 필드 실제 API 이름** 사용 (예 `fm_pk__c`). 이 값이 삭제 대상 데이터 스트림의 Primary Key 여야 삭제 매칭됨.
  > 📷 [스크린샷] Assignment

### 4) Apex 액션
- Action > 검색 **"Data Cloud Ingestion Delete"**
- 입력(네 개 모두 **필수**):
  | 입력 | 값(예시) |
  |---|---|
  | ids | `{!fmPkList}` |
  | Source API 이름 | `Ingestion_Refill_Test` |
  | Object 이름 | `order_original` |
  | Named Credential 이름 | `DataCloud_Ingest` |
  > 📷 [스크린샷] 액션 입력
- (선택) 출력 `success`/`message`/`accepted` 를 변수로 받아 로깅

### 5) Save & **Activate**

## 동작 이해
- Flow 는 레코드별로 돌지만 Data Cloud 가 배치로 묶어 Apex 를 호출 → Apex 가 모든 `fm_pk` 를
  200개씩 취합 전송(대량 안전). 상세: [개념 §4](concept.md)

## 테스트
1. PK 목록 DMO 에 소량(3~5건) `fm_pk` 투입 → Flow 발동 → DELETE(202, async ~3분)
2. 원본 DLO 에서 해당 `fm_pk` 삭제 확인 (Data Explorer 또는 Query API v2)
   > 📷 [스크린샷] 삭제 전/후 카운트

## 주의
- **fm_pk 필드 매핑 오류가 최다 함정**: 다른 필드를 넘기면 202 는 나오지만 안 지워짐.
- 비동기 지연으로 즉시 반영 안 됨 — 몇 분 대기 후 확인.

관련: [개념 §4·§5](concept.md)
