# 02. Apex 배포 (VS Code)

> 삭제 로직(`DataCloudIngestDelete`)과 토큰 교환(`DataCloudAuthProvider`), Auth Provider 설정 저장용
> CMDT(`DataCloud_Auth_Provider__mdt`)를 org 에 배포한다. Auth Provider 등록에는 `DataCloudAuthProvider` 클래스 배포가 선행되어야함.

이 repo 는 표준 SFDX 프로젝트다(`sfdx-project.json` + `force-app/main/default/`). 소스:
```
force-app/main/default/classes/DataCloudIngestDelete.cls   (+ Test)   Invocable 삭제
force-app/main/default/classes/DataCloudAuthProvider.cls   (+ Test)   core→a360 토큰 교환
force-app/main/default/objects/DataCloud_Auth_Provider__mdt/          Auth Provider 설정 CMDT
```

VS Code로 **clone → org 인증 → 배포**까지 진행한다. (익스텐션·CLI 없다고 가정)

---

## 1) Salesforce CLI 설치
VS Code 익스텐션이 내부적으로 **Salesforce CLI(`sf`)** 를 호출하므로 먼저 설치한다.
- [Salesforce CLI 설치 페이지](https://developer.salesforce.com/tools/salesforcecli) 에서 OS별 설치 파일 실행
- 설치 후 새 터미널에서 확인:
  ```bash
  sf --version
  ```
  > 📷 [스크린샷] sf --version 출력

## 2) VS Code 익스텐션 설치
- VS Code > Extensions (`Ctrl+Shift+X`) > **"Salesforce Extension Pack"** 검색 > **Install**
  (Apex, SOQL, Org Browser 등 한 번에 묶여 설치됨)
  > 📷 [스크린샷] Salesforce Extension Pack 설치
- 설치 후 VS Code 재시작(권장)

## 3) 프로젝트 clone & 열기
```bash
git clone https://github.com/paulyu8868/dc-ingestion-delete-flow.git
```
- VS Code > **File > Open Folder** 로 clone 한 폴더 열기
- `sfdx-project.json` 이 있으므로 VS Code 가 **SFDX 프로젝트로 인식**한다(하단바에 org 표시 영역 생김)

## 4) org 인증 (1회)
- Command Palette (`Ctrl+Shift+P`) > **SFDX: Authorize an Org**
  > 📷 [스크린샷] Authorize an Org 명령
- **Login URL** 선택:
  - 일반 조직: `Production` (`https://login.salesforce.com`)
  - dev/scratch/커스텀 도메인: `Custom` 선택 후 `https://<org>.develop.my.salesforce.com` 입력
- **alias** 입력(예: `myorg`) → 브라우저 열림 → 로그인 → **허용**
  > 📷 [스크린샷] 브라우저 로그인/허용
- (선택) Command Palette > **SFDX: Set a Default Org** 로 방금 org 를 기본값 지정

## 5) 배포
- Explorer 에서 **`force-app`** 폴더 우클릭 > **SFDX: Deploy Source to Org**
  > 📷 [스크린샷] Deploy Source to Org
- 또는 통합 터미널에서:
  ```bash
  sf project deploy start -d force-app -o myorg -l RunSpecifiedTests
  ```
- Output 패널에 배포 결과가 뜬다.
  > 📷 [스크린샷] 배포 성공(Output)

## 6) 확인
- Setup > **Apex Classes** 에 `DataCloudIngestDelete`, `DataCloudAuthProvider` 존재
- 배포 시 테스트가 함께 통과(RunSpecifiedTests)

---

## 참고
- `DataCloudIngestDelete` 는 source/object/NamedCredential 을 **필수 인자**로 받는다(하드코딩 없음).
  대상 지정은 Flow(06) 몫.
- sf CLI 를 쓸 수 없는 환경이면 repo 루트의 `deploy_apex.py`(자체 사용법 주석 포함)로도 배포할 수 있다.

관련: [개념 §4](concept.md) · 다음 → [03-auth-provider](03-auth-provider.md)
