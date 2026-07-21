/**
 * DataCloudIngestDelete 테스트. NC 콜아웃(DELETE)만 목으로 대체.
 * (토큰은 Named Credential 이 주입하므로 이 클래스는 토큰 콜아웃을 하지 않음)
 */
@IsTest
private class DataCloudIngestDeleteTest {

    private class Mock implements HttpCalloutMock {
        private Integer code; private String body;
        Mock(Integer c, String b) { code = c; body = b; }
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('DELETE', req.getMethod());
            System.assert(req.getEndpoint().startsWith('callout:'), 'NC 콜아웃');
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code); r.setBody(body);
            return r;
        }
    }

    private static DataCloudIngestDelete.Request req(List<String> ids) {
        DataCloudIngestDelete.Request q = new DataCloudIngestDelete.Request();
        q.ids = ids;
        q.sourceApi = 'Ingestion_Refill_Test';
        q.objectName = 'order_original';
        q.namedCredential = 'DataCloud_Ingest';
        return q;
    }

    @IsTest
    static void deleteSuccess() {
        Test.setMock(HttpCalloutMock.class, new Mock(202, '{"accepted":true}'));
        Test.startTest();
        List<DataCloudIngestDelete.Result> out = DataCloudIngestDelete.run(
            new List<DataCloudIngestDelete.Request>{ req(new List<String>{ 'a|b|c', '단품|#|x' }) });
        Test.stopTest();
        System.assertEquals(true, out[0].success);
        System.assertEquals(2, out[0].accepted);
    }

    @IsTest
    static void deleteApiError() {
        Test.setMock(HttpCalloutMock.class, new Mock(400, '{"error":"bad"}'));
        Test.startTest();
        List<DataCloudIngestDelete.Result> out = DataCloudIngestDelete.run(
            new List<DataCloudIngestDelete.Request>{ req(new List<String>{ 'pk1' }) });
        Test.stopTest();
        System.assertEquals(false, out[0].success);
    }

    @IsTest
    static void chunkingOver200() {
        Test.setMock(HttpCalloutMock.class, new Mock(202, '{"accepted":true}'));
        List<String> ids = new List<String>();
        for (Integer i = 0; i < 250; i++) ids.add('pk' + i);   // 2 청크
        Test.startTest();
        List<DataCloudIngestDelete.Result> out = DataCloudIngestDelete.run(
            new List<DataCloudIngestDelete.Request>{ req(ids) });
        Test.stopTest();
        System.assertEquals(250, out[0].accepted);
    }

    @IsTest
    static void emptyIds() {
        Test.startTest();
        List<DataCloudIngestDelete.Result> out = DataCloudIngestDelete.run(
            new List<DataCloudIngestDelete.Request>{ req(new List<String>()) });
        Test.stopTest();
        System.assertEquals(false, out[0].success);
    }
}
