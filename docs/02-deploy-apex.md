# 02. Apex 배포

## 무엇 / 왜
삭제 로직(`DataCloudIngestDelete`)과 토큰 교환(`DataCloudAuthProvider`), Auth Provider 설정 저장용
CMDT(`DataCloud_Auth_Provider__mdt`)를 org 에 올린다. Auth Provider 등록(03) 전에 클래스가 org 에 있어야 한다.

## 배포 대상
```
classes/DataCloudIngestDelete.cls         (+ Test)   Invocable 삭제
classes/DataCloudAuthProvider.cls         (+ Test)   core→a360 토큰 교환
objects/DataCloud_Auth_Provider__mdt/                Auth Provider 설정 CMDT
```

## 방법 A — sf CLI
```bash
sf project deploy start -d apex -o <org> -l RunSpecifiedTests
```

## 방법 B — 포함된 스크립트 (sf CLI 없이)
`deploy_apex.py` = Metadata API(SOAP) 배포. `../.env`(또는 지정 .env)의 client_credentials 토큰 사용.
```bash
python deploy_apex.py            # checkOnly 검증 (org 변경 없음)
python deploy_apex.py --deploy   # 실제 배포
```
> 📷 [스크린샷] 배포 성공 로그 (status: Succeeded)

## 확인
- Setup > **Apex Classes** 에 `DataCloudIngestDelete`, `DataCloudAuthProvider` 존재
- 테스트가 함께 통과(RunSpecifiedTests)

## 참고
- `DataCloudIngestDelete` 는 source/object/NamedCredential 을 **필수 인자**로 받는다(하드코딩 없음).
  대상 지정은 Flow(09) 몫.

관련: [개념 §4](concept.md) · 다음 → [03-auth-provider](03-auth-provider.md)
