import 'dart:io' show Platform;

const formFlowVersion = '0.1.0';
const formFlowUserAgentSuffix = 'FormFlowFlutter/$formFlowVersion';

enum FormFlowColorScheme { light, dark, system }

class FormFlowAppearance {
  const FormFlowAppearance({this.colorScheme, this.accent, this.fontFamily});
  final FormFlowColorScheme? colorScheme;

  /// `#rrggbb`
  final String? accent;
  final String? fontFamily;
}

class FormFlowConfig {
  const FormFlowConfig({
    required this.baseUrl,
    required this.slug,
    this.uid,
    this.uidSignature,
    this.variant,
    this.locale,
    this.hidden = const {},
    this.prefill = const {},
    this.attributes = const {},
    this.autoAttributes = true,
    this.appVersion,
    this.posthogSessionId,
    this.posthogDistinctId,
    this.resume,
    this.appearance,
    this.includeAnswers = false,
    this.showClose = false,
    this.timeout = const Duration(seconds: 8),
  });

  final String baseUrl;
  final String slug;
  final String? uid;

  /// HMAC of [uid] computed on YOUR server. Never sign in the app.
  final String? uidSignature;
  final String? variant;
  final String? locale;
  final Map<String, String> hidden;
  final Map<String, String> prefill;

  /// User attributes (attrs.<key>). platform, os_version and locale are added when [autoAttributes] is on.
  final Map<String, String> attributes;
  final bool autoAttributes;
  final String? appVersion;
  final String? posthogSessionId;
  final String? posthogDistinctId;

  /// false starts over instead of resuming saved progress (server-side, per uid).
  final bool? resume;
  final FormFlowAppearance? appearance;
  final bool includeAnswers;
  final bool showClose;
  final Duration timeout;

  FormFlowConfig copyWith({String? slug, String? variant}) => FormFlowConfig(
    baseUrl: baseUrl,
    slug: slug ?? this.slug,
    uid: uid,
    uidSignature: uidSignature,
    variant: variant ?? this.variant,
    locale: locale,
    hidden: hidden,
    prefill: prefill,
    attributes: attributes,
    autoAttributes: autoAttributes,
    appVersion: appVersion,
    posthogSessionId: posthogSessionId,
    posthogDistinctId: posthogDistinctId,
    resume: resume,
    appearance: appearance,
    includeAnswers: includeAnswers,
    showClose: showClose,
    timeout: timeout,
  );

  Map<String, String> resolvedAttributes() {
    final auto = <String, String>{};
    if (autoAttributes) {
      try {
        auto['platform'] = Platform.operatingSystem;
        auto['os_version'] = Platform.operatingSystemVersion;
        auto['locale'] = locale ?? Platform.localeName;
      } catch (_) {
        /* web */
      }
      if (appVersion != null) auto['app_version'] = appVersion!;
    }
    return {...auto, ...attributes};
  }

  static String _e(String s) =>
      Uri.encodeQueryComponent(s).replaceAll('+', '%20');

  /// `<baseUrl>/embed/<slug>?native=1&uid=&uid_sig=&variant=&lang=&answers=1&close=1&resume=0&ph_*&scheme&accent&font&hidden.x=&prefill.y=&attrs.z=`
  String url({bool restart = false}) {
    final q = <String>['native=1'];
    if (uid != null && uid!.isNotEmpty) q.add('uid=${_e(uid!)}');
    if (uidSignature != null && uidSignature!.isNotEmpty)
      q.add('uid_sig=${_e(uidSignature!)}');
    if (variant != null && variant!.isNotEmpty)
      q.add('variant=${_e(variant!)}');
    if (locale != null && locale!.isNotEmpty) q.add('lang=${_e(locale!)}');
    if (includeAnswers) q.add('answers=1');
    if (showClose) q.add('close=1');
    if (resume == false || restart) q.add('resume=0');
    if (posthogSessionId != null && posthogSessionId!.isNotEmpty)
      q.add('ph_session=${_e(posthogSessionId!)}');
    if (posthogDistinctId != null && posthogDistinctId!.isNotEmpty)
      q.add('ph_distinct=${_e(posthogDistinctId!)}');
    final a = appearance;
    if (a?.colorScheme != null) q.add('scheme=${a!.colorScheme!.name}');
    if (a?.accent != null) q.add('accent=${_e(a!.accent!)}');
    if (a?.fontFamily != null) q.add('font=${_e(a!.fontFamily!)}');
    for (final k in (hidden.keys.toList()..sort())) {
      q.add('hidden.${_e(k)}=${_e(hidden[k]!)}');
    }
    for (final k in (prefill.keys.toList()..sort())) {
      q.add('prefill.${_e(k)}=${_e(prefill[k]!)}');
    }
    final attrs = resolvedAttributes();
    for (final k in (attrs.keys.toList()..sort())) {
      q.add('attrs.${_e(k)}=${_e(attrs[k]!)}');
    }
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/embed/${_e(slug)}?${q.join('&')}';
  }

  /// Only the configured host may load inside the WebView.
  bool isAllowed(String url) {
    if (url == 'about:blank') return true;
    final h = Uri.tryParse(url)?.host.toLowerCase();
    final b = Uri.tryParse(baseUrl)?.host.toLowerCase();
    return h != null && h.isNotEmpty && h == b;
  }
}
