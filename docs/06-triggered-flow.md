# 06. Data Cloud-Triggered Flow

> Apex Trigger를 **Data Cloud-Triggered Flow**로 대체함.
>  **삭제할 PK 목록이 담긴 DMO** 에 레코드가 생기면 해당 Flow가 Trigger되며, Invocable Apex(`DataCloudIngestDelete`)에 삭제할 PK 리스트를 전달하고 호출한다.

<img width="592" height="759" alt="image" src="https://github.com/user-attachments/assets/7edca42a-ad40-442a-9ab3-ff70ef0655e4" />

## 선행 조건
- 앞선 단계(01 ~ 05)
- 삭제할 PK 목록을 담은 **DMO**
  - DLO는 직접적으로 사용 불가능. DMO 매핑 필요
  - DLO 적재 방법은 상관없음(Data Transform, Ingestion... 등)   

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


관련: [개념 §4·§5](concept.md)
