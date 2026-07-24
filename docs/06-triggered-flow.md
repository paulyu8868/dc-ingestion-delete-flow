# 06. Data Cloud-Triggered Flow

> Apex Trigger를 **Data Cloud-Triggered Flow**로 대체함.
>  **삭제할 PK 목록이 담긴 DMO** 에 레코드가 생기면 해당 Flow가 Trigger되며, Invocable Apex(`DataCloudIngestDelete`)에 삭제할 PK 리스트를 전달하고 호출한다.

<img width="592" height="759" alt="image" src="https://github.com/user-attachments/assets/7edca42a-ad40-442a-9ab3-ff70ef0655e4" />

## 선행 조건
- 앞선 단계(01 ~ 05)
- 삭제할 PK 목록을 담은 **DMO**
  - DLO는 직접적으로 사용 불가능. DMO 매핑 필요
  - DLO 적재 방식은 상관없음(Data Transform, Ingestion... 등)   

## ⚙️세팅 방법
### 1) Flow 생성
- Setup > **Flows** > New Flow > **Data Cloud-Triggered Flow**
- Start
  - **Choose Data Cloud Object**:
    - 삭제할 PK 목록을 담은 **DMO** 선택
    - Trigger the Flow When: `A record is created` / `A record is created or updated`
  > <img width="886" height="793" alt="image" src="https://github.com/user-attachments/assets/c4857477-b6b5-4f6d-850c-b1f4222a6f86" />


### 2) 삭제 PK 리스트 컬렉션 변수 생성
- New Resource > Variable
  - **API Name:** `fmPkList`
  - **Data Type:** `Text`
  - ✅**Allow multiple values**
    
### 3) 컬렉션에 PK 리스트 담기  (Assignment)
- `(+)`Add Element > Assignment
  - **Label:** `deleteListAssignment`
  - **API Name:** `deleteListAssignment`
  - **Variable:** `{!fmPkList}`
  - **Operator:** `Add`
  - **Value:** `{!$Record.<삭제 PK 컬럼>}` (예시. `{!$Record.fm_pk__c}`)
    - ⚠️ 삭제 DMO의 **PK 필드 API 이름** 사용


### 4) Apex 액션
- `(+)`Add Element > Action > 검색 `Data Cloud Ingestion Delete`
  - **Label:** `Data Cloud Ingestion Delete`
  - **API Name:** `Data_Cloud_Ingestion_Delete`
  - **Set Input Values**:
    
  | 입력 | 값(예시) | 설명 |
  |---|---|---|
  | **삭제할 fm_pk (ids) 목록** | `{!fmPkList}` |  |
  | **Named Credential 이름** | `DataCloud_Ingest` |  |
  | **Object 이름 (YAML 스키마 object명)** | 예시. `order_original` | ⚠️ 삭제 대상(Ingestion API)의 Object명. **스키마(yaml)에 등록된 Object명 기준** |
  | **Source API 이름 (Ingestion API 소스명)** | 예시. `Ingestion_Refill_Test` | ⚠️삭제 대상(Ingestion API)의 **Ingestion API명** |


### 5) Save & **Activate**
- Save 후 Activate

## 동작 이해
- Flow 는 레코드별로 돌지만 Data Cloud 가 배치로 묶어 Apex 를 호출 → Apex 가 모든 `pk` 를
  200개씩 취합 전송(대량 안전). 상세: [개념 §4](concept.md)

## 테스트
1. PK 목록 DMO 에 소량(3~5건) `pk` 투입 → Flow 발동 → DELETE(202)
2. 원본 Data Stream 에서 레코드 삭제 확인
   > ![Uploading image.png…]()



관련: [개념 §4·§5](concept.md)
