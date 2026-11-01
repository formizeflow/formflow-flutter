import 'dart:convert';

class FormFlowOutcome {
  const FormFlowOutcome({this.passed, this.outcomeId, this.endingId});
  final bool? passed;
  final String? outcomeId;
  final String? endingId;
  @override
  bool operator ==(Object o) =>
      o is FormFlowOutcome &&
      o.passed == passed &&
      o.outcomeId == outcomeId &&
      o.endingId == endingId;
  @override
  int get hashCode => Object.hash(passed, outcomeId, endingId);
}

/// The form asks the app to do something: notifications, tracking, open a URL, sign in, deep link, or a custom name.
class FormFlowRequest {
  const FormFlowRequest(this.requestId, this.action, this.params);
  final String requestId;
  final String action;
  final Map<String, String> params;
}

sealed class FormFlowEvent {
  const FormFlowEvent();

  /// Parse a JavaScriptChannel message. Null for anything that is not a FormFlow message. `submit` and `resize` are dropped (`complete` follows `submit`).
  static FormFlowEvent? parse(String raw) {
    Object? j;
    try {
      j = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (j is! Map || j['source'] != 'formflow') return null;
    final d = (j['data'] is Map)
        ? Map<String, dynamic>.from(j['data'] as Map)
        : <String, dynamic>{};
    switch (j['type']) {
      case 'ready':
        return FormFlowReady(
          formId: (d['formId'] ?? j['formId'] ?? '') as String,
          versionId: d['versionId'] as String?,
          experimentId: d['experimentId'] as String?,
          variantId: d['variantId'] as String?,
          locale: (d['locale'] ?? '') as String,
        );
      case 'view':
        return const FormFlowView();
      case 'start':
        return const FormFlowStart();
      case 'step':
        if (d['index'] is! num || d['total'] is! num) return null;
        return FormFlowStep(
          index: (d['index'] as num).toInt(),
          fieldId: (d['fieldId'] ?? '') as String,
          total: (d['total'] as num).toInt(),
        );
      case 'answer':
        if (d['fieldId'] is! String) return null;
        return FormFlowAnswer(
          fieldId: d['fieldId'] as String,
          type: (d['type'] ?? 'unknown') as String,
          value: d['value'],
        );
      case 'complete':
        if (d['submissionId'] is! String) return null;
        final oc = (d['outcome'] is Map)
            ? Map<String, dynamic>.from(d['outcome'] as Map)
            : <String, dynamic>{};
        return FormFlowComplete(
          submissionId: d['submissionId'] as String,
          outcome: FormFlowOutcome(
            passed: oc['passed'] as bool?,
            outcomeId: oc['outcomeId'] as String?,
            endingId: oc['endingId'] as String?,
          ),
          endingId: d['endingId'] as String?,
          durationMs: (d['durationMs'] as num?)?.toInt(),
          answers: d['answers'] is Map
              ? Map<String, dynamic>.from(d['answers'] as Map)
              : null,
        );
      case 'request':
        if (d['requestId'] is! String || d['action'] is! String) return null;
        final p = d['params'] is Map
            ? (d['params'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : <String, String>{};
        return FormFlowRequestEvent(
          FormFlowRequest(d['requestId'] as String, d['action'] as String, p),
        );
      case 'progress':
        if (d['step'] is! num || d['total'] is! num) return null;
        return FormFlowProgress(
          step: (d['step'] as num).toInt(),
          total: (d['total'] as num).toInt(),
          percent: ((d['percent'] ?? 0) as num).toInt(),
        );
      case 'close':
        return const FormFlowClose();
      case 'error':
        return FormFlowError((d['message'] ?? '') as String);
    }
    return null;
  }
}

class FormFlowReady extends FormFlowEvent {
  const FormFlowReady({
    required this.formId,
    this.versionId,
    this.experimentId,
    this.variantId,
    required this.locale,
  });
  final String formId;
  final String? versionId, experimentId, variantId;
  final String locale;
}

class FormFlowView extends FormFlowEvent {
  const FormFlowView();
}

class FormFlowStart extends FormFlowEvent {
  const FormFlowStart();
}

class FormFlowStep extends FormFlowEvent {
  const FormFlowStep({
    required this.index,
    required this.fieldId,
    required this.total,
  });
  final int index;
  final String fieldId;
  final int total;
}

class FormFlowAnswer extends FormFlowEvent {
  const FormFlowAnswer({required this.fieldId, required this.type, this.value});
  final String fieldId, type;

  /// Present only with includeAnswers and a non-sensitive field.
  final Object? value;
}

class FormFlowComplete extends FormFlowEvent {
  const FormFlowComplete({
    required this.submissionId,
    required this.outcome,
    this.endingId,
    this.durationMs,
    this.answers,
  });
  final String submissionId;
  final FormFlowOutcome outcome;
  final String? endingId;
  final int? durationMs;
  final Map<String, dynamic>? answers;
}

class FormFlowRequestEvent extends FormFlowEvent {
  const FormFlowRequestEvent(this.request);
  final FormFlowRequest request;
}

class FormFlowProgress extends FormFlowEvent {
  const FormFlowProgress({
    required this.step,
    required this.total,
    required this.percent,
  });
  final int step, total, percent;
}

class FormFlowClose extends FormFlowEvent {
  const FormFlowClose();
}

class FormFlowError extends FormFlowEvent {
  const FormFlowError(this.message);
  final String message;
}
