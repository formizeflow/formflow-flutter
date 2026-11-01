import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Response of POST /api/v1/public/onboarding/decide.
class FormFlowDecision {
  const FormFlowDecision({
    required this.show,
    this.experimentId,
    this.variantId,
    this.formId,
    this.slug,
    this.versionId,
    required this.reason,
    this.fromCache = false,
  });
  final bool show;
  final String? experimentId, variantId, formId, slug, versionId;
  final String reason;

  /// Set by the SDK when the network failed and a cached decision was returned.
  final bool fromCache;

  /// Accepts `{data: {...}}` or the bare object; null for junk.
  static FormFlowDecision? parse(String raw) {
    try {
      final r = jsonDecode(raw);
      if (r is! Map) return null;
      final o = (r['data'] is Map) ? r['data'] as Map : r;
      if (o['show'] is! bool) return null;
      String? s(String k) => o[k] is String ? o[k] as String : null;
      return FormFlowDecision(
        show: o['show'] as bool,
        experimentId: s('experimentId'),
        variantId: s('variantId'),
        formId: s('formId'),
        slug: s('slug'),
        versionId: s('versionId'),
        reason: s('reason') ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  String toJson() => jsonEncode({
    'show': show,
    'experimentId': experimentId,
    'variantId': variantId,
    'formId': formId,
    'slug': slug,
    'versionId': versionId,
    'reason': reason,
  });

  /// A config for this decision, or null when the flow must be skipped (holdout, completed, no match).
  FormFlowConfig? config(FormFlowConfig base) => show && slug != null
      ? base.copyWith(slug: slug, variant: variantId)
      : null;
}

/// Plug in shared_preferences (or anything) to keep decisions across launches. Default: memory only.
abstract class FormFlowStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FormFlowClient {
  FormFlowClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 8),
    this.storage,
    http.Client? client,
  }) : _http = client ?? http.Client();
  final String baseUrl;
  final Duration timeout;
  final FormFlowStorage? storage;
  final http.Client _http;
  final Map<String, FormFlowDecision> _mem = {};

  String _key(String entry, String? uid) =>
      'formflow.decision.$entry.${uid ?? 'anon'}';

  Future<FormFlowDecision?> cached(String entry, {String? uid}) async {
    final k = _key(entry, uid);
    if (_mem[k] != null) return _mem[k];
    final raw = await storage?.read(k);
    return raw == null ? null : FormFlowDecision.parse(raw);
  }

  /// Ask the server whether to show the flow. On network failure returns the cached decision (fromCache) or rethrows.
  Future<FormFlowDecision> decide({
    required String entry,
    String? uid,
    String? uidSignature,
    Map<String, String> attributes = const {},
    String? appVersion,
    String? posthogSessionId,
    String? posthogDistinctId,
  }) async {
    try {
      final body = <String, Object?>{
        'entry': entry,
        if (uid != null) 'uid': uid,
        if (uidSignature != null) 'uid_sig': uidSignature,
        'attributes': FormFlowConfig(
          baseUrl: baseUrl,
          slug: 'x',
          attributes: attributes,
          appVersion: appVersion,
        ).resolvedAttributes(),
        if (posthogSessionId != null) 'ph_session': posthogSessionId,
        if (posthogDistinctId != null) 'ph_distinct': posthogDistinctId,
      };
      final res = await _http
          .post(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/public/onboarding/decide',
            ),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (res.statusCode != 200)
        throw http.ClientException('decide ${res.statusCode}');
      final d =
          FormFlowDecision.parse(res.body) ??
          (throw const FormatException('bad decision'));
      _mem[_key(entry, uid)] = d;
      storage?.write(_key(entry, uid), d.toJson());
      return d;
    } catch (_) {
      final c = await cached(entry, uid: uid);
      if (c != null)
        return FormFlowDecision(
          show: c.show,
          experimentId: c.experimentId,
          variantId: c.variantId,
          formId: c.formId,
          slug: c.slug,
          versionId: c.versionId,
          reason: c.reason,
          fromCache: true,
        );
      rethrow;
    }
  }

  /// Warm the decision cache. Never throws.
  Future<FormFlowDecision?> preload({
    required String entry,
    String? uid,
    String? uidSignature,
    Map<String, String> attributes = const {},
  }) async {
    try {
      return await decide(
        entry: entry,
        uid: uid,
        uidSignature: uidSignature,
        attributes: attributes,
      );
    } catch (_) {
      return null;
    }
  }
}
