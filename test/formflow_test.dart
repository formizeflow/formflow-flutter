import 'package:flutter_test/flutter_test.dart';
import 'package:formizeflow/formflow.dart';

void main() {
  test('url encodes everything', () {
    const c = FormFlowConfig(
      baseUrl: 'https://f.example.com/',
      slug: 'on boarding',
      uid: 'u 1&x',
      variant: 'v2',
      locale: 'de',
      hidden: {'plan': 'pro/1'},
      prefill: {'email': 'a+b@c.co'},
      includeAnswers: true,
      autoAttributes: false,
    );
    expect(
      c.url(),
      'https://f.example.com/embed/on%20boarding?native=1&uid=u%201%26x&variant=v2&lang=de&answers=1&hidden.plan=pro%2F1&prefill.email=a%2Bb%40c.co',
    );
  });

  test('identity, appearance, attributes', () {
    const c = FormFlowConfig(
      baseUrl: 'https://f.co',
      slug: 'x',
      uid: 'u',
      uidSignature: 'ab/c=',
      posthogSessionId: 's1',
      posthogDistinctId: 'd1',
      resume: false,
      appearance: FormFlowAppearance(
        colorScheme: FormFlowColorScheme.dark,
        accent: '#112233',
        fontFamily: 'Inter',
      ),
      attributes: {'plan': 'pro'},
      autoAttributes: false,
    );
    expect(
      c.url(),
      'https://f.co/embed/x?native=1&uid=u&uid_sig=ab%2Fc%3D&resume=0&ph_session=s1&ph_distinct=d1&scheme=dark&accent=%23112233&font=Inter&attrs.plan=pro',
    );
  });

  test('answers off by default; navigation allow-list', () {
    const c = FormFlowConfig(
      baseUrl: 'https://f.example.com',
      slug: 'x',
      autoAttributes: false,
    );
    expect(c.url(), 'https://f.example.com/embed/x?native=1');
    expect(c.isAllowed('https://f.example.com/embed/x'), true);
    expect(c.isAllowed('https://f.example.com.evil.com/'), false);
    expect(c.isAllowed('https://evil.com/'), false);
  });

  test('parses ready, step, answer', () {
    final r = FormFlowEvent.parse(
      '{"source":"formflow","type":"ready","formId":"f1","data":{"formId":"f1","versionId":"v9","experimentId":"e1","variantId":"b","locale":"en"}}',
    ) as FormFlowReady;
    expect(
      [r.formId, r.versionId, r.experimentId, r.variantId, r.locale],
      ['f1', 'v9', 'e1', 'b', 'en'],
    );
    final s = FormFlowEvent.parse(
      '{"source":"formflow","type":"step","data":{"index":2,"fieldId":"a","total":5}}',
    ) as FormFlowStep;
    expect([s.index, s.fieldId, s.total], [2, 'a', 5]);
    final a = FormFlowEvent.parse(
      '{"source":"formflow","type":"answer","data":{"fieldId":"a","type":"short_text"}}',
    ) as FormFlowAnswer;
    expect(a.value, isNull);
    final v = FormFlowEvent.parse(
      '{"source":"formflow","type":"answer","data":{"fieldId":"a","type":"short_text","value":"hi"}}',
    ) as FormFlowAnswer;
    expect(v.value, 'hi');
  });

  test('parses complete with answers and request', () {
    final c = FormFlowEvent.parse(
      '{"source":"formflow","type":"complete","data":{"submissionId":"s1","outcome":{"passed":true,"endingId":"end"},"endingId":"end","durationMs":1200,"answers":{"a":"x","m":["p","q"]}}}',
    ) as FormFlowComplete;
    expect(c.submissionId, 's1');
    expect(c.outcome, const FormFlowOutcome(passed: true, endingId: 'end'));
    expect(c.durationMs, 1200);
    expect(c.answers!['m'], ['p', 'q']);
    final r = FormFlowEvent.parse(
      '{"source":"formflow","type":"request","data":{"requestId":"r1","action":"notifications","params":{"topic":"news"}}}',
    ) as FormFlowRequestEvent;
    expect(
      [r.request.requestId, r.request.action, r.request.params['topic']],
      ['r1', 'notifications', 'news'],
    );
  });

  test('ignores foreign and folded messages', () {
    expect(FormFlowEvent.parse('garbage'), isNull);
    expect(FormFlowEvent.parse('{"source":"other","type":"close"}'), isNull);
    expect(
      FormFlowEvent.parse('{"source":"formflow","type":"submit","data":{}}'),
      isNull,
    );
    expect(
      FormFlowEvent.parse('{"source":"formflow","type":"close","data":{}}'),
      isA<FormFlowClose>(),
    );
  });

  test('decisions', () {
    final d = FormFlowDecision.parse(
      '{"data":{"show":true,"variantId":"b","slug":"onb","reason":"variant"}}',
    )!;
    const base = FormFlowConfig(
      baseUrl: 'https://f.co',
      slug: '',
      autoAttributes: false,
    );
    expect(d.config(base)!.variant, 'b');
    expect(d.config(base)!.slug, 'onb');
    expect(
      FormFlowDecision.parse('{"show":false,"reason":"holdout"}')!.config(base),
      isNull,
    );
    expect(FormFlowDecision.parse('nope'), isNull);
  });
}
