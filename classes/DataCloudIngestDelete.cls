/**
 * Data Cloud Ingestion DELETE — fm_pk(=데이터 스트림 primary key) 목록을 삭제.
 *
 * Triggered Flow → 이 Invocable Apex → (대량 호출 시) 전 요청의 ids 취합 → 200개씩 청크 → NC 콜아웃.
 *   엔드포인트: DELETE callout:{NC}/api/v1/ingest/sources/{source}/{object}
 *   본문:       {"ids": ["fm_pk1", ...]}   (요청당 최대 200)
 *   응답:       202 Accepted (async, ~3분)
 *
 * 범용: source/object/NamedCredential 은 모두 호출자(Flow)가 넘기는 필수 인자. 하드코딩된 기본값 없음.
 * 인증: Named Credential 이 커스텀 Auth Provider(DataCloudAuthProvider)로 a360 DC 토큰을 자동 주입.
 *       이 클래스는 토큰을 다루지 않음.
 *
 * Flow bulkification: run() 은 List<Request> 를 (source/object/NC)별로 취합해 전역 200 청크로 전송
 *   → 배치가 100건을 넘어도 콜아웃 한도(트랜잭션당 100) 방어. 결과는 요청 수와 동일 크기로 반환.
 * ⚠️ 루프 가드: 삭제가 DMO 재변경 → Triggered Flow 재발동 가능 → 진입 조건으로 차단(README).
 */
public with sharing class DataCloudIngestDelete {

    private static final Integer CHUNK = 200;

    public class Request {
        @InvocableVariable(required=true label='삭제할 fm_pk (ids) 목록'
            description='데이터 스트림 Primary Key(fm_pk) 값들. 내부에서 200개씩 분할 전송.')
        public List<String> ids;
        @InvocableVariable(required=true label='Source API 이름 (Ingestion API 소스명)'
            description='Ingestion API 커넥터의 소스 API 이름. 예: Ingestion_Refill_Test')
        public String sourceApi;
        @InvocableVariable(required=true label='Object 이름 (YAML 스키마 object명)'
            description='Ingestion 스키마의 object 이름. 예: order_original (DLO의 __dll 이름 아님)')
        public String objectName;
        @InvocableVariable(required=true label='Named Credential 이름'
            description='a360 토큰을 주입하는 Named Credential. 예: DataCloud_Ingest')
        public String namedCredential;
    }

    public class Result {
        @InvocableVariable public Integer requested;
        @InvocableVariable public Integer accepted;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String  message;
    }

    @InvocableMethod(label='Data Cloud Ingestion Delete'
                     description='fm_pk 목록을 Ingestion DELETE API 로 삭제 (전역 200 청크, 202 async)')
    public static List<Result> run(List<Request> requests) {
        // 1) 타겟(source||object||nc)별로 ids 취합
        Map<String, List<String>> idsByKey  = new Map<String, List<String>>();
        Map<String, List<String>> metaByKey = new Map<String, List<String>>();
        for (Request req : requests) {
            List<String> t = resolveTarget(req);
            String key = String.join(t, '||');
            if (!idsByKey.containsKey(key)) {
                idsByKey.put(key, new List<String>());
                metaByKey.put(key, t);
            }
            if (req.ids != null) {
                idsByKey.get(key).addAll(req.ids);
            }
        }

        // 2) 타겟별 전송 (전역 200 청크)
        Map<String, Result> resByKey = new Map<String, Result>();
        for (String key : idsByKey.keySet()) {
            resByKey.put(key, sendAll(metaByKey.get(key), idsByKey.get(key)));
        }

        // 3) 요청 수와 동일 크기로 결과 매핑 (Flow 출력 매핑 요건)
        List<Result> out = new List<Result>();
        for (Request req : requests) {
            out.add(resByKey.get(String.join(resolveTarget(req), '||')));
        }
        return out;
    }

    private static List<String> resolveTarget(Request req) {
        // 세 값 모두 호출자(Flow 등)가 명시 — 하드코딩된 기본값 없음 (범용)
        return new List<String>{
            req.sourceApi       == null ? '' : req.sourceApi.trim(),
            req.objectName      == null ? '' : req.objectName.trim(),
            req.namedCredential == null ? '' : req.namedCredential.trim()
        };
    }

    private static Result sendAll(List<String> meta, List<String> ids) {
        String src = meta[0], obj = meta[1], nc = meta[2];
        Result res = new Result();
        res.requested = ids.size();
        res.accepted  = 0;
        res.success   = true;
        if (ids.isEmpty()) {
            res.success = false; res.message = 'ids 가 비어있습니다.'; return res;
        }
        if (String.isBlank(src) || String.isBlank(obj) || String.isBlank(nc)) {
            res.success = false; res.message = 'sourceApi / objectName / namedCredential 은 필수입니다.'; return res;
        }

        String base = 'callout:' + nc + '/api/v1/ingest/sources/'
            + EncodingUtil.urlEncode(src, 'UTF-8').replace('+', '%20') + '/'
            + EncodingUtil.urlEncode(obj, 'UTF-8').replace('+', '%20');

        Integer total = ids.size();
        for (Integer i = 0; i < total; i += CHUNK) {
            Integer stop = i + CHUNK;
            if (stop > total) { stop = total; }
            List<String> chunk = new List<String>();
            for (Integer k = i; k < stop; k++) {
                chunk.add(ids[k]);
            }

            HttpRequest r = new HttpRequest();
            r.setEndpoint(base);
            r.setMethod('DELETE');
            r.setHeader('Content-Type', 'application/json');
            r.setTimeout(120000);
            r.setBody(JSON.serialize(new Map<String, Object>{ 'ids' => chunk }));

            HttpResponse resp = new Http().send(r);
            if (resp.getStatusCode() == 202) {
                res.accepted += chunk.size();
            } else {
                res.success = false;
                res.message = 'DELETE 실패 (offset ' + String.valueOf(i) + '): '
                    + String.valueOf(resp.getStatusCode()) + ' ' + resp.getBody();
                return res;
            }
        }
        res.message = 'OK (' + String.valueOf(res.accepted) + '/' + String.valueOf(res.requested) + ' 접수, 202 async)';
        return res;
    }
}
