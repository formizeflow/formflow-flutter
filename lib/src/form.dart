import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'config.dart';
import 'events.dart';

/// Hold one to call [restart] (start over, ignoring saved progress) or [respond].
class FormFlowController {
  _FormFlowFormState? _s;
  void restart() => _s?._restart();
  void respond(String requestId, Object? result) =>
      _s?._respond(requestId, result);
}

class FormFlowForm extends StatefulWidget {
  const FormFlowForm({
    super.key,
    required this.config,
    this.controller,
    this.onReady,
    this.onStart,
    this.onStep,
    this.onAnswer,
    this.onComplete,
    this.onClose,
    this.onError,
    this.onTimeout,
    this.onRequest,
    this.onEvent,
  });

  final FormFlowConfig config;
  final FormFlowController? controller;
  final void Function(FormFlowReady)? onReady;
  final VoidCallback? onStart;
  final void Function(FormFlowStep)? onStep;
  final void Function(FormFlowAnswer)? onAnswer;
  final void Function(FormFlowComplete)? onComplete;
  final VoidCallback? onClose;
  final void Function(String message)? onError;

  /// The form was not ready in time or failed to load. Carry on with your own flow.
  final VoidCallback? onTimeout;

  /// Answer a form request (notifications, tracking, deep link, custom). The return value goes back to the form.
  final Future<Object?> Function(FormFlowRequest)? onRequest;
  final void Function(FormFlowEvent)? onEvent;

  @override
  State<FormFlowForm> createState() => _FormFlowFormState();
}

/// Route one event to the matching callbacks (exported for tests).
void dispatchFormFlowEvent(FormFlowEvent e, FormFlowForm w) {
  switch (e) {
    case FormFlowReady():
      w.onReady?.call(e);
    case FormFlowStart():
      w.onStart?.call();
    case FormFlowStep():
      w.onStep?.call(e);
    case FormFlowAnswer():
      w.onAnswer?.call(e);
    case FormFlowComplete():
      w.onComplete?.call(e);
    case FormFlowClose():
      w.onClose?.call();
    case FormFlowError():
      w.onError?.call(e.message);
    default:
      break;
  }
  w.onEvent?.call(e);
}

class _FormFlowFormState extends State<FormFlowForm> {
  late final WebViewController _web;
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._s = this;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FormFlowFlutter',
        onMessageReceived: (m) => _onMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            if (widget.config.isAllowed(r.url))
              return NavigationDecision.navigate;
            final u = Uri.tryParse(r.url);
            if (u != null && (u.scheme == 'https' || u.scheme == 'http'))
              launchUrl(u, mode: LaunchMode.inAppBrowserView);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) {
              widget.onError?.call(e.description);
              _timedOut();
            }
          },
        ),
      );
    _boot();
  }

  Future<void> _boot() async {
    try {
      final ua = await _web.getUserAgent();
      if (ua != null) await _web.setUserAgent('$ua $formFlowUserAgentSuffix');
    } catch (_) {
      /* keep the default user agent */
    }
    if (mounted) _load();
  }

  void _load({bool restart = false}) {
    _ready = false;
    _timer?.cancel();
    _timer = Timer(widget.config.timeout, _timedOut);
    _web.loadRequest(Uri.parse(widget.config.url(restart: restart)));
  }

  void _timedOut() {
    if (_ready) return;
    _ready = true;
    _timer?.cancel();
    widget.onTimeout?.call();
  }

  void _restart() => _load(restart: true);

  void _respond(String requestId, Object? result) {
    final msg = jsonEncode(
      jsonEncode({'type': 'respond', 'requestId': requestId, 'result': result}),
    );
    _web.runJavaScript(
      'window.FormFlow&&window.FormFlow.native&&window.FormFlow.native.receive($msg);',
    );
  }

  void _onMessage(String raw) {
    final e = FormFlowEvent.parse(raw);
    if (e == null || !mounted) return;
    if (e is FormFlowReady) {
      _ready = true;
      _timer?.cancel();
    }
    if (e is FormFlowRequestEvent && widget.onRequest != null) {
      widget.onRequest!(e.request).then(
        (r) => _respond(e.request.requestId, r),
        onError: (_) => _respond(e.request.requestId, 'error'),
      );
    }
    dispatchFormFlowEvent(e, widget);
  }

  @override
  void didUpdateWidget(FormFlowForm old) {
    super.didUpdateWidget(old);
    if (old.config.url() != widget.config.url()) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.controller?._s == this) widget.controller?._s = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
